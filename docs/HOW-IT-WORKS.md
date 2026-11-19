# How it works

This document explains exactly what the installer does, why every decision was
made, and where the sharp edges are. Read it before trusting the script — that is
the point of open source.

---

## The shape of the solution

```text
  you type                 launcher                     Windows VPS
 ┌─────────┐    no args   ┌──────────────────┐  RDP    ┌──────────────┐
 │   vps   │ ───────────► │ ~/.local/bin/vps │ ──────► │ 136.x.x.x:3389│
 └─────────┘              │  (Remmina,       │  3389   │  Windows      │
                          │   fullscreen)    │         └──────────────┘
      │ args              └──────────────────┘
      ▼
 ┌──────────────────────────┐
 │ ~/vps-connect/linux-macos/vps │  status · test · setup · audio · mic · ...
 └──────────────────────────┘
```

* **No arguments** → Remmina opens the saved profile fullscreen. This is the
  everyday path.
* **Any argument** → the helper script handles maintenance commands.
* **Settings** live in `~/.config/vps-connect/vps.conf` (mode `600`).
* **The password** lives in the GNOME keyring, not in any file.

---

## Installation flow

1. **Preflight**
   * refuses to run as root (avoids `HOME=/root` mistakes),
   * validates Bash and the terminal,
   * detects the distribution's package manager (apt, dnf, pacman, zypper),
   * detects the screen resolution from `xrandr` (fallback `1366x768`).

2. **Three questions**
   * address — validated as hostname / IPv4 / IPv6 characters only,
   * username — letters, digits, dot, dash, underscore,
   * password — read with `read -rs`, confirmed twice, never echoed.

3. **Packages** (only the missing ones)
   * Remmina + RDP plugin (the GUI path),
   * FreeRDP 3 (maintenance/tunnel path) with FreeRDP 2 as an optional fallback,
   * Python 3 (handshake probe, keyring bridge),
   * `python3-secretstorage` (keyring bridge) where available.
   * If a configured APT proxy is down, the installer retries once with the proxy
     disabled instead of failing.

4. **Secrets**
   * The password is piped to a short-lived Python helper on **stdin**.
   * Stored with schema `org.remmina.Password` and attributes
     `filename=<profile path>`, `key=password`, `xdg:schema=org.remmina.Password`.
     Those three attributes are exactly what Remmina 1.4 looks up.
   * The secret is read back and compared; only then is `password=.` written to
     the profile. If the keyring is unavailable, the installer falls back to a
     `600` profile and says so loudly.

5. **Files**
   * Remmina profile, launcher, helper, README.
   * `~/.local/bin` added to `~/.profile` and `~/.bashrc` with an idempotent,
     marked block (works in login shells and interactive shells).
   * `/usr/local/bin/vps` fallback installed with `sudo install`.
   * The installer copies itself to `~/vps-connect/vps-setup.sh` so `vps setup`
     always runs the same version.

6. **Proof**
   * `bash -n` on every generated script,
   * `vps status` must read the saved settings back,
   * `vps test` performs a TCP connect **and** a real X.224 RDP handshake.

---

## Why Remmina instead of plain FreeRDP?

FreeRDP is an excellent protocol engine, but on Wayland and touch hardware its
input path can duplicate pointer events, producing phantom clicks. Remmina’s own
input layer plus this profile avoids it:

```ini
multitransport=0      # no UDP/multitransport path
rdp_mouse_jitter=0    # no synthetic idle mouse movement
colordepth=16         # bandwidth-friendly, still readable
quality=0             # prioritise latency
viewmode=1            # fullscreen
window_maximize=1     # size the surface before connecting
```

`cert_ignore=1` is intentional. A Windows VPS normally presents a **self-signed**
RDP certificate whose name never matches the IP address. Without it, Remmina
blocks the connection before the password is even tried. If you have a proper
certificate and DNS name, set it back to `0`.

The window size is pre-filled from your real display (`window_width` /
`window_height`) because Remmina 1.4 sizes the remote framebuffer from the
connection widget. Starting fullscreen with a 640×480 profile produces a tiny
200×200 desktop in the middle of the screen. Pre-setting the size fixes it.

---

## Password and keyring

The profile contains only:

```ini
password=.
```

The dot is a marker meaning “ask libsecret”. The actual entry:

```text
schema      org.remmina.Password
attributes  filename = /home/<you>/.local/share/remmina/windows-vps-stable.remmina
            key      = password
            xdg:schema = org.remmina.Password
secret      <your password>
```

The installer verifies the entry by reading it back and comparing bytes. If the
keyring is locked or missing, the entry is deleted and the password is written to
the `600` profile instead, with a warning. Remmina migrates it to the keyring on
the first successful connection.

Base64 in `vps.conf` is **obfuscation, not encryption**. It exists so the helper
can feed FreeRDP without putting the secret on a command line. The file is `600`.

---

## Why the password never shows up in `ps`

* Keyring: written through `stdin`.
* FreeRDP: arguments (including `/p:` and the host) are sent through
  `/args-from:fd:0`, so the process command line only contains
  `xfreerdp3 /args-from:fd:0`.
* `sudo`: the administrator password is read with `read -rs` and piped to
  `sudo -S`; it is never stored.

---

## Idempotency and recovery

* Every replaced file is copied to
  `~/.local/state/vps-connect/backup-<timestamp>/` first.
* Files are written to a temporary file in the same directory, `chmod`-ed, then
  atomically renamed.
* Re-running keeps your port, audio/mic choices and connection mode.
* A failure prints one clear message and exits non-zero; nothing is deleted.
* `--uninstall` removes only the exact paths this project owns.

---

## What it deliberately does **not** do

* It does not change anything on the Windows machine.
* It does not open firewall ports or enable RDP on the server.
* It does not run as root.
* It does not phone home, check for updates, or collect analytics.
* It does not configure the optional Xray/REALITY HTTPS tunnel. `vps import`
  stores a key if you supply one, but the tunnel client is out of scope here.

---

## File map

```text
~/.local/bin/vps                                      launcher (700)
~/.local/share/remmina/windows-vps-stable.remmina     profile  (600)
~/.config/vps-connect/vps.conf                        settings (600)
~/vps-connect/linux-macos/vps                         helper   (755)
~/vps-connect/vps-setup.sh                            installer copy
~/vps-connect/README.md                               generated notes
/usr/local/bin/vps                                    fallback (755, root)
~/.local/state/vps-connect/                           log + backups (700)
```

---

## Limits

* RDP must already work on the Windows side (Remote Desktop enabled, port 3389
  reachable).
* NLA is assumed. A Microsoft-account login usually fails; use the local
  `Admin` / `Administrator` account.
* The display size is captured at install time. Re-run the installer after
  changing monitors permanently.
* GNOME keyring is assumed on the desktop. Other secret services work if they
  implement the Secret Service API.
