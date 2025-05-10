#Requires AutoHotkey v2.0

#Include WindowApp.ahk

class Browser
{
    static GetURL()
    {
        handle := WinActive("A")
        WinActivate(handle)

        A_Clipboard := ""
        Send("^l")
        Send("^c")
        Send("{Esc}")

        if !ClipWait(0.5)
        {
            return ""
        }

        return A_Clipboard
    }

    static IsActive() 
    {
        for exe in WindowApp.KnownBrowsers 
        {
            if WinExist("ahk_exe " exe)
            {
                return true
            }
        }

        return false
    }
}
