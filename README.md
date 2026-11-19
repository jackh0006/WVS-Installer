# WVS Installer

### Type one word. Get your Windows desktop.

**The safest, simplest way to keep a Windows VPS one keystroke away on Linux.**

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform: Linux](https://img.shields.io/badge/platform-Linux-lightgrey)
![Shell: Bash 4+](https://img.shields.io/badge/shell-bash%204%2B-121011?logo=gnu-bash)
![Version: 2.0.0](https://img.shields.io/badge/version-2.0.0-success)
![Tests: 44/44](https://img.shields.io/badge/tests-44%2F44-brightgreen)
![Telemetry: none](https://img.shields.io/badge/telemetry-none-brightgreen)

```text
$ vps
```

That is the whole user manual.

---

## Why people need this

Millions of people run a **Windows VPS** for things Linux cannot do well: trading
terminals, Windows-only business software, remote support, design tools, a clean
browser machine, or a desktop that is always on.

Connecting to it from Linux is normally a small pile of pain:

* long `xfreerdp` commands copied from a forum,
* the password typed again every single time,
* a tiny 200×200 desktop in the middle of a black screen,
* phantom double-clicks on Wayland and touchpads,
* certificate warnings that block the connection,
* settings that vanish after a reboot,
* no clean way to remove it all later.

**WVS Installer fixes all of that in about 30 seconds.** It asks three short
questions, stores the password in your desktop keyring, writes a tested Remmina
profile, installs the `vps` command, verifies the path with a real RDP handshake,
and then gets out of the way.

After that, connecting is:

```text
vps
```

One word. Every day. After every reboot.

---

## What it does

| | |
|---|---|
| 🔐 **Secure by default** | Password goes into the GNOME keyring, never into a shell history, process list, log or config file. |
| 🧠 **Three questions** | Address, user, password. Sensible defaults. No flags to memorise. |
| 🖥️ **Fullscreen that fits** | Detects your screen so the remote desktop is sharp and correctly sized, not a 200×200 postage stamp. |
| 🖱️ **No phantom clicks** | Remmina input layer, UDP off, mouse jitter off — safe on Wayland and touch screens. |
| 🔁 **Idempotent** | Run it again any time. Every file it replaces is backed up first. |
| 🧪 **Tested** | ShellCheck-clean and 44 functional tests run in GitHub Actions. |
| 🧹 **Clean uninstall** | One command removes the files, the PATH lines and the keyring entry. |
| 🚫 **No telemetry** | No accounts, no analytics, no phoning home. The only network traffic is your own RDP connection. |

---

## Quick install

**Requirements:** Linux (Ubuntu, Debian, Mint, Fedora, Arch, openSUSE), Bash 4+,
and the address / username / password of a Windows machine with Remote Desktop
enabled.

```bash
git clone https://github.com/jackh0006/WVS-Installer.git
cd WVS-Installer
./vps-setup.sh
```

Then answer the three questions and type:

```bash
vps
```

> **Downloaded a single file instead?**
> `chmod +x vps-setup.sh && ./vps-setup.sh`
> Double-clicking the script also works — it reopens itself in a terminal.

### The three questions

```text
1/3  VPS address (IP or hostname) [203.0.113.10]:
2/3  Username [Admin]:
3/3  Password for Admin (it will not be shown):
```

Press **Enter** to accept the value in brackets. The password is hidden while
you type it. Nothing else is asked.

---

## A five-year-old can do it

A complete, picture-style walkthrough lives in **[docs/GUIDE.md](docs/GUIDE.md)**.
It assumes you have never opened a terminal and explains every key press.

The short version:

1. Open the terminal (`Ctrl` + `Alt` + `T`).
2. Run the two lines above.
3. Answer the three questions. Press `Enter` after each one.
4. Type `vps` and press `Enter`.
5. You are on your Windows desktop.

If you can type your name, you can install this.

---

## What gets installed

| File | Purpose | Mode |
|------|---------|------|
| `~/.local/bin/vps` | the one-word launcher | `700` |
| `~/.local/share/remmina/windows-vps-stable.remmina` | tested RDP profile | `600` |
| `~/.config/vps-connect/vps.conf` | saved settings (password is base64-encoded; file is private) | `600` |
| `~/vps-connect/linux-macos/vps` | maintenance helper | `755` |
| `~/vps-connect/vps-setup.sh` | a copy of this installer, used by `vps setup` | `755` |
| `/usr/local/bin/vps` | root-owned fallback copy | `755` |

The real password lives in the **GNOME keyring** (entry
`Remmina: Windows VPS - password`, schema `org.remmina.Password`). The Remmina
profile only contains the marker `password=.`. The installer reads the secret
back from the keyring to prove it was stored correctly before finishing.

Every replaced file is backed up to
`~/.local/state/vps-connect/backup-<timestamp>/`.

---

## Everyday commands

| Command | What it does |
|---------|--------------|
| `vps` | connect, fullscreen |
| `vps status` | show saved settings |
| `vps test` | TCP + real RDP handshake test |
| `vps setup` | change address, user or password |
| `vps audio on\|off` | hear / mute the VPS |
| `vps mic on\|off` | forward your microphone |
| `vps mode direct\|tunnel` | switch connection mode |
| `vps stop` | stop the background tunnel |
| `vps help` | built-in help |

Inside the session:

```text
Ctrl + Alt + Enter   toggle fullscreen
Ctrl + Alt + End     send Ctrl + Alt + Del to the VPS
Ctrl + Alt + Home    show/hide the connection bar
```

---

## Security by design

* **No secrets on the command line.** The keyring is written through stdin and
  FreeRDP receives credentials through `/args-from:fd:0`, so they never appear in
  `ps` or shell history.
* **No secrets in logs.** The installer keeps a log of actions, never of secrets.
* **Least privilege.** The installer refuses to run as root. It asks for the
  administrator password once, only to install packages and the fallback copy.
* **Private files.** Config and profile are `600`; the launcher is `700`.
* **Supply chain.** One dependency-free Bash file. No `curl | bash`, no remote
  code, no post-install scripts beyond the packages your distribution provides.
* **Auditable.** Read every line before you run it. That is the point.

The full threat model and design notes are in **[docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)**
and **[SECURITY.md](SECURITY.md)**.

---

## Uninstall

```bash
./vps-setup.sh --uninstall
```

Removes the launcher, profile, helper, saved settings, PATH lines, fallback copy
and keyring entry. Backups stay in `~/.local/state/vps-connect/`.

---

## Verifying a release

Every release ships the script and a `SHA256SUMS` file:

```bash
sha256sum -c SHA256SUMS
```

CI runs on every push and pull request: **ShellCheck** (`-S info`), Bash syntax
checks, and the full functional suite in `tests/run-tests.sh` (44 checks:
permissions, keyring fallback, idempotency, input validation, uninstall).

---

## Donate

This project is free and always will be. If it saves you time, donations go
toward server costs and keeping it maintained.

| Asset | Network | Address |
|-------|---------|---------|
| Bitcoin | BTC | `bc1q8t0fn2yrsy4lh3m0pz34uj27t8vxjeavkjym83` |
| Dogecoin | DOGE | `D6ZdMQ7mHGGmuH9prpZ2zjpnG5Q3WVRDtC` |
| Ethereum | ETH | `0xdad428900a4359be8f76b3062df34211582e09eb` |
| USDT | ERC-20 | `0xdad428900a4359be8f76b3062df34211582e09eb` |
| BNB | BEP-20 | `0xdad428900a4359be8f76b3062df34211582e09eb` |
| USDT | BEP-20 | `0xdad428900a4359be8f76b3062df34211582e09eb` |
| TRON | TRX | `TMpb6RNTuGNM1eTakm9kjds1mRTPYYJesf` |
| USDT | TRC-20 | `TMpb6RNTuGNM1eTakm9kjds1mRTPYYJesf` |
| Solana | SOL | `BDCCrRez1yD1RpkAtiqKKDk3BfxPD8P7nkL26jCYrzgL` |
| USDT | SPL | `BDCCrRez1yD1RpkAtiqKKDk3BfxPD8P7nkL26jCYrzgL` |
| USDC | SPL | `BDCCrRez1yD1RpkAtiqKKDk3BfxPD8P7nkL26jCYrzgL` |
| XRP | XRP Ledger | `rNUAhaATFLvosdu9m9M95bupRBtZ8eqpj9` |
| Toncoin | TON | `UQCu6-3yGyQ5dzvcCxr2gobuvx5ddbS9EC690qtey92P5_wX` |
| Litecoin | LTC | `ltc1q2gs89cfy3mumr7gu9w0zl9rllf80q67m5rmma8` |

> Only send the matching asset on the matching network. Crypto transfers are
> final.

---

## License

MIT © 2026 jackh0006 — see [LICENSE](LICENSE).

## Disclaimer

WVS Installer is an independent helper. It is not affiliated with Microsoft,
Remmina, FreeRDP or GNOME. You must own, or be authorised to access, the Windows
machine you connect to. Remote Desktop must already be enabled and reachable on
that machine; this project builds the Linux client, not the Windows server.
