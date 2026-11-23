#!/usr/bin/env bash
set -euo pipefail

# Godot can log script/import errors while returning zero; fail on those too.
GODOT_BIN="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/.."
check_log="$(mktemp)"
trap 'rm -f "$check_log"' EXIT

run_checked() {
    "$GODOT_BIN" "$@" 2>&1 | tee "$check_log"
    if grep -Eq 'SCRIPT ERROR:|(^|[[:space:]])ERROR:' "$check_log"; then
        return 1
    fi
}

run_checked --headless --path . --editor --quit
run_checked --headless --path . --script res://tests/run_tests.gd
run_checked --headless --path . --fixed-fps 60 --script res://tests/run_customer_tests.gd
run_checked --headless --path . --fixed-fps 60 --script res://tests/run_checkout_tests.gd
run_checked --headless --path . --fixed-fps 60 --script res://tests/run_day_tests.gd
run_checked --headless --path . --quit-after 60
