global Config
global command_helper_enabled := false
global command_toast_gui := ""
global command_toast_text := ""
global command_toast_visible := false

InitCommandToast() {
    global Config, command_helper_enabled
    command_helper_enabled := Config["helper"]["enabled"]
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
    global command_helper_enabled, command_toast_gui, command_toast_text, command_toast_visible
    if !command_helper_enabled
        return

    text := BuildCommandToastText()
    if (text = "")
        return

    if !command_toast_gui {
        command_toast_gui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "be-there Command Overlay")
        command_toast_gui.SetFont("s10", "Consolas")
        command_toast_text := command_toast_gui.AddText("w420", text)
    } else if (command_toast_text.Text != text) {
        command_toast_text.Text := text
    }

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
    command_toast_visible := true
}

HideCommandToast() {
    global command_toast_gui, command_toast_visible
    if command_toast_gui {
        command_toast_gui.Hide()
        command_toast_visible := false
    }
}

ToggleCommandHelper() {
    global command_helper_enabled
    command_helper_enabled := !command_helper_enabled
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

BuildCommandToastText() {
    global Config
    is_command_mode := ReloadModeActive()
    is_move_mode := Window.IsMoveMode()
    lines := []
    lines.Push("be-there")
    lines.Push("")
    key_width := 16

    if is_move_mode {
        lines.Push("Move Mode")
        lines.Push(FormatRow("h/j/k/l", "move window", key_width))
        lines.Push(FormatRow(Config["window"]["move_mode"]["cancel_key"], "exit move mode", key_width))
        return StrJoin(lines, "`n")
    }

    if is_command_mode {
        lines.Push("Command Mode")
        lines.Push(FormatRow("r", "reload config", key_width))
        lines.Push(FormatRow("e", "open config file", key_width))
        lines.Push(FormatRow("i", "window inspector", key_width))
        lines.Push(FormatRow("n", "toggle helper", key_width))
        lines.Push(FormatRow("w", "new window (active app)", key_width))
        lines.Push(FormatRow("Esc", "exit command mode", key_width))
        return StrJoin(lines, "`n")
    }

    lines.Push("Apps")
    lines.Push("  " PadRight("Key", key_width) "  App")
    lines.Push("  " RepeatChar("-", key_width) "  " RepeatChar("-", 16))
    for _, app in Config["apps"] {
        lines.Push("  " PadRight(app["hotkey"], key_width) "  " app["id"])
    }
    lines.Push("")
    lines.Push("Window")
    lines.Push(FormatRow("arrows", "resize", key_width))
    lines.Push(FormatRow("shift+h/j/k/l", "resize center", key_width))
    lines.Push(FormatRow("ctrl+h/j/k/l", "move", key_width))
    lines.Push(FormatRow("m", "maximize", key_width))
    lines.Push(FormatRow("q", "close", key_width))
    lines.Push(FormatRow(Config["window"]["cycle_app_windows_hotkey"], "cycle app windows", key_width))
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
