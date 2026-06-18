# cc-switch Codex Monitor

Keep Codex CLI / Codex Desktop sessions visible when switching Codex providers with `cc-switch-cli`.

`cc-switch-cli` may write different top-level `model_provider` values for different Codex providers. Codex Desktop groups remote sessions by that metadata, so switching providers can make existing history look like it disappeared. This project installs a small wrapper and refresh helper that keep Codex pinned to a stable provider namespace:

```toml
model_provider = "custom"

[model_providers.custom]
```

The current provider name, base URL, model, API mode, auth requirement, and API key are still synchronized from `cc-switch-cli`.

## What It Installs

- `cc-switch-cli` wrapper: runs the real CLI, then refreshes Codex only when relevant config or DB files changed.
- `cc-switch-refresh-codex`: normalizes Codex config, syncs auth, migrates existing session metadata to `custom`, and restarts Codex app-server/proxy processes.
- Optional aliases: `ccswitch` and `cc-switch`.

## Repository Layout

```text
bin/
  cc-switch-cli-wrapper
  cc-switch-refresh-codex
scripts/
  install-cc-switch-codex-monitor.sh
docs/
  cc-switch-codex-monitor-guide.md
tests/
  shellcheck.sh
```

## Requirements

- Linux target host
- Existing official `cc-switch-cli`
- Bash, Python 3, SQLite support in Python
- `sha256sum`, `stat`, `pgrep`, `mktemp`, `sed`

## Install

On the target host:

```bash
git clone <repo-url> cc-switch-codex-monitor
cd cc-switch-codex-monitor
sudo bash scripts/install-cc-switch-codex-monitor.sh
```

Default installed paths:

```text
/usr/local/bin/cc-switch-cli
/usr/local/bin/cc-switch-cli.real
/usr/local/bin/cc-switch-refresh-codex
/usr/local/bin/ccswitch
/usr/local/bin/cc-switch
```

Install to another directory:

```bash
sudo bash scripts/install-cc-switch-codex-monitor.sh --install-dir /opt/bin
```

Skip aliases:

```bash
sudo bash scripts/install-cc-switch-codex-monitor.sh --no-aliases
```

## Verify

Run a manual refresh once:

```bash
/usr/local/bin/cc-switch-refresh-codex
```

Check Codex config:

```bash
grep -E '^(model_provider|model|base_url|wire_api|requires_openai_auth)' ~/.codex/config.toml
grep -n '\[model_providers\.custom\]' ~/.codex/config.toml
```

Check logs:

```bash
tail -80 ~/.cc-switch/codex-refresh.log
```

More background and troubleshooting commands are in [docs/cc-switch-codex-monitor-guide.md](docs/cc-switch-codex-monitor-guide.md).

## Development

Run shell checks locally:

```bash
bash tests/shellcheck.sh
```

If `shellcheck` is not installed, the test script still runs `bash -n` syntax checks.

## License

MIT
