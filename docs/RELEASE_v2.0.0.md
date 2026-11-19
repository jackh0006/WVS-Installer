# WVS Installer 2.0.0

**One word to your Windows desktop. Secure by default, tested on every commit.**

## Why you need it

If you use a Windows VPS from Linux, you already know the routine: a long
`xfreerdp` command, the password retyped every time, a postage-stamp desktop in
the middle of a black screen, phantom clicks on Wayland, and certificate warnings
that block the connection before you can even log in.

WVS Installer turns all of that into:

```text
vps
```

## What it does

* Asks **three questions**: address, username, password. About 30 seconds.
* Installs only the missing pieces (Remmina, FreeRDP, Python, keyring support)
  on apt, dnf, pacman and zypper systems.
* Stores the password in the **GNOME keyring**, verifies it by reading it back,
  and never puts it in a shell history, process list, log or profile.
* Writes a **tested Remmina profile**: fullscreen, correct screen size, UDP off,
  mouse jitter off, clipboard/audio/mic on, self-signed RDP certificate accepted.
* Installs the `vps` command and a maintenance helper
  (`status`, `test`, `setup`, `audio`, `mic`, `mode`, `import`, `stop`, `help`).
* Proves the path with a **real RDP handshake**, not a ping.
* Is **idempotent**: safe to re-run, backs up every file it replaces.
* Uninstalls cleanly with `./vps-setup.sh --uninstall`.

## Install

```bash
git clone https://github.com/jackh0006/WVS-Installer.git
cd WVS-Installer
./vps-setup.sh
```

Then type `vps`.

The complete beginner walkthrough is in `docs/GUIDE.md` and assumes you have
never opened a terminal.

## Verification

Every release asset is listed in `SHA256SUMS`:

```bash
sha256sum -c SHA256SUMS
```

CI (GitHub Actions) runs ShellCheck, Bash syntax checks, version consistency and
a 44-check functional suite on every push and pull request. This release was cut
from a commit where all jobs passed.

## Notes

* The project is independent and not affiliated with Microsoft, Remmina or
  FreeRDP.
* RDP must already be enabled and reachable on the Windows machine.
* No telemetry, no accounts, no remote code.

## Donate

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

MIT licensed. Free forever.
