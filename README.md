# Omarchy Control Panel Plugin

A unified graphical settings and control panel for [Omarchy Linux](https://omarchy.org/).

## Features
- **Displays**: Resolution, refresh rate, scaling, and brightness controls.
- **Power & Battery**: Performance, balanced, and power-saver profiles, idle and sleep timeouts.
- **Appearance**: System theme switcher and wallpaper controls.
- **Sound**: Volume slider and output/input selection.
- **About**: Hardware specs and system status.

## Architecture
- Native **Omarchy Shell Plugin** (`kind: ["panel"]`).
- Written in **QML / Quickshell** matching the active Omarchy theme.
- Entry point: `ControlPanel.qml`.

## Testing
Run the automated test suite covering manifest validation, backend scripts, diff tracker, QML views, and IPC integration:

```bash
./test/run.sh
```
