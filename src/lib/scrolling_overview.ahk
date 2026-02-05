global Config

global scrolling_overview_active := false
global scrolling_overview_gui := ""
global scrolling_overview_items := []
global scrolling_overview_selected_index := 0
global scrolling_overview_hotkeys_bound := false

ShowScrollingOverview() {
    if !ScrollingModeActive()
        return

    overview_config := Config["modes"]["scrolling"]["overview"]
    if !overview_config["enabled"]
        return

    if scrolling_overview_active {
        ScrollingOverviewClose()
        return
    }

    ScrollingOverviewOpen()
}

ScrollingOverviewOpen() {
    global scrolling_overview_active, scrolling_overview_gui
    global scrolling_overview_selected_index

    snapshot := ScrollingGetSnapshot()
    if !(snapshot is Map)
        return

    if (snapshot["list"].Length = 0)
        return

    scrolling_overview_active := true
    scrolling_overview_selected_index := snapshot["center_index"]

    PauseFocusBorderUpdates(true)

    scrolling_overview_gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "harken Scrolling Overview")
    scrolling_overview_gui.BackColor := "101010"
    WinSetTransColor("101010", scrolling_overview_gui)
    scrolling_overview_gui.MarginX := 0
    scrolling_overview_gui.MarginY := 0
    scrolling_overview_gui.OnEvent("Close", (*) => ScrollingOverviewClose())

    ScrollingOverviewBuild(snapshot)
    scrolling_overview_gui.Show("NoActivate")
    ScrollingOverviewBindHotkeys()
}

ScrollingOverviewClose() {
    global scrolling_overview_active, scrolling_overview_gui, scrolling_overview_items
    if !scrolling_overview_active
        return
    scrolling_overview_active := false
    ScrollingOverviewUnbindHotkeys()
    ScrollingOverviewClear()
    if scrolling_overview_gui {
        scrolling_overview_gui.Destroy()
        scrolling_overview_gui := ""
    }
    PauseFocusBorderUpdates(false)
    ScrollingReflow()
}

ScrollingOverviewBuild(snapshot) {
    global scrolling_overview_gui, scrolling_overview_items

    overview_config := Config["modes"]["scrolling"]["overview"]
    visible_count := Max(1, Integer(overview_config["visible_count"]))
    if (Mod(visible_count, 2) = 0)
        visible_count += 1

    scale_center := overview_config["center_scale"]
    scale_side := overview_config["side_scale"]
    spacing_px := Integer(overview_config["spacing_px"])
    use_live := overview_config["use_live_thumbnails"]

    screen_w := A_ScreenWidth
    screen_h := A_ScreenHeight

    base_w := Floor(screen_w * 0.42)
    base_h := Floor(screen_h * 0.42)
    if (base_w < 320)
        base_w := 320
    if (base_h < 200)
        base_h := 200

    center_w := Floor(base_w * scale_center)
    center_h := Floor(base_h * scale_center)
    side_w := Floor(base_w * scale_side)
    side_h := Floor(base_h * scale_side)

    center_x := Floor((screen_w - center_w) / 2)
    center_y := Floor((screen_h - center_h) / 2) - 40
    if (center_y < 40)
        center_y := 40

    visible := ScrollingOverviewVisibleIndices(snapshot["list"].Length, snapshot["center_index"], visible_count)

    scrolling_overview_items := []

    for i, index in visible {
        hwnd := snapshot["list"][index]
        if !WinExist("ahk_id " hwnd)
            continue

        is_center := (index = snapshot["center_index"])
        w := is_center ? center_w : side_w
        h := is_center ? center_h : side_h
        offset := i - Ceil(visible.Length / 2)
        slot_gap := spacing_px + Ceil((center_w - side_w) / 2)
        x := center_x + offset * (side_w + slot_gap)
        y := center_y + (is_center ? 0 : Floor((center_h - side_h) / 2))

        slot := Map(
            "hwnd", hwnd,
            "is_center", is_center,
            "rect", Map("x", x, "y", y, "w", w, "h", h),
            "thumb", 0,
            "title_ctrl", "",
            "icon_ctrl", ""
        )

        if use_live {
            slot["thumb"] := ScrollingOverviewRegisterThumbnail(hwnd, x, y, w, h)
        }

        if !slot["thumb"] {
            slot["icon_ctrl"] := ScrollingOverviewAddIcon(hwnd, x, y, w, h)
        }

        title := WinGetTitle("ahk_id " hwnd)
        slot["title_ctrl"] := scrolling_overview_gui.AddText(
            "x" x " y" (y + h + 8) " w" w " Center cFFFFFF", title
        )

        scrolling_overview_items.Push(slot)
    }
}

ScrollingOverviewVisibleIndices(total, center_index, visible_count) {
    half := Floor(visible_count / 2)
    start := Max(1, center_index - half)
    finish := Min(total, center_index + half)
    if (finish - start + 1 < visible_count) {
        if (start = 1)
            finish := Min(total, start + visible_count - 1)
        else if (finish = total)
            start := Max(1, finish - visible_count + 1)
    }

    indices := []
    loop finish - start + 1
        indices.Push(start + A_Index - 1)
    return indices
}

ScrollingOverviewRegisterThumbnail(hwnd, x, y, w, h) {
    global scrolling_overview_gui

    thumb := 0
    if DllCall("dwmapi\DwmRegisterThumbnail", "ptr", scrolling_overview_gui.Hwnd, "ptr", hwnd, "ptr*", &thumb) != 0
        return 0

    rect := Buffer(16, 0)
    NumPut("int", x, rect, 0)
    NumPut("int", y, rect, 4)
    NumPut("int", x + w, rect, 8)
    NumPut("int", y + h, rect, 12)

    props := Buffer(48, 0)
    NumPut("uint", 0x1 | 0x4 | 0x8, props, 0)
    NumPut("int", x, props, 4)
    NumPut("int", y, props, 8)
    NumPut("int", x + w, props, 12)
    NumPut("int", y + h, props, 16)
    NumPut("int", 0, props, 20)
    NumPut("int", 0, props, 24)
    NumPut("int", 0, props, 28)
    NumPut("int", 0, props, 32)
    NumPut("uchar", 255, props, 36)
    NumPut("int", 1, props, 40)
    NumPut("int", 0, props, 44)

    if DllCall("dwmapi\DwmUpdateThumbnailProperties", "ptr", thumb, "ptr", props) != 0 {
        DllCall("dwmapi\DwmUnregisterThumbnail", "ptr", thumb)
        return 0
    }
    return thumb
}

ScrollingOverviewAddIcon(hwnd, x, y, w, h) {
    global scrolling_overview_gui
    path := ""
    try path := WinGetProcessPath("ahk_id " hwnd)
    if !path
        path := WinGetProcessName("ahk_id " hwnd)

    icon_size := Min(64, w, h)
    icon_x := x + Floor((w - icon_size) / 2)
    icon_y := y + Floor((h - icon_size) / 2)
    try {
        return scrolling_overview_gui.AddPicture(
            "x" icon_x " y" icon_y " w" icon_size " h" icon_size,
            "Icon1 " path
        )
    }
    return ""
}

ScrollingOverviewBindHotkeys() {
    global scrolling_overview_hotkeys_bound
    HotIf (*) => scrolling_overview_active
    Hotkey("Left", (*) => ScrollingOverviewMove(-1))
    Hotkey("Right", (*) => ScrollingOverviewMove(1))
    Hotkey("Enter", (*) => ScrollingOverviewConfirm())
    Hotkey("Esc", (*) => ScrollingOverviewClose())
    HotIf
    scrolling_overview_hotkeys_bound := true
}

ScrollingOverviewUnbindHotkeys() {
    global scrolling_overview_hotkeys_bound
    if !scrolling_overview_hotkeys_bound
        return
    HotIf (*) => scrolling_overview_active
    try Hotkey("Left", "Off")
    try Hotkey("Right", "Off")
    try Hotkey("Enter", "Off")
    try Hotkey("Esc", "Off")
    HotIf
    scrolling_overview_hotkeys_bound := false
}

ScrollingOverviewMove(delta) {
    global scrolling_overview_selected_index
    snapshot := ScrollingGetSnapshot()
    if !(snapshot is Map)
        return

    next_index := scrolling_overview_selected_index + delta
    if (next_index < 1 || next_index > snapshot["list"].Length)
        return

    scrolling_overview_selected_index := next_index
    ScrollingOverviewClear()
    ScrollingOverviewBuild(Map("list", snapshot["list"], "center_index", scrolling_overview_selected_index))
}

ScrollingOverviewConfirm() {
    global scrolling_overview_selected_index
    snapshot := ScrollingGetSnapshot()
    if !(snapshot is Map)
        return
    if (scrolling_overview_selected_index < 1 || scrolling_overview_selected_index > snapshot["list"].Length)
        return
    hwnd := snapshot["list"][scrolling_overview_selected_index]
    if hwnd
        ActivateWindow(hwnd)
    ScrollingOverviewClose()
}

ScrollingOverviewClear() {
    global scrolling_overview_items
    for _, item in scrolling_overview_items {
        if item.Has("thumb") && item["thumb"]
            DllCall("dwmapi\DwmUnregisterThumbnail", "ptr", item["thumb"])
    }
    scrolling_overview_items := []
}
