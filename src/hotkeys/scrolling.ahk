global Config

if Config.Has("modes") && Config["modes"]["active"] = "scrolling" {
    workspace_count := Integer(Config["modes"]["scrolling"]["workspace_count"])
    max_index := (workspace_count <= 0) ? 9 : Min(9, workspace_count)
    overview_config := Config["modes"]["scrolling"]["overview"]
    HotIf (*) => GetKeyState(super_key, "P")
    loop max_index {
        index := A_Index
        Hotkey("" index, (*) => ScrollingSwitchWorkspace(index))
        Hotkey("+" index, (*) => ScrollingMoveWindowToWorkspace(index))
    }
    if overview_config["enabled"]
        Hotkey(overview_config["hotkey"], (*) => ShowScrollingOverview())
    HotIf
}
