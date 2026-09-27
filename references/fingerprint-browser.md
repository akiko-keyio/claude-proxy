# Fingerprint browser and VPS proxy

Claude sign-in, OAuth authorization, and Remote Control must happen only in a
dedicated fingerprint-browser profile whose network path is the VPS proxy. Do
not open these URLs in the ordinary user browser, another browser profile, an
incognito window, a cloud preview, or an email/chat app built-in browser.

The required order is:

```text
configure VPS egress
  -> create a dedicated fingerprint profile
  -> attach Gost HTTP(S) proxy or local SSH SOCKS5
  -> verify IP/DNS/WebRTC/timezone/locale
  -> sign in to Claude / complete OAuth in that profile
  -> open the Remote Control URL in that same profile
```

## Egress option 1: authenticated Gost proxy

This is the preferred normal setup:

```text
Protocol: HTTPS preferred; HTTP fallback
Host: <VPS_PUBLIC_IP_OR_DOMAIN>
Port: 443 HTTPS or 8383 HTTP
User: <PROXY_USER>
Password: <PROXY_PASSWORD>
```

Use HTTPS on an untrusted local network. HTTP is compatible but plaintext. If
only one port is needed, close the unused port in the cloud firewall.

## Egress option 2: SSH dynamic SOCKS5

On Windows, create an encrypted SSH SOCKS listener:

```powershell
ssh -N `
  -D 127.0.0.1:1080 `
  -o ExitOnForwardFailure=yes `
  -o ServerAliveInterval=30 `
  -o ServerAliveCountMax=3 `
  <VPS_USER>@<VPS_PUBLIC_IP_OR_DOMAIN>
```

Configure the fingerprint profile as:

```text
Protocol: Socks5
Host: 127.0.0.1
Port: 1080
User: empty
Password: empty
```

Keep the SSH process running. It is a useful fallback, but for persistent daily
use prefer a supervised Gost service over a hand-launched SSH tunnel.

## Profile rules

- Create one profile per Claude account and do not reuse it for unrelated work.
- Configure the proxy before any Claude sign-in or OAuth.
- Keep OS platform and User Agent consistent.
- Keep the generated fingerprint unless a field is internally inconsistent.
- Use the VPS region's timezone, for example `Asia/Singapore`.
- Use a locale consistent with the intended region and user.
- Disable WebRTC or use proxy/replace mode so it cannot expose the local IP.
- Do not import cookies, localStorage, extensions, history, or settings from an
  ordinary profile.

Changing every field manually is not inherently safer. A stable and coherent
identity is more important than an unrealistic fingerprint.

## Required pre-login checks

Open these checks inside the profile before Claude authorization:

```text
https://ipinfo.io
https://browserleaks.com/ip
https://browserscan.net
```

Verify:

- the public IP is the VPS IP, not the home/office IP;
- WebRTC does not expose the real local IP;
- DNS and timezone do not contradict the proxy region;
- language/locale matches the intended persona;
- the proxy survives a browser restart.

Leave `Change IP URL` empty for a static VPS. It is for rotating-proxy
providers; rotating a Claude-linked profile can damage identity consistency.

## Authorization and Remote Control

The CLI may print a Claude OAuth URL, and tmux will later print a
`claude.ai/code/session_...` URL. In both cases:

1. Copy the URL.
2. Paste it into the address bar of the verified fingerprint profile.
3. Complete authorization or use Remote Control there.

If the URL was opened in the wrong browser, stop before approving it. Close or
deny the authorization flow, rotate suspicious session/token material if
necessary, and restart the flow in the correct profile. For strict identity
separation, use a new Claude account/profile rather than retaining a login with
mixed-network history.
