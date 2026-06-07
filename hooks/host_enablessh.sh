#!/bin/bash
# host-side enablessh hook -- runs after _gen_enablessh_local() has written
# the enablessh.local script. The cloud image already has the build's
# public key baked into root's authorized_keys (see host_prepareImage.sh),
# so we just connect over the slirp hostfwd port and push enablessh.local
# to re-affirm sshd config and re-add the key.
#
# Tolerant of transient failures so we don't trip "set -e" in main().

set -u

SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -p "${VM_SSH_PORT}"
)

_n=0
while ! timeout 5 ssh "${SSH_OPTS[@]}" "root@127.0.0.1" exit >/dev/null 2>&1; do
  echo "waiting for sshd on 127.0.0.1:${VM_SSH_PORT} ..."
  sleep 10
  _n=$((_n + 1))
  if [ "$_n" -gt 60 ]; then
    echo "sshd did not come up in time, continuing anyway"
    break
  fi
done

echo "Pushing enablessh.local to root@127.0.0.1:${VM_SSH_PORT}"
ssh "${SSH_OPTS[@]}" "root@127.0.0.1" sh <enablessh.local || true

# give sshd a moment to settle
sleep 5
