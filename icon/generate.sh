#!/usr/bin/env bash
# Regenerates every icon in the repo from icon/caminata.svg.
#
# Run it after editing the SVG; the PNGs are committed so that neither build
# needs rsvg-convert, but they are generated files and nothing should edit
# them by hand.
#
#   brew install librsvg imagemagick
#   ./icon/generate.sh

set -euo pipefail
cd "$(dirname "$0")/.."

SRC="icon/caminata.svg"
IOS="apps/ios/Caminata/Resources/Assets.xcassets/AppIcon.appiconset"
WEB="apps/web"
# The flat colour behind the gradient, used wherever transparency is not allowed.
BG="#0B3D4A"

command -v rsvg-convert >/dev/null || { echo "need rsvg-convert (brew install librsvg)"; exit 1; }
command -v magick >/dev/null || { echo "need magick (brew install imagemagick)"; exit 1; }

render() { rsvg-convert -w "$1" -h "$1" "$SRC" -o "$2"; }

mkdir -p "$IOS"

# iOS rejects an app icon with an alpha channel, even a fully opaque one.
render 1024 /tmp/caminata-1024.png
magick /tmp/caminata-1024.png -background "$BG" -alpha remove -alpha off \
  "$IOS/AppIcon-1024.png"

cat > "$IOS/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

cat > "apps/ios/Caminata/Resources/Assets.xcassets/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

cp "$SRC" "$WEB/favicon.svg"

# A 16px favicon is where the SVG stops being legible, so a raster fallback
# goes with it.
render 32 "$WEB/favicon-32.png"
# Home-screen icon on iOS, which also refuses transparency.
render 180 /tmp/caminata-180.png
magick /tmp/caminata-180.png -background "$BG" -alpha remove -alpha off \
  "$WEB/apple-touch-icon.png"
render 192 "$WEB/icon-192.png"
render 512 "$WEB/icon-512.png"

echo "Generated:"
echo "  $IOS/AppIcon-1024.png"
echo "  $WEB/{favicon.svg,favicon-32.png,apple-touch-icon.png,icon-192.png,icon-512.png}"
