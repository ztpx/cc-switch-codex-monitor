#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CLI_NAME="${CLI_NAME:-cc-switch-cli}"
REAL_SUFFIX="${REAL_SUFFIX:-.real}"
CREATE_ALIASES="${CREATE_ALIASES:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER_SOURCE="${CC_SWITCH_WRAPPER_SOURCE:-$REPO_ROOT/bin/cc-switch-cli-wrapper}"
REFRESH_SOURCE="${CC_SWITCH_REFRESH_SOURCE:-$REPO_ROOT/bin/cc-switch-refresh-codex}"

usage() {
  cat <<'USAGE'
Install Codex config refresh monitoring for cc-switch-cli.

Usage:
  scripts/install-cc-switch-codex-monitor.sh [options]

Options:
  --install-dir DIR      Directory containing cc-switch-cli (default: /usr/local/bin)
  --cli-name NAME        CLI executable name (default: cc-switch-cli)
  --wrapper FILE         Wrapper source file (default: ./bin/cc-switch-cli-wrapper)
  --refresh FILE         Refresh helper source file (default: ./bin/cc-switch-refresh-codex)
  --no-aliases           Do not create ccswitch and cc-switch aliases
  -h, --help             Show this help

Environment overrides:
  INSTALL_DIR=/usr/local/bin
  CLI_NAME=cc-switch-cli
  CREATE_ALIASES=1
  CC_SWITCH_WRAPPER_SOURCE=/path/to/cc-switch-cli-wrapper
  CC_SWITCH_REFRESH_SOURCE=/path/to/cc-switch-refresh-codex

Installed files:
  <install-dir>/cc-switch-cli          wrapper
  <install-dir>/cc-switch-cli.real     original cc-switch-cli binary
  <install-dir>/cc-switch-refresh-codex

Runtime logs:
  ~/.cc-switch/codex-refresh.log
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install-dir)
      INSTALL_DIR="${2:?missing value for --install-dir}"
      shift 2
      ;;
    --cli-name)
      CLI_NAME="${2:?missing value for --cli-name}"
      shift 2
      ;;
    --wrapper)
      WRAPPER_SOURCE="${2:?missing value for --wrapper}"
      shift 2
      ;;
    --refresh)
      REFRESH_SOURCE="${2:?missing value for --refresh}"
      shift 2
      ;;
    --no-aliases)
      CREATE_ALIASES=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

CLI_PATH="$INSTALL_DIR/$CLI_NAME"
REAL_PATH="$CLI_PATH$REAL_SUFFIX"
REFRESH_PATH="$INSTALL_DIR/cc-switch-refresh-codex"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

need_file() {
  if [ ! -f "$1" ]; then
    printf 'Missing source file: %s\n' "$1" >&2
    printf 'Run this installer from the repository root, or pass --wrapper/--refresh.\n' >&2
    exit 1
  fi
}

need_cmd sha256sum
need_cmd stat
need_cmd pgrep
need_cmd mktemp
need_cmd sed

need_file "$WRAPPER_SOURCE"
need_file "$REFRESH_SOURCE"

if [ "$(id -u)" -ne 0 ] && [ ! -w "$INSTALL_DIR" ]; then
  printf 'Need root or write permission for %s\n' "$INSTALL_DIR" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"

if [ ! -e "$CLI_PATH" ] && [ ! -e "$REAL_PATH" ]; then
  resolved="$(command -v "$CLI_NAME" 2>/dev/null || true)"
  if [ -n "$resolved" ]; then
    CLI_PATH="$resolved"
    INSTALL_DIR="$(dirname "$CLI_PATH")"
    REAL_PATH="$CLI_PATH$REAL_SUFFIX"
    REFRESH_PATH="$INSTALL_DIR/cc-switch-refresh-codex"
  else
    printf 'Cannot find %s. Install cc-switch-cli first.\n' "$CLI_NAME" >&2
    exit 1
  fi
fi

is_monitor_wrapper() {
  [ -f "$1" ] && grep -q 'CC_SWITCH_CODEX_MONITOR_LOG' "$1" 2>/dev/null
}

if [ -e "$CLI_PATH" ] || [ -L "$CLI_PATH" ]; then
  if is_monitor_wrapper "$CLI_PATH"; then
    printf 'Existing wrapper detected at %s\n' "$CLI_PATH"
  else
    if [ -e "$REAL_PATH" ]; then
      printf 'Real binary already exists: %s\n' "$REAL_PATH"
      printf 'Replacing wrapper only; leaving existing real binary in place.\n'
    else
      mv "$CLI_PATH" "$REAL_PATH"
      chmod 0755 "$REAL_PATH"
      printf 'Moved original CLI to %s\n' "$REAL_PATH"
    fi
  fi
fi

if [ ! -x "$REAL_PATH" ]; then
  printf 'Real cc-switch binary is missing or not executable: %s\n' "$REAL_PATH" >&2
  exit 1
fi

tmp_wrapper="$(mktemp)"
tmp_refresh="$(mktemp)"
cleanup() {
  rm -f "$tmp_wrapper" "$tmp_refresh"
}
trap cleanup EXIT

cp "$WRAPPER_SOURCE" "$tmp_wrapper"
cp "$REFRESH_SOURCE" "$tmp_refresh"
chmod 0755 "$tmp_wrapper" "$tmp_refresh"

escaped_real_path="$(printf '%s\n' "$REAL_PATH" | sed 's/[#\/&]/\\&/g')"
escaped_refresh_path="$(printf '%s\n' "$REFRESH_PATH" | sed 's/[#\/&]/\\&/g')"

sed -i \
  -e "s#REAL_BIN=\"\${CC_SWITCH_CLI_REAL:-/usr/local/bin/cc-switch-cli.real}\"#REAL_BIN=\"\${CC_SWITCH_CLI_REAL:-$escaped_real_path}\"#" \
  -e "s#REFRESH_BIN=\"\${CC_SWITCH_CODEX_REFRESH:-/usr/local/bin/cc-switch-refresh-codex}\"#REFRESH_BIN=\"\${CC_SWITCH_CODEX_REFRESH:-$escaped_refresh_path}\"#" \
  "$tmp_wrapper"

install -m 0755 "$tmp_wrapper" "$CLI_PATH"
install -m 0755 "$tmp_refresh" "$REFRESH_PATH"

if [ "$CREATE_ALIASES" = "1" ]; then
  ln -sfn "$CLI_PATH" "$INSTALL_DIR/ccswitch"
  ln -sfn "$CLI_PATH" "$INSTALL_DIR/cc-switch"
fi

printf 'Installed cc-switch Codex monitor.\n'
printf '  wrapper: %s\n' "$CLI_PATH"
printf '  real:    %s\n' "$REAL_PATH"
printf '  helper:  %s\n' "$REFRESH_PATH"
if [ "$CREATE_ALIASES" = "1" ]; then
  printf '  aliases: %s, %s\n' "$INSTALL_DIR/ccswitch" "$INSTALL_DIR/cc-switch"
fi
printf '  log:     ~/.cc-switch/codex-refresh.log\n'
