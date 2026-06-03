#host-side hook to initialize ssh access.
#
#The cloud image already has the build's public key baked into root's
#authorized_keys (see hooks/prepareImage.sh), so we just wait for sshd to come
#up over the network and then push enablessh.local to re-affirm the sshd config
#and re-add the key. Everything here is tolerant so a transient failure does not
#abort the build (build.sh runs with "set -e").


vmip="$($vmsh getVMIP $osname || true)"
echo "VM IP: $vmip"

_n=0
while ! timeout 5 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "root@$vmip" exit >/dev/null 2>&1; do
  echo "waiting for sshd on '$vmip' ..."
  sleep 10
  vmip="$($vmsh getVMIP $osname || true)"
  _n=$((_n + 1))
  if [ "$_n" -gt 60 ]; then
    echo "sshd did not come up in time, continuing anyway"
    break
  fi
done

echo "Pushing enablessh.local to root@$vmip"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "root@$vmip" sh <enablessh.local || true

#give sshd a moment to restart
sleep 5
