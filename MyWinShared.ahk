#Requires AutoHotkey v2.0
#Warn All, Off

#Include Libs\StringUtils.ahk

Clipboard_Copy() 
{
    A_Clipboard := ""
    Send("^c")
    ClipWait()

    return A_Clipboard
}

Clipboard_Paste(value)
{
	A_Clipboard := value
	
	Send("^v")
}

Clipboard_ToUpper(*) 
{
	input:= Clipboard_Copy()
	output := StrUpper(input )

	Clipboard_Paste(output)
}

Clipboard_ToLower(*) 
{
	input:= Clipboard_Copy()
	output := StrLower(input )

	Clipboard_Paste(output)
}

#^f::
{
    formatMenu := Menu()
    formatMenu.Add("To&Upper", Clipboard_ToUpper)
	formatMenu.Add("To&Lower", Clipboard_ToLower)
	
    formatMenu.Show()
}