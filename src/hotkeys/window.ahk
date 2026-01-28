global Config, super_key

resize_step := Config["window"]["resize_step"]
move_step := Config["window"]["move_step"]
super_double_tap_ms := Config["window"]["super_double_tap_ms"]
move_mode_enabled := Config["window"]["move_mode"]["enable"]
move_mode_cancel_key := Config["window"]["move_mode"]["cancel_key"]
center_cycle_hotkey := Config["window"]["center_width_cycle_hotkey"]
cycle_app_windows_hotkey := Config["window"]["cycle_app_windows_hotkey"]

last_super_tap := 0
max_restore := Map()

ResizeActiveWindow(delta_w, delta_h) {
    hwnd := WinExist("A")
    if !hwnd || Window.IsException("ahk_id " hwnd)
        return

    if (WinGetMinMax("ahk_id " hwnd) = 1)
        WinRestore "ahk_id " hwnd

    WinGetPosEx(&x, &y, &w, &h, "ahk_id " hwnd)

    new_w := w + delta_w
    new_h := h + delta_h

    if (new_w <= 0 || new_h <= 0)
        return

    if (x < Screen.left)
        x := Screen.left
    if (y < Screen.top)
        y := Screen.top

    max_w := Screen.right - x
    max_h := Screen.bottom - y
    new_w := Min(new_w, max_w)
    new_h := Min(new_h, max_h)

    WinMoveEx(x, y, new_w, new_h, "ahk_id " hwnd)
}

ResizeActiveWindowCentered(delta_w, delta_h) {
    hwnd := WinExist("A")
    if !hwnd || Window.IsException("ahk_id " hwnd)
        return

    if (WinGetMinMax("ahk_id " hwnd) = 1)
        WinRestore "ahk_id " hwnd

    WinGetPosEx(&x, &y, &w, &h, "ahk_id " hwnd)

    new_w := w + (delta_w * 2)
    new_h := h + (delta_h * 2)
    new_x := x - delta_w
    new_y := y - delta_h

    if (new_w <= 0 || new_h <= 0)
        return

    if (new_x < Screen.left) {
        new_w -= (Screen.left - new_x)
        new_x := Screen.left
    }
    if (new_y < Screen.top) {
        new_h -= (Screen.top - new_y)
        new_y := Screen.top
    }

    max_w := Screen.right - new_x
    max_h := Screen.bottom - new_y
    new_w := Min(new_w, max_w)
    new_h := Min(new_h, max_h)

    if (new_w <= 0 || new_h <= 0)
        return

    WinMoveEx(new_x, new_y, new_w, new_h, "ahk_id " hwnd)
}

MoveActiveWindow(delta_x, delta_y) {
    hwnd := WinExist("A")
    if !hwnd || Window.IsException("ahk_id " hwnd)
        return

    if (WinGetMinMax("ahk_id " hwnd) = 1)
        WinRestore "ahk_id " hwnd

    WinGetPosEx(&x, &y, &w, &h, "ahk_id " hwnd)

    new_x := x + delta_x
    new_y := y + delta_y

    min_x := Screen.left
    min_y := Screen.top
    max_x := Screen.right - w
    max_y := Screen.bottom - h

    new_x := Min(Max(new_x, min_x), max_x)
    new_y := Min(Max(new_y, min_y), max_y)

    WinMoveEx(new_x, new_y, w, h, "ahk_id " hwnd)
}

SortWindowList(list) {
    sorted := []
    for _, id in list
        sorted.Push(id)

    count := sorted.Length
    loop count - 1 {
        i := A_Index
        loop count - i {
            j := A_Index
            if (sorted[j] > sorted[j + 1]) {
                temp := sorted[j]
                sorted[j] := sorted[j + 1]
                sorted[j + 1] := temp
            }
        }
    }

    return sorted
}

FilterWindowList(exe, list) {
    filtered := []
    for _, id in list {
        class_name := WinGetClass("ahk_id " id)
        if (exe = "explorer.exe") {
            if (class_name = "Progman" || class_name = "WorkerW" || class_name = "Shell_TrayWnd")
                continue
        }
        ex_style := WinGetExStyle("ahk_id " id)
        if (ex_style & 0x80) || (ex_style & 0x8000000)
            continue
        if (!(WinGetStyle("ahk_id " id) & 0x10000000))
            continue
        filtered.Push(id)
    }
    return filtered
}

HandleSuperTap() {
    global last_super_tap, super_double_tap_ms

    if Window.IsMoveMode() {
        Window.SetMoveMode(false)
        UpdateCommandToastVisibility()
        return
    }

    if (A_TickCount - last_super_tap <= super_double_tap_ms) {
        Window.SetMoveMode(true)
        UpdateCommandToastVisibility()
        last_super_tap := 0
        return
    }

    last_super_tap := A_TickCount
}

OnSuperKeyUp() {
    global move_mode_enabled
    if move_mode_enabled
        HandleSuperTap()
    if ReloadModeActive() {
        global reload_mode_activated_at
        if (A_TickCount - reload_mode_activated_at < 500) {
            UpdateCommandToastVisibility()
            return
        }
        ClearReloadMode()
    }
    UpdateCommandToastVisibility()
}

if (move_mode_enabled || Config["reload"]["mode_enabled"] || Config["helper"]["enabled"]) {
    Hotkey(super_key " up", (*) => OnSuperKeyUp())
}

CenterWidthCycle(*) {
    static state := 0
    state := Mod(state + 1, 3)

    hwnd := WinExist("A")
    if !hwnd
        return

    ; Restore if maximized so Move works correctly
    if (WinGetMinMax("ahk_id " hwnd) = 1)
        WinRestore "ahk_id " hwnd

    ; Get work area of current monitor
    MonitorGetWorkArea(MonitorGetPrimary(), &mx1, &my1, &mx2, &my2)
    mw := mx2 - mx1
    mh := my2 - my1

    if (state = 0) {
        ; center 1/3
        w := mw / 3
    } else if (state = 1) {
        ; center 1/2
        w := mw / 2
    } else {
        ; center 2/3
        w := mw * 2 / 3
    }

    left_margin := Screen.left_margin
    right_margin := Screen.right_margin
    top_margin := Screen.top_margin

    mx1 += left_margin
    mw := mw - left_margin - right_margin
    mh := mh - top_margin

    x := mx1 + (mw - w) / 2
    y := my1 + top_margin

    WinMove x, y, w, mh, "ahk_id " hwnd
}

ToggleMaximize(*) {
    hwnd := WinExist("A")
    if !hwnd
        return

    coords := Window.GetCurrentPosition()
    if Window.IsMaximized(coords) {
        if max_restore.Has(hwnd) {
            saved := max_restore[hwnd]
            WinRestore "ahk_id " hwnd
            WinMoveEx(saved.x, saved.y, saved.w, saved.h, "ahk_id " hwnd)
        }
        return
    }

    WinGetPosEx(&x, &y, &w, &h, "ahk_id " hwnd)
    max_restore[hwnd] := { x: x, y: y, w: w, h: h }
    Window.Maximize()
}

CloseWindow(*) {
    hwnd := WinExist("A")
    if !hwnd
        return
    WinClose "ahk_id " hwnd
}

CycleAppWindows(*) {
    hwnd := WinExist("A")
    if !hwnd
        return

    exe := WinGetProcessName("ahk_id " hwnd)
    if !exe
        return

    win_list := WinGetList("ahk_exe " exe)
    win_list := FilterWindowList(exe, win_list)
    if (win_list.Length < 2)
        return

    win_list := SortWindowList(win_list)

    current_index := 0
    for i, id in win_list {
        if (id = hwnd) {
            current_index := i
            break
        }
    }

    next_index := (current_index >= win_list.Length || current_index = 0) ? 1 : current_index + 1
    WinActivate "ahk_id " win_list[next_index]
}

HotIf (*) => GetKeyState(super_key, "P")
Hotkey(center_cycle_hotkey, CenterWidthCycle)
Hotkey("Left", (*) => ResizeActiveWindow(-resize_step, 0))
Hotkey("Right", (*) => ResizeActiveWindow(resize_step, 0))
Hotkey("Up", (*) => ResizeActiveWindow(0, -resize_step))
Hotkey("Down", (*) => ResizeActiveWindow(0, resize_step))
Hotkey("+h", (*) => ResizeActiveWindowCentered(-resize_step, 0))
Hotkey("+l", (*) => ResizeActiveWindowCentered(resize_step, 0))
Hotkey("+j", (*) => ResizeActiveWindowCentered(0, -resize_step))
Hotkey("+k", (*) => ResizeActiveWindowCentered(0, resize_step))
Hotkey("^h", (*) => MoveActiveWindow(-move_step, 0))
Hotkey("^l", (*) => MoveActiveWindow(move_step, 0))
Hotkey("^j", (*) => MoveActiveWindow(0, move_step))
Hotkey("^k", (*) => MoveActiveWindow(0, -move_step))
Hotkey("m", ToggleMaximize)
Hotkey("q", CloseWindow)
Hotkey(cycle_app_windows_hotkey, CycleAppWindows)
HotIf

if move_mode_enabled {
    HotIf Window.IsMoveMode
    Hotkey("h", (*) => MoveActiveWindow(-move_step, 0))
    Hotkey("l", (*) => MoveActiveWindow(move_step, 0))
    Hotkey("j", (*) => MoveActiveWindow(0, move_step))
    Hotkey("k", (*) => MoveActiveWindow(0, -move_step))
    Hotkey(move_mode_cancel_key, (*) => ExitMoveMode())
    HotIf
}

ExitMoveMode() {
    Window.SetMoveMode(false)
    UpdateCommandToastVisibility()
}
