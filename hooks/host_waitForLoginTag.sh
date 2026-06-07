#!/bin/bash
# host-side waitForLoginTag override (called from start_and_wait after
# startVM + openConsole, before the default waitForText fires).
#
# Ubuntu cloud images boot to a serial getty, but the arch/console plumbing
# makes OCR/console-text matching fragile (especially under aarch64 TCG).
# Since prepareImage already baked SSH access into the qcow2, we just poll
# the slirp hostfwd port on 127.0.0.1:$VM_SSH_PORT until sshd answers TCP.
# At that point the system is up enough for host_enablessh.sh to take over.
#
# Under slirp the guest's 192.168.122.x is NOT routable from the host, so
# the hostfwd port is the only way in -- do NOT try to reach the guest IP
# directly here.

set -u
_n=0
while [ "$_n" -lt 120 ]; do
  if (echo > "/dev/tcp/127.0.0.1/${VM_SSH_PORT}") 2>/dev/null; then
    echo "sshd is listening on 127.0.0.1:${VM_SSH_PORT}"
    break
  fi
  echo "waiting for VM sshd on 127.0.0.1:${VM_SSH_PORT} ..."
  sleep 5
  _n=$((_n + 1))
done

sleep 5
