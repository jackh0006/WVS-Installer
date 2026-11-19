## Summary

What does this change, and why?

## Type

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] CI / tooling

## How it was tested

```text
bash -n vps-setup.sh install.sh tests/run-tests.sh
shellcheck -S info vps-setup.sh install.sh tests/run-tests.sh
bash tests/run-tests.sh
```

## Checklist

- [ ] No secret, real address or personal path is included
- [ ] `shellcheck -S info` is clean
- [ ] All tests pass
- [ ] Docs/CHANGELOG updated for user-visible changes
- [ ] The three-question flow is unchanged (or the change is explained above)
