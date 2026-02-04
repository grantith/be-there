#Requires AutoHotkey v2.0

ShowWindowInspector() {
    static inspector_gui := ""
    static window_list := ""

    if inspector_gui {
        inspector_gui.Show()
        RefreshList(window_list)
        return
    }

    inspector_gui := Gui("+Resize", "harken Window Inspector")
    inspector_gui.SetFont("s10", "Segoe UI")

    window_list := inspector_gui.AddListView("w980 r26 Grid", ["Title", "Exe", "Class", "PID", "HWND"])
    window_list.ModifyCol(1, 400)
    window_list.ModifyCol(2, 140)
    window_list.ModifyCol(3, 200)
    window_list.ModifyCol(4, 80)
    window_list.ModifyCol(5, 120)

    refresh_btn := inspector_gui.AddButton("xm y+10 w110", "Refresh")
    refresh_btn.OnEvent("Click", (*) => RefreshList(window_list))

    copy_selected_btn := inspector_gui.AddButton("x+10 yp w140", "Copy Selected")
    copy_selected_btn.OnEvent("Click", (*) => CopySelected(window_list))

    copy_all_btn := inspector_gui.AddButton("x+10 yp w120", "Copy All")
    copy_all_btn.OnEvent("Click", (*) => CopyAll(window_list))

    export_btn := inspector_gui.AddButton("x+10 yp w140", "Export File")
    export_btn.OnEvent("Click", (*) => ExportAll(window_list))

    inspector_gui.OnEvent("Close", (*) => inspector_gui.Hide())
    inspector_gui.Show()

    RefreshList(window_list)
}

RefreshList(window_list) {
    window_list.Delete()

    for _, hwnd in WinGetList() {
        title := WinGetTitle("ahk_id " hwnd)
        exe := WinGetProcessName("ahk_id " hwnd)
        class_name := WinGetClass("ahk_id " hwnd)
        pid := WinGetPID("ahk_id " hwnd)
        window_list.Add("", title, exe, class_name, pid, Format("0x{:X}", hwnd))
    }
}

CopySelected(window_list) {
    rows := []
    row := 0
    while row := window_list.GetNext(row) {
        rows.Push(GetRowValues(window_list, row))
    }
    if rows.Length = 0
        return
    A_Clipboard := BuildOutput(rows)
}

CopyAll(window_list) {
    rows := []
    loop window_list.GetCount() {
        rows.Push(GetRowValues(window_list, A_Index))
    }
    if rows.Length = 0
        return
    A_Clipboard := BuildOutput(rows)
}

ExportAll(window_list) {
    rows := []
    loop window_list.GetCount() {
        rows.Push(GetRowValues(window_list, A_Index))
    }
    if rows.Length = 0
        return

    default_path := A_Desktop "\\window-list.txt"
    save_path := FileSelect("S", default_path, "Export Window List", "Text (*.txt)")
    if !save_path
        return

    FileDelete(save_path)
    FileAppend(BuildOutput(rows), save_path)
}

GetRowValues(window_list, row) {
    return [
        window_list.GetText(row, 1),
        window_list.GetText(row, 2),
        window_list.GetText(row, 3),
        window_list.GetText(row, 4),
        window_list.GetText(row, 5)
    ]
}

BuildOutput(rows) {
    output := "Title\tExe\tClass\tPID\tHWND`n"
    for _, row in rows {
        output .= row[1] "\t" row[2] "\t" row[3] "\t" row[4] "\t" row[5] "`n"
    }
    return output
}
