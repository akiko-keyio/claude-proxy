#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo -E $0" >&2
  exit 1
fi

CLAUDE_USER="${CLAUDE_USER:-claude}"
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl gnupg openssh-client sshfs fuse3 tmux

if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | sed 's/^v//;s/\..*//')" -lt 22 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

if ! id "${CLAUDE_USER}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${CLAUDE_USER}"
fi

install -d -o "${CLAUDE_USER}" -g "${CLAUDE_USER}" -m 700 \
  "/home/${CLAUDE_USER}/.claude" \
  "/home/${CLAUDE_USER}/.ssh" \
  "/mnt/claude-remote"

npm install -g @anthropic-ai/claude-code@latest

echo "Claude Code $(claude --version) installed."
echo "Next: sudo -iu ${CLAUDE_USER}, then run: claude auth login --claudeai"
echo "Generate a mount key if needed: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_windows -N ''"
