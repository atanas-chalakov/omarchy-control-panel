#!/usr/bin/env bash
# install.sh — Setup and install Omarchy Control Panel
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="ac.control-panel"

echo "============================================================"
echo " Installing Omarchy Control Panel ($PLUGIN_ID)"
echo "============================================================"

# 1. Ensure required local directories exist
mkdir -p "$HOME/.config/omarchy/plugins"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/applications"

# 2. Link plugin into Omarchy plugins directory
PLUGIN_TARGET="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
if [[ -L "$PLUGIN_TARGET" || -d "$PLUGIN_TARGET" ]]; then
  if [[ "$(readlink -f "$PLUGIN_TARGET" 2>/dev/null || true)" == "$SCRIPT_DIR" ]]; then
    echo "✓ Plugin symlink already points to $SCRIPT_DIR"
  else
    echo "Updating plugin symlink at $PLUGIN_TARGET..."
    rm -rf "$PLUGIN_TARGET"
    ln -s "$SCRIPT_DIR" "$PLUGIN_TARGET"
  fi
else
  echo "Linking plugin into $PLUGIN_TARGET..."
  ln -s "$SCRIPT_DIR" "$PLUGIN_TARGET"
fi

# 3. Install CLI launcher
echo "Installing CLI launcher to ~/.local/bin/omarchy-control-panel..."
ln -sf "$SCRIPT_DIR/bin/omarchy-control-panel" "$HOME/.local/bin/omarchy-control-panel"
chmod +x "$SCRIPT_DIR/bin/omarchy-control-panel"

# 4. Install Desktop Application entry
echo "Installing desktop entry to ~/.local/share/applications/omarchy-control-panel.desktop..."
sed "s|Exec=omarchy-control-panel|Exec=$HOME/.local/bin/omarchy-control-panel|g" \
  "$SCRIPT_DIR/omarchy-control-panel.desktop" > "$HOME/.local/share/applications/omarchy-control-panel.desktop"

# Update desktop database if available
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# 5. Validate plugin manifest
if command -v omarchy >/dev/null 2>&1; then
  echo "Validating plugin manifest..."
  omarchy plugin validate "$SCRIPT_DIR" || echo "Note: Manifest validation warning"

  # 6. Enable in Omarchy shell
  echo "Enabling plugin in Omarchy shell..."
  omarchy plugin enable "$PLUGIN_ID" --section right 2>/dev/null || true
fi

echo ""
echo "============================================================"
echo " ✓ Installation complete!"
echo "============================================================"
echo "You can now open the Control Panel using:"
echo "  • Status Bar: Click the Control Panel companion icon"
echo "  • Terminal:   omarchy-control-panel (or omarchy-control-panel sound)"
echo "  • App Menu:   Search for 'Control Panel' in Rofi / Walker"
echo ""
echo "To bind to a key in Hyprland (~/.config/hypr/bindings.conf):"
echo "  bind = \$mainMod, I, exec, omarchy-control-panel"
echo "============================================================"
