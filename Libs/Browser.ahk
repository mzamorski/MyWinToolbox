#Requires AutoHotkey v2.0

Browser_GetURL()
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