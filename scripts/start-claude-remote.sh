#!/usr/bin/env bash
set -euo pipefail

session="claude-remote"
workdir="/mnt/claude-remote"
CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-bypassPermissions}"

if [[ ${EUID} -eq 0 ]]; then
  echo "Run as the dedicated non-root Claude user, not root." >&2
  exit 1
fi

if [[ ! -d ${workdir} ]]; then
  echo "Missing ${workdir}. Mount the Windows folder first." >&2
  exit 1
fi

if ! claude auth status 2>/dev/null | jq -e '.loggedIn == true' >/dev/null; then
  echo "Claude is not signed in. Run: claude auth login --claudeai" >&2
  exit 1
fi

if [[ ${1:-} == restart ]]; then
  tmux kill-session -t "${session}" 2>/dev/null || true
elif tmux has-session -t "${session}" 2>/dev/null; then
  echo "Session ${session} already exists."
  echo "Attach with: tmux attach -t ${session}"
  exit 0
fi

tmux new-session -d -s "${session}" -c "${workdir}" \
  "claude --remote-control ${session} --permission-mode ${CLAUDE_PERMISSION_MODE}"

sleep 1
if ! tmux has-session -t "${session}" 2>/dev/null; then
  echo "Claude exited immediately. Inspect with: tmux new-session -s debug" >&2
  exit 1
fi

echo "Session ${session} started in ${workdir}."
echo "Attach: tmux attach -t ${session}"
echo "Claude web list: https://claude.ai/code"
