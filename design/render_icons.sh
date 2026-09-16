#!/usr/bin/env bash
# Renders the launcher PNGs from the vector sources in this folder.
#
# Run it after changing any of the SVGs:
#   bash design/render_icons.sh
#
# Uses headless Chrome because it is already on this machine and renders SVG
# filters and masks the same way a browser does — no extra toolchain needed.
set -euo pipefail

CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIN_ROOT="$(cd "$ROOT" && pwd -W 2>/dev/null || echo "$ROOT")"
RES="$ROOT/android/app/src/main/res"

render() { # svg-name  size  output-path
  local svg="$1" size="$2" out="$3"
  local win_out="${WIN_ROOT}/${out#"$ROOT/"}"
  mkdir -p "$(dirname "$out")"
  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --default-background-color=00000000 \
    --window-size="$size,$size" \
    --screenshot="$(cygpath -w "$out" 2>/dev/null || echo "$win_out")" \
    "file:///${WIN_ROOT}/design/${svg}?size=${size}" >/dev/null 2>&1
  printf '  %-46s %sx%s\n' "${out#"$ROOT/"}" "$size" "$size"
}

# The SVGs declare width/height 512; Chrome scales them to the window size.
sized() { # svg  size  out
  local tmp="$ROOT/design/.render.svg"
  sed -E "s/width=\"512\" height=\"512\"/width=\"$2\" height=\"$2\"/" \
    "$ROOT/design/$1" > "$tmp"
  render ".render.svg" "$2" "$3"
}

echo "Launcher icon (legacy square):"
sized app_icon.svg 48  "$RES/mipmap-mdpi/ic_launcher.png"
sized app_icon.svg 72  "$RES/mipmap-hdpi/ic_launcher.png"
sized app_icon.svg 96  "$RES/mipmap-xhdpi/ic_launcher.png"
sized app_icon.svg 144 "$RES/mipmap-xxhdpi/ic_launcher.png"
sized app_icon.svg 192 "$RES/mipmap-xxxhdpi/ic_launcher.png"

echo "Adaptive foreground (108dp canvas):"
sized app_icon_foreground.svg 108 "$RES/mipmap-mdpi/ic_launcher_foreground.png"
sized app_icon_foreground.svg 162 "$RES/mipmap-hdpi/ic_launcher_foreground.png"
sized app_icon_foreground.svg 216 "$RES/mipmap-xhdpi/ic_launcher_foreground.png"
sized app_icon_foreground.svg 324 "$RES/mipmap-xxhdpi/ic_launcher_foreground.png"
sized app_icon_foreground.svg 432 "$RES/mipmap-xxxhdpi/ic_launcher_foreground.png"

echo "Themed icon (Android 13 monochrome):"
sized app_icon_monochrome.svg 108 "$RES/mipmap-mdpi/ic_launcher_monochrome.png"
sized app_icon_monochrome.svg 162 "$RES/mipmap-hdpi/ic_launcher_monochrome.png"
sized app_icon_monochrome.svg 216 "$RES/mipmap-xhdpi/ic_launcher_monochrome.png"
sized app_icon_monochrome.svg 324 "$RES/mipmap-xxhdpi/ic_launcher_monochrome.png"
sized app_icon_monochrome.svg 432 "$RES/mipmap-xxxhdpi/ic_launcher_monochrome.png"

echo "Preview:"
sized app_icon.svg 1024 "$ROOT/design/app_icon_1024.png"

rm -f "$ROOT/design/.render.svg"
echo "Done."
