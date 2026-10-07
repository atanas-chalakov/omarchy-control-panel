#!/usr/bin/env bash
# uninstall.sh — Remove Omarchy Control Panel
set -euo pipefail

PLUGIN_ID="ac.control-panel"

echo "Uninstalling Omarchy Control Panel ($PLUGIN_ID)..."

# 1. Disable in Omarchy shell
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin disable "$PLUGIN_ID" 2>/dev/null || true
fi

# 2. Remove files
rm -f "$HOME/.local/bin/omarchy-control-panel"
rm -f "$HOME/.local/share/applications/omarchy-control-panel.desktop"
rm -f "$HOME/.config/omarchy/plugins/$PLUGIN_ID"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

echo "✓ Omarchy Control Panel successfully removed."
