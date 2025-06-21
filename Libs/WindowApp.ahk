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
}