# Hypr Rotate

**One shortcut. Four orientations. Zero persistence.**

A minimal, runtime-only display rotation utility for Hyprland.

Rotate your focused monitor with a single command or keyboard shortcut.

## Features

- Rotates the currently focused display
- Cycles through four orientations
- Desktop notification after rotation
- No daemon or background services
- No persistent monitor configuration changes
- No dependencies on Omarchy, MAME, or other applications

## Rotation cycle

Each execution advances one orientation:

Landscape 0° → Portrait 90° → Landscape 180°
→ Portrait 270° → Landscape 0°

## Requirements

- Hyprland supporting the Lua monitor API
  (`hyprctl eval` and `hl.monitor`)
- Bash
- jq
- notify-send (libnotify)

Tested on Omarchy with Hyprland's Lua configuration system.

Compatibility with older Hyprland versions has not been
verified.

### Dependencies on Arch Linux

    sudo pacman -S --needed jq libnotify

## Installation

Clone the repository:

    git clone https://github.com/Magik23/hypr-rotate.git
    cd hypr-rotate

Install the script:

    install -Dm755 hypr-rotate ~/.local/bin/hypr-rotate

Ensure ~/.local/bin is in your PATH.

## Usage

From the terminal:

    hypr-rotate

The currently focused monitor advances to the next orientation.

## Keyboard shortcut

Suggested shortcut: Super + Alt + R.

### Omarchy (Lua bindings)

In ~/.config/hypr/bindings.lua:

    o.bind("SUPER + ALT + R", "Hypr Rotate", "hypr-rotate")

### Standard Hyprland Lua configuration

    hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("hypr-rotate"))

Use the binding syntax appropriate for your configuration.
Do not add both examples or duplicate an existing shortcut.

## Runtime-only behavior

Hypr Rotate does not write to monitors.lua, hyprland.lua,
hyprland.conf, or other persistent monitor configuration.

Your startup display orientation remains controlled by your
existing Hyprland configuration.

It does not install or modify a wallpaper renderer.

## Known limitations

- Requires Hyprland's supported Lua monitor API
- Multi-monitor behavior has not yet been separately validated
- Mirror/flipped transforms are not part of the rotation cycle

## Updating

    cd hypr-rotate
    git pull --ff-only
    install -Dm755 hypr-rotate ~/.local/bin/hypr-rotate

## Uninstallation

    rm ~/.local/bin/hypr-rotate

Remove your added keyboard shortcut separately.

## License

MIT. See LICENSE.
