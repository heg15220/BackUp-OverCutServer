#!/usr/bin/env bash
# Exports OverCut GP for the web (no threads: no COOP/COEP headers needed) and,
# if a target is given, copies the build into a frontend's public/ folder.
#   tools/export_web.sh [<frontend>/public/games/overcut-gp]
# GODOT can point at another Godot 4.7.2 console binary.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/c/Users/hugoe/AppData/Local/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe}"
mkdir -p "$HERE/export/web"
"$GODOT" --headless --path "$HERE" --export-release "Web" export/web/index.html
if [ $# -ge 1 ]; then
  mkdir -p "$1"
  rm -f "$1"/index.*
  cp "$HERE"/export/web/index.* "$1"/
  echo "Copied web build to $1"
fi
