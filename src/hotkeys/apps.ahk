global Config, super_key

HotIf (*) => GetKeyState(super_key, "P")
for _, app in Config["apps"] {
    hotkey_name := app["hotkey"]
    win_title := app["win_title"]
    run_cmd := app["run"]
    hotkey_id := app["id"]
    Hotkey(hotkey_name, FocusOrRun.Bind(win_title, run_cmd, hotkey_id, app))
}
HotIf
