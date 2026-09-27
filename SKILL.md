---
name: claude-proxy
description: Deploy a VPS HTTPS proxy, Tailscale private network, Windows SSHFS file mount, and Claude Code Remote Control for fingerprint-browser workflows.
metadata:
  short-description: Set up private VPS proxy and Claude Code remote access
---

# Claude VPS proxy and Remote Control

Use this skill when the user wants an isolated VPS to provide a Singapore/regional HTTPS proxy, private Tailscale connectivity, controlled access to a Windows folder, and a Claude Code session controllable from claude.ai/code.

This skill is setup-focused. Do not use it to route unrelated services, expose broad machine access, or bypass an explicit organizational policy.

## Operating rules

- Treat VPS, Windows OpenSSH, Tailscale, firewall, and Claude account changes as authorized only when the current user explicitly asks for that part of the setup.
- Ask for placeholders instead of reusing credentials from another conversation. Never write passwords, API keys, OAuth codes, or private keys into skill files or commit history.
- Never let the user complete Claude sign-in, OAuth authorization, or Remote Control in their ordinary browser. First create a dedicated fingerprint-browser profile, connect it through the VPS Gost proxy or local SSH SOCKS5, verify that it has the intended public IP and no WebRTC/DNS/timezone leaks, then authorize and use Claude in that profile only.
- Prefer a physical Windows path such as `C:/Users/<user>/path` over a mapped drive letter; OpenSSH sessions may not see interactive drive mappings.
- Run Claude Code as a dedicated non-root user. Claude Code intentionally refuses dangerous permission-bypass modes under root/sudo.
- Before enabling `bypassPermissions`, tell the user that the Claude process can execute arbitrary commands on the VPS and modify the mounted Windows folder without prompts. Offer `acceptEdits` when full bypass is not required.
- Put reversible changes first: install packages, configure services, then start the remote session. Stop and show diagnostics if SSH, Tailscale, or the SSHFS mount is unhealthy.

## Required inputs

Collect and export these values in the shell only:

```bash
export VPS_HOST='your.vps.example'
export PROXY_USER='proxy-user'
export PROXY_PASSWORD='strong-random-value'
export WINDOWS_USER='windows-account-name'
export WINDOWS_TS_IP='100.x.y.z'
export WINDOWS_REMOTE_PATH='C:/Users/windows-account-name/folder'
export CLAUDE_USER='claude'
```

The user must separately sign in to Tailscale and Claude. Never ask for their account passwords. Claude sign-in/OAuth and Remote Control may occur only in the verified fingerprint profile; see `references/fingerprint-browser.md`.

## Workflow

1. Read `references/deployment.md` and choose the applicable stage.
2. On a fresh Ubuntu VPS, run `scripts/install-vps.sh`. This installs Tailscale, Docker, SSHFS dependencies, and an authenticated HTTPS/HTTP Gost proxy.
3. On Windows, run `scripts/configure-windows.ps1` from an elevated PowerShell to install and start OpenSSH Server and authorize the VPS key.
4. Install Tailscale on Windows, then exchange both Tailscale IPv4 addresses and test private SSH connectivity.
5. Follow `references/fingerprint-browser.md`: create a dedicated profile, connect it through Gost or local SSH SOCKS5, and verify IP, DNS, WebRTC, timezone, and locale before any Claude login.
6. Sign in to Claude web only in that profile. Do not approve a CLI OAuth URL yet.
7. On the VPS, run `scripts/install-claude.sh` to create the dedicated Claude user and install Claude Code.
8. Run `claude auth login --claudeai`, paste its URL only into the same profile, and complete CLI OAuth there.
9. Run `scripts/mount-windows.sh` to mount the selected Windows folder over SSHFS.
10. Run `scripts/start-claude-remote.sh` as the Claude user to create a persistent tmux Remote Control session.
11. Open the resulting Remote Control URL only in the same verified profile, then run `scripts/verify.sh` and resolve failures before telling the user the setup is complete.

Do not proceed past a failed mount or SSH test. A broken mount can make Claude operate in the wrong directory or fail in confusing ways.

## Operational entry points

- Start/restart remote session: `scripts/start-claude-remote.sh`
- Mount/unmount the Windows folder: `scripts/mount-windows.sh {mount|unmount|status}`
- Health check: `scripts/verify.sh`
- Fingerprint-browser/auth constraint: `references/fingerprint-browser.md`

Detailed commands, troubleshooting, and security hardening are in `references/deployment.md`.
