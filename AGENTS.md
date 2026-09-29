# Agent Instructions (`AGENTS.md`) - Omarchy Control Panel

This repository contains the Omarchy Control Panel plugin.

## Technical Stack & Constraints
- **Language**: QML (Qt Quick 6 / Quickshell).
- **Style Rules**: Always use Omarchy's design tokens (`Color.background`, `Color.foreground`, `Style.font.family`, `Style.spacing.*`, `Style.cornerRadius`).
- **Validation**: Validate manifest changes with `omarchy plugin validate .`.
- **Testing**: Test summon via `omarchy-shell shell summon ac.control-panel '{}'`.
