# Contributing

Thanks for helping. This project values **small, auditable changes** over large
rewrites.

## Before you start

* Read [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md) and [SECURITY.md](SECURITY.md).
* One feature or fix per pull request.
* Never commit a real address, username or password. Tests use `127.0.0.1`.

## Requirements

* Bash 4+
* ShellCheck 0.9+
* Linux (the test suite is Linux-only by design)

## Run the checks

```bash
bash -n vps-setup.sh install.sh tests/run-tests.sh
shellcheck -S info vps-setup.sh install.sh tests/run-tests.sh
bash tests/run-tests.sh
```

All three must be clean. CI runs the same commands on every push and pull
request, plus Bash syntax checks.

## Style

* Bash, not POSIX `sh` — the script relies on arrays and `[[ ]]`.
* Quote everything; keep `set -Eeuo pipefail` at the top.
* No new runtime dependencies without a discussion in an issue first.
* Keep user-facing text short, friendly and free of jargon.
* Never print, log, or pass a secret as an argument.
* Prefer `if` over `cmd && ok || fail` chains (ShellCheck SC2015).
* Add or update a test for every behaviour change.

## Commit messages

```text
type: short summary

Optional longer explanation.
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `ci`, `chore`.

## Pull request checklist

- [ ] `bash -n` is clean
- [ ] `shellcheck -S info` is clean
- [ ] `tests/run-tests.sh` passes (44/44 or more)
- [ ] No secrets, addresses or personal paths added
- [ ] README/docs updated if behaviour changed
- [ ] CHANGELOG.md updated for user-visible changes

## Security issues

Do **not** open a public issue. Use the **Security** tab → *Report a
vulnerability*.

## License

By contributing you agree that your contribution is licensed under the MIT
License (see [LICENSE](LICENSE)).
