global Config

if Config.Has("directional_focus") && Config["directional_focus"]["enabled"] {
    Hotkey("!h", (*) => DirectionalFocus("left"))
    Hotkey("!l", (*) => DirectionalFocus("right"))
    Hotkey("!j", (*) => DirectionalFocus("down"))
    Hotkey("!k", (*) => DirectionalFocus("up"))
    Hotkey("!+h", (*) => ScrollingSwap("left"))
    Hotkey("!+l", (*) => ScrollingSwap("right"))
    Hotkey("![", (*) => DirectionalFocusStacked("prev"))
    Hotkey("!]", (*) => DirectionalFocusStacked("next"))
    Hotkey("!+d", (*) => ToggleDirectionalFocusDebug())
    Hotkey("!+s", (*) => SetLastStackedFromActive())
}
