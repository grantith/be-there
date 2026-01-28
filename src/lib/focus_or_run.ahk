; Helper: focus existing window, otherwise run app.
; If the target window is already active, toggle back to the previous window
; recorded for this hotkey.
FocusOrRun(winTitle, exePath, hotkey_id, app_config := "", *) {
    static last_window := Map()
    target_hwnd := 0
    hwnds := WinGetList(winTitle)
    current_hwnd := WinGetID("A")

    if (hwnds.Length) {
        for hwnd in hwnds {
            if (InStr(winTitle, "explorer.exe")) {
                class_name := WinGetClass("ahk_id " hwnd)
                if (class_name = "Progman" || class_name = "WorkerW" || class_name = "Shell_TrayWnd")
                    continue
            }
            ex_style := WinGetExStyle("ahk_id " hwnd)
            if (ex_style & 0x80) || (ex_style & 0x8000000)
                continue
            if (!(WinGetStyle("ahk_id " hwnd) & 0x10000000))
                continue

            state := WinGetMinMax("ahk_id " hwnd)
            if (state = -1) {
                if (!target_hwnd)
                    target_hwnd := hwnd
                continue
            }
            target_hwnd := hwnd
            break
        }
        if (!target_hwnd)
            target_hwnd := hwnds[1]
    }

    if target_hwnd {
        if (current_hwnd = target_hwnd) {
            if last_window.Has(hotkey_id) && WinExist("ahk_id " last_window[hotkey_id]) {
                WinActivate "ahk_id " last_window[hotkey_id]
            }
            return
        }
        if current_hwnd && (current_hwnd != target_hwnd) {
            last_window[hotkey_id] := current_hwnd
        }
        WinActivate "ahk_id " target_hwnd
    } else {
        RunResolved(exePath, app_config)
    }
}

RunResolved(command, app_config := "") {
    resolved := ResolveRunPath(command, app_config)
    try {
        Run resolved
    } catch as err {
        MsgBox(
            "Failed to launch: " command "`n" err.Message "`n`n" .
            "Tip: set apps[].run to a full path or an App Paths-registered exe.",
            "be-there",
            "Iconx"
        )
    }
}

ResolveRunPath(command, app_config := "") {
    command := Trim(command, " `t")
    if (SubStr(command, 1, 1) = '"' && SubStr(command, -1) = '"')
        command := SubStr(command, 2, -1)
    if (InStr(command, "\\") || InStr(command, "/") || InStr(command, ":")) {
        if FileExist(command)
            return command
        return command
    }

    candidates := [command, command ".exe"]
    reg_roots := [
        "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\",
        "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\"
    ]

    for _, name in candidates {
        for _, root in reg_roots {
            try {
                path := RegRead(root name)
                if path
                    return path
            }
        }
    }

    shortcut_target := FindStartMenuShortcut(command)
    if shortcut_target
        return shortcut_target

    exe_name := command
    if !InStr(StrLower(exe_name), ".exe")
        exe_name := exe_name ".exe"

    extra_paths := []
    if (app_config is Map && app_config.Has("run_paths") && app_config["run_paths"] is Array) {
        for _, path in app_config["run_paths"]
            extra_paths.Push(path)
    }

    for _, path in extra_paths {
        path := ExpandEnvVars(path)
        candidate := path "\\" exe_name
        if FileExist(candidate)
            return candidate
    }

    alias_target := FindWindowsAppsAlias(exe_name)
    if alias_target
        return alias_target

    uninstall_target := FindUninstallEntry(command)
    if uninstall_target
        return uninstall_target

    common_target := FindExeInCommonLocations(exe_name)
    if common_target
        return common_target

    for _, base in GetCommonRunPaths() {
        candidate := base "\\" exe_name
        if FileExist(candidate)
            return candidate
    }

    return command
}

GetCommonRunPaths() {
    paths := []
    user_profile := EnvGet("USERPROFILE")
    app_data := EnvGet("APPDATA")
    local_app_data := EnvGet("LOCALAPPDATA")
    program_files := EnvGet("ProgramFiles")
    program_files_x86 := EnvGet("ProgramFiles(x86)")

    if app_data
        paths.Push(app_data)
    if local_app_data
        paths.Push(local_app_data)
    if program_files
        paths.Push(program_files)
    if program_files_x86
        paths.Push(program_files_x86)
    if user_profile
        paths.Push(user_profile)

    return paths
}

ExpandEnvVars(path) {
    if !path
        return ""

    expanded := path
    if InStr(expanded, "%") {
        loop {
            start := InStr(expanded, "%")
            if !start
                break
            end := InStr(expanded, "%",, start + 1)
            if !end
                break
            var_name := SubStr(expanded, start + 1, end - start - 1)
            var_value := EnvGet(var_name)
            expanded := SubStr(expanded, 1, start - 1) var_value SubStr(expanded, end + 1)
        }
    }

    if (SubStr(expanded, 1, 2) = "~\\") {
        user_profile := EnvGet("USERPROFILE")
        if user_profile
            expanded := user_profile SubStr(expanded, 2)
    }

    return expanded
}

FindStartMenuShortcut(command) {
    name := StrLower(command)
    if InStr(name, ".exe")
        name := SubStr(name, 1, StrLen(name) - 4)

    folders := [A_StartMenu, A_StartMenuCommon]
    for _, base in folders {
        path := base "\\Programs"
        if !DirExist(path)
            continue
        loop files, path "\\*.lnk", "R" {
            SplitPath(A_LoopFileName, &file_name)
            file_name := StrLower(file_name)
            if !(InStr(file_name, name)) {
                target := ResolveShortcutTarget(A_LoopFilePath)
                if !target
                    continue
                if InStr(StrLower(target), name)
                    return target
                continue
            }
            target := ResolveShortcutTarget(A_LoopFilePath)
            if target
                return target
        }
    }
    return ""
}

ResolveShortcutTarget(link_path) {
    if !FileExist(link_path)
        return ""
    try {
        shell := ComObject("WScript.Shell")
        shortcut := shell.CreateShortcut(link_path)
        target := shortcut.TargetPath
        if target && FileExist(target)
            return target
    }
    return ""
}

FindWindowsAppsAlias(exe_name) {
    apps_path := EnvGet("LOCALAPPDATA") "\\Microsoft\\WindowsApps"
    if !DirExist(apps_path)
        return ""
    alias_path := apps_path "\\" exe_name
    if FileExist(alias_path)
        return alias_path
    return ""
}

FindUninstallEntry(command) {
    name := StrLower(command)
    if InStr(name, ".exe")
        name := SubStr(name, 1, StrLen(name) - 4)

    roots := [
        "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        "HKEY_LOCAL_MACHINE\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
    ]

    for _, root in roots {
        loop reg, root, "K" {
            subkey_path := A_LoopRegKey "\\" A_LoopRegName
            try display_name := RegRead(subkey_path, "DisplayName")
            if !display_name
                continue
            if !InStr(StrLower(display_name), name)
                continue

            try install_loc := RegRead(subkey_path, "InstallLocation")
            if install_loc {
                exe_path := FindExeInDirectory(install_loc, name ".exe")
                if exe_path
                    return exe_path
            }

            try display_icon := RegRead(subkey_path, "DisplayIcon")
            if display_icon {
                icon_path := Trim(display_icon, " `t")
                if (SubStr(icon_path, 1, 1) = '"' && SubStr(icon_path, -1) = '"')
                    icon_path := SubStr(icon_path, 2, -1)
                if FileExist(icon_path)
                    return icon_path
            }
        }
    }
    return ""
}

FindExeInCommonLocations(exe_name) {
    for _, base in GetCommonRunPaths() {
        candidate := FindExeInDirectory(base, exe_name)
        if candidate
            return candidate
        candidate := FindExeInDirectory(base "\\Programs", exe_name)
        if candidate
            return candidate
    }
    return ""
}

FindExeInDirectory(base, exe_name) {
    if !DirExist(base)
        return ""
    loop files, base "\\*\\" exe_name, "R" {
        return A_LoopFilePath
    }
    return ""
}
