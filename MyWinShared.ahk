#Requires AutoHotkey v2.0

#Include Libs\Constants.ahk
#Include Libs\StringUtils.ahk
#Include Libs\ClipboardUtils.ahk
#Include Libs\CryptoUtils.ahk
#Include Libs\DateTimeUtils.ahk
#Include Libs\ConfigUtils.ahk
#Include Libs\WinAPI.ahk
#Include Libs\MenuUtils.ahk

SendMode("Input")
SetTitleMatchMode("2")
DetectHiddenWindows(true)
Persistent



;========================================================================================================================
; STARTUP
;========================================================================================================================

global CurrentScriptName := "MyWinShared.ahk"
global MainScriptName := A_ScriptName

if (MainScriptName = CurrentScriptName)
{
    MsgBox("This script cannot be run directly."
        ,"Execution Blocked", "Iconx"
    )
    ExitApp(-1)
}

global ConfigFilePath := MainScriptName . CONFIG_FILE_EXTENSION
global SharedConfigFilePath := CurrentScriptName . CONFIG_FILE_EXTENSION

try
{
	global Secret := Ini_ReadOrDefault(ConfigFilePath, "Settings", "Secret")
	global UserSignatures := Ini_GetSectionEntries(ConfigFilePath, "UserSignatures")
	global TextSnippets := Ini_GetSectionEntries(SharedConfigFilePath, "TextSnippets")
	global DummyText := Ini_ReadOrDefault(SharedConfigFilePath, "Content", "DummyText")
}
catch Error as e
{
	MsgBox(e.Message . "`nLine: " . e.Line . " / " . e.What
		,"Config error")
	Exit
}


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

Menu_StringGenerator_Dummy(*)
{
	Std_Paste(DummyText)
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

Menu_StringGenerator_CurrentDateTime_ISO8601(*)
{
	output := DateTimeUtils.GetCurrentISO8601Date()

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

Menu_Format_Clipboard_ToLower(*)
{
	input:= Clipboard_Copy()
	output := StringUtils.ToSingleLine(input)

	Clipboard_Paste(output)
}

;--------------------------------------------------------------------------------
; Create 'Format' menu. 

formatMenu := Menu()
formatMenu.SetColor("cbe7b6")
formatMenu.Add("To&Upper", Clipboard_ToUpper)
formatMenu.Add("To&Lower", Clipboard_ToLower)
formatMenu.Add("ToSingleLine", Menu_Format_Clipboard_ToLower)
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

subMenu := Menu()
subMenu.Add("Encrypt", Menu_Format_Encrypt_RC4)
subMenu.Add("Decrypt", Menu_Format_Decrypt_RC4)
formatMenu.Add("&Crypto.RC4", subMenu)

subMenu := Menu()
subMenu.Add("Encrypt", Menu_Format_Encrypt_BASE64)
subMenu.Add("Decrypt", Menu_Format_Decrypt_BASE64)

formatMenu.Add("Crypto.BASE64", subMenu)

;--------------------------------------------------------------------------------
; Create 'Stringgenerator' menu. 

Menu_UserSignature(itemName, itemPos, menu)
{
    value := UserSignatures[itemName]
    Std_Paste(value)
}

stringGeneratorMenu := Menu()
stringGeneratorMenu.SetColor("cee1f8")
stringGeneratorMenu.Add("&Random.Guid", Menu_StringGenerator_RandomGuid)

subMenu := Menu()
subMenu.Add("16", Menu_StringGenerator_RandomString_16)
subMenu.Add("32", Menu_StringGenerator_RandomString_32)
subMenu.Add("Dummy", Menu_StringGenerator_Dummy)
stringGeneratorMenu.Add("&Random.String", subMenu)

stringGeneratorMenu.Add()

stringGeneratorMenu.Add("&Date.Current", Menu_StringGenerator_CurrentDate)

subMenu := Menu()
subMenu.Add("Local", Menu_StringGenerator_CurrentDateTime)
subMenu.Add("UTC ISO-8601", Menu_StringGenerator_CurrentDateTime_ISO8601)

stringGeneratorMenu.Add("&DateTime.Current", subMenu)
stringGeneratorMenu.Add()

subMenu := Menu()
subMenu.Add("120", Menu_StringGenerator_Separator_120)

stringGeneratorMenu.Add("&Separator", subMenu)
stringGeneratorMenu.Add()

signaturesMenu := Menu()
for key, value in UserSignatures
{
    signaturesMenu.Add(key, Menu_UserSignature)
}

stringGeneratorMenu.Add("UserSignatures", signaturesMenu)

;--------------------------------------------------------------------------------
; Create 'TextSnippet' menu. 

Menu_TextSnippetCallback(itemName, itemPos, menu)
{
	output := TextSnippets[itemName]
	Clipboard_Paste(output)
}

textSnippetsMenu := MenuUtils.Build(TextSnippets, Menu_TextSnippetCallback)
textSnippetsMenu.SetColor("fcfddb")



;========================================================================================================================
; HOTKEYS
;========================================================================================================================

;--------------------------------------------------------------------------------
; Show 'FormatMenu'

#^f::
{
    formatMenu.Show()
}

;--------------------------------------------------------------------------------
; Show 'StringGeneratorMenu'

#^i::
{
	stringGeneratorMenu.Show()
}

;--------------------------------------------------------------------------------
; Show 'TextSnippetsMenu'

#^s::		; Win + Ctrl + Shift
{
	textSnippetsMenu.Show()
}

;--------------------------------------------------------------------------------
; Paste current local date-time.

#^d::
{
	Menu_StringGenerator_CurrentDateTime()
}

;--------------------------------------------------------------------------------
; Close all windows of the same type (class)

HotKey_CloseAllWindows(withSameTitle := false)
{
	prevTitleMode := A_TitleMatchMode 
	SetTitleMatchMode(3)

	windowClass := WinGetClass("A")
	windowTitle := WinGetTitle("A")
	
	windowGroup := StrReplace(windowClass, A_Space, "_")
	
	if (withSameTitle)
	{
		GroupAdd(windowGroup, windowTitle . " ahk_class " . windowClass)
	}
	else
	{
		GroupAdd(windowGroup, "ahk_class " . windowClass)
	}
	
	WinClose("ahk_group " . windowGroup)

  
	message := windowTitle . " (" . windowClass . ")"
	SetTitleMatchMode(prevTitleMode)

	Traytip("Close windows", message)
}

#!F4::		; Win + Alt + F4
{
	HotKey_CloseAllWindows(true)
}

^#F4::		; Ctrl + Win + F4
{
	HotKey_CloseAllWindows()
}



;========================================================================================================================
; HOTSTRINGS
;========================================================================================================================

Hotstring(":0*:@=", Config_GetEmail())

Config_GetEmail() 
{
	return Ini_ReadOrDefault(ConfigFilePath, "Settings", "Email")
}
