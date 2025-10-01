;========================================================================================================================
; INFO
;========================================================================================================================
; Minimize To Tray
;---
; Hotkey: Shift + RButton
; Behavior:
;   - Hides the window under the mouse (or the active window) and adds a tray icon for it.
;   - Left-clicking that tray icon restores the window and removes the icon.
;   - "Restore all" tray menu item brings back every hidden window.
;   - On script exit, all hidden windows are restored automatically.
;========================================================================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

#Include "WinAPI.ahk"
#Include "WindowApp.ahk"

;========================================================================================================================
; GLOBALS / STATE
;========================================================================================================================

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
OnMessage(gTaskbarMsg,  (*) => RefreshTrayIcons())
OnExit(ExitCleanup)

; Tray menu for convenience
A_TrayMenu.Delete()     ; Start clean
A_TrayMenu.Add("&Restore all windows", RestoreAll)
A_TrayMenu.Add()        ; Separator
A_TrayMenu.Add("E&xit", (*) => ExitApp())

;========================================================================================================================
; HOTKEY: Shift + Right Mouse Button
;========================================================================================================================

+RButton::{
    hwnd := WinAPI_HwndUnderMouse()
    if (!hwnd)
    {
        hwnd := WinExist("A") ; fallback to active window
    }

    ; Filter out non-user windows (desktop, tray, our sink, etc.)
    if (!WindowApp.IsRealWindow(hwnd) || hwnd = gSinkHwnd)
    {
        return
    }

    MinimizeToTray(hwnd)
    
    ; Swallow the click so it doesn't open a context menu
    return
}

;========================================================================================================================
; CORE: Minimize / Restore
;========================================================================================================================

MinimizeToTray(hwnd) {
    global gHiddenWins
    if gHiddenWins.Has(hwnd)
        return  ; already hidden

    title := WinGetTitle("ahk_id " hwnd)
    hIcon := WinAPI_GetWindowIcon(hwnd)
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

;========================================================================================================================
; Tray icon add/remove/readd
;========================================================================================================================

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

RefreshTrayIcons() {
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

;========================================================================================================================
; UTILITIES
;========================================================================================================================

ExitCleanup(*) {
    ; Restore all hidden windows and remove icons
    global gHiddenWins
    for hwnd, obj in gHiddenWins.Clone() {
        try WinShow("ahk_id " hwnd)
        RemoveTrayIcon(hwnd)
    }
}
