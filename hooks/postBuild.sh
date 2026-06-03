#some tasks run inside the VM (as root) as soon as it is up.
#
#Keep everything tolerant: build.sh runs this over ssh with "set -e", so a
#non-zero exit here would abort the whole build.

export DEBIAN_FRONTEND=noninteractive

echo "=================== ubuntu postBuild ===="

# Prime the apt lists so the later package install (tree/rsync/sshfs) is fast.
apt-get update || true

# Make sure sshd survives the reboot that build.sh does right after this hook.
systemctl enable ssh.service 2>/dev/null || systemctl enable ssh 2>/dev/null || true

# Drop cloud-init's first-boot state so it does not try to re-disable our sshd
# settings or re-run network bring-up on later boots. Harmless if absent.
cloud-init clean --logs 2>/dev/null || true

echo "ubuntu postBuild done."

exit 0
