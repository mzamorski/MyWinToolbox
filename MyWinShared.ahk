#Requires AutoHotkey v2.0

#Include Constants.ahk
#Include Libs\StringUtils.ahk
#Include Libs\ClipboardUtils.ahk
#Include Libs\DateTimeUtils.ahk

global ConfigFilePath := A_ScriptName . ".config"

Menu_StringGenerator_RandomGuid(*)
{
	guid := ComObject("Scriptlet.TypeLib").GUID
    
	output := StrReplace(guid, "{", "")
    output := StrReplace(output, "}", "")

	Clipboard_Paste(output)
}

Menu_StringGenerator_CurrentDate(*)
{
	output := DateTimeUtils.GetCurrentDate()

	Clipboard_Paste(output)
}

;========================================================================================================================
; CONTEXT-MENUS
;========================================================================================================================

#^f::
{
    formatMenu := Menu()
    formatMenu.Add("To&Upper", Clipboard_ToUpper)
	formatMenu.Add("To&Lower", Clipboard_ToLower)
	formatMenu.Add("To&Quoted.Single", Clipboard_ToSingleQuoted)
	formatMenu.Add("&BreakLines.80", Clipboard_BreakLines_80)
	formatMenu.Add("&BreakLines.120", Clipboard_BreakLines_120)
	formatMenu.Add()
	formatMenu.Add("Char.Replicate.80", Clipboard_Replicate_80)
	formatMenu.Add("Char.Replicate.120", Clipboard_Replicate_120)
	formatMenu.Add()
	formatMenu.Add("Path.ToSingleBackslash", Clipboard_ToSingleBackslash)
	formatMenu.Add("Path.ToDoubleBackslash", Clipboard_ToDoubleBackslash)
	formatMenu.Add()
	formatMenu.Add("SQL.AddBraket", Clipboard_AddBraket)
	formatMenu.Add("SQL.RemoveBraket", Clipboard_RemoveBraket)
	formatMenu.Add()
	formatMenu.Add("&Number.AddThousandsSeparators", Clipboard_AddThousandsSeparators)
	
    formatMenu.Show()
}

#^i::
{
	stringGeneratorMenu := Menu()
    stringGeneratorMenu.Add("&Random.Guid", Menu_StringGenerator_RandomGuid)
	stringGeneratorMenu.Add("&Date.Current", Menu_StringGenerator_CurrentDate)

	stringGeneratorMenu.Show()
}

;========================================================================================================================
; HOT-STRINGS
;========================================================================================================================

Hotstring(":0*:@=", Config_GetEmail())

Config_GetEmail() 
{
	return IniRead(ConfigFilePath, "Settings", "Email", UNKNOWN)
}

;========================================================================================================================
; HOT-KEYS
;========================================================================================================================
