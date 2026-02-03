global Config, super_key

if Config.Has("window_selector") && Config["window_selector"]["enabled"] {
    hotkey_name := Config["window_selector"]["hotkey"]
    Hotkey(super_key " & " hotkey_name, (*) => WindowWalker.Show())
}
