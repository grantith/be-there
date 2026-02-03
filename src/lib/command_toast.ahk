global Config, AppState
global command_helper_enabled := false
global command_toast_gui := ""
global command_toast_text := ""
global command_toast_visible := false
global command_toast_view_key := ""
global command_toast_apps_list := ""
global command_toast_image_list := ""
global command_toast_icon_cache := Map()
global command_toast_default_icon_index := 0
global command_toast_last_mode := ""
global command_toast_normal_refresh_pending := false

InitCommandToast() {
    global Config, AppState, command_helper_enabled
    command_helper_enabled := Config["helper"]["enabled"]
    if (AppState is Map && AppState.Has("command_helper_enabled"))
        command_helper_enabled := AppState["command_helper_enabled"]
}

UpdateCommandToastVisibility() {
    global command_helper_enabled, super_key
    if !command_helper_enabled {
        HideCommandToast()
        return
    }

    if GetKeyState(super_key, "P") || ReloadModeActive() || Window.IsMoveMode() {
        ShowCommandToast()
    } else {
        HideCommandToast()
    }
}

ShowCommandToast() {
    global command_helper_enabled, command_toast_gui, command_toast_visible, command_toast_view_key, command_toast_last_mode, command_toast_normal_refresh_pending
    if !command_helper_enabled
        return

    model := BuildCommandToastModel()
    if !(model is Map) || !model.Has("key") || (model["key"] = "")
        return

    if (model["mode"] = "normal" && command_toast_last_mode != "normal") {
        command_toast_view_key := ""
        command_toast_normal_refresh_pending := true
    }

    if !command_toast_gui || (command_toast_view_key != model["key"]) {
        if command_toast_gui
            command_toast_gui.Destroy()
        command_toast_gui := ""
        command_toast_text := ""
        command_toast_apps_list := ""
        command_toast_image_list := ""
        command_toast_icon_cache := Map()
        command_toast_default_icon_index := 0
        CreateCommandToastGui(model)
        command_toast_view_key := model["key"]
    } else if (model["mode"] = "normal" && command_toast_normal_refresh_pending) {
        ; defer refresh until after show to avoid flicker
    }

    opacity := NormalizeOverlayOpacity()
    if (opacity < 255)
        WinSetTransparent(opacity, command_toast_gui)

    command_toast_gui.Show("NoActivate")
    command_toast_gui.GetPos(&x, &y, &w, &h)
    GetCommandToastWorkArea(&left, &top, &right, &bottom)
    dpi_scale := A_ScreenDPI / 96
    margin := Round(24 * dpi_scale)
    if (margin < 16)
        margin := 16
    if (margin > 64)
        margin := 64
    pos_x := right - w - margin
    pos_y := bottom - h - margin
    min_x := left + margin
    max_x := right - w - margin
    min_y := top + margin
    max_y := bottom - h - margin
    pos_x := Max(min_x, Min(pos_x, max_x))
    pos_y := Max(min_y, Min(pos_y, max_y))
    command_toast_gui.Show("NoActivate x" pos_x " y" pos_y)
    if (model["mode"] = "normal" && command_toast_normal_refresh_pending) {
        RefreshCommandToastIcons(model)
        command_toast_normal_refresh_pending := false
    }
    command_toast_visible := true
    command_toast_last_mode := model["mode"]
}

CreateCommandToastGui(model) {
    global command_toast_gui, command_toast_text, command_toast_apps_list, command_toast_image_list
    command_toast_gui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "be-there Command Overlay")
    command_toast_gui.MarginX := 12
    command_toast_gui.MarginY := 10
    opacity := NormalizeOverlayOpacity()
    if (opacity < 255)
        WinSetTransparent(opacity, command_toast_gui)

    command_toast_gui.SetFont("s10 w600", "Segoe UI")
    command_toast_gui.AddText("xm", model["title"])

    overlay_width := 420

    if (model["mode"] = "normal") {
        command_toast_gui.SetFont("s9 w600", "Segoe UI")
        command_toast_gui.AddText("xm y+6", "Apps")
        command_toast_gui.SetFont("s9", "Segoe UI")

        row_count := Max(1, Min(8, model["apps"].Length))
        command_toast_apps_list := command_toast_gui.AddListView("xm w" overlay_width " r" row_count " -Multi NoSortHdr", ["Key", "App"])
        command_toast_image_list := IL_Create(16)
        command_toast_default_icon_index := EnsureDefaultAppIcon()
        command_toast_apps_list.SetImageList(command_toast_image_list, 1)
        command_toast_apps_list.ModifyCol(1, 70)
        command_toast_apps_list.ModifyCol(2, overlay_width - 90)

        for _, app in model["apps"] {
            icon_index := GetAppIconIndex(app["icon_path"])
            command_toast_apps_list.Add("Icon" icon_index, app["hotkey"], app["label"])
        }

        command_toast_gui.SetFont("s9", "Consolas")
        command_toast_text := command_toast_gui.AddText("xm y+6 w" overlay_width, model["body_text"])
        return
    }

    command_toast_gui.SetFont("s9", "Consolas")
    command_toast_text := command_toast_gui.AddText("xm y+6 w" overlay_width, model["body_text"])
}

RefreshCommandToastIcons(model) {
    global command_toast_apps_list, command_toast_image_list, command_toast_icon_cache, command_toast_default_icon_index
    if !command_toast_apps_list
        return
    if !(model is Map) || !model.Has("apps")
        return

    command_toast_icon_cache := Map()
    command_toast_image_list := IL_Create(16)
    command_toast_default_icon_index := EnsureDefaultAppIcon()
    command_toast_apps_list.SetImageList(command_toast_image_list, 1)
    command_toast_apps_list.Delete()
    row_count := Max(1, Min(8, model["apps"].Length))
    command_toast_apps_list.Opt("r" row_count)
    for _, app in model["apps"] {
        icon_index := GetAppIconIndex(app["icon_path"])
        command_toast_apps_list.Add("Icon" icon_index, app["hotkey"], app["label"])
    }
}

HideCommandToast() {
    global command_toast_gui, command_toast_visible
    if command_toast_gui {
        command_toast_gui.Hide()
        command_toast_visible := false
    }
}

ToggleCommandHelper() {
    global command_helper_enabled, AppState
    command_helper_enabled := !command_helper_enabled
    if !(AppState is Map)
        AppState := Map()
    AppState["command_helper_enabled"] := command_helper_enabled
    SaveState(AppState)
    status := command_helper_enabled ? "enabled" : "disabled"
    TrayTip("", "")
    TrayTip("be-there", "Command overlay " status, 2)
    UpdateCommandToastVisibility()
}

GetCommandToastWorkArea(&left, &top, &right, &bottom) {
    mon := ""
    try hwnd := WinGetID("A")
    if hwnd {
        try mon_handle := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
        if mon_handle
            mon := ConvertMonitorHandleToNumber(mon_handle)
    }
    if !mon
        mon := MonitorGetPrimary()
    MonitorGetWorkArea(mon, &left, &top, &right, &bottom)
}

ConvertMonitorHandleToNumber(handle) {
    mon_handle_list := ""
    mon_callback := CallbackCreate(__EnumMonitors, "Fast", 4)

    if DllCall("EnumDisplayMonitors", "Ptr", 0, "Ptr", 0, "Ptr", mon_callback, "UInt", 0) {
        loop parse, mon_handle_list, "`n"
            if (A_LoopField = handle)
                return A_Index
    }
    return ""

    __EnumMonitors(hMonitor, hDevCon, pRect, args) {
        mon_handle_list .= hMonitor "`n"
        return true
    }
}

BuildCommandToastModel() {
    global Config
    is_command_mode := ReloadModeActive()
    is_move_mode := Window.IsMoveMode()
    key_width := 16
    model := Map()

    if is_move_mode {
        lines := []
        lines.Push(FormatRow("h/j/k/l", "move window", key_width))
        lines.Push(FormatRow(Config["window"]["move_mode"]["cancel_key"], "exit move mode", key_width))
        model["mode"] := "move"
        model["title"] := "Move Mode"
        model["body_text"] := StrJoin(lines, "`n")
        model["key"] := "move|" model["body_text"]
        return model
    }

    if is_command_mode {
        lines := []
        lines.Push(FormatRow("r", "reload config", key_width))
        lines.Push(FormatRow("e", "open config file", key_width))
        lines.Push(FormatRow("i", "window inspector", key_width))
        lines.Push(FormatRow("n", "toggle helper", key_width))
        lines.Push(FormatRow("w", "new window (active app)", key_width))
        lines.Push(FormatRow("Esc", "exit command mode", key_width))
        model["mode"] := "command"
        model["title"] := "Command Mode"
        model["body_text"] := StrJoin(lines, "`n")
        model["key"] := "command|" model["body_text"]
        return model
    }

    model["mode"] := "normal"
    model["title"] := "be-there"
    model["apps"] := BuildAppRows()
    model["body_text"] := BuildCommandToastBodyText(key_width)
    model["key"] := "normal|" model["body_text"] "|" BuildAppsKey(model["apps"])
    return model
}

BuildCommandToastBodyText(key_width := 16) {
    global Config
    lines := []
    lines.Push("Window")
    lines.Push(FormatRow("arrows", "resize", key_width))
    lines.Push(FormatRow("shift+h/j/k/l", "resize center", key_width))
    lines.Push(FormatRow("ctrl+h/j/k/l", "move", key_width))
    lines.Push(FormatRow("m", "maximize", key_width))
    lines.Push(FormatRow("q", "close", key_width))
    lines.Push(FormatRow(Config["window"]["cycle_app_windows_hotkey"], "cycle app windows", key_width))
    if Config.Has("window_selector") && Config["window_selector"]["enabled"] {
        lines.Push(FormatRow(Config["window_selector"]["hotkey"], "window selector", key_width))
    }
    if Config.Has("directional_focus") && Config["directional_focus"]["enabled"] {
        lines.Push(FormatRow("alt+h/l", "focus left/right", key_width))
        lines.Push(FormatRow("alt+j/k", "focus down/up", key_width))
        lines.Push(FormatRow("alt+[ / ]", "cycle stacked", key_width))
    }
    lines.Push("")
    lines.Push("Global Hotkeys")
    for _, hotkey_config in Config["global_hotkeys"] {
        if hotkey_config["enabled"]
            lines.Push(FormatRow(hotkey_config["hotkey"], hotkey_config["send_keys"], key_width))
    }
    lines.Push("")
    lines.Push("Command Mode")
    lines.Push(FormatRow(Config["reload"]["mode_hotkey"], "enter command mode", key_width))
    return StrJoin(lines, "`n")
}

BuildAppRows() {
    global Config
    rows := []
    for _, app in Config["apps"] {
        icon_path := ResolveAppIconPath(app)
        rows.Push(Map(
            "hotkey", app["hotkey"],
            "label", app["id"],
            "icon_path", icon_path
        ))
    }
    return rows
}

BuildAppsKey(apps) {
    key := ""
    for _, app in apps {
        key .= app["hotkey"] "|" app["label"] "|" app["icon_path"] "||"
    }
    return key
}

ResolveAppIconPath(app) {
    if !(app is Map)
        return ""
    if app.Has("win_title") {
        path := FindAppWindowPath(app["win_title"])
        if (path != "")
            return path
    }
    if app.Has("run") {
        path := ResolveRunPath(app["run"], app)
        if path && FileExist(path)
            return path
    }
    return ""
}

FindAppWindowPath(win_title) {
    if !win_title
        return ""
    hwnds := WinGetList(win_title)
    if (hwnds.Length = 0)
        return ""

    for _, hwnd in hwnds {
        if (InStr(win_title, "explorer.exe")) {
            class_name := WinGetClass("ahk_id " hwnd)
            if (class_name = "Progman" || class_name = "WorkerW" || class_name = "Shell_TrayWnd")
                continue
        }
        ex_style := WinGetExStyle("ahk_id " hwnd)
        if (ex_style & 0x80) || (ex_style & 0x8000000)
            continue
        if !(WinGetStyle("ahk_id " hwnd) & 0x10000000)
            continue
        try {
            path := WinGetProcessPath("ahk_id " hwnd)
            if path
                return path
        } catch {
        }
    }
    return ""
}

GetAppIconIndex(path) {
    global command_toast_image_list, command_toast_icon_cache, command_toast_default_icon_index
    if (path != "" && command_toast_icon_cache.Has(path))
        return command_toast_icon_cache[path]

    if (path = "" || !FileExist(path))
        return command_toast_default_icon_index

    icon_index := 0
    try icon_index := IL_Add(command_toast_image_list, path, 1)
    if (!icon_index)
        icon_index := command_toast_default_icon_index

    if (path != "")
        command_toast_icon_cache[path] := icon_index
    return icon_index
}

EnsureDefaultAppIcon() {
    global command_toast_image_list
    icon_index := 0
    try icon_index := IL_Add(command_toast_image_list, "shell32.dll", 1)
    if (!icon_index)
        icon_index := 1
    return icon_index
}

NormalizeOverlayOpacity() {
    global Config
    opacity := 255
    if Config.Has("helper") && Config["helper"].Has("overlay_opacity")
        opacity := Config["helper"]["overlay_opacity"]
    if !IsNumber(opacity)
        opacity := 255
    opacity := Floor(opacity)
    if (opacity < 0)
        opacity := 0
    if (opacity > 255)
        opacity := 255
    return opacity
}

StrJoin(items, sep) {
    output := ""
    for i, item in items {
        if (i > 1)
            output .= sep
        output .= item
    }
    return output
}

FormatRow(key, desc, key_width) {
    return "  " PadRight(key, key_width) "  " desc
}

PadRight(text, width) {
    if (StrLen(text) >= width)
        return text
    return text . RepeatChar(" ", width - StrLen(text))
}

RepeatChar(char, count) {
    output := ""
    loop count
        output .= char
    return output
}
