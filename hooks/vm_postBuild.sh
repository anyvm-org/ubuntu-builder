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

echo "ubuntu postBuild done."

exit 0
