#Requires AutoHotkey v2.0

#Include Constants.ahk
#Include Libs\StringUtils.ahk
#Include Libs\ClipboardUtils.ahk
#Include Libs\DateTimeUtils.ahk
#Include Libs\ConfigUtils.ahk
#Include Libs\WinAPI.ahk

global ConfigFilePath := A_ScriptName . ".config"

Menu_StringGenerator_RandomGuid(*)
{
	guid := ComObject("Scriptlet.TypeLib").GUID
    
	output := StrReplace(guid, "{", "")
    output := StrReplace(output, "}", "")

	Clipboard_Paste(output)
}

Menu_StringGenerator_RandomString_16(*)
{
	output:= StringUtils.Random(16)

	Clipboard_Paste(output)
}

Menu_StringGenerator_RandomString_32(*)
{
	output:= StringUtils.Random(32)

	Clipboard_Paste(output)
}

Menu_StringGenerator_CurrentDate(*)
{
	output := DateTimeUtils.GetCurrentDate()

	Clipboard_Paste(output)
}

Menu_StringGenerator_CurrentDateTime(*)
{
	output := DateTimeUtils.GetCurrentDate(true)

	Clipboard_Paste(output)
}

Menu_StringGenerator_Separator_120(*)
{
	output := StringUtils.Replicate("-", 120)

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
	stringGeneratorMenu.Add("&Random.String.16", Menu_StringGenerator_RandomString_16)
	stringGeneratorMenu.Add("&Random.String.32", Menu_StringGenerator_RandomString_32)
	stringGeneratorMenu.Add()
	stringGeneratorMenu.Add("&Date.Current", Menu_StringGenerator_CurrentDate)
	stringGeneratorMenu.Add("&DateTime.Current", Menu_StringGenerator_CurrentDateTime)
	stringGeneratorMenu.Add()
	stringGeneratorMenu.Add("&Separator.120", Menu_StringGenerator_Separator_120)
	
	stringGeneratorMenu.Show()
}

;========================================================================================================================
; HOT-STRINGS
;========================================================================================================================

Hotstring(":0*:@=", Config_GetEmail())

Config_GetEmail() 
{
	return IniReadOrDefault(ConfigFilePath, "Settings", "Email")
}

;========================================================================================================================
; HOT-KEYS
;========================================================================================================================
