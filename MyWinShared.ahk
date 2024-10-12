#Requires AutoHotkey v2.0
#Warn All, Off

#Include Libs\StringUtils.ahk
#Include Libs\ClipboardUtils.ahk


#^f::
{
    formatMenu := Menu()
    formatMenu.Add("To&Upper", Clipboard_ToUpper)
	formatMenu.Add("To&Lower", Clipboard_ToLower)
	formatMenu.Add("To&Quoted.Single", Clipboard_ToSingleQuoted)
	
    formatMenu.Show()
}