#Requires AutoHotkey v2.0

#Include Constants.ahk
#Include Libs\StringUtils.ahk
#Include Libs\ClipboardUtils.ahk
#Include Libs\CryptoUtils.ahk
#Include Libs\DateTimeUtils.ahk
#Include Libs\ConfigUtils.ahk
#Include Libs\WinAPI.ahk

SendMode("Input")
SetTitleMatchMode("2")
DetectHiddenWindows(true)
Persistent

;========================================================================================================================
; STARTUP
;========================================================================================================================

if (A_ScriptName = "MyWinShared.ahk")
{
    MsgBox("This script cannot be run directly."
        ,"Execution Blocked", "Iconx"
    )
    ExitApp(-1)
}

global ConfigFilePath := A_ScriptName . CONFIG_FILE_EXTENSION
global Secret := Ini_ReadOrDefault(ConfigFilePath, "Settings", "Secret")

;========================================================================================================================

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

Menu_Format_Encrypt_RC4(*)
{
	input:= Clipboard_Copy()
	output := CryptoUtils.Encrypt(input, Secret)

	Clipboard_Paste(output)
}

Menu_Format_Decrypt_RC4(*)
{
	input:= Clipboard_Copy()
	output := CryptoUtils.Decrypt(input, Secret)

	Clipboard_Paste(output)
}

Menu_Format_Encrypt_BASE64(*)
{
	input:= Clipboard_Copy()
	output := CryptoUtils.EncryptBase64(input)

	Clipboard_Paste(output)
}

Menu_Format_Decrypt_BASE64(*)
{
	input:= Clipboard_Copy()
	output := CryptoUtils.DecryptBase64(input)

	Clipboard_Paste(output)
}

;--------------------------------------------------------------------------------
; Create menus. 
;--------------------------------------------------------------------------------

formatMenu := Menu()
formatMenu.SetColor("cbe7b6", true)
formatMenu.Add("To&Upper", Clipboard_ToUpper)
formatMenu.Add("To&Lower", Clipboard_ToLower)
formatMenu.Add("To&Quoted.Single", Clipboard_ToSingleQuoted)
formatMenu.Add("To&Quoted.Double", Clipboard_ToDoubleQuoted)

subMenu := Menu()
subMenu.Add("80", Clipboard_BreakLines_80)
subMenu.Add("120", Clipboard_BreakLines_120)
formatMenu.Add("&BreakLines", subMenu)

formatMenu.Add()

subMenu := Menu()
subMenu.Add("80", Clipboard_Replicate_80)
subMenu.Add("120", Clipboard_Replicate_120)
formatMenu.Add("Char.Replicate", subMenu)

formatMenu.Add()

formatMenu.Add("Path.ToSingleBackslash", Clipboard_ToSingleBackslash)
formatMenu.Add("Path.ToDoubleBackslash", Clipboard_ToDoubleBackslash)

formatMenu.Add()

formatMenu.Add("SQL.AddBraket", Clipboard_AddBraket)
formatMenu.Add("SQL.RemoveBraket", Clipboard_RemoveBraket)

formatMenu.Add()

formatMenu.Add("&Number.AddThousandsSeparators", Clipboard_AddThousandsSeparators)

formatMenu.Add()

formatMenu.Add("&Encrypt.RC4", Menu_Format_Encrypt_RC4)
formatMenu.Add("&Decrypt.RC4", Menu_Format_Decrypt_RC4)
formatMenu.Add("&Encrypt.BASE64", Menu_Format_Encrypt_BASE64)
formatMenu.Add("&Decrypt.BASE64", Menu_Format_Decrypt_BASE64)

;--------------------------------------------------------------------------------

stringGeneratorMenu := Menu()
stringGeneratorMenu.SetColor("cee1f8", true)
stringGeneratorMenu.Add("&Random.Guid", Menu_StringGenerator_RandomGuid)

subMenu := Menu()
subMenu.Add("16", Menu_StringGenerator_RandomString_16)
subMenu.Add("32", Menu_StringGenerator_RandomString_32)
stringGeneratorMenu.Add("&Random.String", subMenu)

stringGeneratorMenu.Add()

stringGeneratorMenu.Add("&Date.Current", Menu_StringGenerator_CurrentDate)
stringGeneratorMenu.Add("&DateTime.Current", Menu_StringGenerator_CurrentDateTime)
stringGeneratorMenu.Add()

subMenu := Menu()
subMenu.Add("120", Menu_StringGenerator_Separator_120)

stringGeneratorMenu.Add("&Separator", subMenu)

;========================================================================================================================
; HOTKEYS
;========================================================================================================================

#^f::
{
    formatMenu.Show()
}

#^i::
{
	stringGeneratorMenu.Show()
}

;========================================================================================================================
; HOTSTRINGS
;========================================================================================================================

Hotstring(":0*:@=", Config_GetEmail())

Config_GetEmail() 
{
	return Ini_ReadOrDefault(ConfigFilePath, "Settings", "Email")
}

;========================================================================================================================
; HOTKEYS
;========================================================================================================================
