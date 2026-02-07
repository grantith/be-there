#Include %A_LineFile%\..\VD.ahk

VirtualDesktopEnabled() {
    global Config
    if !IsSet(Config)
        return false
    if !Config.Has("virtual_desktop")
        return false
    return Config["virtual_desktop"]["enabled"]
}

VirtualDesktopTrayEnabled() {
    global Config
    if !VirtualDesktopEnabled()
        return false
    return Config["virtual_desktop"].Has("tray_indicator") && Config["virtual_desktop"]["tray_indicator"]
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
    InitVirtualDesktopTrayIndicator()
}

InitVirtualDesktopTrayIndicator() {
    if !VirtualDesktopTrayEnabled()
        return
    UpdateVirtualDesktopTrayIndicator()
    VD.ListenersCurrentVirtualDesktopChanged[UpdateVirtualDesktopTrayIndicator] := true
}

UpdateVirtualDesktopTrayIndicator(*) {
    if !VirtualDesktopTrayEnabled()
        return
    current := GetCurrentDesktopNumFresh()
    if (current <= 0)
        current := VD.getCurrentDesktopNum()
    total := VD.getCount()
    if (total <= 0)
        return
    text := FormatVirtualDesktopTrayText(current, total)
    try A_TrayMenu.SetTip(text)
    SetTrayIconText(text)
}

FormatVirtualDesktopTrayText(current, total) {
    global Config
    format := "{current}/{total}"
    if Config.Has("virtual_desktop") && Config["virtual_desktop"].Has("tray_format")
        format := Config["virtual_desktop"]["tray_format"]
    format := StrReplace(format, "{current}", current)
    format := StrReplace(format, "{total}", total)
    return format
}

SetTrayIconText(text) {
    if (text = "")
        return
    hicon := CreateTextTrayIcon(text)
    if !hicon
        return
    TraySetIcon("HICON:" hicon)
    global tray_indicator_hicon
    if (IsSet(tray_indicator_hicon) && tray_indicator_hicon)
        DllCall("user32\DestroyIcon", "Ptr", tray_indicator_hicon)
    tray_indicator_hicon := hicon
}

CreateTextTrayIcon(text) {
    icon_size := 32
    hdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
    if !hdc
        return 0

    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", icon_size, bi, 4)
    NumPut("Int", -icon_size, bi, 8)
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 32, bi, 14)
    NumPut("UInt", 0, bi, 16)
    ppv_bits := 0
    hbm_color := DllCall("gdi32\CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &ppv_bits, "Ptr", 0, "UInt", 0, "Ptr")
    if !hbm_color {
        DllCall("gdi32\\DeleteDC", "Ptr", hdc)
        return 0
    }

    hbm_mask := DllCall("gdi32\CreateBitmap", "Int", icon_size, "Int", icon_size, "UInt", 1, "UInt", 1, "Ptr", 0, "Ptr")
    old_bmp := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hbm_color, "Ptr")

    DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1)

    font_height := -Round(icon_size * 0.55)
    hfont := DllCall("gdi32\CreateFontW", "Int", font_height, "Int", 0, "Int", 0, "Int", 0, "Int", 600, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0, "WStr", "Segoe UI", "Ptr")
    old_font := 0
    if hfont
        old_font := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hfont, "Ptr")

    rect := Buffer(16, 0)
    NumPut("Int", 0, rect, 0)
    NumPut("Int", 0, rect, 4)
    NumPut("Int", icon_size, rect, 8)
    NumPut("Int", icon_size, rect, 12)
    format := 0x00000001 | 0x00000004 | 0x00000020

    DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", 0x000000)
    rect_shadow := Buffer(16, 0)
    NumPut("Int", 1, rect_shadow, 0)
    NumPut("Int", 1, rect_shadow, 4)
    NumPut("Int", icon_size + 1, rect_shadow, 8)
    NumPut("Int", icon_size + 1, rect_shadow, 12)
    DllCall("user32\DrawTextW", "Ptr", hdc, "WStr", text, "Int", -1, "Ptr", rect_shadow, "UInt", format)

    DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", 0xFFFFFF)
    DllCall("user32\DrawTextW", "Ptr", hdc, "WStr", text, "Int", -1, "Ptr", rect, "UInt", format)

    if hfont {
        if old_font
            DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", old_font)
        DllCall("gdi32\DeleteObject", "Ptr", hfont)
    }
    if old_bmp
        DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", old_bmp)
    DllCall("gdi32\DeleteDC", "Ptr", hdc)

    iconinfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
    NumPut("UInt", 1, iconinfo, 0)
    NumPut("UInt", 0, iconinfo, 4)
    NumPut("UInt", 0, iconinfo, 8)
    if (A_PtrSize == 8) {
        NumPut("Ptr", hbm_mask, iconinfo, 16)
        NumPut("Ptr", hbm_color, iconinfo, 24)
    } else {
        NumPut("Ptr", hbm_mask, iconinfo, 12)
        NumPut("Ptr", hbm_color, iconinfo, 16)
    }
    hicon := DllCall("user32\CreateIconIndirect", "Ptr", iconinfo, "Ptr")

    DllCall("gdi32\DeleteObject", "Ptr", hbm_color)
    DllCall("gdi32\DeleteObject", "Ptr", hbm_mask)

    return hicon
}

RefreshVirtualDesktopState() {
    if !VirtualDesktopEnabled()
        return
    try {
        VD.IVirtualDesktopListChanged()
        VD.currentDesktopNum := VD.IVirtualDesktopMap[VD.IVirtualDesktopManagerInternal.GetCurrentDesktop()]
    }
}

GetCurrentDesktopNumFresh() {
    if !VirtualDesktopEnabled()
        return 0
    try {
        VD.IVirtualDesktopListChanged()
        current := VD.IVirtualDesktopMap[VD.IVirtualDesktopManagerInternal.GetCurrentDesktop()]
        if (current > 0)
            VD.currentDesktopNum := current
        return current
    }
    return 0
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
