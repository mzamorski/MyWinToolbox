#Requires AutoHotkey v2.0

DetectHiddenWindows(true)
SetTitleMatchMode(2)

class WindowApp 
{
    static KnownBrowsers := ["chrome.exe", "firefox.exe", "msedge.exe", "brave.exe"]

    static IsActive(exeName)
    {
        if !RegExMatch(exeName, "\.exe$")
        {
            exeName .= ".exe"
        }
    
        return WinActive("ahk_exe " exeName)
    }

    static IsKeepassActive() 
    {
        return WindowApp.IsActive("KeePass.exe")
    }

    static IsBrowserActive() 
    {
        for exe in WindowApp.KnownBrowsers 
        {
            if WindowApp.IsActive(exe)
            {
                return true
            }
        }

        return false
    }
    
    static IsRealWindow(hwnd) {
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
}