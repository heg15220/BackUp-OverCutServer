#!/usr/bin/env bash
# Re-bakes data/speed_envelopes.json (SpeedProfile's skidpad and car envelopes) after a
# physics or car-data change; tests/ai/test_speed_envelopes.gd fails while it is stale.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/c/Users/hugoe/AppData/Local/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe}"
"$GODOT" --headless --path "$HERE" --script res://tools/bake_speed_envelopes.gd
