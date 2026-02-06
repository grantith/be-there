#Requires AutoHotkey v2.0
#SingleInstance

#Include src/lib/JXON.ahk
#Include src/lib/toml.ahk
#Include src/lib/config_loader.ahk
#Include src/lib/state_store.ahk
#Include src/lib/focus_or_run.ahk
#Include src/lib/command_toast.ahk
#Include src/lib/window_inspector.ahk

config_dir := GetConfigDir()
DirCreate(config_dir)
global config_path := config_dir "\harken.toml"
EnsureConfigExists(config_path, DefaultConfig())
config_result := LoadConfig(config_path, DefaultConfig())
global Config := config_result["config"]
config_errors := config_result["errors"]
if (config_errors.Length) {
    LogConfigErrors(config_errors, config_dir "\config.errors.log", config_path)
    ExitApp
}
global AppState := LoadState()
InitCommandToast()

super_keys := Config["super_key"]
if !(super_keys is Array)
    super_keys := [super_keys]

RegisterSuperKeyHotkey("~", "", (*) => OnSuperKeyDown())
if HasSuperKey("CapsLock")
    SetCapsLockState "AlwaysOff"

reload_config := Config["reload"]
if reload_config["enabled"] {
    reload_hotkey := reload_config["hotkey"]
    reload_mode_hotkey := reload_config["mode_hotkey"]
    reload_mode_enabled := reload_config["mode_enabled"]
    reload_mode_timeout := reload_config["mode_timeout_ms"]
    global reload_mode_active := false

    if reload_config["super_key_required"] {
        HotIf IsSuperKeyPressed
        Hotkey(reload_hotkey, (*) => Reload())
        HotIf
    } else {
        Hotkey(reload_hotkey, (*) => Reload())
    }

    if reload_mode_enabled {
        RegisterSuperComboHotkey(reload_mode_hotkey, (*) => ActivateReloadMode(reload_mode_timeout))
        HotIf ReloadModeActive
        Hotkey(reload_hotkey, (*) => ExecuteCommand(() => Reload()))
        Hotkey("i", (*) => ExecuteCommand(OpenWindowInspector))
        Hotkey("n", (*) => ExecuteCommand(ToggleCommandHelper))
        Hotkey("w", (*) => ExecuteCommand(OpenNewWindowForActiveApp))
        Hotkey("e", (*) => ExecuteCommand(OpenConfigFile))
        Hotkey("Esc", ClearReloadMode)
        HotIf
    }
}

if reload_config["enabled"] && reload_config["watch_enabled"]
    StartConfigWatcher(config_path, reload_config["watch_interval_ms"])

SetWinDelay(-1)

#Include src/lib/window_manager.ahk
#Include src/lib/directional_focus.ahk
#Include src/lib/carousel.ahk
#Include src/lib/scrolling_mode.ahk
#Include src/lib/scrolling_overview.ahk
#Include src/lib/focus_border.ahk
#Include src/lib/window_walker.ahk
#Include src/hotkeys/global_hotkey.ahk
#Include src/hotkeys/apps.ahk
#Include src/hotkeys/window.ahk
#Include src/hotkeys/directional_focus.ahk
#Include src/hotkeys/window_walker.ahk
#Include src/hotkeys/scrolling.ahk
#Include src/hotkeys/unbound.ahk

InitCarousel()
InitScrolling()

DefaultConfig() {
    return Map(
        "config_version", 1,
        "super_key", ["CapsLock"],
        "apps", [
            Map("id", "files", "hotkey", "e", "win_title", "ahk_exe explorer.exe", "run", "explorer"),
            Map("id", "editor", "hotkey", "v", "win_title", "ahk_exe Code.exe", "run", "code"),
            Map("id", "terminal", "hotkey", "s", "win_title", "ahk_exe WindowsTerminal.exe", "run", "wt"),
            Map("id", "notes", "hotkey", "n", "win_title", "ahk_exe notepad++.exe", "run", "notepad++")
        ],
        "global_hotkeys", [
            Map(
                "enabled", true,
                "hotkey", "Alt",
                "target_exes", [],
                "send_keys", "^{Tab}"
            )
        ],
        "window", Map(
            "resize_step", 20,
            "move_step", 20,
            "super_double_tap_ms", 300,
            "move_mode", Map(
                "enable", true,
                "cancel_key", "Esc"
            ),
            "cycle_app_windows_hotkey", "c",
            "center_width_cycle_hotkey", "Space"
        ),
        "window_selector", Map(
            "enabled", true,
            "hotkey", "w",
            "max_results", 12,
            "title_preview_len", 60,
            "match_title", true,
            "match_exe", true,
            "include_minimized", true,
            "close_on_focus_loss", true
        ),
        "window_manager", Map(
            "grid_size", 3,
            "margins", Map(
                "top", 6,
                "left", 4,
                "right", 4
            ),
            "gap_px", 0,
            "exceptions_regex", "(Progman|Shell_TrayWnd|Shell_SecondaryTrayWnd|WorkerW|XamlExplorerHostIslandWindow|XamlExplorerHostIslandWindow_WASDK|#32768|tooltips_class32|SysShadow|MultitaskingViewFrame|TaskSwitcherWnd|Window Class|Winit Thread Event Target|PseudoConsoleWindow)"
        ),
        "directional_focus", Map(
            "enabled", true,
            "stacked_overlap_threshold", 0.5,
            "stack_tolerance_px", 25,
            "prefer_topmost", true,
            "prefer_last_stacked", true,
            "frontmost_guard_px", 200,
            "perpendicular_overlap_min", 0.2,
            "cross_monitor", false,
            "debug_enabled", false
        ),
        "focus_border", Map(
            "enabled", true,
            "border_color", "#357EC7",
            "move_mode_color", "#2ECC71",
            "command_mode_color", "#FFD400",
            "border_thickness", 4,
            "corner_radius", 16,
            "update_interval_ms", 20
        ),
        "modes", Map(
            "active", "",
            "carousel", Map(
                "auto_snap_center_on_focus", true,
                "default_home_quadrant", "tl",
                "excluded_apps", ["PowerToys.PowerLauncher.exe"],
                "corner_width_ratio", 0.25,
                "corner_height_ratio", 0.5,
                "layout_mode", "four_slots",
                "full_side", "left"
            ),
            "scrolling", Map(
                "wrap_enabled", false,
                "center_width_ratio", 0.5,
                "side_width_ratio", 0.25,
                "gap_px", 0,
                "workspace_count", 1,
                "seed_with_open_windows", true,
                "overview", Map(
                    "enabled", true,
                    "hotkey", "o",
                    "visible_count", 5,
                    "center_scale", 0.9,
                    "side_scale", 0.6,
                    "spacing_px", 40,
                    "use_live_thumbnails", true
                )
            )
        ),
        "helper", Map(
            "enabled", true,
            "overlay_opacity", 200
        ),
        "reload", Map(
            "enabled", true,
            "hotkey", "r",
            "super_key_required", true,
            "watch_enabled", false,
            "watch_interval_ms", 1000,
            "mode_enabled", true,
            "mode_hotkey", ";",
            "mode_timeout_ms", 20000
        )
    )
}

LogConfigErrors(errors, log_path, config_path := "") {
    DirCreate(GetConfigDir())
    header := "[" A_Now "] Config errors:" "`n"
    FileAppend(header, log_path)
    for _, err in errors {
        FileAppend("- " err "`n", log_path)
    }
    FileAppend("`n", log_path)

    summary := "Config errors detected.`n"
    summary .= "Log: " log_path "`n"
    if config_path
        summary .= "Config: " config_path "`n"

    details := summary "`n"
    for _, err in errors {
        details .= "- " err "`n"
    }

    ShowConfigErrorsGui(details, log_path)
}

ShowConfigErrorsGui(details, log_path) {
    gui := Gui("+AlwaysOnTop", "harken Config Errors")
    gui.SetFont("s10", "Segoe UI")
    edit := gui.AddEdit("w760 r18 ReadOnly", details)
    open_btn := gui.AddButton("xm y+10 w120", "Open Log")
    open_btn.OnEvent("Click", (*) => Run(log_path))
    close_btn := gui.AddButton("x+10 yp w120", "Close")
    close_btn.OnEvent("Click", (*) => gui.Destroy())
    gui.Show()
}

EnsureConfigExists(config_path, default_config) {
    if FileExist(config_path)
        return

    config_text := TomlDump(default_config, ["apps", "global_hotkeys"])
    FileAppend(config_text, config_path, "UTF-8")
}

GetConfigDir() {
    user_profile := EnvGet("USERPROFILE")
    if !user_profile
        user_profile := A_ScriptDir
    return user_profile "\.config\harken"
}

StartConfigWatcher(path, interval_ms := 1000) {
    global config_watch_mtime := ""
    if FileExist(path)
        config_watch_mtime := FileGetTime(path, "M")

    SetTimer((*) => CheckConfigWatcher(path), interval_ms)
}

CheckConfigWatcher(path) {
    global config_watch_mtime
    if !FileExist(path)
        return

    current := FileGetTime(path, "M")
    if (config_watch_mtime = "") {
        config_watch_mtime := current
        return
    }
    if (current != config_watch_mtime)
        Reload()
}

ActivateReloadMode(timeout_ms := 1500) {
    global reload_mode_active := true
    global reload_mode_activated_at := A_TickCount
    global focus_border_enabled
    if focus_border_enabled
        ScheduleFocusBorderUpdate()
    SetTimer(ClearReloadMode, 0)
    SetTimer(ClearReloadMode, -timeout_ms)
    UpdateCommandToastVisibility()
}

ClearReloadMode(*) {
    global reload_mode_active := false
    global focus_border_enabled
    if focus_border_enabled
        ScheduleFocusBorderUpdate()
    UpdateCommandToastVisibility()
}

ReloadModeActive(*) {
    global reload_mode_active
    return reload_mode_active
}

ExecuteCommand(callback) {
    callback.Call()
    ClearReloadMode()
}

OnSuperKeyDown() {
    UpdateCommandToastVisibility()
}

IsSuperKeyPressed(*) {
    global super_keys
    for _, key in super_keys {
        if GetKeyState(key, "P")
            return true
    }
    return false
}

HasSuperKey(target_key) {
    global super_keys
    target_lower := StrLower(target_key)
    for _, key in super_keys {
        if (StrLower(key) = target_lower)
            return true
    }
    return false
}

RegisterSuperKeyHotkey(prefix, suffix, callback) {
    global super_keys
    for _, key in super_keys
        Hotkey(prefix key suffix, callback)
}

RegisterSuperComboHotkey(hotkey_name, callback) {
    global super_keys
    for _, key in super_keys
        Hotkey(key " & " hotkey_name, callback)
}

OpenWindowInspector() {
    ShowWindowInspector()
}

OpenConfigFile() {
    global config_path
    if !config_path
        return
    if FileExist(config_path)
        Run(config_path)
}

OpenNewWindowForActiveApp() {
    hwnd := WinExist("A")
    if !hwnd
        return

    exe := WinGetProcessName("ahk_id " hwnd)
    if !exe
        return

    app_config := FindAppConfigByExe(exe)
    if (app_config is Map) {
        RunResolved(app_config["run"], app_config)
        return
    }

    RunResolved(exe)
}

FindAppConfigByExe(exe_name) {
    exe_lower := StrLower(exe_name)
    for _, app in Config["apps"] {
        win_title := StrLower(app["win_title"])
        if InStr(win_title, "ahk_exe " exe_lower)
            return app
    }
    return ""
}
