global Config

global scrolling_enabled := false
global scrolling_last_active_hwnd := 0
global scrolling_workspace_count := 1
global scrolling_active_workspace := 1
global scrolling_workspaces := Map()
global scrolling_center_index := Map()
global scrolling_dynamic_workspaces := false
global scrolling_wrap_enabled := true
global scrolling_center_width_ratio := 0.5
global scrolling_side_width_ratio := 0.25
global scrolling_gap_px := 0
global scrolling_seed_with_open_windows := true

InitScrolling() {
    global Config
    global scrolling_enabled, scrolling_workspace_count, scrolling_workspaces, scrolling_center_index
    global scrolling_wrap_enabled, scrolling_center_width_ratio, scrolling_side_width_ratio, scrolling_gap_px
    global scrolling_seed_with_open_windows
    global scrolling_dynamic_workspaces

    if !Config.Has("modes")
        return
    if Config["modes"]["active"] != "scrolling"
        return

    scrolling_config := Config["modes"]["scrolling"]
    scrolling_enabled := true
    scrolling_wrap_enabled := scrolling_config["wrap_enabled"]
    scrolling_center_width_ratio := scrolling_config["center_width_ratio"]
    scrolling_side_width_ratio := scrolling_config["side_width_ratio"]
    scrolling_gap_px := scrolling_config["gap_px"]
    raw_workspace_count := Integer(scrolling_config["workspace_count"])
    scrolling_dynamic_workspaces := (raw_workspace_count <= 0)
    scrolling_workspace_count := scrolling_dynamic_workspaces ? 1 : Max(1, raw_workspace_count)
    scrolling_seed_with_open_windows := scrolling_config["seed_with_open_windows"]

    scrolling_workspaces := Map()
    scrolling_center_index := Map()
    loop scrolling_workspace_count {
        scrolling_workspaces[A_Index] := []
        scrolling_center_index[A_Index] := 0
    }

    if scrolling_seed_with_open_windows
        ScrollingSeedFromOpenWindows()

    if scrolling_dynamic_workspaces
        ScrollingEnsureDynamicWorkspace()

    SetTimer(ScrollingTick, 150)
}

ScrollingModeActive() {
    global scrolling_enabled
    return scrolling_enabled
}

ScrollingOverviewActive() {
    global scrolling_overview_active
    return scrolling_overview_active
}

ScrollingTick(*) {
    global scrolling_enabled, scrolling_last_active_hwnd
    if !scrolling_enabled
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
    if (active_hwnd = scrolling_last_active_hwnd)
        return

    prev_hwnd := scrolling_last_active_hwnd
    scrolling_last_active_hwnd := active_hwnd
    ScrollingHandleFocusChange(prev_hwnd, active_hwnd)
}

ScrollingHandleFocusChange(prev_hwnd, active_hwnd) {
    if !ScrollingShouldManageWindow(active_hwnd)
        return

    ScrollingEnsureWindowInWorkspace(active_hwnd)
    ScrollingSetCenter(active_hwnd)
    ScrollingReflow()
}

ScrollingShouldManageWindow(hwnd) {
    if !hwnd
        return false
    if !WinExist("ahk_id " hwnd)
        return false
    class_name := WinGetClass("ahk_id " hwnd)
    if (class_name = "AutoHotkeyGUI")
        return false
    if Window.IsException("ahk_id " hwnd)
        return false
    ex_style := WinGetExStyle("ahk_id " hwnd)
    if ((ex_style & 0x80) && !(ex_style & 0x40000))
        return false

    state := WinGetMinMax("ahk_id " hwnd)
    if (state = -1)
        return false

    return true
}

ScrollingSeedFromOpenWindows() {
    global scrolling_active_workspace, scrolling_center_index

    list := ScrollingGetWorkspaceList(scrolling_active_workspace)
    list.Length := 0

    hwnds := WinGetList()
    for _, hwnd in hwnds {
        if ScrollingShouldManageWindow(hwnd)
            list.Push(hwnd)
    }

    active_hwnd := 0
    try active_hwnd := WinGetID("A")
    if active_hwnd {
        center_index := ScrollingIndexOf(list, active_hwnd)
        if (center_index > 0)
            scrolling_center_index[scrolling_active_workspace] := center_index
    }

    if (scrolling_center_index[scrolling_active_workspace] = 0 && list.Length > 0)
        scrolling_center_index[scrolling_active_workspace] := 1

    ScrollingReflow()
}

ScrollingEnsureWindowInWorkspace(hwnd) {
    global scrolling_active_workspace
    list := ScrollingGetWorkspaceList(scrolling_active_workspace)
    if (ScrollingIndexOf(list, hwnd) = 0)
        list.Push(hwnd)
}

ScrollingSwitchWorkspace(index) {
    global scrolling_active_workspace, scrolling_workspace_count
    global scrolling_dynamic_workspaces
    if (scrolling_dynamic_workspaces && index > scrolling_workspace_count)
        ScrollingEnsureWorkspace(index)
    if (index < 1 || index > scrolling_workspace_count)
        return
    if (index = scrolling_active_workspace)
        return

    ScrollingParkWorkspace(scrolling_active_workspace)
    scrolling_active_workspace := index
    ScrollingReflow()
}

ScrollingMoveWindowToWorkspace(index) {
    global scrolling_active_workspace, scrolling_workspace_count, scrolling_center_index
    global scrolling_dynamic_workspaces

    if (scrolling_dynamic_workspaces && index > scrolling_workspace_count)
        ScrollingEnsureWorkspace(index)
    if (index < 1 || index > scrolling_workspace_count)
        return

    hwnd := WinExist("A")
    if !hwnd
        return
    if !ScrollingShouldManageWindow(hwnd)
        return

    current_list := ScrollingGetWorkspaceList(scrolling_active_workspace)
    current_index := ScrollingIndexOf(current_list, hwnd)
    if (current_index > 0)
        current_list.RemoveAt(current_index)

    target_list := ScrollingGetWorkspaceList(index)
    if (ScrollingIndexOf(target_list, hwnd) = 0)
        target_list.Push(hwnd)

    if (index = scrolling_active_workspace) {
        scrolling_center_index[scrolling_active_workspace] := ScrollingIndexOf(target_list, hwnd)
        ScrollingReflow()
        return
    }

    ScrollingParkWindow(hwnd)
    if (current_list.Length = 0)
        scrolling_center_index[scrolling_active_workspace] := 0
    else if (scrolling_center_index[scrolling_active_workspace] > current_list.Length)
        scrolling_center_index[scrolling_active_workspace] := current_list.Length
    ScrollingReflow()
}

ScrollingParkWorkspace(index) {
    list := ScrollingGetWorkspaceList(index)
    for _, hwnd in list {
        if !WinExist("ahk_id " hwnd)
            continue
        ScrollingParkWindow(hwnd)
    }
}

ScrollingParkWindow(hwnd) {
    if !hwnd
        return

    area := ScrollingGetWorkArea()
    if (area["w"] <= 0 || area["h"] <= 0)
        return

    WinGetPosEx(&x, &y, &w, &h, "ahk_id " hwnd)
    if (w <= 0 || h <= 0)
        return

    target_x := area["x"] + area["w"] + 20000
    target_y := area["y"]
    WinMoveEx(target_x, target_y, w, h, "ahk_id " hwnd)
}

ScrollingSetCenter(hwnd) {
    global scrolling_active_workspace, scrolling_center_index
    list := ScrollingGetWorkspaceList(scrolling_active_workspace)
    index := ScrollingIndexOf(list, hwnd)
    if (index > 0)
        scrolling_center_index[scrolling_active_workspace] := index
}

ScrollingMove(direction) {
    global scrolling_active_workspace, scrolling_wrap_enabled, scrolling_center_index

    list := ScrollingGetWorkspaceList(scrolling_active_workspace)
    if (list.Length = 0)
        return

    current_index := scrolling_center_index[scrolling_active_workspace]
    if (current_index <= 0)
        current_index := 1

    next_index := current_index
    if (direction = "left")
        next_index := current_index - 1
    else if (direction = "right")
        next_index := current_index + 1

    if (next_index < 1)
        next_index := scrolling_wrap_enabled ? list.Length : 1
    if (next_index > list.Length)
        next_index := scrolling_wrap_enabled ? 1 : list.Length

    scrolling_center_index[scrolling_active_workspace] := next_index
    target_hwnd := list[next_index]
    if target_hwnd
        ActivateWindow(target_hwnd)

    ScrollingReflow()
}

ScrollingSwap(direction) {
    if !ScrollingModeActive()
        return

    global scrolling_active_workspace, scrolling_wrap_enabled, scrolling_center_index
    list := ScrollingGetWorkspaceList(scrolling_active_workspace)
    if (list.Length < 2)
        return

    center_index := scrolling_center_index[scrolling_active_workspace]
    if (center_index <= 0)
        center_index := 1

    offset := direction = "left" ? -1 : 1
    neighbor_index := ScrollingNeighborIndex(center_index, offset, list.Length, scrolling_wrap_enabled)
    if (neighbor_index = center_index)
        return

    temp := list[center_index]
    list[center_index] := list[neighbor_index]
    list[neighbor_index] := temp
    scrolling_center_index[scrolling_active_workspace] := neighbor_index

    ScrollingReflow()
}

ScrollingReflow() {
    global scrolling_active_workspace, scrolling_center_index, scrolling_workspaces
    global scrolling_dynamic_workspaces
    if ScrollingOverviewActive()
        return
    list := ScrollingGetWorkspaceList(scrolling_active_workspace)
    if (list.Length = 0)
        return

    list := ScrollingPruneList(list)
    scrolling_workspaces[scrolling_active_workspace] := list
    if (list.Length = 0)
        return

    center_index := scrolling_center_index[scrolling_active_workspace]
    if (center_index <= 0 || center_index > list.Length)
        center_index := 1
    scrolling_center_index[scrolling_active_workspace] := center_index

    center_hwnd := list[center_index]
    left_hwnd := 0
    right_hwnd := 0

    if (list.Length = 2) {
        other_index := (center_index = 1) ? 2 : 1
        left_hwnd := list[other_index]
    } else if (list.Length >= 3) {
        left_index := ScrollingNeighborIndex(center_index, -1, list.Length, scrolling_wrap_enabled)
        right_index := ScrollingNeighborIndex(center_index, 1, list.Length, scrolling_wrap_enabled)
        if (left_index != center_index)
            left_hwnd := list[left_index]
        if (right_index != center_index)
            right_hwnd := list[right_index]
    }

    layout := ScrollingComputeLayout()
    if layout = ""
        return

    ScrollingMoveToRect(center_hwnd, layout["center"])
    if left_hwnd
        ScrollingMoveToRect(left_hwnd, layout["left"])
    if right_hwnd
        ScrollingMoveToRect(right_hwnd, layout["right"])

    for i, hwnd in list {
        if (hwnd = center_hwnd || hwnd = left_hwnd || hwnd = right_hwnd)
            continue
        ScrollingMoveToRect(hwnd, layout["center"])
    }

    if scrolling_dynamic_workspaces
        ScrollingEnsureDynamicWorkspace()
}

ScrollingComputeLayout() {
    global scrolling_side_width_ratio, scrolling_center_width_ratio
    area := ScrollingGetWorkArea()
    if (area["w"] <= 0 || area["h"] <= 0)
        return ""

    gap_px := ScrollingResolveGapPx()
    side_w := Floor(area["w"] * scrolling_side_width_ratio)
    center_w := Floor(area["w"] * scrolling_center_width_ratio)
    total := side_w * 2 + center_w + gap_px * 2
    if (total > area["w"]) {
        center_w := area["w"] - (side_w * 2) - (gap_px * 2)
        if (center_w < 0)
            center_w := 0
    }

    left_rect := Map(
        "x", area["x"],
        "y", area["y"],
        "w", side_w,
        "h", area["h"]
    )
    center_rect := Map(
        "x", area["x"] + side_w + gap_px,
        "y", area["y"],
        "w", center_w,
        "h", area["h"]
    )
    right_rect := Map(
        "x", center_rect["x"] + center_w + gap_px,
        "y", area["y"],
        "w", side_w,
        "h", area["h"]
    )

    return Map("left", left_rect, "center", center_rect, "right", right_rect)
}

ScrollingMoveToRect(hwnd, rect) {
    if !hwnd
        return
    WinRestore "ahk_id " hwnd
    WinMoveEx(rect["x"], rect["y"], rect["w"], rect["h"], "ahk_id " hwnd)
    ScheduleFocusBorderUpdate()
}

ScrollingGetWorkArea() {
    MonitorGetWorkArea(MonitorGetPrimary(), &mx1, &my1, &mx2, &my2)
    mw := mx2 - mx1
    mh := my2 - my1

    left_margin := Screen.left_margin
    right_margin := Screen.right_margin
    gap_px := ScrollingResolveGapPx()

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

ScrollingResolveGapPx() {
    global Config, scrolling_gap_px
    if (scrolling_gap_px > 0)
        return scrolling_gap_px
    return Config["window_manager"]["gap_px"]
}

ScrollingNeighborIndex(center_index, direction, length, wrap) {
    next_index := center_index + direction
    if (next_index < 1)
        return wrap ? length : 1
    if (next_index > length)
        return wrap ? 1 : length
    return next_index
}

ScrollingIndexOf(list, hwnd) {
    for i, item in list {
        if (item = hwnd)
            return i
    }
    return 0
}

ScrollingGetWorkspaceList(index) {
    global scrolling_workspaces
    if !scrolling_workspaces.Has(index)
        scrolling_workspaces[index] := []
    return scrolling_workspaces[index]
}

ScrollingEnsureWorkspace(index) {
    global scrolling_workspace_count
    if (index <= scrolling_workspace_count)
        return
    loop index - scrolling_workspace_count {
        new_index := scrolling_workspace_count + A_Index
        ScrollingGetWorkspaceList(new_index)
    }
    scrolling_workspace_count := index
}

ScrollingEnsureDynamicWorkspace() {
    global scrolling_workspace_count, scrolling_active_workspace
    max_used := 0
    for index, list in scrolling_workspaces {
        if (list.Length > 0 && index > max_used)
            max_used := index
    }
    desired := Max(1, max_used + 1)
    if (scrolling_active_workspace > desired)
        desired := scrolling_active_workspace
    ScrollingEnsureWorkspace(desired)
}

ScrollingPruneList(list) {
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

ScrollingGetSnapshot() {
    global scrolling_active_workspace, scrolling_center_index
    list := ScrollingGetWorkspaceList(scrolling_active_workspace)
    if (list.Length = 0)
        return Map("list", [], "center_index", 0)

    list := ScrollingPruneList(list)
    if (list.Length = 0)
        return Map("list", [], "center_index", 0)

    center_index := scrolling_center_index[scrolling_active_workspace]
    if (center_index <= 0 || center_index > list.Length)
        center_index := 1

    return Map("list", list, "center_index", center_index)
}
