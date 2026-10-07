#!/usr/bin/env bash
# capture-gallery.sh — Automated screenshot capture of Omarchy Control Panel
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ASSETS_DIR="$PROJECT_ROOT/assets/screenshots"
PLUGIN_ID="ac.control-panel"

mkdir -p "$ASSETS_DIR"

if ! command -v grim >/dev/null 2>&1; then
  echo "Error: grim is required to capture screenshots." >&2
  exit 1
fi

get_geometry() {
  hyprctl clients -j | jq -r '.[] | select(.title=="Control Panel") | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | head -n1
}

capture_view() {
  local name="$1"
  local payload="$2"
  local target_file="$ASSETS_DIR/${name}.png"

  echo "Capturing view: $name..."
  omarchy-shell shell summon "$PLUGIN_ID" "$payload" >/dev/null 2>&1 || true
  sleep 0.6

  local geom
  geom=$(get_geometry)
  if [[ -n "$geom" && "$geom" != "null" ]]; then
    grim -g "$geom" "$target_file"
    echo "✓ Saved $target_file ($geom)"
  else
    echo "Warning: could not detect Control Panel window geometry" >&2
  fi
}

echo "============================================================"
echo " Capturing Omarchy Control Panel Screenshot Gallery"
echo "============================================================"

capture_view "overview" '{"category":"search","diff":false}'
capture_view "diff-inspector" '{"category":"appearance","diff":true}'
capture_view "power-gaming" '{"category":"power","diff":false}'
capture_view "sound-audio" '{"category":"sound","diff":false}'
capture_view "network-wifi" '{"category":"network","diff":false}'
capture_view "wifi-share-qr" '{"category":"network","action":"qr","diff":false}'
capture_view "appearance" '{"category":"appearance","diff":false}'
capture_view "displays" '{"category":"displays","diff":false}'

# Copy primary overview to root preview.png for marketplace
cp "$ASSETS_DIR/overview.png" "$PROJECT_ROOT/preview.png"

# Hide panel after capturing
omarchy-shell -q shell hide "$PLUGIN_ID" >/dev/null 2>&1 || true

echo "============================================================"
echo " Gallery capture complete! Saved to assets/screenshots/"
echo "============================================================"
