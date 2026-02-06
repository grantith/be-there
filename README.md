# Harken
A window manager written in AutoHotkey v2.

The aim is a low-friction workflow: a single super modifier, mnemonic app keys, and fast window actions. Alt+Tab and Win+Tab still work, but you will hardly use them.

## Contents
- [Overview](#overview)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Default Config Keys](#default-config-keys)
- [Window Matching](#window-matching)
- [Path Expansion](#path-expansion)
- [Window Manager Exceptions](#window-manager-exceptions)
- [Helper Utility](#helper-utility)
- [Command Overlay](#command-overlay)
- [Known Limitations](#known-limitations)
- [Layout](#layout)
- [Third-Party](#third-party)

## Overview

> [!NOTE]
> CapsLock is the default super key, because who needs it?

### Features


Launch-or-focus a program with `super + [letter]`, or directionally change window focus with `alt + h/l/j/k` (left, right, down, up) and `alt + [` / `alt + ]` for back/forward in a stack.
![Alt text](docs/assets/focus.gif)

Cycle centered window widths with `super + spacebar`.
![Alt text](docs/assets/center-cycle.gif)

Maximizes/restores with `super + m`.
![Alt text](docs/assets/maximize.gif)

Move a window with `super + h/j/k/l`.
![Alt text](docs/assets/move.gif)

Freely move a window with double tap super + h/j/k/l
![Alt text](docs/assets/free-move.gif)

Resize edges with `super + shift + h/j/k/l`.
![Alt text](docs/assets/resize.gif)

Show the [Command Overlay](#command-overlay) when the super key is held. Disable through command mode.
![Alt text](docs/assets/command_overlay.png)

Use the "window switcher" (like powertoys window walker) with `super + w`.
![Alt text](docs/assets/window_switcher.png)

Other
- `super + alt` sends `ctrl + tab` (configurable via `global_hotkeys`)
- `super + c` cycle through windows of the same app
- `super + w` open Window Selector (fuzzy find open windows)
- `alt + h/l` move window focus left/right
- `alt + j/k` move window focus down/up (non-stacked)
- `alt + [` / `alt + ]` move window focus forward/back through stacked windows

Enter Command Mode with `super + ;`.
- `r` to reload program/config
- `e` to open config file
- `w` opens a new window for the active program, if the program supports it
- `n` toggles the command overlay on or off
- `i` opens the [Helper Utility](#helper-utility)


## Configuration

### Quick start

- Start the program and enter command mode with `super + ;`. The binary is not currently signed and you will be warned by Windows. Clone and use `main.ahk` directly as an alternative.
- The focus border uses `harken_focus_border_helper.exe` for smoother rendering; keep it next to `harken.exe` when using the compiled binary.
- Press `e` to open the config file. You can also find it manually in `~/.config/harken/harken.toml`.
- The repository example lives at `config/config.example.toml`.
- After making changes to your config you can reload the config (the entire program, actually) with `r` while in command mode.

### Default Config Keys
- `super_key`: key or list of keys used as the super modifier (e.g., `CapsLock` or `["F24", "CapsLock"]`).
- `apps`: list of app bindings with `hotkey`, `win_title`, and `run` command.
- `apps[].run_paths`: optional list of directories to search for the executable.
- `apps[].home_quadrant`: optional carousel home (`tl`, `tr`, `bl`, `br`).
- `apps[].carousel_excluded`: optional flag to ignore carousel snapping.
- `global_hotkeys`: array of scoped hotkey bindings (set `target_exes` empty for global use).
- `window`: resize/move steps and hotkeys (including move mode).
- `window_selector`: Window Selector settings (hotkey, match fields, display limits).
- `window_manager`: grid size, margins, gaps, and ignored window classes.
- `directional_focus`: directional focus settings (stacked threshold, stack tolerance, topmost preference, last-stacked preference, frontmost guard, perpendicular overlap min, cross-monitor, debug).
- `focus_border`: overlay appearance and update interval (including command mode color).
- `modes.active`: active layout mode (`carousel` or `scrolling`; any other value disables modes).
- `modes.carousel`: optional snapping behavior (layout modes, auto-center on focus, home quadrants, and corner sizing).
- `modes.carousel.layout_mode`: `four_slots`, `two_slots_tb`, or `one_side_full` (overflow stacks in center).
- `modes.carousel.full_side`: `left` or `right` when using `one_side_full`.
- `modes.scrolling`: scrolling layout settings (center/side width ratios, gap, workspaces).
- `modes.scrolling.workspace_count`: number of workspaces (set to `0` for dynamic + one empty workspace; up to 9 hotkeys supported).
- Scrolling hotkeys: `super + 1..9` switch workspace, `super + shift + 1..9` move active window.
- Scrolling overview: `super + o` opens a horizontal overview (no wrapping).
- `helper`: command overlay settings.
- `reload`: hotkey and file watch settings for config reload.

### Window Matching
- `apps[].win_title` accepts standard AutoHotkey window selectors.
- Common forms: plain title text, `ahk_exe <exe>`, `ahk_class <class>`, `ahk_pid <pid>`.
- Use `ahk_exe` for stable matching when window titles change (e.g., tabs/documents).
- Plain title text supports AutoHotkey's standard title matching and wildcards (e.g., `* - Notepad`).
- `ahk_exe`, `ahk_class`, and `ahk_pid` are exact matches; wildcards/regex are not supported today but could be added later.

### Path Expansion
- `apps[].run_paths` supports environment variables like `%APPDATA%` and `%LOCALAPPDATA%`.
- `~\` expands to your user profile (e.g., `~\AppData\Roaming`).

### Helper Utility
- `tools/window_inspector.ahk` lists active window titles, exe names, classes, and PIDs.
- Use it to identify values for `apps[].win_title` in your config.
- In Command Mode, press `i` to launch the window inspector.
- Use Refresh to update the list; Copy Selected/All or Export to save results.

## Known Limitations
- This has not been tested with multi-monitor setups or much outside of ultra-wide monitors.
- Some apps (e.g., Discord) launch via `Update.exe` and keep versioned subfolders, which makes auto-resolution unreliable for launching or focusing more challenging.
- For some apps that minimize or close to the system tray, it's recommended you disable that in the program. Otherwise you can try to set `apps[].run` to a stable full path (or use `run_paths`) in your config.
- Windows with elevated permissions may ignore Harken hotkeys unless Harken is run as Administrator.

## Third-Party
- JXON (AHK v2 JSON serializer) from https://github.com/TheArkive/JXON_ahk2
  - License: `LICENSES/JXON_ahk2-LICENSE.md`
- winri (border rendering reference) from https://github.com/sub07/winri
  - License: `LICENSES/winri-MIT.txt`
- Focus border helper (Rust): iced (custom-winri branch) from https://github.com/sub07/iced
- Focus border helper (Rust): serde/serde_json from https://github.com/serde-rs/serde
- Focus border helper (Rust): windows from https://github.com/microsoft/windows-rs

## Similar tools and inspirations

For this project I was primarily inspired by what I was able to accomplish with [Raycast](https://www.raycast.com/) on macOS. Between [Karabiner](https://karabiner-elements.pqrs.org/), Raycast, and [HammerSpoon](https://www.hammerspoon.org/) one could achieve all of Harken and more on macOS. I needed to move back to windows for work, and I wanted a way to use the same flow on Windows that I had become accustomed to on macOS.

Other macOS tools that I tried for more than five minutes were [AeroSpace](https://github.com/nikitabobko/AeroSpace) and [Loop](https://github.com/MrKai77/Loop).

### [FancyZones](https://learn.microsoft.com/en-us/windows/powertoys/fancyzones)

FancyZones is okay, but it doesn't remove the need to know where things are in order to focus on them, and its features are insufficient for a truly keyboard-centered workflow.

### [Komorebi](https://github.com/LGUG2Z/komorebi)

I really like komorebi--though I didn't use it for long and I have never been able to stick with tiling in the long run--but for those who prefer the tiling approach this might be the best option on Windows.

### [GlazeWM](https://github.com/glzr-io/glazewm)

GlazeWM is another popular tiling window manager for Windows operating systems.

## Credits

The foundation of Harken was built upon [this reddit post](https://old.reddit.com/r/AutoHotkey/comments/17qv594/window_management_tool/), shared by u/CrashKZ -- Thanks to [/u/plankoe](https://old.reddit.com/user/plankoe) for their initial contributions, too.

