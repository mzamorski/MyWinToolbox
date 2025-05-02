#Requires AutoHotkey v2.0

Browser_GetURL()
{
    handle := WinActive("A")
    WinActivate(handle)

    A_Clipboard := ""
    Send("^l")
    Sleep(100)
    Send("^c")
    Sleep(100)

    if !ClipWait(0.5)
    {
        return ""
    }

    return A_Clipboard
}