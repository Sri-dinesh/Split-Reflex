#!/usr/bin/env bash
# ==============================================================================
# Split Reflex - Android launcher icon generator
#
# Regenerates every launcher asset from the single 512x512 Play Store source:
#   * legacy square + round mipmaps (Android 7 and below)
#   * adaptive icon foreground + monochrome layers (Android 8+)
#
# Requirements: ImageMagick 7 (`magick`).
# Usage: ./tool/generate_android_icons.sh
# ==============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="assets/playstore_icon_512.png"
RES="android/app/src/main/res"
BG_COLOR="#07070A"

if [[ ! -f "$SRC" ]]; then
  echo "error: missing $SRC" >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "error: ImageMagick 7 (magick) is required" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- 1. Foreground layer: drop the near-black plate, keep the glow -----------
magick "$SRC" \
  -fuzz 22% -transparent "$BG_COLOR" \
  "$WORK/foreground.png"

# --- 2. Monochrome layer: the bright diamond silhouette (themed icons) ------
magick "$SRC" \
  -colorspace gray -threshold 42% -alpha copy \
  -fill white -colorize 100 \
  "$WORK/monochrome.png"

# --- 3. Legacy square icon (full bleed, no mask) ----------------------------
magick "$SRC" -resize 512x512 "$WORK/legacy.png"

# --- 4. Legacy round icon ---------------------------------------------------
magick "$SRC" -resize 512x512 -alpha set -background none \
  \( +clone -alpha extract -fill black -colorize 100 \
     -draw "fill white circle 256,256 256,1" \) \
  -alpha off -compose CopyOpacity -composite \
  "$WORK/round.png"

declare -A DENSITY=(
  [mdpi]=108
  [hdpi]=162
  [xhdpi]=216
  [xxhdpi]=324
  [xxxhdpi]=432
)

for density in "${!DENSITY[@]}"; do
  size="${DENSITY[$density]}"
  # Adaptive icons: artwork must sit inside the 66dp safe zone of the 108dp canvas.
  inner=$(( size * 66 / 100 ))
  dir="$RES/mipmap-$density"
  mkdir -p "$dir"

  magick -size "${size}x${size}" "xc:none" \
    \( "$WORK/foreground.png" -resize "${inner}x${inner}" \) \
    -gravity center -composite \
    "$dir/ic_launcher_foreground.png"

  magick -size "${size}x${size}" "xc:none" \
    \( "$WORK/monochrome.png" -resize "${inner}x${inner}" \) \
    -gravity center -composite \
    "$dir/ic_launcher_monochrome.png"

  legacy=$(( size * 48 / 108 ))
  magick "$WORK/legacy.png" -resize "${legacy}x${legacy}" "$dir/ic_launcher.png"
  magick "$WORK/round.png" -resize "${legacy}x${legacy}" "$dir/ic_launcher_round.png"
done

# --- 5. Adaptive icon descriptors ------------------------------------------
mkdir -p "$RES/mipmap-anydpi-v26" "$RES/values"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
XML

cp "$RES/mipmap-anydpi-v26/ic_launcher.xml" "$RES/mipmap-anydpi-v26/ic_launcher_round.xml"

cat > "$RES/values/colors.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">$BG_COLOR</color>
    <color name="launch_background">$BG_COLOR</color>
</resources>
XML

echo "Launcher icons regenerated in $RES"
