#!/usr/bin/env bash
# Base TAP test library for omarchy-control-panel test suite

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  echo "source test/base-test.sh from a test file; do not run it directly" >&2
  exit 1
fi

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT

TEST_DIR="$ROOT/test"
SCRIPTS_DIR="$ROOT/scripts"
VIEWS_DIR="$ROOT/views"
MANIFEST="$ROOT/manifest.json"

export TEST_DIR SCRIPTS_DIR VIEWS_DIR MANIFEST

pass() {
  printf 'ok - %s\n' "$1"
}

skip() {
  printf 'ok - %s # SKIP\n' "$1"
}

fail() {
  local description="$1"
  local detail="${2:-}"

  [[ -n $detail ]] && printf '%s\n' "$detail" >&2
  printf 'not ok - %s\n' "$description" >&2
  exit 1
}

require_command() {
  local command="$1"
  command -v "$command" >/dev/null 2>&1 || fail "required command is available: $command"
}

compositor_reachable() {
  local socket=${WAYLAND_DISPLAY:-}
  [[ -n $socket ]] || return 1
  [[ $socket == /* ]] || socket=${XDG_RUNTIME_DIR:-}/$socket
  [[ -S $socket ]] || return 1

  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || return 0

  local attempt
  for attempt in 1 2 3; do
    hyprctl -j monitors >/dev/null 2>&1 && return 0
    (( attempt < 3 )) && sleep 0.3
  done

  return 1
}

require_compositor() {
  local description="$1"
  if compositor_reachable; then
    ulimit -c 0 2>/dev/null || true
    return 0
  fi
  skip "no Wayland compositor; skipping $description"
  exit 0
}
