#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

scripts=(
  "$repo_root/bin/cc-switch-cli-wrapper"
  "$repo_root/bin/cc-switch-refresh-codex"
  "$repo_root/scripts/install-cc-switch-codex-monitor.sh"
)

for script in "${scripts[@]}"; do
  bash -n "$script"
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${scripts[@]}"
else
  printf 'shellcheck not found; skipped static analysis after bash -n.\n' >&2
fi
