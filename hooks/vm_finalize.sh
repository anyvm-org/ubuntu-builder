# Image-slimming finalize. Runs as the LAST in-guest hook, after postBuild
# and the VM_PRE_INSTALL_PKGS apt installs.
#
# NOTE: do NOT remove /var/lib/apt/lists here. The images deliberately ship
# pre-baked apt lists so users (and the vmactions VM_PREPARE step) can
# `apt-get install` without an `apt-get update`, which is painfully slow on
# the TCG-emulated arches (see the note in vm_postBuild.sh). Only the
# package archive cache is dropped.

echo "=== finalize: image cleanup ==="

# Drop cached .deb archives fetched by the build's installs.
apt-get clean || true

# TRIM every mounted filesystem: the build disk runs with discard=unmap,
# so freed ext4 blocks (package churn, kernel/u-boot leftovers) become
# holes in the qcow2 and the export-time sparsify reclaims them.
fstrim -av || true

df -h || true
echo "=== finalize: image cleanup done ==="
