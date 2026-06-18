# Contributing / 贡献指南

感谢你改进这个项目。

Thanks for improving this project.

## Local Checks / 本地检查

Run:

```bash
bash tests/shellcheck.sh
```

这些脚本面向 Linux 主机运行，即使仓库是在 Windows 或其他平台上编辑，也请尽量在 Linux/CI 环境验证。

The scripts are intended to run on Linux hosts, even if the repository is edited from another platform.

## Project Notes / 项目约定

- 运行时脚本放在 `bin/`。Keep runtime scripts in `bin/`.
- 安装逻辑放在 `scripts/`。Keep installer logic in `scripts/`.
- 行为变更时更新 `docs/cc-switch-codex-monitor-guide.md`。Update the guide when behavior changes.
- 不要提交 secrets、provider keys、本地 Codex 配置或 cc-switch 数据库。Do not commit secrets, provider keys, local Codex configs, or cc-switch databases.
