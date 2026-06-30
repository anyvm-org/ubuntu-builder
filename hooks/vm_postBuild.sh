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
