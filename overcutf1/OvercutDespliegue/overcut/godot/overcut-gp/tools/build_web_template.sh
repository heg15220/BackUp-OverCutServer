#!/usr/bin/env bash
# Builds OverCut GP's own web export template: Godot 4.7.2 without the modules the
# game never uses (tools/web_template/custom.py) and with GLES3 shader variants
# compiled on first use (tools/web_template/gles3_lazy_specializations.patch).
#   tools/build_web_template.sh
# Needs a Godot 4.7.2-stable checkout in GODOT_SRC, scons, and Emscripten 4.0.11
# from emsdk in EMSDK. tools/export_web.sh picks the result up automatically.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_SRC="${GODOT_SRC:-/c/Users/hugoe/godot-build/godot}"
EMSDK="${EMSDK:-/c/Users/hugoe/godot-build/emsdk}"
OUT="$HERE/export/templates/web_nothreads_release.zip"

# shellcheck disable=SC1091
source "$EMSDK/emsdk_env.sh" > /dev/null

cd "$GODOT_SRC"
if git apply --check "$HERE/tools/web_template/gles3_lazy_specializations.patch" 2> /dev/null; then
  git apply "$HERE/tools/web_template/gles3_lazy_specializations.patch"
elif ! git apply --reverse --check "$HERE/tools/web_template/gles3_lazy_specializations.patch" 2> /dev/null; then
  echo "The GLES3 patch neither applies nor is applied in $GODOT_SRC" >&2
  exit 1
fi

scons profile="$HERE/tools/web_template/custom.py" -j"$(nproc)"

mkdir -p "$(dirname "$OUT")"
touch "$HERE/export/.gdignore"
cp bin/godot.web.template_release.wasm32.nothreads.zip "$OUT"
echo "Web template: $OUT"
