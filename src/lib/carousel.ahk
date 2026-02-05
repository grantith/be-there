global Config

global carousel_enabled := false
global carousel_last_active_hwnd := 0
global carousel_home_by_hwnd := Map()
global carousel_quadrant_occupants := Map(
    "tl", 0,
    "tr", 0,
    "bl", 0
)
global carousel_focus_source := ""
global carousel_focus_source_hwnd := 0
global carousel_focus_source_expires_at := 0
global carousel_default_home := "tl"
global carousel_auto_snap_center := true
global carousel_excluded := []
global carousel_corner_width_ratio := 0.25
global carousel_corner_height_ratio := 0.25
global carousel_recent_hwnds := []
global carousel_full_height_corners := false
global carousel_layout_mode := "four_slots"
global carousel_full_side := "left"

InitCarousel() {
    global carousel_enabled, carousel_default_home, carousel_auto_snap_center, carousel_excluded
    global carousel_corner_width_ratio, carousel_corner_height_ratio
    global carousel_layout_mode, carousel_full_side
    if !Config.Has("modes")
        return
    if Config["modes"]["active"] != "carousel"
        return

    carousel_config := Config["modes"]["carousel"]

    carousel_enabled := true
    carousel_default_home := CarouselNormalizeQuadrant(carousel_config["default_home_quadrant"])
    carousel_auto_snap_center := carousel_config["auto_snap_center_on_focus"]
    carousel_excluded := carousel_config["excluded_apps"]
    carousel_corner_width_ratio := CarouselClampRatio(carousel_config["corner_width_ratio"], 0.25)
    carousel_corner_height_ratio := CarouselClampRatio(carousel_config["corner_height_ratio"], 0.25)
    carousel_layout_mode := CarouselNormalizeLayoutMode(carousel_config["layout_mode"])
    carousel_full_side := CarouselNormalizeFullSide(carousel_config["full_side"])

    SetTimer(CarouselTick, 150)
}

SetCarouselFocusSource(source, hwnd := 0, ttl_ms := 400) {
    global carousel_focus_source, carousel_focus_source_hwnd, carousel_focus_source_expires_at
    carousel_focus_source := source
    carousel_focus_source_hwnd := hwnd
    carousel_focus_source_expires_at := A_TickCount + ttl_ms
}

CarouselTick(*) {
    global carousel_enabled, carousel_last_active_hwnd
    if !carousel_enabled
        return

    active_hwnd := 0
    try active_hwnd := WinGetID("A")
    if !active_hwnd
        return
    if Window.IsException("ahk_id " active_hwnd)
        return
    ex_style := WinGetExStyle("ahk_id " active_hwnd)
    if ((ex_style & 0x80) && !(ex_style & 0x40000))
        return
    if (active_hwnd = carousel_last_active_hwnd)
        return

    prev_hwnd := carousel_last_active_hwnd
    carousel_last_active_hwnd := active_hwnd
    CarouselHandleFocusChange(prev_hwnd, active_hwnd)
}

CarouselHandleFocusChange(prev_hwnd, active_hwnd) {
    source := CarouselPeekFocusSource(active_hwnd)

    if (active_hwnd && CarouselShouldManageWindow(active_hwnd))
        CarouselTouchRecent(active_hwnd)

    if (source = "directional") {
        CarouselClearFocusSource()
        return
    }

    if (!active_hwnd || !CarouselShouldManageWindow(active_hwnd))
        return

    if CarouselShouldCenterOnFocus(active_hwnd)
        CarouselMoveToCenter(active_hwnd)

    CarouselReflowSlots(active_hwnd)
}

CarouselShouldCenterOnFocus(active_hwnd) {
    global carousel_auto_snap_center, carousel_focus_source, carousel_focus_source_hwnd
    global carousel_focus_source_expires_at

    if !carousel_auto_snap_center
        return false

    source := ""
    if (carousel_focus_source != "" && A_TickCount <= carousel_focus_source_expires_at) {
        if (!carousel_focus_source_hwnd || carousel_focus_source_hwnd = active_hwnd) {
            source := carousel_focus_source
        }
    }

    carousel_focus_source := ""
    carousel_focus_source_hwnd := 0
    carousel_focus_source_expires_at := 0

    if (source = "directional")
        return false

    return true
}

CarouselPeekFocusSource(active_hwnd) {
    global carousel_focus_source, carousel_focus_source_hwnd, carousel_focus_source_expires_at

    if (carousel_focus_source = "")
        return ""
    if (A_TickCount > carousel_focus_source_expires_at)
        return ""
    if (carousel_focus_source_hwnd && carousel_focus_source_hwnd != active_hwnd)
        return ""

    return carousel_focus_source
}

CarouselClearFocusSource() {
    global carousel_focus_source, carousel_focus_source_hwnd, carousel_focus_source_expires_at
    carousel_focus_source := ""
    carousel_focus_source_hwnd := 0
    carousel_focus_source_expires_at := 0
}

CarouselShouldManageWindow(hwnd) {
    if !hwnd
        return false
    if !WinExist("ahk_id " hwnd)
        return false
    class_name := WinGetClass("ahk_id " hwnd)
    if (class_name = "AutoHotkeyGUI")
        return false
    if Window.IsException("ahk_id " hwnd)
        return false

    state := WinGetMinMax("ahk_id " hwnd)
    if (state = -1)
        return false

    if CarouselIsExcluded(hwnd)
        return false

    return true
}

CarouselIsExcluded(hwnd) {
    global carousel_excluded

    app := CarouselFindAppConfig(hwnd)
    if (app is Map) {
        if (app.Has("carousel_excluded") && app["carousel_excluded"])
            return true
        if (app.Has("id") && CarouselListHas(carousel_excluded, app["id"]))
            return true
    }

    exe := WinGetProcessName("ahk_id " hwnd)
    if exe && CarouselListHas(carousel_excluded, exe)
        return true

    return false
}

CarouselListHas(list, value) {
    if !(list is Array)
        return false
    target := StrLower(value)
    for _, item in list {
        if (StrLower(item) = target)
            return true
    }
    return false
}

CarouselFindAppConfig(hwnd) {
    global Config
    exe := WinGetProcessName("ahk_id " hwnd)
    if !exe
        return ""
    exe_lower := StrLower(exe)
    for _, app in Config["apps"] {
        win_title := StrLower(app["win_title"])
        if InStr(win_title, "ahk_exe " exe_lower)
            return app
    }
    return ""
}

CarouselSnapToHome(hwnd) {
    quadrant := CarouselGetHomeQuadrant(hwnd)
    if (quadrant = "br") {
        CarouselMoveToQuadrant(hwnd, quadrant)
        return
    }

    occupant := CarouselGetQuadrantOccupant(quadrant)
    if (occupant && occupant != hwnd && WinExist("ahk_id " occupant))
        CarouselMoveToQuadrant(occupant, "br")

    CarouselMoveToQuadrant(hwnd, quadrant)
    CarouselSetQuadrantOccupant(quadrant, hwnd)
}

CarouselGetHomeQuadrant(hwnd) {
    global carousel_home_by_hwnd, carousel_default_home
    if (carousel_home_by_hwnd.Has(hwnd))
        return carousel_home_by_hwnd[hwnd]

    quadrant := ""
    app := CarouselFindAppConfig(hwnd)
    if (app is Map && app.Has("home_quadrant"))
        quadrant := app["home_quadrant"]

    quadrant := CarouselNormalizeQuadrant(quadrant)
    if (quadrant = "")
        quadrant := CarouselChooseOpenQuadrant()
    if (quadrant = "")
        quadrant := carousel_default_home

    carousel_home_by_hwnd[hwnd] := quadrant
    return quadrant
}

CarouselTouchRecent(hwnd) {
    global carousel_recent_hwnds
    if !hwnd
        return

    new_list := []
    new_list.Push(hwnd)
    for _, existing in carousel_recent_hwnds {
        if (existing = hwnd)
            continue
        new_list.Push(existing)
    }
    carousel_recent_hwnds := new_list
}

CarouselReflowSlots(active_hwnd) {
    global carousel_recent_hwnds
    global carousel_full_height_corners
    global carousel_layout_mode

    carousel_recent_hwnds := CarouselPruneRecent(carousel_recent_hwnds)

    candidates := []
    for _, hwnd in carousel_recent_hwnds {
        if (hwnd = active_hwnd)
            continue
        if !CarouselShouldManageWindow(hwnd)
            continue
        candidates.Push(hwnd)
    }

    CarouselSetQuadrantOccupant("tl", 0)
    CarouselSetQuadrantOccupant("tr", 0)
    CarouselSetQuadrantOccupant("bl", 0)

    slot_order := CarouselGetSlotOrder(candidates.Length)
    slot_index := 1

    for _, hwnd in candidates {
        if (slot_index <= slot_order.Length) {
            quadrant := slot_order[slot_index]
            CarouselMoveToSlot(hwnd, quadrant)
            CarouselSetQuadrantOccupant(CarouselSlotToQuadrant(quadrant), hwnd)
            slot_index += 1
        } else {
            overflow_slot := CarouselGetOverflowSlot()
            CarouselMoveToSlot(hwnd, overflow_slot)
        }
    }
}

CarouselPruneRecent(list) {
    cleaned := []
    for _, hwnd in list {
        if !WinExist("ahk_id " hwnd)
            continue
        if (WinGetMinMax("ahk_id " hwnd) = -1)
            continue
        cleaned.Push(hwnd)
    }
    return cleaned
}

CarouselChooseOpenQuadrant() {
    for _, quadrant in ["tl", "tr", "bl"] {
        if CarouselQuadrantAvailable(quadrant)
            return quadrant
    }
    return ""
}

CarouselQuadrantAvailable(quadrant) {
    occupant := CarouselGetQuadrantOccupant(quadrant)
    if (occupant && WinExist("ahk_id " occupant))
        return false
    CarouselSetQuadrantOccupant(quadrant, 0)
    return true
}

CarouselNormalizeQuadrant(value) {
    if !value
        return ""
    value := StrLower(Trim(value))
    if (value = "tl" || value = "tr" || value = "bl" || value = "br")
        return value
    if (value = "top_left")
        return "tl"
    if (value = "top_right")
        return "tr"
    if (value = "bottom_left")
        return "bl"
    if (value = "bottom_right")
        return "br"
    return ""
}

CarouselGetQuadrantOccupant(quadrant) {
    global carousel_quadrant_occupants
    if !carousel_quadrant_occupants.Has(quadrant)
        return 0
    return carousel_quadrant_occupants[quadrant]
}

CarouselSetQuadrantOccupant(quadrant, hwnd) {
    global carousel_quadrant_occupants
    if !carousel_quadrant_occupants.Has(quadrant)
        return
    carousel_quadrant_occupants[quadrant] := hwnd
}

CarouselMoveToQuadrant(hwnd, quadrant) {
    if !hwnd
        return

    area := CarouselGetWorkArea()
    if (area["w"] <= 0 || area["h"] <= 0)
        return

    corner := CarouselGetCornerMetrics(area)
    left_w := corner["w"]
    right_w := corner["w"]
    top_h := corner["h"]
    bottom_h := corner["h"]

    x := area["x"]
    y := area["y"]
    w := left_w
    h := top_h

    if (quadrant = "tr") {
        x := area["x"] + area["w"] - right_w
        w := right_w
    } else if (quadrant = "bl") {
        y := area["y"] + area["h"] - bottom_h
        h := bottom_h
    } else if (quadrant = "br") {
        x := area["x"] + area["w"] - right_w
        y := area["y"] + area["h"] - bottom_h
        w := right_w
        h := bottom_h
    }

    WinRestore "ahk_id " hwnd
    WinMoveEx(x, y, w, h, "ahk_id " hwnd)
    ScheduleFocusBorderUpdate()
}

CarouselMoveToSlot(hwnd, slot) {
    if (slot = "center") {
        CarouselMoveToCenter(hwnd)
        return
    }
    if (slot = "tl" || slot = "tr" || slot = "bl" || slot = "br") {
        CarouselMoveToQuadrant(hwnd, slot)
        return
    }

    if (slot = "left_full") {
        CarouselMoveToSideFull(hwnd, "left")
        return
    }
    if (slot = "right_full") {
        CarouselMoveToSideFull(hwnd, "right")
        return
    }
    if (slot = "left_top") {
        CarouselMoveToSideHalf(hwnd, "left", "top")
        return
    }
    if (slot = "left_bottom") {
        CarouselMoveToSideHalf(hwnd, "left", "bottom")
        return
    }
    if (slot = "right_top") {
        CarouselMoveToSideHalf(hwnd, "right", "top")
        return
    }
    if (slot = "right_bottom") {
        CarouselMoveToSideHalf(hwnd, "right", "bottom")
        return
    }
    if (slot = "top_full") {
        CarouselMoveToBand(hwnd, "top")
        return
    }
    if (slot = "bottom_full") {
        CarouselMoveToBand(hwnd, "bottom")
        return
    }
}

CarouselMoveToCenter(hwnd) {
    if !hwnd
        return

    area := CarouselGetWorkArea()
    if (area["w"] <= 0 || area["h"] <= 0)
        return

    gap_px := Config["window_manager"]["gap_px"]
    corner := CarouselGetCornerMetrics(area)
    corner_w := corner["w"]
    w := area["w"] - (corner_w * 2) - (gap_px * 2)
    h := area["h"]
    x := area["x"] + corner_w + gap_px
    y := area["y"]

    if (w <= 0 || h <= 0)
        return

    WinRestore "ahk_id " hwnd
    WinMoveEx(x, y, w, h, "ahk_id " hwnd)
    ScheduleFocusBorderUpdate()
}

CarouselMoveToSideFull(hwnd, side) {
    if !hwnd
        return
    area := CarouselGetWorkArea()
    if (area["w"] <= 0 || area["h"] <= 0)
        return

    corner := CarouselGetCornerMetrics(area)
    w := corner["w"]
    h := area["h"]
    x := area["x"]
    if (side = "right")
        x := area["x"] + area["w"] - w
    y := area["y"]

    WinRestore "ahk_id " hwnd
    WinMoveEx(x, y, w, h, "ahk_id " hwnd)
    ScheduleFocusBorderUpdate()
}

CarouselMoveToSideHalf(hwnd, side, vertical) {
    if !hwnd
        return
    area := CarouselGetWorkArea()
    if (area["w"] <= 0 || area["h"] <= 0)
        return

    corner := CarouselGetCornerMetrics(area)
    w := corner["w"]
    h := corner["h"]
    x := area["x"]
    if (side = "right")
        x := area["x"] + area["w"] - w
    y := area["y"]
    if (vertical = "bottom")
        y := area["y"] + area["h"] - h

    WinRestore "ahk_id " hwnd
    WinMoveEx(x, y, w, h, "ahk_id " hwnd)
    ScheduleFocusBorderUpdate()
}

CarouselMoveToBand(hwnd, vertical) {
    if !hwnd
        return
    area := CarouselGetWorkArea()
    if (area["w"] <= 0 || area["h"] <= 0)
        return

    gap_px := Config["window_manager"]["gap_px"]
    h := Floor((area["h"] - gap_px) / 2)
    w := area["w"]
    x := area["x"]
    y := area["y"]
    if (vertical = "bottom")
        y := area["y"] + area["h"] - h

    WinRestore "ahk_id " hwnd
    WinMoveEx(x, y, w, h, "ahk_id " hwnd)
    ScheduleFocusBorderUpdate()
}

CarouselGetWorkArea() {
    MonitorGetWorkArea(MonitorGetPrimary(), &mx1, &my1, &mx2, &my2)
    mw := mx2 - mx1
    mh := my2 - my1

    left_margin := Screen.left_margin
    right_margin := Screen.right_margin
    gap_px := Config["window_manager"]["gap_px"]

    x := mx1 + left_margin
    y := my1
    w := mw - left_margin - right_margin
    h := mh

    if (gap_px > 0) {
        x += gap_px
        y += gap_px
        w -= gap_px * 2
        h -= gap_px * 2
    }

    return Map("x", x, "y", y, "w", w, "h", h)
}

CarouselGetCornerMetrics(area) {
    global carousel_corner_width_ratio, carousel_corner_height_ratio, carousel_full_height_corners
    gap_px := Config["window_manager"]["gap_px"]
    gap_half := Floor(gap_px / 2)

    w := Floor(area["w"] * carousel_corner_width_ratio) - gap_half
    if carousel_full_height_corners
        h := area["h"]
    else
        h := Floor(area["h"] * carousel_corner_height_ratio) - gap_half
    if (w < 0)
        w := 0
    if (h < 0)
        h := 0

    return Map("w", w, "h", h)
}

CarouselGetSlotOrder(candidate_count) {
    global carousel_layout_mode, carousel_full_side, carousel_full_height_corners

    if (carousel_layout_mode = "two_slots_tb") {
        carousel_full_height_corners := false
        return ["left_full", "right_full"]
    }

    if (carousel_layout_mode = "one_side_full") {
        carousel_full_height_corners := false
        if (carousel_full_side = "left")
            return ["left_full", "right_top", "right_bottom"]
        return ["right_full", "left_top", "left_bottom"]
    }

    if (candidate_count <= 2) {
        carousel_full_height_corners := true
        return ["tl", "tr"]
    }

    carousel_full_height_corners := false
    return ["tl", "bl", "br"]
}

CarouselGetOverflowSlot() {
    return "center"
}

CarouselSlotToQuadrant(slot) {
    if (slot = "tl" || slot = "tr" || slot = "bl" || slot = "br")
        return slot
    return ""
}

CarouselNormalizeLayoutMode(value) {
    if !value
        return "four_slots"
    value := StrLower(Trim(value))
    if (value = "four_slots" || value = "two_slots_tb" || value = "one_side_full")
        return value
    return "four_slots"
}

CarouselNormalizeFullSide(value) {
    if !value
        return "left"
    value := StrLower(Trim(value))
    if (value = "left" || value = "right")
        return value
    return "left"
}

CarouselClampRatio(value, fallback) {
    if !IsNumber(value)
        return fallback
    value := Float(value)
    if (value < 0.1)
        return 0.1
    if (value > 0.5)
        return 0.5
    return value
}
