# Image-slimming finalize. Runs as the LAST in-guest hook, after postBuild
# and the VM_PRE_INSTALL_PKGS apt installs.
#
# NOTE: do NOT remove /var/lib/apt/lists here. The images deliberately ship
# pre-baked apt lists so users (and the vmactions VM_PREPARE step) can
# `apt-get install` without an `apt-get update`, which is painfully slow on
# the TCG-emulated arches (see the note in vm_postBuild.sh). Only the
# package archive cache is dropped.

echo "=== finalize: image cleanup ==="

# --- 26.04+ only: slim the dracut initrd -------------------------------
# 26.04 replaced initramfs-tools with dracut, and the stock dracut initrd
# is 67M against 24.04's 30M. Its default module set covers storage stacks
# and boot paths this image cannot reach: the root is always a virtio-blk
# disk with an ext4 filesystem found by LABEL=cloudimg-rootfs (see the
# kernel cmdline the builder bakes), so there is no LVM, no RAID, no
# multipath, no dm-crypt, no btrfs, no network root -- and no console at
# all during initrd, which makes plymouth/i18n/console-setup dead weight
# too. Every omitted module is one less thing for udev to settle on.
#
# Measured locally on x86_64/KVM: initrd 67M -> 42M and roughly 0.5-1.0s
# off a ~10.5s boot -- real but inside this host's +-1.5s noise. The point
# is the TCG guests: the emulated arches amplify guest-side work ~30x
# (26.04 aarch64 boots in 360s in CI vs 222s for 24.04), so the CI legs are
# the measurement that matters, not a laptop.
#
# initramfs-tools images (24.04 and older) have no dracut and skip this.
#
# s390x is EXCLUDED, on evidence from run 31559841601 -- it is the one arch
# where this both gains nothing and breaks the image:
#
#   arch      stock   slim    post-export verification boot
#   x86_64     67M     42M    ok
#   aarch64    85M     64M    ok
#   ppc64le    70M     45M    ok
#   riscv64    73M     50M    ok
#   s390x      27M     26M    NEVER BECAME SSH-REACHABLE
#
# s390x ships far fewer drivers and firmware blobs, so its stock initrd is
# already a quarter the size of the others and there is nothing to trim --
# but the slimmed initrd stops booting: the verification VM wedges about
# 4.8s in with a kernel backtrace and the serial log freezes at 26 KB, twice
# in a row, 600s each. Which omitted module s390x actually needs was not
# determined; 1M of savings does not justify finding out.
_arch="$(uname -m 2>/dev/null || echo unknown)"
if [ "$_arch" = "s390x" ]; then
    echo "--- s390x: skipping the dracut slim (breaks boot, saves ~1M) ---"
elif command -v dracut >/dev/null 2>&1 && [ -d /etc/dracut.conf.d ]; then
    echo "--- slimming the dracut initrd ---"
    _kver="$(uname -r)"
    echo "before: $(ls -lh "/boot/initrd.img-$_kver" 2>/dev/null | awk '{print $5}')"
    cat > /etc/dracut.conf.d/99-anyvm-slim.conf <<'DRACUTEOF'
# Written by ubuntu-builder hooks/vm_finalize.sh -- see the rationale there.
omit_dracut_modules+=" plymouth btrfs crypt dm lvm mdraid multipath nvdimm overlayfs overlayfs-crypt systemd-cryptsetup fido2 systemd-battery-check systemd-pcrextend i18n console-setup network net-lib dyn-netconf systemd-networkd kernel-modules-extra "
DRACUTEOF
    if dracut -f --quiet; then
        echo "after:  $(ls -lh "/boot/initrd.img-$_kver" 2>/dev/null | awk '{print $5}')"
    else
        # A half-written initrd would brick every later boot of this image,
        # so put the stock configuration back and regenerate before giving
        # up. Slimming is an optimization; booting is not optional.
        echo "WARNING: dracut rebuild failed; restoring the stock initrd"
        rm -f /etc/dracut.conf.d/99-anyvm-slim.conf
        dracut -f || echo "WARNING: stock dracut rebuild ALSO failed"
    fi
fi

# Drop cached .deb archives fetched by the build's installs.
apt-get clean || true

# TRIM every mounted filesystem: the build disk runs with discard=unmap,
# so freed ext4 blocks (package churn, kernel/u-boot leftovers) become
# holes in the qcow2 and the export-time sparsify reclaims them.
fstrim -av || true

df -h || true
echo "=== finalize: image cleanup done ==="
