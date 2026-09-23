#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo -E $0" >&2
  exit 1
fi

: "${PROXY_USER:?Set PROXY_USER}"
: "${PROXY_PASSWORD:?Set PROXY_PASSWORD}"
export PROXY_HTTPS_PORT="${PROXY_HTTPS_PORT:-443}"
export PROXY_HTTP_PORT="${PROXY_HTTP_PORT:-8383}"

if [[ ${PROXY_PASSWORD} == *"@"* || ${PROXY_PASSWORD} == *":"* || ${PROXY_PASSWORD} == *"/"* ]]; then
  echo "PROXY_PASSWORD must not contain '@', ':', or '/' for this simple Gost URL." >&2
  exit 2
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg openssh-client sshfs fuse3 tmux jq ufw

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! tailscale status >/dev/null 2>&1; then
  echo "Follow the printed URL to authorize this VPS on the intended tailnet."
  tailscale up --ssh
fi

docker rm -f gost >/dev/null 2>&1 || true
docker run -d \
  --name gost \
  --restart unless-stopped \
  -p "${PROXY_HTTPS_PORT}:${PROXY_HTTPS_PORT}" \
  -p "${PROXY_HTTP_PORT}:${PROXY_HTTP_PORT}" \
  gogost/gost:latest \
  -L "https://${PROXY_USER}:${PROXY_PASSWORD}@:${PROXY_HTTPS_PORT}" \
  -L "http://${PROXY_USER}:${PROXY_PASSWORD}@:${PROXY_HTTP_PORT}"

if command -v ufw >/dev/null 2>&1; then
  ufw allow OpenSSH || true
  ufw allow "${PROXY_HTTPS_PORT}/tcp" || true
  ufw allow "${PROXY_HTTP_PORT}/tcp" || true
  ufw allow 41641/udp || true
fi

echo
echo "Gost proxy is running."
echo "HTTPS proxy: https://${PROXY_USER}:<password>@$(curl -4 -s https://api.ipify.org):${PROXY_HTTPS_PORT}"
echo "Tailscale IPv4: $(tailscale ip -4 || true)"
echo "Remember to open the same ports in the cloud provider firewall."
