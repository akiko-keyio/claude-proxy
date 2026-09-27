# Deployment reference

## Assumptions

- VPS: Ubuntu 24.04 or newer, root SSH access for initial setup.
- Client: Windows 10/11 with administrative PowerShell.
- Claude: paid Claude account eligible for Claude Code Remote Control.
- Local machine and VPS are on the same Tailscale tailnet.
- The VPS cloud firewall allows SSH, the chosen proxy port, and Tailscale UDP.

Use a physical Windows path for SSHFS. A mapped drive such as `X:` can disappear or be unavailable in the OpenSSH logon session.

## 1. Install VPS proxy

Upload and run:

```bash
export PROXY_USER='proxy-user'
export PROXY_PASSWORD='strong-random-value'
export PROXY_HTTPS_PORT='443'
export PROXY_HTTP_PORT='8383'
sudo ./scripts/install-vps.sh
```

The script installs Docker and starts a Gost container with two listeners:

- `https://user:password@vps:443`
- `http://user:password@vps:8383`

HTTP is useful for compatibility, but HTTPS is preferred for use across hostile networks. Rotate the proxy credential if either port is exposed publicly. If the provider has an external firewall, open only the ports intentionally selected.

## 2. Configure Windows

From elevated PowerShell:

```powershell
$VpsPublicKey = Get-Content .\vps_ed25519.pub
.\scripts\configure-windows.ps1 -VpsPublicKey $VpsPublicKey
```

The script:

- installs and starts OpenSSH Server,
- opens the private-profile SSH firewall rule,
- adds the VPS public key to `administrators_authorized_keys`,
- and sets the default OpenSSH shell to PowerShell.

Then install Tailscale on Windows and sign in to the intended tailnet. Record the Windows Tailscale IPv4 address:

```powershell
tailscale ip -4
```

On the VPS, record its Tailscale IPv4 address too:

```bash
tailscale ip -4
```

Test from the VPS:

```bash
ssh -o BatchMode=yes "$WINDOWS_USER@$WINDOWS_TS_IP" "whoami"
```

## 3. Install Claude Code

Run on the VPS:

```bash
sudo ./scripts/install-claude.sh
```

Before authentication, complete `references/fingerprint-browser.md`: create a dedicated fingerprint profile, connect it through Gost or local SSH SOCKS5, and verify its IP, DNS, WebRTC, timezone, and locale. Do not use the ordinary user browser for Claude web sign-in or CLI OAuth.

This installs Node.js 22, Claude Code, a dedicated `claude` user, and tmux. Then authenticate interactively as that user:

```bash
sudo -iu claude
claude auth login --claudeai
claude auth status
```

The CLI prints an authorization URL and expects the returned code. Paste that URL only into the verified fingerprint profile and complete OAuth there. If the URL was opened elsewhere, deny the flow and restart it in the correct profile.

## 4. Mount a Windows folder

Generate a dedicated VPS key if needed:

```bash
sudo -iu claude ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_windows -N ''
sudo cat /home/claude/.ssh/id_ed25519_windows.pub
```

Authorize that public key on Windows using `configure-windows.ps1`, then mount:

```bash
export WINDOWS_USER='windows-account-name'
export WINDOWS_TS_IP='100.x.y.z'
export WINDOWS_REMOTE_PATH='C:/Users/windows-account-name/folder'
sudo -E ./scripts/mount-windows.sh mount
```

The mount point is `/mnt/claude-remote`, owned by the `claude` user. The script verifies that a test file can be created and removed before declaring success.

For persistence, create a systemd unit after a successful interactive mount:

```ini
[Unit]
Description=Windows folder over SSHFS
Wants=network-online.target
After=network-online.target tailscaled.service

[Mount]
What=/mnt/claude-remote
Where=/mnt/claude-remote
Type=fuse.sshfs
Options=reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,_netdev,allow_other,default_permissions

[Install]
WantedBy=multi-user.target
```

Because SSHFS helper options and identity ownership matter, prefer adding identity and connection options to the helper script and validating the unit manually before enabling it.

## 5. Start Claude Remote Control

As the dedicated user:

```bash
sudo -iu claude
cd /mnt/claude-remote
./scripts-for-claude/start-claude-remote.sh
```

The script starts a tmux session named `claude-remote` and launches:

```bash
claude --remote-control claude-remote --permission-mode bypassPermissions
```

Accept Claude's one-time bypass warning only if the user explicitly wants unprompted execution. For safer behavior, edit the script and use `acceptEdits`.

When connected, Claude Code shows `/rc active` and a claude.ai session URL. Open that URL only in the same verified fingerprint-browser profile that completed Claude authorization. For regional consistency, that profile must use the VPS proxy and match the intended region's timezone and locale.

Detach while keeping it running:

```text
Ctrl+b then d
```

Reattach:

```bash
tmux attach -t claude-remote
```

## Troubleshooting

### Claude web says it cannot reach the computer

On the VPS:

```bash
sudo -iu claude tmux ls
tmux attach -t claude-remote
```

Look for a suspended process or a prompt. A process shown as `T` in `ps` has been suspended. Resume it interactively with `fg`, or stop it and start a new session.

### SSHFS shows an empty or stale folder

- Confirm the physical Windows path, not a mapped drive.
- Run `dir /a <path>` locally.
- Unmount and remount.
- Check `mount | grep sshfs` and the `sshfs` process.
- Confirm the Windows account can log in non-interactively with the key.

### Claude refuses bypass mode

`bypassPermissions` is blocked under root/sudo. Use the dedicated non-root `claude` user. If the user does not truly need unlimited execution, prefer:

```bash
claude --remote-control claude-remote --permission-mode acceptEdits
```

### Proxy fails on one network

- Test both HTTPS and HTTP listeners.
- Compare the browser proxy protocol with the actual listener protocol.
- Check the VPS provider firewall and Gost logs.
- Rotate credentials if an ISP has blocked a plaintext proxy port.

## Security hardening

- Keep root SSH password authentication disabled after setup.
- Keep the proxy credential long and rotate it.
- Prefer HTTPS over plaintext HTTP.
- Do not mount a whole drive when one project folder is enough.
- Do not put Claude credentials, Tailscale auth URLs, OAuth codes, or proxy passwords in shell history or git.
- Do not approve Claude OAuth or open Remote Control outside the verified fingerprint profile.
- Remember that `bypassPermissions` is not sandboxing; it removes Claude Code prompts only.
