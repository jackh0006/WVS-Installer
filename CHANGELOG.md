# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.0.0] - 2026-11-19

First public release. A complete, reproducible rewrite of the hand-made setup
that preceded it.

### Added

* One-word `vps` launcher for Windows VPS over RDP (Remmina, fullscreen).
* Interactive installer asking only three questions: address, user, password.
* GNOME keyring storage using the exact `org.remmina.Password` attributes, with
  byte-for-byte read-back verification before finishing.
* Automatic installation of Remmina, FreeRDP 3 (and optional FreeRDP 2),
  Python 3 and `python3-secretstorage` across apt, dnf, pacman and zypper.
* Screen-size detection so the remote desktop fills the screen correctly.
* Tuned RDP profile: UDP/multitransport off, mouse jitter off, 16 bpp,
  clipboard and audio on, self-signed certificate accepted.
* Maintenance helper: `status`, `test`, `setup`, `audio`, `mic`, `mode`,
  `import`, `stop`, `help` and one-shot `user@host`.
* Real RDP handshake probe (TCP + X.224), not just a ping.
* Idempotent installer with timestamped backups of every replaced file.
* Atomic writes and strict file modes (`600` for secrets, `700` for the launcher).
* `--uninstall` that removes files, PATH lines and the keyring entry.
* PATH handling for login and interactive shells.
* Root-owned fallback copy at `/usr/local/bin/vps`.
* 44-check functional test suite and ShellCheck-clean CI.
* Full documentation: five-year-old guide, architecture, security, troubleshooting.

### Security

* Password never appears in `ps`, shell history, logs or the profile.
* FreeRDP credentials passed via `/args-from:fd:0`.
* `sudo` password read hidden and never stored.
* Refuses to run as root.
* No telemetry, no accounts, no remote code, no `curl | bash`.

### Fixed (compared to the previous manual setup)

* Remmina prompting for the password on every start (missing `key=password`
  keyring attribute).
* 200×200 remote desktop when starting fullscreen from a 640×480 profile.
* `vps test` reporting success while exiting non-zero.
* Lost `PATH` in login shells when only `.bashrc` was updated.
* Stale FreeRDP host key blocking the connection after a VPS rebuild.

[2.0.0]: https://github.com/jackh0006/WVS-Installer/releases/tag/v2.0.0
