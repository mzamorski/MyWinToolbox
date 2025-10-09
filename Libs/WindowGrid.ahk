#Requires AutoHotkey v2.0
#SingleInstance Force

#^1::Win_Third(1)
#^2::Win_Third(2)
#^3::Win_Third(3)

Win_Third(n) {
    hwnd := WinExist("A")
    if (!hwnd)
    {
        return
    }

    Monitor_GetWorkAreaFromWindow(hwnd, &l, &t, &r, &b)

    w := (r - l) // 3
    x := l + (n - 1) * w

    ; Optional: ensure not maximized (some apps ignore move while maximized)
    try WinRestore("ahk_id " hwnd)

    WinMove(x, t, w, (b - t), "ahk_id " hwnd)
}

; Returns work area of the monitor on which the given window (hwnd) resides.
Monitor_GetWorkAreaFromWindow(hwnd, &left, &top, &right, &bottom) {
    idx := Monitor_GetIndexFromWindow(hwnd)
    
    ; Falls back to primary if detection failed
    if (!idx)
    {
        idx := MonitorGetPrimary()
    }

    MonitorGetWorkArea(idx, &left, &top, &right, &bottom)
}

; Finds monitor index whose rect contains the window center.
Monitor_GetIndexFromWindow(hwnd) {
    try {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
    } 
    catch {
        return MonitorGetPrimary()
    }

    cx := wx + ww // 2
    cy := wy + wh // 2

    count := MonitorGetCount()
    Loop count {
        i := A_Index
        
        MonitorGet(i, &l, &t, &r, &b)
        if (cx >= l && cx < r && cy >= t && cy < b)
        {
            return i
        }
    }

    return MonitorGetPrimary()
}
