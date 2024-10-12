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
	formatMenu.Add("Char.Replicate.80", Clipboard_Replicate_80)
	formatMenu.Add("Char.Replicate.120", Clipboard_Replicate_120)
	formatMenu.Add("Path.ToSingleBackslash", Clipboard_ToSingleBackslash)
	formatMenu.Add("Path.ToDoubleBackslash", Clipboard_ToDoubleBackslash)
	
    formatMenu.Show()
}