; CopyWindowInfo - copy active window details to clipboard

#Requires AutoHotkey v2.0

#!c:: {
    hwnd := WinExist("A")
    if !hwnd
        return

    ; Basic window props
    title := WinGetTitle("ahk_id " hwnd)
    cls   := WinGetClass("ahk_id " hwnd)
    pid   := WinGetPID("ahk_id " hwnd)
    exe   := ""
    try exe := WinGetProcessPath("ahk_id " hwnd)
    if !exe
        exe := WinGetProcessName("ahk_id " hwnd)

    ; Geometry
    WinGetPos &x, &y, &w, &h, "ahk_id " hwnd

    ; Monitor + DPI
    monIdx := GetMonitorIndexFromWindow(hwnd)
    dpi    := GetDpiForHwnd(hwnd)

    ; Optional resource (Explorer path)
    resource := GetExplorerPathForHwnd(hwnd)

    ; Build clipboard text (multi-line, human-friendly)
    info :=
    (
    "Title: "         title        "`n"
    "Class: "         cls          "`n"
    "PID: "           pid          "`n"
    "EXE: "           exe          "`n"
    "HWND: "          Format("0x{:X}", hwnd) "`n"
    "Position: "      x "," y      "`n"
    "Size: "          w "x" h      "`n"
    "Monitor Index: " monIdx       "`n"
    "DPI (window): "  dpi          "`n"
    "Resource: "      (resource ? resource : "(n/a)")
    )

    A_Clipboard := info

    ; Short confirmation
    ToolTip "Window info copied"
    SetTimer () => ToolTip(), -800
    return
}

; -------- Helpers --------

; Return 1-based monitor index containing the window center (fallback to primary).
GetMonitorIndexFromWindow(hwnd) {
    try WinGetPos &wx, &wy, &ww, &wh, "ahk_id " hwnd
    catch
        return MonitorGetPrimary()
    cx := wx + ww // 2, cy := wy + wh // 2

    count := MonitorGetCount()
    Loop count {
        i := A_Index
        MonitorGet i, &l, &t, &r, &b
        if (cx >= l && cx < r && cy >= t && cy < b)
            return i
    }
    return MonitorGetPrimary()
}

; Get DPI for a given window (Win10+). Fallback to 96 if API unavailable.
GetDpiForHwnd(hwnd) {
    try return DllCall("User32.dll\GetDpiForWindow", "ptr", hwnd, "uint")
    catch
        return 96
}

; If hwnd is an Explorer window, return current folder path (decoded). Else "".
; Get Explorer folder path for a given hwnd; returns "" if not an Explorer window.
GetExplorerPathForHwnd(hwnd) {
    try {
        shell := ComObject("Shell.Application")
        for w in shell.Windows {
            ; Some entries can be invalid or not expose hwnd/URL; guard with try
            wh := 0
            try {
                if !w
                    continue
                wh := w.hwnd
            } catch {
                continue
            }
            if (wh != hwnd)
                continue

            ; 1) Prefer LocationURL (file:///C:/...) -> decode to filesystem path
            url := ""
            try {
                url := w.LocationURL
            } catch {
                url := ""
            }
            if (url != "") {
                if (SubStr(url, 1, 8) = "file:///") {
                    path := UriDecode(SubStr(url, 9))    ; drop "file:///"
                    path := StrReplace(path, "/", "\")
                    return path
                }
            }

            ; 2) Fallback: Folder.Self.Path (may be empty for virtual locations)
            try {
                return w.Document.Folder.Self.Path
            } catch {
                return ""
            }
        }
    } catch {
        ; COM not available or other failure
    }
    return ""
}

; Percent-decode (e.g., "%20" -> space) for ASCII bytes.
UriDecode(s) {
    return RegExReplace(s, "%([0-9A-Fa-f]{2})", (m) => Chr("0x" m[1]))
}
