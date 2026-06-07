# in-guest postBuild hook (piped to the guest's sh over SSH by build.py).
#
# Keep everything tolerant: build.py runs this with the remote shell exiting
# non-zero on any unhandled error, and one apt hiccup should not abort the
# whole build.

export DEBIAN_FRONTEND=noninteractive

echo "=================== ubuntu postBuild ===="

# Prime the apt lists so the later package install (tree/rsync/sshfs) is
# fast.
apt-get update || true

# Make sure sshd survives the reboot that build.py does right after this hook.
systemctl enable ssh.service 2>/dev/null || systemctl enable ssh 2>/dev/null || true

# NOTE: do NOT run "cloud-init clean" here. build.py reboots right after this
# hook, and a clean makes cloud-init treat the next boot as a new instance,
# which (via ssh_deletekeys) regenerates the SSH host keys. The host key for
# the VM's IP then changes mid-build and the next "ssh" fails with
# "REMOTE HOST IDENTIFICATION HAS CHANGED" / host key verification failed.

echo "ubuntu postBuild done."

exit 0
