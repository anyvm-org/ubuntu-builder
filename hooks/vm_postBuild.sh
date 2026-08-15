# in-guest postBuild hook (piped to the guest's sh over SSH by build.py).
#
# Keep everything tolerant: build.py runs this over the remote shell with
# the remote shell exiting non-zero on any unhandled error, and one apt
# hiccup should not abort the whole build.
#
# IMPORTANT: do NOT run `apt-get update` here. On a TCG aarch64 / riscv64
# guest the post-fetch dpkg trigger phase (man-db rebuild, icon caches,
# etc.) silently chews 25-30 min of CPU on a 2-core GHA runner, which
# blocks the SSH session and looks like the build has hung. The cloud
# image's pre-baked /var/lib/apt/lists is good enough for the
# `apt-get install $VM_PRE_INSTALL_PKGS` step that build.py runs after
# the reboot.

export DEBIAN_FRONTEND=noninteractive

echo "=================== ubuntu postBuild ===="

# Make sure sshd survives the reboot that build.py does right after this
# hook. systemctl is fast even on TCG, so no timeout wrapper needed.
echo "--- enabling ssh.service ---"
systemctl enable ssh.service 2>/dev/null || systemctl enable ssh 2>/dev/null || true

# --- kill the background apt auto-update machinery ----------------------
# Ubuntu cloud images ship apt-daily.timer / apt-daily-upgrade.timer plus
# unattended-upgrades, all of which fire within a couple of minutes of every
# boot and take the dpkg frontend lock. A short-lived VM is handed to the
# user the moment sshd answers, so the user's very first command races them:
#
#   E: Could not get lock /var/lib/dpkg/lock-frontend.
#      It is held by process 989 (apt-get)
#
# apt then exits 100 and the job fails. Seen in vmactions/ubuntu-vm run
# 31873383879: the VM went ready at 08:14:23, apt-daily-upgrade.service had
# started at 08:13:58, and the `prepare: apt-get install -y socat` step died
# 16s later. Nothing in a disposable CI VM benefits from background upgrades
# -- they only mutate the system underneath the job -- so switch them off
# permanently.
#
# Order matters: stop anything already running (a mask does not stop a live
# unit), then disable, then mask so a later package upgrade cannot quietly
# re-enable the units. This block must stay AHEAD of every apt-get in this
# hook, and it protects the VM_PRE_INSTALL_PKGS install build.py runs after
# the reboot as well.
echo "--- disabling apt auto-update timers/services ---"
_apt_auto_units="apt-daily.timer apt-daily-upgrade.timer apt-daily.service
apt-daily-upgrade.service unattended-upgrades.service"
systemctl stop $_apt_auto_units 2>/dev/null || true
systemctl disable apt-daily.timer apt-daily-upgrade.timer \
    unattended-upgrades.service 2>/dev/null || true
systemctl mask $_apt_auto_units 2>/dev/null || true

# Belt and braces, and the part that survives a systemd-unit reshuffle: with
# every APT::Periodic interval at 0 the periodic work is a no-op even if a
# unit comes back. This is the same file the cloud image ships.
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'APTAUTOEOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::AutocleanInterval "0";
APTAUTOEOF

# Make apt-get WAIT for the dpkg lock instead of dying on it. apt ships a
# 120s default for its own `apt` frontend but leaves `apt-get` -- the one
# every script and CI job actually calls -- at 0, i.e. fail immediately:
#
#   $ apt-config dump | grep -i lock::timeout
#   binary::apt::DPkg::Lock::Timeout "120";
#
# That asymmetry is the whole reason `apt-get install` reports the lock as a
# hard error. Setting it globally makes apt-get behave like apt. This is the
# safety net for anything that grabs the lock that we did NOT disable above
# (a user's own background job, a cloud-init module still finishing), so
# keep it even though the auto-update units are masked. Supported since apt
# 2.0; the oldest release built here is jammy with apt 2.4.5.
cat > /etc/apt/apt.conf.d/99anyvm-lock-timeout <<'APTLOCKEOF'
DPkg::Lock::Timeout "120";
APTLOCKEOF

# Wait out an upgrade that was already mid-flight when we stopped it, so the
# apt-get calls below (and build.py's install step) find the lock free.
_n=0
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && [ $_n -lt 60 ]; do
    [ $_n -eq 0 ] && echo "--- waiting for the dpkg lock to be released ---"
    _n=$((_n + 1))
    sleep 5
done

# NOTE: do NOT run "cloud-init clean" here. build.py reboots right after
# this hook, and a clean makes cloud-init treat the next boot as a new
# instance, which (via ssh_deletekeys) regenerates the SSH host keys. The
# host key for the VM's IP then changes mid-build and the next "ssh"
# fails with "REMOTE HOST IDENTIFICATION HAS CHANGED".

# --- 22.04 riscv64 only: convert the artifact from extlinux to EFI grub ---
# The jammy riscv64 cloud image boots ONLY via u-boot's extlinux/sysboot
# path (/boot/extlinux on the root partition; the ESP is EMPTY -- no grub).
# That path is broken on u-boot >= 2024.10 (LMB rework: the in-place FDT
# reservation fails -> "FDT creation failed! hanging..."), and EDK2 UEFI
# cannot boot the image at all (nothing on the ESP to load). The BUILD
# survives because build.py launches QEMU with the pinned u-boot 2024.01
# from files/ (see files/README.md), but end users run whatever firmware
# their host provides. So give the artifact the layout noble ships: grub
# on the ESP fallback path (EFI/BOOT/BOOTRISCV64.EFI) and no extlinux.
# That boots under EDK2 AND any u-boot version (extlinux gone -> u-boot's
# distro scan falls through to the EFI path -> grub). The reboot build.py
# does right after this hook already exercises the new layout in CI.
if [ "$(uname -m)" = "riscv64" ] && grep -q 'VERSION_ID="22.04"' /etc/os-release; then
    echo "--- 22.04 riscv64: converting extlinux boot to EFI grub ---"
    mountpoint -q /boot/efi || mount /boot/efi || true
    # Try the image's pre-baked apt lists first (see the no-apt-get-update
    # note above); only fall back to a one-off `apt-get update` if the
    # pinned version has been rotated out of the ports pool.
    if apt-get install -y grub-efi-riscv64 \
        || { apt-get update && apt-get install -y grub-efi-riscv64; }; then
        if grub-install --target=riscv64-efi --efi-directory=/boot/efi \
              --removable --no-nvram \
            && update-grub; then
            # Purge u-boot-menu so a future kernel update does not
            # regenerate extlinux.conf via u-boot-update and re-break boot
            # on new u-boot (extlinux is scanned BEFORE the EFI fallback).
            apt-get purge -y u-boot-menu || true
            # Move (not delete) the extlinux dir out of u-boot's scan path.
            if [ -d /boot/extlinux ]; then
                mv /boot/extlinux /boot/extlinux.disabled
            fi
            echo "--- 22.04 riscv64: EFI grub conversion OK ---"
        else
            echo "WARNING: grub-install/update-grub failed; keeping extlinux"
        fi
    else
        echo "WARNING: grub-efi-riscv64 install failed; keeping extlinux"
    fi
fi




passwd -d root



echo "ubuntu postBuild done."

exit 0
