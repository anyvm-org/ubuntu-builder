#some host-side setup that runs after the cloud image is downloaded and
#converted into "$osname.qcow2", but BEFORE the VM is created.
#
#Ubuntu cloud images have no console password and no SSH key, so there is no way
#to log in on first boot. We bake root SSH access straight into the qcow2 with
#virt-customize, so that once the VM boots we can just ssh in (see
#hooks/enablessh.sh). This avoids needing a cloud-init seed disk.


echo "Preparing $osname.qcow2 with virt-customize"

# Generate the build's SSH keypair now so we can inject its public key into the
# image. build.sh would otherwise create the same key later; reuse it here.
if [ ! -e "$HOME/.ssh/id_rsa" ]; then
  ssh-keygen -f "$HOME/.ssh/id_rsa" -q -N ""
fi
_pub="$HOME/.ssh/id_rsa.pub"

# libguestfs on a GitHub-hosted runner needs the direct backend.
export LIBGUESTFS_BACKEND=direct
if ! command -v virt-customize >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y libguestfs-tools
fi
# Make the host kernel readable for the libguestfs appliance (harmless if it
# is already readable / not present).
sudo chmod 0644 /boot/vmlinuz-* 2>/dev/null || true

_pw="${VM_ROOT_PASSWORD:-ubuntu}"

# A drop-in that sorts before cloud-init's 50-cloud-init.conf so that our
# "first match wins" sshd directives take effect (cloud images disable root
# login and password auth by default).
_sshd_dropin='PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
KbdInteractiveAuthentication yes
AcceptEnv *'

sudo -E virt-customize -a "$osname.qcow2" \
  --root-password "password:$_pw" \
  --ssh-inject "root:file:$_pub" \
  --run-command 'mkdir -p /etc/ssh/sshd_config.d' \
  --write "/etc/ssh/sshd_config.d/00-anyvm.conf:$_sshd_dropin" \
  --write '/etc/cloud/cloud.cfg.d/99-anyvm-ds.cfg:datasource_list: [ NoCloud, None ]' \
  --run-command 'systemctl enable ssh.service 2>/dev/null || systemctl enable ssh 2>/dev/null || true' \
  --run-command 'systemctl enable serial-getty@ttyS0.service 2>/dev/null || true'

# Make sure libvirt / qemu can read+write the image on the following steps.
sudo chmod 0666 "$osname.qcow2" 2>/dev/null || true

echo "Image prepared:"
ls -lh "$osname.qcow2"
