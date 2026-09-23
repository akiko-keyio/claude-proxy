# claude-proxy

A reusable Codex skill for setting up:

- an authenticated HTTPS proxy on a regional VPS,
- private Tailscale connectivity between the VPS and Windows,
- a Windows folder mounted into the VPS through SSHFS,
- and a persistent Claude Code Remote Control session.

The skill is intentionally secret-free. Fill in credentials at runtime, keep them out of shell history, and never commit them.

## Install as a Codex skill

Copy this folder into the Codex skills directory:

```powershell
$destination = Join-Path $env:USERPROFILE '.codex/skills/claude-proxy'
Copy-Item -Recurse -Force . $destination
```

Then invoke it from Codex with `$claude-proxy`.

## High-level flow

1. Run `scripts/install-vps.sh` on a fresh Ubuntu VPS.
2. Run `scripts/configure-windows.ps1` in an elevated Windows PowerShell.
3. Connect both machines to Tailscale.
4. Run `scripts/install-claude.sh` on the VPS.
5. Run `scripts/mount-windows.sh` on the VPS.
6. Run `scripts/start-claude-remote.sh` as the dedicated Claude user.
7. Validate with `scripts/verify.sh`.

See `SKILL.md` and `references/deployment.md`. The scripts use variables and never contain real credentials.
