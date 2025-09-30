; ===== Minimize To Tray" =====
; Hotkey: Shift + RButton
; Behavior:
;   - Hides the window under the mouse (or the active window) and adds a tray icon for it.
;   - Left-clicking that tray icon restores the window and removes the icon.
;   - "Restore all" tray menu item brings back every hidden window.
;   - On script exit, all hidden windows are restored automatically.

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; -------------------------------
; Globals / State
; -------------------------------
global gTrayGui       := Gui(, "TrayMsgSink")   ; Hidden sink window to receive tray callbacks
global gSinkHwnd      := gTrayGui.Hwnd
global gWM_TRAYMSG    := 0x8000 + 1             ; Custom callback message for Shell_NotifyIcon
global gHiddenWins    := Map()                  ; hwnd -> { title, hIcon, added: true }
global gTaskbarMsg    := DllCall("RegisterWindowMessage", "str","TaskbarCreated", "uint") ; Explorer restart

; Prepare hidden sink GUI (no taskbar item)
gTrayGui.Opt("+ToolWindow -Caption +E0x08000000")  ; WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE
gTrayGui.Show("Hide")

; Message handlers
OnMessage(gWM_TRAYMSG,  TrayIconCallback)
OnMessage(gTaskbarMsg,  (*) => ReaddAllIcons())
OnExit(ExitCleanup)

; Tray menu for convenience
A_TrayMenu.Delete()  ; start clean
A_TrayMenu.Add("&Restore all windows", RestoreAll)
A_TrayMenu.Add() ; separator
A_TrayMenu.Add("E&xit", (*) => ExitApp())

; -------------------------------
; Hotkey: Shift + Right Mouse Button
; -------------------------------
+RButton::{
    hwnd := HwndUnderMouse()
    if !hwnd
        hwnd := WinExist("A") ; fallback to active window

    ; Filter out non-user windows (desktop, tray, our sink, etc.)
    if !IsRealWindow(hwnd) || hwnd = gSinkHwnd
        return

    MinimizeToTray(hwnd)
    ; Swallow the click so it doesn't open a context menu
    return
}

; -------------------------------
; Core: Minimize / Restore
; -------------------------------
MinimizeToTray(hwnd) {
    global gHiddenWins
    if gHiddenWins.Has(hwnd)
        return  ; already hidden

    title := WinGetTitle("ahk_id " hwnd)
    hIcon := GetWindowIcon(hwnd)
    if !hIcon
        hIcon := DllCall("LoadIcon", "ptr",0, "ptr",0x7F00, "ptr") ; IDI_APPLICATION

    if AddTrayIcon(hwnd, hIcon, title) {
        WinHide("ahk_id " hwnd)
        gHiddenWins[hwnd] := { title: title, hIcon: hIcon, added: true }
    }
}

RestoreFromTray(hwnd) {
    global gHiddenWins
    if !gHiddenWins.Has(hwnd)
        return
    try {
        WinShow("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
    }
    RemoveTrayIcon(hwnd)
    gHiddenWins.Delete(hwnd)
}

RestoreAll(*) {
    global gHiddenWins
    for hwnd, obj in gHiddenWins.Clone() {
        RestoreFromTray(hwnd)
    }
}

; -------------------------------
; Tray icon add/remove/readd
; -------------------------------
AddTrayIcon(hwnd, hIcon, tipText) {
    global gSinkHwnd, gWM_TRAYMSG
    NIF_MESSAGE := 0x1, NIF_ICON := 0x2, NIF_TIP := 0x4
    NIM_ADD    := 0x0

    ; Allocate NOTIFYICONDATAW (V5) buffer; 976 bytes (x64) / 952 bytes (x86)
    nid := Buffer(A_PtrSize=8 ? 976 : 952, 0)
    NumPut("UInt", nid.Size, nid, 0)                                 ; cbSize
    NumPut("Ptr",  gSinkHwnd, nid,  A_PtrSize=8 ? 8 : 4)             ; hWnd
    NumPut("UInt", hwnd,      nid, (A_PtrSize=8 ? 16 : 8))           ; uID (we use hwnd for uniqueness)
    NumPut("UInt", NIF_MESSAGE|NIF_ICON|NIF_TIP, nid, (A_PtrSize=8 ? 20 : 12)) ; uFlags
    NumPut("UInt", gWM_TRAYMSG, nid, (A_PtrSize=8 ? 24 : 16))        ; uCallbackMessage
    NumPut("Ptr",  hIcon, nid,  (A_PtrSize=8 ? 32 : 28))             ; hIcon

    ; Tooltip (UTF-16) - 128 WCHARs
    tipOffset := (A_PtrSize=8 ? 40 : 32)
    StrPut(Trim(StrReplace(tipText, "`n", " ")), nid.Ptr + tipOffset, 128, "UTF-16")

    ok := DllCall("Shell32\Shell_NotifyIconW", "UInt",NIM_ADD, "Ptr",nid, "Int")
    return ok
}

RemoveTrayIcon(hwnd) {
    global gSinkHwnd
    NIM_DELETE := 0x2

    nid := Buffer(A_PtrSize=8 ? 976 : 952, 0)
    NumPut("UInt", nid.Size, nid, 0)
    NumPut("Ptr",  gSinkHwnd, nid,  A_PtrSize=8 ? 8 : 4)
    NumPut("UInt", hwnd,      nid, (A_PtrSize=8 ? 16 : 8))

    DllCall("Shell32\Shell_NotifyIconW", "UInt",NIM_DELETE, "Ptr",nid)
}

ReaddAllIcons() {
    global gHiddenWins
    for hwnd, obj in gHiddenWins {
        if WinExist("ahk_id " hwnd) {
            AddTrayIcon(hwnd, obj.hIcon, obj.title)
        }
    }
}

; -------------------------------
; Tray icon callback handler
; -------------------------------
TrayIconCallback(wParam, lParam, msg, hwnd) {
    ; wParam = uID (we used the original window hwnd)
    ; lParam = mouse event (WM_* codes)
    static WM_LBUTTONUP := 0x202, WM_LBUTTONDBLCLK := 0x203
    if (lParam = WM_LBUTTONUP || lParam = WM_LBUTTONDBLCLK) {
        RestoreFromTray(wParam)
    }
}

; -------------------------------
; Utilities
; -------------------------------
HwndUnderMouse() {
    ; Get the window under the mouse.
    ; MouseGetPos (v2): 3rd output = window HWND, 4th = control under cursor.
    MouseGetPos &mx, &my, &hWin, &hCtrl

    ; Coerce to numeric (if we accidentally get a class/control name, this becomes 0)
    hw := hWin + 0
    if !hw
        return 0

    ; Return the top-level ancestor (GA_ROOT = 2)
    return DllCall("GetAncestor", "ptr", hw, "uint", 2, "ptr")
}

IsRealWindow(hwnd) {
    ; Validate handle & existence
    if !hwnd
        return false
    if !WinExist("ahk_id " hwnd)
        return false

    ; Exclude shell/desktop/system windows
    cls := WinGetClass("ahk_id " hwnd)
    if (cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd" || cls = "Progman"
     || cls = "WorkerW" || cls = "NotifyIconOverflowWindow")
        return false

    ; Must be top-level (GA_ROOT)
    if (DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr") != hwnd)
        return false

    ; Style checks
    style := WinGetStyle("ahk_id " hwnd)
    ex    := WinGetExStyle("ahk_id " hwnd)
    if !(style & 0x10000000) ; WS_VISIBLE
        return false
    if  (ex & 0x00000080)    ; WS_EX_TOOLWINDOW
        return false

    return true
}

GetWindowIcon(hwnd) {
    ; Try WM_GETICON small2, small, big; then class icons
    WM_GETICON := 0x7F
    ICON_SMALL2 := 2, ICON_SMALL := 0, ICON_BIG := 1

    for iconType in [ICON_SMALL2, ICON_SMALL, ICON_BIG] {
        hIcon := SendMessage(WM_GETICON, iconType, 0, , "ahk_id " hwnd)
        if hIcon
            return hIcon
    }
    ; Class small icon
    GCLP_HICONSM := -34
    hIcon := DllCall("GetClassLongPtr", "ptr",hwnd, "int",GCLP_HICONSM, "ptr")
    if hIcon
        return hIcon
    ; Class big icon
    GCLP_HICON := -14
    return DllCall("GetClassLongPtr", "ptr",hwnd, "int",GCLP_HICON, "ptr")
}

ExitCleanup(*) {
    ; Restore all hidden windows and remove icons
    global gHiddenWins
    for hwnd, obj in gHiddenWins.Clone() {
        try WinShow("ahk_id " hwnd)
        RemoveTrayIcon(hwnd)
    }
}
