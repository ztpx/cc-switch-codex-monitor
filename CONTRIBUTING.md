# Contributing

Thanks for improving this project.

## Local Checks

Run:

```bash
tests/shellcheck.sh
```

The scripts are intended to run on Linux hosts, even if the repository is edited from another platform.

## Notes

- Keep runtime scripts in `bin/`.
- Keep installer logic in `scripts/`.
- Update `docs/cc-switch-codex-monitor-guide.md` when behavior changes.
- Do not commit secrets, provider keys, local Codex configs, or cc-switch databases.
