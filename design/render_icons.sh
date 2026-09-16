#!/usr/bin/env bash
# Renders the launcher PNGs from the vector sources in this folder.
#
# Run it after changing any of the SVGs:
#   bash design/render_icons.sh
#
# Headless Chrome renders the SVG filters and masks exactly as a browser does,
# but it will not shrink its window below a minimum size, so small outputs come
# out wrong if rendered directly. Each SVG is therefore rendered once at 1024px
# and every launcher size is downscaled from that with high-quality bicubic
# filtering (System.Drawing, already on Windows).
set -euo pipefail

CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RES="$ROOT/android/app/src/main/res"
TMP="$ROOT/design/.render"
mkdir -p "$TMP"

master() { # svg-name -> $TMP/<name>.png at 1024
  local name="${1%.svg}"
  sed -E 's/width="512" height="512"/width="1024" height="1024"/' \
    "$ROOT/design/$1" > "$TMP/$name.svg"
  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --default-background-color=00000000 \
    --window-size=1024,1024 \
    --screenshot="$(cygpath -w "$TMP/$name.png")" \
    "file:///$(cygpath -m "$TMP/$name.svg")" >/dev/null 2>&1
}

JOBS=""
scale() { # svg-name size out
  JOBS+="$(cygpath -w "$TMP/${1%.svg}.png")|$2|$(cygpath -w "$3");"
  mkdir -p "$(dirname "$3")"
  printf '  %-52s %sx%s\n' "${3#"$ROOT/"}" "$2" "$2"
}

master app_icon.svg
master app_icon_foreground.svg
master app_icon_monochrome.svg

echo "Launcher icon (legacy square):"
scale app_icon.svg 48  "$RES/mipmap-mdpi/ic_launcher.png"
scale app_icon.svg 72  "$RES/mipmap-hdpi/ic_launcher.png"
scale app_icon.svg 96  "$RES/mipmap-xhdpi/ic_launcher.png"
scale app_icon.svg 144 "$RES/mipmap-xxhdpi/ic_launcher.png"
scale app_icon.svg 192 "$RES/mipmap-xxxhdpi/ic_launcher.png"

echo "Adaptive foreground (108dp canvas):"
scale app_icon_foreground.svg 108 "$RES/mipmap-mdpi/ic_launcher_foreground.png"
scale app_icon_foreground.svg 162 "$RES/mipmap-hdpi/ic_launcher_foreground.png"
scale app_icon_foreground.svg 216 "$RES/mipmap-xhdpi/ic_launcher_foreground.png"
scale app_icon_foreground.svg 324 "$RES/mipmap-xxhdpi/ic_launcher_foreground.png"
scale app_icon_foreground.svg 432 "$RES/mipmap-xxxhdpi/ic_launcher_foreground.png"

echo "Themed icon (Android 13 monochrome):"
scale app_icon_monochrome.svg 108 "$RES/mipmap-mdpi/ic_launcher_monochrome.png"
scale app_icon_monochrome.svg 162 "$RES/mipmap-hdpi/ic_launcher_monochrome.png"
scale app_icon_monochrome.svg 216 "$RES/mipmap-xhdpi/ic_launcher_monochrome.png"
scale app_icon_monochrome.svg 324 "$RES/mipmap-xxhdpi/ic_launcher_monochrome.png"
scale app_icon_monochrome.svg 432 "$RES/mipmap-xxxhdpi/ic_launcher_monochrome.png"

JOBS="$JOBS" powershell.exe -NoProfile -Command '
Add-Type -AssemblyName System.Drawing
foreach ($job in $env:JOBS.Split(";", [StringSplitOptions]::RemoveEmptyEntries)) {
  $src, $size, $out = $job.Split("|"); $size = [int]$size
  $img = [System.Drawing.Image]::FromFile($src)
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = "HighQualityBicubic"; $g.SmoothingMode = "HighQuality"
  $g.PixelOffsetMode = "HighQuality"; $g.CompositingQuality = "HighQuality"
  $attr = New-Object System.Drawing.Imaging.ImageAttributes
  $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $size, $size), 0, 0, $img.Width, $img.Height, "Pixel", $attr)
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose()
}'

echo "Preview:"
cp "$TMP/app_icon.png" "$ROOT/design/app_icon_1024.png"
echo "  design/app_icon_1024.png"

rm -rf "$TMP"
echo "Done."
