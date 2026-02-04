; ================================
; Active Window Rounded Border Overlay
; For Windows 11 (24H2)
; Runs continuously in the background.
; Adjust the border color, thickness, and corner roundness below.
; ================================

global Config

focus_config := Config["focus_border"]
global focus_border_enabled := focus_config["enabled"]
global focus_border_helper_pid := 0
global focus_border_helper_hwnd := 0
global focus_border_hook_system := 0
global focus_border_hook_object := 0
global focus_border_hook_callback := 0
if focus_border_enabled {
    ; ------------- User Settings -------------
    border_color := ParseHexColor(focus_config["border_color"])   ; Hex color (#RRGGBB)
    move_mode_color := ParseHexColor(focus_config["move_mode_color"]) ; Hex color (#RRGGBB)
    border_thickness := Integer(focus_config["border_thickness"])      ; Border thickness in pixels
    corner_radius := Integer(focus_config["corner_radius"])        ; Corner roundness in pixels
    update_interval := Integer(focus_config["update_interval_ms"])      ; Debounce (ms) for focus border updates
    ; ------------- End Settings -------------

    StartFocusBorderHelper()
    StartFocusBorderEventHooks(update_interval)
    OnExit(StopFocusBorderHooksAndHelper)

    ; Global variables to track the last active window's position & size.
    global prev_hwnd := 0, prev_ax := 0, prev_ay := 0, prev_aw := 0, prev_ah := 0
    global prev_color := border_color
    global prev_visible := false
    global flash_until := 0
    global flash_color := 0xB0B0B0

    UpdateBorder()

    ; -------------------------------
    ; UpdateBorder: Sends focus border updates to the helper process.
    ; -------------------------------
    UpdateBorder(*) {
        global border_thickness, corner_radius, border_color, move_mode_color
        global prev_hwnd, prev_ax, prev_ay, prev_aw, prev_ah
        global prev_color, prev_visible
        global flash_until, flash_color

        active_hwnd := DllCall("GetForegroundWindow", "ptr")
        if (!active_hwnd || !WinExist("ahk_id " active_hwnd)) {
            if prev_visible
                SendFocusBorderUpdate(false, 0, 0, 0, 0, "#000000", border_thickness, corner_radius)
            prev_visible := false
            return
        }
        style := WinGetStyle("ahk_id " active_hwnd)
        if (style & 0x20000000) {  ; WS_MINIMIZE flag
            if prev_visible
                SendFocusBorderUpdate(false, 0, 0, 0, 0, "#000000", border_thickness, corner_radius)
            prev_visible := false
            return
        }

        rect := Buffer(16, 0)
        if (DllCall("dwmapi\DwmGetWindowAttribute", "ptr", active_hwnd, "uint", 9, "ptr", rect, "uint", 16) = 0) {
            ax := NumGet(rect, 0, "int")
            ay := NumGet(rect, 4, "int")
            right := NumGet(rect, 8, "int")
            bottom := NumGet(rect, 12, "int")
            aw := right - ax
            ah := bottom - ay
        } else {
            WinGetPos(&ax, &ay, &aw, &ah, "ahk_id " active_hwnd)
        }

        if (flash_until > A_TickCount)
            desired_color := flash_color
        else if ReloadModeActive()
            desired_color := 0xFFD400
        else
            desired_color := Window.IsMoveMode() ? move_mode_color : border_color

        if (active_hwnd = prev_hwnd && ax = prev_ax && ay = prev_ay && aw = prev_aw && ah = prev_ah && desired_color = prev_color && prev_visible) {
            return
        }

        color_hex := "#" Format("{:06X}", desired_color & 0xFFFFFF)
        if SendFocusBorderUpdate(true, ax, ay, aw, ah, color_hex, border_thickness, corner_radius) {
            prev_hwnd := active_hwnd, prev_ax := ax, prev_ay := ay, prev_aw := aw, prev_ah := ah
            prev_color := desired_color
            prev_visible := true
        } else {
            prev_visible := false
        }
    }
}

FlashFocusBorder(color := 0xB0B0B0, duration_ms := 130) {
    global focus_border_enabled, flash_until, flash_color
    if !focus_border_enabled
        return
    flash_color := color
    flash_until := A_TickCount + duration_ms
    global prev_color
    prev_color := -1
}

StartFocusBorderHelper() {
    global focus_border_helper_pid, focus_border_helper_hwnd, focus_border_helper_path
    if focus_border_helper_pid
        return
    helper_path := ResolveFocusBorderHelperPath()
    if !helper_path
        return
    focus_border_helper_path := helper_path
    Run('"' helper_path '"', "", "Hide", &focus_border_helper_pid)
    focus_border_helper_hwnd := WaitForFocusBorderHelperWindow()
}

StopFocusBorderHelper(*) {
    global focus_border_helper_pid, focus_border_helper_hwnd
    if focus_border_helper_pid {
        try ProcessClose(focus_border_helper_pid)
    }
    focus_border_helper_pid := 0
    focus_border_helper_hwnd := 0
}

StopFocusBorderHooksAndHelper(*) {
    StopFocusBorderEventHooks()
    StopFocusBorderHelper()
}

StartFocusBorderEventHooks(debounce_ms := 20) {
    global focus_border_hook_system, focus_border_hook_object, focus_border_hook_callback
    global focus_border_debounce_ms := debounce_ms
    if focus_border_hook_callback
        return

    focus_border_hook_callback := CallbackCreate(FocusBorderWinEventProc, "Fast", 7)
    flags := 0x0000 | 0x0002 ; WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS

    EVENT_SYSTEM_FOREGROUND := 0x0003
    EVENT_SYSTEM_MINIMIZESTART := 0x0016
    EVENT_SYSTEM_MINIMIZEEND := 0x0017
    EVENT_OBJECT_SHOW := 0x8002
    EVENT_OBJECT_HIDE := 0x8003
    EVENT_OBJECT_LOCATIONCHANGE := 0x800B

    focus_border_hook_system := DllCall(
        "SetWinEventHook",
        "uint", EVENT_SYSTEM_FOREGROUND,
        "uint", EVENT_SYSTEM_MINIMIZEEND,
        "ptr", 0,
        "ptr", focus_border_hook_callback,
        "uint", 0,
        "uint", 0,
        "uint", flags,
        "ptr"
    )

    focus_border_hook_object := DllCall(
        "SetWinEventHook",
        "uint", EVENT_OBJECT_SHOW,
        "uint", EVENT_OBJECT_LOCATIONCHANGE,
        "ptr", 0,
        "ptr", focus_border_hook_callback,
        "uint", 0,
        "uint", 0,
        "uint", flags,
        "ptr"
    )
}

StopFocusBorderEventHooks() {
    global focus_border_hook_system, focus_border_hook_object, focus_border_hook_callback
    if focus_border_hook_system {
        DllCall("UnhookWinEvent", "ptr", focus_border_hook_system)
        focus_border_hook_system := 0
    }
    if focus_border_hook_object {
        DllCall("UnhookWinEvent", "ptr", focus_border_hook_object)
        focus_border_hook_object := 0
    }
    if focus_border_hook_callback {
        CallbackFree(focus_border_hook_callback)
        focus_border_hook_callback := 0
    }
}

FocusBorderWinEventProc(h_hook, event, hwnd, id_object, id_child, event_thread, event_time) {
    global focus_border_enabled
    if !focus_border_enabled
        return
    if !hwnd
        return
    if (id_object != 0)
        return
    ScheduleFocusBorderUpdate()
}

ScheduleFocusBorderUpdate() {
    global focus_border_debounce_ms
    SetTimer(UpdateBorder, 0)
    SetTimer(UpdateBorder, -focus_border_debounce_ms)
}

ResolveFocusBorderHelperPath() {
    helper_name := "harken_focus_border_helper.exe"
    candidate_paths := [
        A_ScriptDir "\\" helper_name,
        A_ScriptDir "\\tools\\focus_border_helper\\target\\release\\" helper_name,
        A_ScriptDir "\\tools\\focus_border_helper\\target\\debug\\" helper_name
    ]
    for _, path in candidate_paths {
        if FileExist(path)
            return path
    }
    return ""
}

WaitForFocusBorderHelperWindow(timeout_ms := 1500) {
    start_time := A_TickCount
    while (A_TickCount - start_time) < timeout_ms {
        hwnd := FindFocusBorderHelperWindow()
        if hwnd
            return hwnd
        Sleep(50)
    }
    return 0
}

FindFocusBorderHelperWindow() {
    return DllCall("FindWindow", "str", "HarkenFocusBorderHelper", "ptr", 0, "ptr")
}

EnsureFocusBorderHelperWindow() {
    global focus_border_helper_hwnd, focus_border_helper_pid
    if focus_border_helper_hwnd && DllCall("IsWindow", "ptr", focus_border_helper_hwnd)
        return focus_border_helper_hwnd
    focus_border_helper_hwnd := FindFocusBorderHelperWindow()
    if !focus_border_helper_hwnd {
        focus_border_helper_pid := 0
        StartFocusBorderHelper()
    }
    return focus_border_helper_hwnd
}

SendFocusBorderUpdate(visible, x, y, w, h, color_hex, thickness, radius) {
    hwnd := EnsureFocusBorderHelperWindow()
    if !hwnd
        return false

    payload := Map(
        "visible", visible,
        "x", x,
        "y", y,
        "w", w,
        "h", h,
        "color", color_hex,
        "thickness", thickness,
        "radius", radius
    )
    json := Jxon_Dump(payload, 0)
    return SendCopyData(hwnd, json)
}

SendCopyData(hwnd, text) {
    data_size := StrPut(text, "UTF-8")
    data := Buffer(data_size, 0)
    StrPut(text, data, "UTF-8")


    cds := Buffer(A_PtrSize * 3, 0)
    NumPut("UPtr", 1, cds, 0)
    NumPut("UInt", data_size, cds, A_PtrSize)
    NumPut("UPtr", data.Ptr, cds, A_PtrSize * 2)

    return DllCall("SendMessage", "ptr", hwnd, "uint", 0x4A, "ptr", 0, "ptr", cds)
}

ParseHexColor(value) {
    if (value is Integer)
        return value
    if !(value is String)
        return 0
    trimmed := Trim(value)
    if (SubStr(trimmed, 1, 1) = "#")
        trimmed := SubStr(trimmed, 2)
    if (StrLen(trimmed) = 8 && RegExMatch(trimmed, "i)^0x[0-9a-f]{6}$"))
        return Integer(trimmed)
    if (StrLen(trimmed) = 6 && RegExMatch(trimmed, "i)^[0-9a-f]{6}$"))
        return Integer("0x" trimmed)
    return 0
}
