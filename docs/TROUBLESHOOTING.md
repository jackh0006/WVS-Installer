# Troubleshooting

Start with:

```bash
vps status
vps test
```

`vps test` distinguishes “the network cannot reach the VPS” from “the VPS is up
but the credentials are wrong”. That saves most of the guesswork.

---

## The command

| Symptom | Cause | Fix |
|---------|-------|-----|
| `vps: command not found` | `~/.local/bin` is not in this shell's `PATH` | Open a new terminal. If it persists, run the installer again, then `source ~/.profile`. |
| `vps` opens Remmina but immediately closes | VPS off, firewall, or wrong address | `vps test`, then check the provider panel. |
| `Unknown command` | Typo | `vps help` |

---

## The connection

| Symptom | Cause | Fix |
|---------|-------|-----|
| `TCP 3389 does not answer` | VPS off, IP changed, provider firewall | Check the provider panel; confirm the IP |
| `TCP connects but nothing comes back` | DPI / VPN / path blackhole | Try another network or a VPN; this is not a password problem |
| `TCP connects but the reply is not RDP` | A proxy is rewriting the port | Disable HTTP/SOCKS proxies, or connect through the provider's tunnel |
| `Credentials rejected` | Wrong password, or a Microsoft account | Use the local `Admin`/`Administrator` account, not a Microsoft login. Re-run `vps setup`. |
| Certificate warning | Self-signed RDP certificate | Expected. The profile sets `cert_ignore=1`. Do not disable it unless you have a trusted certificate. |

---

## The picture

| Symptom | Cause | Fix |
|---------|-------|-----|
| Small desktop in the middle of black | Remote resolution was fixed before the window was sized | Re-run the installer (it writes the current screen size), or set `window_width`/`window_height` in the profile to your resolution |
| Windowed instead of fullscreen | View mode lost | `Ctrl + Alt + Enter`, or ensure `viewmode=1` in the profile |
| Black screen after login | Explorer crash or slow GPU driver in the guest | Wait; then `Ctrl + Alt + End` → Task Manager → restart Explorer |
| Rough text / banded colours | `colordepth=16` is intentional for bandwidth | Set `colordepth=32` in the profile, reconnect |
| Duplicated / phantom clicks | Touch or Wayland input duplication | Keep `multitransport=0`, `rdp_mouse_jitter=0`, and launch through `vps` (not `xfreerdp` directly) |
| Clipboard does not work | Disabled in the profile | Set `disableclipboard=0`, reconnect |

---

## The password prompt keeps coming back

Remmina asks every time when the keyring entry cannot be read.

1. Open **Passwords and Keys** (GNOME keyring) and make sure the *Login* keyring
   is unlocked.
2. Re-run the installer; it rewrites the entry and verifies it.
3. As a last resort the installer falls back to a `600` profile. Remmina will
   move the password into the keyring on the first successful connection.

---

## Installation problems

| Symptom | Cause | Fix |
|---------|-------|-----|
| `sudo: a password is required` | No interactive terminal | Run the installer from a normal terminal, not from a cron job or a GUI file manager without a terminal |
| Package installation fails | Broken/misconfigured APT proxy or no network | The installer retries with the proxy disabled. Check `/etc/apt/apt.conf.d/proxy.conf` if it still fails. |
| `Remmina is still missing` | Distribution package not available | Install Remmina from your software centre, then run the installer again |
| `Input ended before all questions were answered` | The script was fed input that ended early | Run it interactively and answer the prompts |
| Nothing happens on double-click | File manager opened it in an editor | Right-click → *Run as program*, or run it in a terminal |

---

## Removing everything

```bash
./vps-setup.sh --uninstall
```

This removes the launcher, profile, helper, saved settings, PATH lines, fallback
copy and the keyring entry. Backups remain under
`~/.local/state/vps-connect/`.

---

## Still stuck?

Open an issue with:

* the output of `vps status` (it contains no password),
* the output of `vps test`,
* your distribution and version,
* the exact message you see.

Never paste your password or the contents of `~/.config/vps-connect/vps.conf`.
