#host-side hook used by start_and_wait().
#
#Ubuntu cloud images boot to a serial getty, but the arch/console plumbing makes
#OCR/console-text matching fragile (especially under aarch64 emulation). Since we
#bake SSH access into the image and reach it over the network, we just wait until
#the VM has picked up a DHCP lease, then let hooks/enablessh.sh poll sshd.


_n=0
while [ "$_n" -lt 60 ]; do
  if $vmsh getVMIP "$osname" 2>/dev/null | grep -qE '192\.168\.'; then
    echo "VM has a DHCP lease."
    break
  fi
  echo "waiting for VM network ..."
  sleep 5
  _n=$((_n + 1))
done

sleep 5
