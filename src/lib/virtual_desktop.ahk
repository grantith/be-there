#Include %A_LineFile%\..\VD.ahk

VirtualDesktopEnabled() {
    global Config
    if !IsSet(Config)
        return false
    if !Config.Has("virtual_desktop")
        return false
    return Config["virtual_desktop"]["enabled"]
}

VirtualDesktopSwitchOnFocus() {
    global Config
    if !VirtualDesktopEnabled()
        return false
    return Config["virtual_desktop"]["switch_on_focus"]
}

InitVirtualDesktop() {
    if !VirtualDesktopEnabled()
        return
    ensure_count := Config["virtual_desktop"]["ensure_count"]
    if (ensure_count > 0)
        VD.createUntil(ensure_count)
}

GetWindowDesktopNum(hwnd) {
    if !VirtualDesktopEnabled()
        return 0
    try return VD.getDesktopNumOfHWND(hwnd)
    catch as err
        return 0
}

IsWindowOnCurrentDesktop(hwnd) {
    if !VirtualDesktopEnabled()
        return true
    desktop_num := GetWindowDesktopNum(hwnd)
    if (desktop_num <= 0)
        return true
    return desktop_num = VD.getCurrentDesktopNum()
}

GetWindowsAcrossDesktops(win_title := "") {
    if !VirtualDesktopEnabled()
        return WinGetList(win_title)
    bak_detect_hidden_windows := A_DetectHiddenWindows
    A_DetectHiddenWindows := true
    windows := WinGetList(win_title)
    A_DetectHiddenWindows := bak_detect_hidden_windows
    return windows
}

WindowExistsAcrossDesktops(hwnd) {
    bak_detect_hidden_windows := A_DetectHiddenWindows
    A_DetectHiddenWindows := true
    exists := WinExist("ahk_id " hwnd)
    A_DetectHiddenWindows := bak_detect_hidden_windows
    return exists
}

ActivateWindowAcrossDesktops(hwnd) {
    if !hwnd
        return 0
    if !WindowExistsAcrossDesktops(hwnd)
        return 0

    if VirtualDesktopSwitchOnFocus() {
        desktop_num := GetWindowDesktopNum(hwnd)
        if (desktop_num > 0 && desktop_num != VD.getCurrentDesktopNum()) {
            try {
                VD.goToDesktopOfWindow("ahk_id " hwnd, true)
            } catch as err {
                try {
                    WinActivate "ahk_id " hwnd
                } catch
                    return 0
            }
            try return WinGetID("A")
            catch
                return 0
        }

        if (desktop_num <= 0) {
            try {
                VD.goToDesktopOfWindow("ahk_id " hwnd, true)
                try return WinGetID("A")
                catch
                    return 0
            } catch as err {
                ; fall through to direct activation
            }
        }
    }

    try {
        WinActivate "ahk_id " hwnd
    } catch
        return 0
    try return WinGetID("A")
    catch
        return 0
}
