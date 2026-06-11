# In-guest install script for ubuntu (piped into the guest sh by build.py
# with ANYVM_PKGS prepended; runs under set -e).
#
# Ubuntu cloud images no longer ship usable pre-baked universe package
# indexes (s390x never had them; the amd64/arm64/riscv64 serials published
# around 2026-06-10 dropped them too), so a plain `apt-get install tree
# sshfs ...` fails with "E: Unable to locate package tree" (tree and sshfs
# live in universe) and the whole transaction aborts -- nfs-common and
# rsync then go missing as well. Refresh the indexes first.
#
# APT::Update::Post-Invoke-Success="" skips the post-update apt hooks
# (the command-not-found database rebuild in particular): they burn tens
# of minutes of CPU on TCG-emulated guests (the historical "apt-get update
# hang" on aarch64) and the build does not need them.
export DEBIAN_FRONTEND=noninteractive
apt-get update -o APT::Update::Post-Invoke-Success=""
apt-get install -y $ANYVM_PKGS
