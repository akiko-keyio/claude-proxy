#!/usr/bin/env bash
set -euo pipefail

action="${1:-status}"
mountpoint=/mnt/claude-remote
CLAUDE_USER="${CLAUDE_USER:-claude}"
: "${WINDOWS_USER:?Set WINDOWS_USER}"
: "${WINDOWS_TS_IP:?Set WINDOWS_TS_IP}"
: "${WINDOWS_REMOTE_PATH:?Set WINDOWS_REMOTE_PATH}"

identity="/home/${CLAUDE_USER}/.ssh/id_ed25519_windows"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo -E $0 ${action}" >&2
  exit 1
fi

if ! id "${CLAUDE_USER}" >/dev/null 2>&1; then
  echo "User ${CLAUDE_USER} does not exist. Run install-claude.sh first." >&2
  exit 1
fi

case "${action}" in
  mount)
    [[ -f ${identity} ]] || {
      echo "Missing ${identity}. Generate it as ${CLAUDE_USER} and authorize the public key on Windows." >&2
      exit 1
    }

    mkdir -p "${mountpoint}"
    umount "${mountpoint}" 2>/dev/null || fusermount3 -uz "${mountpoint}" 2>/dev/null || true

    sshfs "${WINDOWS_USER}@${WINDOWS_TS_IP}:${WINDOWS_REMOTE_PATH}" "${mountpoint}" \
      -o "IdentityFile=${identity}" \
      -o UserKnownHostsFile="/home/${CLAUDE_USER}/.ssh/known_hosts" \
      -o StrictHostKeyChecking=accept-new \
      -o reconnect \
      -o ServerAliveInterval=15 \
      -o ServerAliveCountMax=3 \
      -o allow_other \
      -o default_permissions \
      -o "uid=$(id -u "${CLAUDE_USER}")" \
      -o "gid=$(id -g "${CLAUDE_USER}")" \
      -o umask=077

    testfile="${mountpoint}/.claude-proxy-mount-test"
    if echo ok >"${testfile}" && [[ $(cat "${testfile}") == ok ]]; then
      rm -f "${testfile}"
      echo "Mounted ${WINDOWS_REMOTE_PATH} at ${mountpoint} and verified write access."
    else
      echo "Mount exists but write verification failed." >&2
      exit 1
    fi
    ;;
  unmount)
    umount "${mountpoint}" 2>/dev/null || fusermount3 -uz "${mountpoint}"
    echo "Unmounted ${mountpoint}."
    ;;
  status)
    if mountpoint -q "${mountpoint}"; then
      findmnt -T "${mountpoint}" -no TARGET,SOURCE,FSTYPE,OPTIONS
      ls -la "${mountpoint}"
    else
      echo "${mountpoint} is not mounted."
      exit 1
    fi
    ;;
  *)
    echo "Usage: sudo -E $0 {mount|unmount|status}" >&2
    exit 2
    ;;
esac
