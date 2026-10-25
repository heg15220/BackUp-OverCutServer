#!/usr/bin/env bash
# Headless test suite.   tools/run_tests.sh [filter]
# Benchmark (24 cars):   "$GODOT" --headless --path . --script res://tests/bench/bench_sim.gd
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/c/Users/hugoe/AppData/Local/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe}"
ARGS=(--headless --fixed-fps 120 --path "$HERE" --script res://tests/run_tests.gd)
[ $# -ge 1 ] && ARGS+=(-- "--filter=$1")
"$GODOT" "${ARGS[@]}"
