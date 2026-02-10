# Roadmap

This file tracks planned features and ideas for future development.

## Status Legend
- **Planned** - Actively planning/designing
- **Idea** - Interesting possibility, needs discussion
- **Rejected** - Decided against (with reason)
- **Completed** - Implemented (see PRD.md)

---

## Future Ideas

### Cross-Platform Status Bar Support
Add status bar applications for enhanced desktop experience on both macOS and Linux.

**Status:** Idea

**Packages:**
- **macOS**: SketchyBar - Highly customizable status bar replacement
- **Linux**: Waybar - Status bar for Wayland compositors (works on X11 too)

**Implementation Approach:**
- Add packages to `packages.yaml`:
  - `sketchybar` → `macos.personal.cli`
  - `waybar` → `linux.personal.cli`
- Provide balanced config files in `dotfiles/.config/`:
  - SketchyBar: `.config/sketchybar/sketchybarrc`
  - Waybar: `.config/waybar/config` + `.config/waybar/style.css`
- Auto-start configuration:
  - macOS: `~/Library/LaunchAgents/` plist for SketchyBar
  - Linux: systemd user service for Waybar
- GNU Stow handles symlinking (existing workflow)

**Config Features (Balanced Complexity):**
- Clock and date display
- Battery status (laptops)
- Network connectivity indicator
- Volume control widget
- System stats (CPU, memory usage)
- Media playback controls
- Clean, minimal aesthetic

**Design Decisions:**
- **Vanilla only**: No additional plugins/dependencies beyond base packages
- **Personal packages**: Not tied to work environment
- **User-maintained configs**: Dotfiles provide starting point, user customizes
- **Standard desktop focus**: No advanced tiling WM integrations (yabai/Sway/i3)
- **Auto-start enabled**: Launches on login for seamless experience

**Technical Notes:**
- SketchyBar requires macOS Big Sur (11.0) or later
- Waybar works on Wayland (Sway, Hyprland) and X11 (i3, bspwm)
- Both support CSS/styling for appearance customization
- Config files use standard formats (shell script for SketchyBar, JSON for Waybar)

**Benefits:**
- Consistent status bar experience across platforms
- Better system information visibility
- Customizable to match user preferences
- Maintained as part of dotfiles (version controlled)

**Next Steps (when moving to Planned):**
1. Research minimal working configs for both tools
2. Create example configs with balanced feature set
3. Test auto-start on both platforms
4. Document customization options in README
5. Add to devcontainer tests

---

### CI/CD Integration
GitHub Actions workflow using devcontainers

**Features:**
- Run tests on every PR
- Test against multiple OS combinations
- Automated changelog generation
- Release automation

**Status:** Low priority, local testing sufficient for now

---

### Complete refactor after stop using MacOS
The repository is currently focused on supporting both macOS and Linux, which adds complexity. Once I fully switch to Linux, I plan to refactor the repository to simplify it and focus solely on Linux configurations and packages.

Embrace Linux Atomic like NixOS or Fedora Atomic with Sway/Hyprland as the main desktop environment. This will allow me to leverage Nix for package management and configuration, potentially replacing the need for traditional dotfiles with home-manager.

---

## How to Propose Features

1. Add idea to "Future Ideas" section above
2. Discuss in GitHub Issues or with maintainer
3. If approved, add detailed specification to PRD.md
4. Update ROADMAP.md status markers
5. Implement and test

---

## Archive

Features that were considered but rejected or deprioritized.

_(None yet)_
