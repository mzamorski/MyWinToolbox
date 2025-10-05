#Requires AutoHotkey v2.0
#SingleInstance Force

#Include Libs\Constants.ahk
#Include Libs\StringUtils.ahk
#Include Libs\ClipboardUtils.ahk
#Include Libs\CryptoUtils.ahk
#Include Libs\DateTimeUtils.ahk
#Include Libs\ConfigUtils.ahk
#Include Libs\WinAPI.ahk
#Include Libs\MenuUtils.ahk
#include Libs\Externals\_JXON.ahk
#Include Libs\Externals\XHotstring.ahk
#Include Libs\IOUtils.ahk
#Include Libs\ExplorerUtils.ahk
#Include Libs\MinimizeToTray.ahk
#Include Libs\WindowGrid.ahk
#Include Libs\CopyWindowInfo.ahk

SendMode("Input")
SetTitleMatchMode("2")
DetectHiddenWindows(true)
Persistent

global AUTO_PASTE_TIMER_INTERVAL_MS := 500
global AutoPasteEntries := []



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

; --------------------------------------------------------------------------------
; Config/Main/INI

try
{
	; Shared config
	global SpacesPerIndent  := Ini_ReadOrDefault(SharedConfigFilePath, "Settings", "SpacesPerIndent")
	global DummyText := Ini_ReadOrDefault(SharedConfigFilePath, "Content", "DummyText")

        ; Home/Work config
        global Secret := Ini_ReadOrDefault(ConfigFilePath, "Settings", "Secret")
        global UserSignatures := Ini_GetSectionEntries(ConfigFilePath, "UserSignatures")
        global AutoPasteEntries := AutoPaste_LoadEntries(ConfigFilePath)
}
catch Error as e
{
        MsgBox(e.Message . "`nLine: " . e.Line . " / " . e.What
                ,"Config error"
        )

        ExitApp(-1)
}

global AutoPasteHandledWindows := Map()
if (AutoPasteEntries.Length > 0)
{
        SetTimer(AutoPaste_CheckActiveWindow, AUTO_PASTE_TIMER_INTERVAL_MS)
}

; --------------------------------------------------------------------------------
; Config/TextSnippets/JSON

try
{
	fileContent := FileRead("TextSnippets.json")
	global TextSnippetsJson := jxon_load(&fileContent)
}
catch Error as e
{
	MsgBox(e.Message . "`nLine: " . e.Line . " / " . e.What
		,"Config error"
	)
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

Menu_StringGenerator_Separator_80(*)
{
	output := StringUtils.Replicate("-", 80)

	Clipboard_Paste(output)
}

Menu_StringGenerator_Separator_50(*)
{
	output := StringUtils.Replicate("-", 50)

	Clipboard_Paste(output)
}


;========================================================================================================================
; CONTEXT-MENUS
;========================================================================================================================

;--------------------------------------------------------------------------------
; Create 'Format' menu. 

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

Menu_Format_AHK_ToSpecialKeys(*)
{
	input:= Clipboard_Copy()
	
	output := StringUtils.AHK.Replace(input, "(`r?`n)+", "{Enter {1:d}}")
	output := StringUtils.AHK.Replace(output, "(`t)+", "{Tab {1:d}}")

	Clipboard_Paste(output)
}

Menu_Format_Sort_Ascending(*)
{
	Menu_Format_Sort(true)
}

Menu_Format_Sort_Descending(*)
{
	Menu_Format_Sort(false)
}

Menu_Format_Sort(ascending := true)
{
	input := Clipboard_Copy()
	if !input 
	{
		return
	}
	
    output := ascending ? Sort(input) : Sort(input, "R")

	Clipboard_Paste(output)
}

Menu_Format_SQL_ToValuesTable(*)
{
	input := Clipboard_Copy()
	if !input 
	{
		return
	}

	lines := StrSplit(input, "`n", "`r")
	values := []

	for line in lines 
	{
		line := Trim(line)
		if (line != "")
		{
			values.Push("('" line "')")
		}
	}

	sqlValues := StringUtils.Join(values, ",`n")
	output := "SELECT *`nFROM (VALUES `n" sqlValues "`n) AS v(Name);"

	Clipboard_Paste(output)
}

Menu_Format_SQL_ToQuotedList(*)
{
	input := Clipboard_Copy()
	output := STRING_EMPTY

	separator := STRING_EMPTY

	lines := StrSplit(input, "`n", "`r")
	for i, line in lines
	{
		line := Trim(line)
		if (!StringUtils.IsNullOrWhiteSpace(line))
		{
			output .= separator . "'" . line . "'`n"
		}

		if (!separator)
		{
			separator := ","
		}
	}

	Clipboard_Paste(output)
}

;--------------------------------------------------------------------------------

formatMenu := Menu()
formatMenu.SetColor("cbe7b6")
formatMenu.Add("To&Upper", Clipboard_ToUpper)
formatMenu.Add("To&Lower", Clipboard_ToLower)

subMenu := Menu()
subMenu.Add("&Ascending", Menu_Format_Sort_Ascending)
subMenu.Add("&Descending", Menu_Format_Sort_Descending)
formatMenu.Add("&Sort", subMenu)

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
formatMenu.Add("SQL.ToQuotedList", Menu_Format_SQL_ToQuotedList)
formatMenu.Add("SQL.ToValuesTable", Menu_Format_SQL_ToValuesTable)

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

; AHK.ToSpecialKeys
formatMenu.Add()
formatMenu.Add("AHK.ToSpecialKeys", Menu_Format_AHK_ToSpecialKeys)

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
subMenu.Add("50", Menu_StringGenerator_Separator_50)
subMenu.Add("80", Menu_StringGenerator_Separator_80)
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

SNIPPET_TITLE_PROPERY := "Title"
SNIPPET_CONTENT_PROPERY := "Content"
SNIPPET_CONTENT_SEPARATOR := "--"

Menu_TextSnippetCallback(itemName, itemPos, menu, content := unset)
{
	SendInput(content)
}

textSnippetsMenu := Menu()
textSnippetsMenu.SetColor("b6e0e7")

for snippetName in TextSnippetsJson
{
	subMenu := Menu()

	if (snippetName = SNIPPET_CONTENT_SEPARATOR)
	{
		textSnippetsMenu.Add()
		continue
	}

    snippets := TextSnippetsJson[snippetName]

    if (snippets.Length > 0)
    {
        for snippet in snippets
        {
            content := snippet[SNIPPET_CONTENT_PROPERY]

			if (content = SNIPPET_CONTENT_SEPARATOR)
			{
				subMenu.Add()
				continue
			}

            if (snippet.Has(SNIPPET_TITLE_PROPERY))
            {
                title := snippet[SNIPPET_TITLE_PROPERY]
            }
            else
            {
                title := content
            }
    
            subMenu.Add(title, Menu_TextSnippetCallback.Bind(,,, content))
        }

        textSnippetsMenu.Add(snippetName, subMenu)
    }
}

;--------------------------------------------------------------------------------
; Create 'EmojiMenu' menu. 

emojiMenu := Menu()
emojiMenu.Add("🤑 — Money-Mouth Face", (*) => Send("🤑"))
emojiMenu.Add("👍 — Thumbs Up", (itemName, *) => Send("👍"))
emojiMenu.Add("👎 — Thumbs Down", (itemName, *) => Send("👎"))
emojiMenu.Add("☠️ — Skull and Crossbones", (itemName, *) => Send("☠️"))
emojiMenu.Add("💨 — Dashing Away", (itemName, *) => Send("💨"))

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

#^i::		; Win + Ctrl + i
{
	stringGeneratorMenu.Show()
}

;--------------------------------------------------------------------------------
; Show 'TextSnippetsMenu'

#^s::		; Win + Ctrl + s
{
	textSnippetsMenu.Show()
}

;--------------------------------------------------------------------------------
; Show 'EmocjiMenu'

#^e::		; Win + Ctrl + e
{
	emojiMenu.Show()
}

;--------------------------------------------------------------------------------
; Paste current local date-time.

#^d::		; Win + Ctrl + d
{
	Menu_StringGenerator_CurrentDate()
}

;--------------------------------------------------------------------------------
; Always On Top — toggle for the active window

#^PgUp:: {
    hwnd := WinExist("A")
    if !hwnd
        return

    ex := WinGetExStyle("ahk_id " hwnd)
    isTop := (ex & 0x00000008) ; WS_EX_TOPMOST

    WinSetAlwaysOnTop !isTop, "ahk_id " hwnd
    ToolTip (isTop ? "Always-on-top: OFF" : "Always-on-top: ON")
    SetTimer () => ToolTip(), -700
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

	TrayTip("Close windows", message)
}

#!F4::		; Win + Alt + F4
{
	HotKey_CloseAllWindows(true)
}

^#F4::		; Ctrl + Win + F4
{
	HotKey_CloseAllWindows()
}

#Space::	; Win + Space
{
    MouseGetPos(&x, &y)
    
	color := PixelGetColor(x, y)
	color := StrLower(color)

	A_Clipboard := color
    
	color := "c" SubStr(color, 3)
    
    colorWindow := Gui()
    colorWindow.BackColor := color
    colorWindow.Opt("-Caption +ToolWindow +Disabled +Border")
    colorWindow.Show("w50 h50 x" . x . " y" . y)
    Sleep (1000)
	
    colorWindow.Destroy()
}

^#Home::		; Ctrl + Win + Home
{
	TrayTip("The script will be reloaded.", MainScriptName)
	Sleep(2000)
	Reload
}

^#End::		; Ctrl + Win + End
{
	TrayTip("The script will be closed.", MainScriptName)
	Sleep(2000)
	ExitApp
}

; --------------------------------------------------------------------------------
; Insert a 4-space indent.

^Tab::		; Ctrl + tab
{
	Send(Format("{Space {1:i}}", SpacesPerIndent))
}

; --------------------------------------------------------------------------------
; Move all selected files/folders to a specified destination directory.

^#m::
{
	paths := Explorer_GetSelectedFiles()
    if (!paths)
    {
        MsgBox("Failed to retrieve file names from Explorer!")
    }
    
    currentDirectory := Explorer_GetActivePath()
    defaultDirName := DateTimeUtils.GetTimestamp()
 
    dialogResult := InputBox("Please enter directory name", "MoveTo", "w100 h70", defaultDirName)
    if (dialogResult.Result = "Cancel")
    {
        return
    }

    newDirectoryName := StringUtils.IsNullOrWhiteSpace(dialogResult.Value) 
        ? defaultDirName 
        : dialogResult.Value

    destDirectoryPath := PathUtils.Combine(currentDirectory, newDirectoryName)
    if (!DirectoryUtils.Create(destDirectoryPath))
    {
        MsgBox("Failed to create the directory!")
    }

	for path in paths 
    {
        if InStr(FileExist(path), "D") 
        {
            DirMove(path, destDirectoryPath, 1)
        } 
        else
        {
            FileMove(path, destDirectoryPath)    
        }
	}
}

;========================================================================================================================
; AUTO-PASTE
;========================================================================================================================

AutoPaste_LoadEntries(configFilePath)
{
        entries := []

        try
        {
                sectionEntries := Ini_GetSectionEntries(configFilePath, "AutoPaste")
        }
        catch
        {
                return entries
        }

        for name, rawValue in sectionEntries
        {
                if (StringUtils.IsNullOrWhiteSpace(name))
                {
                        continue
                }

                try
                {
                        entry := AutoPaste_ParseEntry(name, rawValue)

                        if (entry)
                        {
                                entries.Push(entry)
                        }
                }
                catch Error as e
                {
                        OutputDebug(Format("[AutoPaste] Entry '{1}' skipped: {2} (Line: {3})", name, e.Message, e.Line))
                }
        }

        return entries
}

AutoPaste_ParseEntry(name, rawValue)
{
        if (StringUtils.IsNullOrWhiteSpace(rawValue))
        {
                throw Error("AutoPaste entry is empty.")
        }

        try
        {
                definition := jxon_load(&rawValue)
        }
        catch Error as innerError
        {
                throw Error("AutoPaste entry is not valid JSON. " . innerError.Message)
        }

        if (!IsObject(definition))
        {
                throw Error("AutoPaste entry must be a JSON object.")
        }

        entry := Map()
        entry.CaseSense := false
        entry["name"] := name

        for property, value in definition
        {
                key := StrLower(property)

                switch key
                {
                        case "title":
                                entry["title"] := AutoPaste_ToString(value)
                        case "titlematchmode":
                                entry["titleMatchMode"] := StrLower(AutoPaste_ToString(value))
                        case "exe", "process", "processname":
                                entry["exe"] := AutoPaste_ToString(value)
                        case "class", "winclass":
                                entry["class"] := AutoPaste_ToString(value)
                        case "text":
                                entry["text"] := AutoPaste_ToString(value, false)
                        case "inputtype":
                                entry["inputType"] := value + 0
                        case "delay", "delayms":
                                entry["delayMs"] := value + 0
                        default:
                                entry[key] := value
                }
        }

        if (!entry.Has("text") || StringUtils.IsNullOrWhiteSpace(entry["text"]))
        {
                throw Error("AutoPaste entry requires a non-empty 'text' value.")
        }

        if (!entry.Has("inputType"))
        {
                entry["inputType"] := 0
        }

        if (!entry.Has("delayMs"))
        {
                entry["delayMs"] := 0
        }

        if (entry.Has("titleMatchMode"))
        {
                mode := entry["titleMatchMode"]

                if (mode = "exact")
                {
                        mode := "equals"
                        entry["titleMatchMode"] := mode
                }

                if (mode != "equals" && mode != "contains")
                {
                        throw Error("AutoPaste entry has unsupported TitleMatchMode '" . mode . "'.")
                }
        }

        return entry
}

AutoPaste_ToString(value, trim := true)
{
        result := value

        if (Type(result) != "String")
        {
                result := result . ""
        }

        if (trim)
        {
                result := Trim(result)
        }

        return result
}

AutoPaste_CheckActiveWindow(*)
{
        global AutoPasteEntries
        global AutoPasteHandledWindows

        if (AutoPasteEntries.Length = 0)
        {
                return
        }

        hwnd := WinExist("A")
        if (!hwnd)
        {
                return
        }

        if (AutoPasteHandledWindows.Has(hwnd))
        {
                return
        }

        for entry in AutoPasteEntries
        {
                if (AutoPaste_WindowMatches(hwnd, entry))
                {
                        if (AutoPaste_Perform(hwnd, entry))
                        {
                                AutoPasteHandledWindows[hwnd] := entry["name"]
                        }

                        break
                }
        }
}

AutoPaste_WindowMatches(hwnd, entry)
{
        if (entry.Has("exe"))
        {
                winExe := WinGetProcessName("ahk_id " hwnd)

                if (!AutoPaste_EqualsIgnoreCase(winExe, entry["exe"]))
                {
                        return false
                }
        }

        if (entry.Has("class"))
        {
                winClass := WinGetClass("ahk_id " hwnd)

                if (!AutoPaste_EqualsIgnoreCase(winClass, entry["class"]))
                {
                        return false
                }
        }

        if (entry.Has("title"))
        {
                winTitle := WinGetTitle("ahk_id " hwnd)
                matchValue := entry["title"]
                matchMode := entry.Has("titleMatchMode") ? entry["titleMatchMode"] : "contains"

                if (matchMode = "equals")
                {
                        if (!AutoPaste_EqualsIgnoreCase(winTitle, matchValue))
                        {
                                return false
                        }
                }
                else
                {
                        if (!InStr(winTitle, matchValue, false))
                        {
                                return false
                        }
                }
        }

        return true
}

AutoPaste_Perform(hwnd, entry)
{
        if (entry["delayMs"] > 0)
        {
                Sleep(entry["delayMs"])
        }

        if (!WinExist("ahk_id " hwnd))
        {
                return false
        }

        if (!WinActive("ahk_id " hwnd))
        {
                WinActivate("ahk_id " hwnd)

                if (!WinWaitActive("ahk_id " hwnd, , 1))
                {
                        return false
                }
        }

        Std_Paste(entry["text"], entry["inputType"])

        return true
}

AutoPaste_EqualsIgnoreCase(value, expected)
{
        return StrLower(AutoPaste_ToString(value)) = StrLower(AutoPaste_ToString(expected))
}

;========================================================================================================================
; HOTSTRINGS
; --
; O  - Remove the ending character.
; b0 - Don't delete the typed text.
; *  - Trigger immediately.
; ?  - Search everywhere (trigger even if the start is not separated from the previous text).
; X  - Execute. Instead of replacement text.
;========================================================================================================================

Config_GetEmail() 
{
	return Ini_ReadOrDefault(ConfigFilePath, "Settings", "Email")
}

Terminal_IsActive() {
    winExe := WinGetProcessPath("A")
    return InStr(winExe, "cmd.exe") || InStr(winExe, "WindowsTerminal.exe")
}

TortoiseGit_IsActive() {
    winExe := WinGetProcessPath("A")
    return InStr(winExe, "TortoiseGitProc.exe")
}

;--------------------------------------------------------------------------------

Hotstring(":0*:@=", Config_GetEmail())
Hotstring(":0*:@me", Config_GetEmail())
Hotstring(":0*:--=", Menu_StringGenerator_Separator_120)

; Add three zeros (convert to thousands)
XHotstring(":*:(\d+)k=", (match, *) => Send(match[1] . "000"))

#Hotstring *

; Insert char [—]
::@--::{U+2014}

; Insert char [→]
::@->::{U+2192}

; Insert char [✓]
::@v::{U+2713}

#Hotstring

;--------------------------------------------------------------------------------
; Terminal

#HotIf Terminal_IsActive()

::s30m=::
{
    SendText("shutdown -s -t 1800")
}

::s1h=::
{
    SendText("shutdown -s -t 3600")
}

::s2h=::
{
    SendText("shutdown -s -t 7200")
}

#HotIf 

;--------------------------------------------------------------------------------
; TortoiseGit

#HotIf TortoiseGit_IsActive()

::r=::Refactoring.

#HotIf