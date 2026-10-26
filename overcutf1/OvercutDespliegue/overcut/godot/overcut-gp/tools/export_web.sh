#!/usr/bin/env bash
# Exports OverCut GP for the web (no threads: no COOP/COEP headers needed) and,
# if a target is given, copies the build into a frontend's public/ folder.
#   tools/export_web.sh [<frontend>/public/games/overcut-gp]
# GODOT can point at another Godot 4.7.2 console binary.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/c/Users/hugoe/AppData/Local/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe}"
mkdir -p "$HERE/export/web"
# Keep Godot from importing its own build output as project assets.
touch "$HERE/export/.gdignore"
rm -f "$HERE"/export/web/*.import
# Our own trimmed template (tools/build_web_template.sh) once it has been built.
TEMPLATE="$HERE/export/templates/web_nothreads_release.zip"
if [ -f "$TEMPLATE" ]; then
  command -v cygpath > /dev/null && TEMPLATE="$(cygpath -m "$TEMPLATE")"
  cp "$HERE/export_presets.cfg" "$HERE/export/export_presets.cfg.bak"
  trap 'mv "$HERE/export/export_presets.cfg.bak" "$HERE/export_presets.cfg"' EXIT
  sed -i "s|^custom_template/release=.*|custom_template/release=\"$TEMPLATE\"|" "$HERE/export_presets.cfg"
  echo "Using web template $TEMPLATE"
fi
"$GODOT" --headless --path "$HERE" --export-release "Web" export/web/index.html
if [ $# -ge 1 ]; then
  mkdir -p "$1"
  rm -f "$1"/index.*
  find "$HERE/export/web" -maxdepth 1 -name "index.*" ! -name "*.import" -exec cp {} "$1"/ \;
  echo "Copied web build to $1"
fi
