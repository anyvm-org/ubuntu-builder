# In-guest install script for s390x (piped into the guest sh by build.py
# with ANYVM_PKGS prepended; runs under set -e).
#
# Unlike the amd64/arm64/riscv64 cloud images, the s390x cloud image ships
# WITHOUT pre-baked universe package indexes, so a plain `apt-get install
# tree sshfs ...` fails with "Unable to locate package" (tree and sshfs
# live in universe). Fetch the indexes first. This is the only ubuntu
# variant where we pay the apt-get update cost (the post-update apt hooks
# like command-not-found burn some TCG CPU); everywhere else the pre-baked
# lists are sufficient -- see the warning in vm_postBuild.sh.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y $ANYVM_PKGS
