#!/usr/bin/env bash
set -euo pipefail

CLAUDE_USER="${CLAUDE_USER:-claude}"
failed=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; failed=1; }

for command in docker tailscale sshfs tmux jq claude; do
  if command -v "$command" >/dev/null 2>&1; then pass "$command installed"; else fail "$command missing"; fi
done

if docker inspect --format '{{.State.Running}}' gost 2>/dev/null | grep -q true; then
  pass "Gost container running"
else
  fail "Gost container not running"
fi

if tailscale status >/dev/null 2>&1; then
  pass "Tailscale connected"
else
  fail "Tailscale not connected"
fi

if mountpoint -q /mnt/claude-remote; then
  pass "SSHFS mount active"
  if runuser -u "${CLAUDE_USER}" -- test -w /mnt/claude-remote; then
    pass "Claude user can write to mount"
  else
    fail "Claude user cannot write to mount"
  fi
else
  fail "SSHFS mount inactive"
fi

if runuser -u "${CLAUDE_USER}" -- claude auth status 2>/dev/null | jq -e '.loggedIn == true' >/dev/null; then
  pass "Claude user authenticated"
else
  fail "Claude user not authenticated"
fi

if runuser -u "${CLAUDE_USER}" -- tmux has-session -t claude-remote 2>/dev/null; then
  pass "Claude Remote Control tmux session exists"
else
  fail "Claude Remote Control tmux session missing"
fi

exit "$failed"
