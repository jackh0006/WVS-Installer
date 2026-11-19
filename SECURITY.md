# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 2.x     | ✅ |
| < 2.0   | ❌ |

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Use GitHub's private vulnerability reporting on this repository:

> **Security** tab → **Report a vulnerability**

Include:

* affected version (`./vps-setup.sh --version`),
* your distribution and Bash version,
* a minimal reproduction,
* the impact you believe it has.

You can expect an acknowledgement within **72 hours** and a fix or a written
assessment within **14 days**. Credit is given in the release notes unless you
prefer to stay anonymous.

## Security design

WVS Installer is a single, dependency-free Bash file. The full design is in
[docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md). The short version:

| Property | How |
|----------|-----|
| No secret in `ps` | Keyring writes through stdin; FreeRDP uses `/args-from:fd:0` |
| No secret in shell history | Password is read with `read -rs`, never as an argument |
| No secret in logs | The log records actions, never values |
| No secret in the profile | `password=.` marker + keyring entry, verified by read-back |
| Private files | profile/config `600`, launcher `700`, state dir `700` |
| No privilege creep | refuses root; one `sudo` escalation for packages and the fallback copy |
| No remote code | no `curl \| bash`, no downloaded scripts, no post-install hooks |
| No telemetry | no analytics, no accounts, no update phone-home |
| Recoverable | every overwritten file is backed up before the write |

## Threat model

**Protected against**

* another local user reading the VPS password,
* the password leaking through process listings, shell history or logs,
* accidental destruction of an existing configuration,
* a half-finished install leaving a broken `vps` command,
* a malicious repository file silently changing the installer’s behaviour
  (everything is one auditable file; releases carry checksums).

**Not protected against**

* an attacker with **root** on your machine,
* a compromised desktop session, keylogger or locked/unlocked keyring attacker,
* a malicious or compromised **VPS** you choose to connect to,
* physical access to an unlocked machine,
* weak VPS passwords — use a long, unique one.

## Secret handling details

The keyring entry is created with:

```text
schema      org.remmina.Password
attributes  filename=<profile path>, key=password, xdg:schema=org.remmina.Password
```

The installer reads the secret back and compares it byte-for-byte before it
writes `password=.` into the profile. If verification fails, it deletes the
partial entry and falls back to a `600` profile with an explicit warning.

`PASS_B64` in `vps.conf` is **base64, not encryption**. It exists only so the
helper can feed FreeRDP without placing the password on a command line.

## Verifying a release

```bash
sha256sum -c SHA256SUMS
```

Compare the checksum with the one published in the release notes. Releases are
built from the tagged commit that passed CI (ShellCheck + functional tests).

## Dependencies

The installer downloads nothing itself. It installs distribution packages:
Remmina, FreeRDP, Python 3 and `python3-secretstorage`. Their security is managed
by your distribution. The project has no runtime dependencies beyond Bash, the
standard Unix tools, and those packages.
