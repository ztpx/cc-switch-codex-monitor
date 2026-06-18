# cc-switch Codex Monitor

让 `cc-switch-cli` 切换 Codex 供应商时，Codex CLI / Codex Desktop 的历史会话仍然可见。

Keep Codex CLI / Codex Desktop sessions visible when switching Codex providers with `cc-switch-cli`.

## 项目用途 / Purpose

`cc-switch-cli` 在切换不同 Codex provider 时，可能会把 Codex 顶层配置写成不同的 `model_provider`。Codex Desktop 会按 session metadata 里的 `model_provider` 分区展示远程会话，所以切换 provider 后，旧会话可能看起来像“消失了”。

`cc-switch-cli` may write different top-level `model_provider` values for different Codex providers. Codex Desktop groups remote sessions by that metadata, so switching providers can make existing history look like it disappeared.

本项目通过安装一个 wrapper 和 refresh helper，把 Codex 固定到稳定的 provider namespace：

This project installs a small wrapper and refresh helper that keep Codex pinned to a stable provider namespace:

```toml
model_provider = "custom"

[model_providers.custom]
```

当前 provider 的显示名、base URL、model、wire API、auth 设置和 API key 仍然会从 `cc-switch-cli` 同步。

The current provider name, base URL, model, API mode, auth requirement, and API key are still synchronized from `cc-switch-cli`.

## 安装内容 / What It Installs

- `cc-switch-cli` wrapper：包装真实 CLI，命令结束后只有检测到 Codex 配置或 cc-switch DB 变化才刷新。
- `cc-switch-refresh-codex`：归一化 Codex 配置、同步 auth、迁移历史 session metadata，并重启 Codex app-server/proxy。
- 可选别名 / Optional aliases：`ccswitch`、`cc-switch`。

## 项目结构 / Repository Layout

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

## 环境要求 / Requirements

- Linux 目标服务器 / Linux target host
- 已安装官方 `cc-switch-cli` / Existing official `cc-switch-cli`
- Bash、Python 3、Python SQLite support
- `sha256sum`、`stat`、`pgrep`、`mktemp`、`sed`

## 安装 / Install

在目标服务器上执行 / On the target host:

```bash
git clone https://github.com/ztpx/cc-switch-codex-monitor.git
cd cc-switch-codex-monitor
sudo bash scripts/install-cc-switch-codex-monitor.sh
```

默认安装路径 / Default installed paths:

```text
/usr/local/bin/cc-switch-cli
/usr/local/bin/cc-switch-cli.real
/usr/local/bin/cc-switch-refresh-codex
/usr/local/bin/ccswitch
/usr/local/bin/cc-switch
```

安装到其他目录 / Install to another directory:

```bash
sudo bash scripts/install-cc-switch-codex-monitor.sh --install-dir /opt/bin
```

不创建别名 / Skip aliases:

```bash
sudo bash scripts/install-cc-switch-codex-monitor.sh --no-aliases
```

## 验证 / Verify

手动刷新一次 / Run a manual refresh once:

```bash
/usr/local/bin/cc-switch-refresh-codex
```

检查 Codex 配置是否固定为 `custom` / Check Codex config:

```bash
grep -E '^(model_provider|model|base_url|wire_api|requires_openai_auth)' ~/.codex/config.toml
grep -n '\[model_providers\.custom\]' ~/.codex/config.toml
```

查看刷新日志 / Check logs:

```bash
tail -80 ~/.cc-switch/codex-refresh.log
```

更多背景、运行逻辑和故障排查见：

More background, runtime details, and troubleshooting commands:

[docs/cc-switch-codex-monitor-guide.md](docs/cc-switch-codex-monitor-guide.md)

## 开发 / Development

本地检查 shell 脚本 / Run shell checks locally:

```bash
bash tests/shellcheck.sh
```

如果本机没有安装 `shellcheck`，测试脚本仍会执行 `bash -n` 语法检查。

If `shellcheck` is not installed, the test script still runs `bash -n` syntax checks.

## License

MIT
