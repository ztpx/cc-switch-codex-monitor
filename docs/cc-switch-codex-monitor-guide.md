# cc-switch-cli 与 Codex Desktop 配置统一方案 / Configuration Unification Guide

本文档记录本次 `cc-switch-cli` 管理 Codex CLI / Codex Desktop 远程会话时遇到的问题、最终修复策略、安装步骤和验证方法。后续迁移到其他服务器时，可以直接上传本项目并执行 `scripts/` 下的安装脚本，避免重新手工配置。

This guide documents the issue, final strategy, installation steps, verification commands, and troubleshooting flow for keeping Codex CLI / Codex Desktop sessions visible while switching providers with `cc-switch-cli`.

## 背景问题 / Background

远端服务器通过 `cc-switch-cli` 切换 Codex 供应商后，Codex Desktop 远程工作区里的历史会话看起来会丢失。例如：

After switching Codex providers through `cc-switch-cli` on a remote server, Codex Desktop may appear to lose remote workspace history. For example:

- EliasApi 下能看到 `/dep/lx_iso/ubuntu-24.04.3_cipan` 的历史会话。
- 切到 GGbond 后，同一工作区显示“暂无对话”。
- 切回 EliasApi 后，会话又出现。

实际会话文件没有删除，仍在：

```bash
/root/.codex/sessions
```

根因是 `cc-switch-cli` 原生切换供应商时，会把 Codex 顶层配置写成不同的 `model_provider`，例如：

```toml
model_provider = "OpenAI"
model_provider = "ggbond"
model_provider = "api"
```

Codex Desktop 会按 session metadata 里的 `model_provider` 分区展示会话。供应商切换后，Desktop 会进入另一个分区，所以旧会话看起来像丢了。

Codex Desktop groups sessions by the `model_provider` stored in session metadata. When provider switching changes this value, Desktop enters a different group, so old sessions look hidden rather than deleted.

## 最终策略 / Final Strategy

统一约束如下：

The normalized rules are:

1. Codex 顶层永远固定：

```toml
model_provider = "custom"
```

2. Codex provider section 永远固定：

```toml
[model_providers.custom]
```

3. `name` 保留当前供应商显示名，不影响会话分区，例如：

```toml
[model_providers.custom]
name = "GGbond"
base_url = "https://api.bondai.cc"
wire_api = "responses"
requires_openai_auth = true
```

4. 切换供应商时只允许变化这些内容：

- `model`
- `[model_providers.custom].name`
- `[model_providers.custom].base_url`
- `[model_providers.custom].wire_api`
- `[model_providers.custom].requires_openai_auth`
- `/root/.codex/auth.json` 中的 key

5. 已有 session metadata 会一次性迁移为：

```json
"model_provider": "custom"
```

## 本地文件 / Project Files

当前项目文件结构：

```text
bin/cc-switch-cli-wrapper
bin/cc-switch-refresh-codex
scripts/install-cc-switch-codex-monitor.sh
docs/cc-switch-codex-monitor-guide.md
```

文件职责：

- `cc-switch-cli-wrapper`：包装真实的 `cc-switch-cli`，在命令退出后检查配置/DB 是否变化，有变化才执行刷新。
- `cc-switch-refresh-codex`：归一化 Codex 配置、同步当前供应商 key、迁移 session metadata、重启 Codex app-server/proxy。
- `install-cc-switch-codex-monitor.sh`：通用安装脚本，把原始 `cc-switch-cli` 移动为 `.real`，安装 wrapper/helper，并创建 `ccswitch`、`cc-switch` alias。

File responsibilities:

- `cc-switch-cli-wrapper`: wraps the real `cc-switch-cli` and refreshes Codex only when config or DB files changed after the command exits.
- `cc-switch-refresh-codex`: normalizes Codex config, syncs the current provider key, migrates session metadata, and restarts Codex app-server/proxy.
- `install-cc-switch-codex-monitor.sh`: installer that moves the original `cc-switch-cli` to `.real`, installs the wrapper/helper, and creates optional aliases.

## 远端安装步骤 / Remote Installation

假设目标服务器已安装官方 `cc-switch-cli`，路径为 `/usr/local/bin/cc-switch-cli`。

Assume the target server already has the official `cc-switch-cli` installed at `/usr/local/bin/cc-switch-cli`.

从本地上传整个项目目录，或在目标服务器上 clone 仓库后执行：

```bash
git clone <repo-url> cc-switch-codex-monitor
cd cc-switch-codex-monitor
sudo bash scripts/install-cc-switch-codex-monitor.sh
```

如果只想通过 `scp` 临时上传：

```bash
scp -r bin scripts root@<server-ip>:/tmp/cc-switch-codex-monitor/
ssh root@<server-ip> 'cd /tmp/cc-switch-codex-monitor && bash scripts/install-cc-switch-codex-monitor.sh'
```

安装完成后的远端文件：

```text
/usr/local/bin/cc-switch-cli
/usr/local/bin/cc-switch-cli.real
/usr/local/bin/cc-switch-refresh-codex
/usr/local/bin/ccswitch
/usr/local/bin/cc-switch
```

如果只想更新当前 wrapper/helper，不移动真实 binary：

```bash
scp bin/cc-switch-cli-wrapper bin/cc-switch-refresh-codex root@<server-ip>:/tmp/
ssh root@<server-ip> 'install -m 0755 /tmp/cc-switch-cli-wrapper /usr/local/bin/cc-switch-cli && install -m 0755 /tmp/cc-switch-refresh-codex /usr/local/bin/cc-switch-refresh-codex'
```

## 运行逻辑 / Runtime Behavior

### cc-switch-cli wrapper

wrapper 会计算这些文件的签名：

```text
$CODEX_HOME/config.toml
$CODEX_HOME/auth.json
$HOME/.cc-switch/cc-switch.db
```

命令执行前记录一次，命令退出后再记录一次。只有发生变化时才执行：

```bash
/usr/local/bin/cc-switch-refresh-codex
```

刷新节奏：

- 不在 TUI 界面内部每秒刷新。
- 不在添加/编辑/删除过程中频繁重启 Codex。
- 只在 `ccswitch` TUI 退出后统一检查一次。
- `provider current` / `provider list` 这类只读命令不会触发刷新。

Refresh behavior:

- It does not refresh every second inside the TUI.
- It avoids frequent Codex restarts while adding/editing/deleting providers.
- It checks once after `ccswitch` exits.
- Read-only commands such as `provider current` / `provider list` do not trigger refresh unless files actually changed.

### cc-switch-refresh-codex

刷新脚本会做这些事：

1. 扫描 `/root/.cc-switch/cc-switch.db` 中所有 Codex provider 模板。
2. 把模板中的 `model_provider` 和 `[model_providers.*]` 统一改成 `custom`。
3. 保留 provider 的显示名到 `name`，例如 `EliasApi`、`GGbond`。
4. 读取当前 provider 的 `model`、`base_url`、`wire_api`、`requires_openai_auth`。
5. 写入 `/root/.codex/config.toml`，固定为 `[model_providers.custom]`。
6. 同步当前 provider 的 key 到 `/root/.codex/auth.json`。
7. 把已有 `/root/.codex/sessions/**/*.jsonl` 第一行 session metadata 里的 `model_provider` 迁移为 `custom`。
8. 重启 Codex app-server/proxy，让 Codex Desktop/CLI 加载新配置。

In short, the refresh helper rewrites Codex provider templates and active config to use `custom`, syncs auth from the current provider, migrates existing session metadata, and restarts Codex processes so the new config is loaded.

## 验证命令 / Verification

查看当前供应商：

```bash
cc-switch-cli provider current -a codex
```

查看 Codex 配置是否固定 `custom`：

```bash
grep -E '^(model_provider|model|base_url|wire_api|requires_openai_auth)' /root/.codex/config.toml
grep -n '\[model_providers\.custom\]' /root/.codex/config.toml
```

期望示例：

```toml
model_provider = "custom"
model = "gpt-5.4"

[model_providers.custom]
name = "GGbond"
base_url = "https://api.bondai.cc"
wire_api = "responses"
requires_openai_auth = true
```

验证所有 session metadata 是否统一为 `custom`：

```bash
python3 - <<'PY'
import json, glob, collections
c = collections.Counter()
for f in glob.glob("/root/.codex/sessions/**/*.jsonl", recursive=True):
    try:
        with open(f, encoding="utf-8") as fh:
            first = json.loads(fh.readline())
        c[first.get("payload", {}).get("model_provider")] += 1
    except Exception:
        c["ERROR"] += 1
print(dict(c))
PY
```

期望：

```text
{'custom': <session_count>}
```

验证指定项目历史会话是否可见：

```bash
cc-switch-cli sessions list | grep -F "/dep/lx_iso/ubuntu-24.04.3_cipan" | head
```

验证 Codex 请求：

```bash
cd /dep/lx_iso/ubuntu-24.04.3_cipan
timeout 75s codex exec --json "只回复 OK" </dev/null
```

期望返回包含：

```json
{"type":"item.completed","item":{"type":"agent_message","text":"OK"}}
```

查看刷新日志：

```bash
tail -80 /root/.cc-switch/codex-refresh.log
```

正常日志应包含：

```text
start command: provider switch -a codex ggbond
codex config changed after command: provider switch -a codex ggbond
Codex config already normalized for ggbond (GGbond).
Codex auth synchronized for current provider.
Codex restart complete; the next Codex CLI/App connection will load the new config.
```

旧版本日志里不应频繁出现 TUI 内部操作期间的多次：

```text
codex config changed while command is running
```

## 新增供应商后的预期 / After Adding a New Provider

在 `ccswitch` TUI 中新增供应商时，cc-switch 可能仍会先按 provider ID 生成模板，例如：

```toml
model_provider = "some_provider"

[model_providers.some_provider]
name = "some_provider"
```

这是 cc-switch 原生行为。退出 TUI 后，wrapper 会发现 `cc-switch.db` 变化并执行刷新，自动改成：

```toml
model_provider = "custom"

[model_providers.custom]
name = "<供应商显示名>"
```

然后当前 provider 会写入 `/root/.codex/config.toml`。

When a new provider is added in the `ccswitch` TUI, native `cc-switch-cli` behavior may generate provider-specific templates first. After the TUI exits, the wrapper detects DB changes and normalizes them back to `custom`.

## 故障排查 / Troubleshooting

### 切换后 Desktop 还是看不到历史会话 / Desktop Still Cannot See History

检查 session metadata 是否仍有非 `custom`：

```bash
python3 - <<'PY'
import json, glob, collections
c = collections.Counter()
for f in glob.glob("/root/.codex/sessions/**/*.jsonl", recursive=True):
    try:
        with open(f, encoding="utf-8") as fh:
            first = json.loads(fh.readline())
        c[first.get("payload", {}).get("model_provider")] += 1
    except Exception:
        c["ERROR"] += 1
print(dict(c))
PY
```

手动执行一次刷新：

```bash
/usr/local/bin/cc-switch-refresh-codex
```

### 切换后 Codex 请求 401 / Codex Returns 401 After Switching

检查 active key 是否等于当前 provider key。不要输出完整 key，可以比较 hash：

```bash
python3 - <<'PY'
import hashlib, json, sqlite3
active = json.load(open("/root/.codex/auth.json"))["OPENAI_API_KEY"]
print("active", hashlib.sha256(active.encode()).hexdigest()[:16])
with sqlite3.connect("/root/.cc-switch/cc-switch.db") as conn:
    for provider_id, key in conn.execute("select id, json_extract(settings_config, '$.auth.OPENAI_API_KEY') from providers where app_type='codex'"):
        print(provider_id, hashlib.sha256((key or '').encode()).hexdigest()[:16])
PY
```

### 修改后 Codex Desktop 没加载新配置 / Desktop Did Not Load New Config

手动重启 Codex app-server/proxy：

```bash
/usr/local/bin/cc-switch-refresh-codex
```

或检查残留进程：

```bash
pgrep -af 'codex app-server|codex app-server proxy'
```

## 给 AI 的实现清单 / Implementation Checklist for Another AI

如果后续让另一个 AI 在新服务器实现同样优化，让它按以下清单执行：

1. 安装官方 `cc-switch-cli`，确认能运行 `cc-switch-cli --version`。
2. 上传项目并执行 `scripts/install-cc-switch-codex-monitor.sh`。
3. 确认 `/usr/local/bin/cc-switch-cli.real` 是官方 binary。
4. 确认 `/usr/local/bin/cc-switch-cli` 是 wrapper。
5. 确认 `/usr/local/bin/cc-switch-refresh-codex` 存在且可执行。
6. 执行 `/usr/local/bin/cc-switch-refresh-codex` 做一次初始归一化。
7. 检查 `/root/.codex/config.toml` 顶层必须是 `model_provider = "custom"`。
8. 检查当前 provider section 必须是 `[model_providers.custom]`。
9. 检查 `name` 是当前供应商显示名。
10. 检查 `/root/.codex/sessions` metadata 全部为 `custom`。
11. 切换至少两个供应商，确认只变化 `name/base_url/model/key`，不变化 `model_provider`。
12. 运行 `codex exec --json "只回复 OK" </dev/null` 验证请求成功。

## 当前验证过的远端行为 / Verified Remote Behavior

在 `10.100.52.179` 上已验证：

- EliasApi 与 GGbond 切换后，`model_provider` 都保持 `custom`。
- `[model_providers.custom].name` 会随当前供应商变成 `EliasApi` 或 `GGbond`。
- `/root/.codex/sessions` 中历史会话 metadata 已统一为 `custom`。
- `cc-switch-cli sessions list` 能看到 `/dep/lx_iso/ubuntu-24.04.3_cipan` 的历史会话。
- `codex exec --json "只回复 OK" </dev/null` 可以返回 `OK`。
- wrapper 不再在 TUI 操作过程中频繁刷新，只在命令/TUI 退出后检查一次。
