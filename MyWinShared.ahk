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
}
catch Error as e
{
	MsgBox(e.Message . "`nLine: " . e.Line . " / " . e.What
		,"Config error"
	)

	ExitApp(-1)
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

try
{
        hotstringsFilePath := "Hotstrings.json"
        if FileExist(hotstringsFilePath)
        {
                fileContent := FileRead(hotstringsFilePath)
                global HotstringsJson := jxon_load(&fileContent)
        }
        else
        {
                global HotstringsJson := []
        }
}
catch Error as e
{
        MsgBox(e.Message . "`nLine: " . e.Line . " / " . e.What
                ,"Config error"
        )
        global HotstringsJson := []
}

global DynamicHotstrings_Registry := []
global DynamicHotstrings_DiagnosticsGui := 0

DynamicHotstrings_Register()



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
; Show diagnostics for dynamic hotstrings

#^+h::		; Win + Ctrl + Shift + h
{
	DynamicHotstrings_ShowDiagnostics()
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
; HOTSTRINGS
; --
; O  - Remove the ending character.
; b0 - Don't delete the typed text.
; *  - Trigger immediately.
; ?  - Search everywhere (trigger even if the start is not separated from the previous text).
; X  - Execute. Instead of replacement text.
;========================================================================================================================

DynamicHotstrings_Register()
{
        global HotstringsJson
        global DynamicHotstrings_Registry

        if !IsSet(HotstringsJson)
        {
                return
        }

	config := DynamicHotstrings_ParseConfiguration(HotstringsJson)
	if !IsObject(config)
	{
		return
	}

        definitions := config["Hotstrings"]
        if !IsObject(definitions) || (definitions.Length = 0)
        {
                DynamicHotstrings_Registry := []
                return
        }

        DynamicHotstrings_Registry := []
        items := []
        for definition in definitions
        {
                items.Push(Map(
		"Priority", DynamicHotstring_GetPriority(definition)
		, "Definition", definition
		))
	}

	items.Sort((a, b, *) => (a["Priority"] < b["Priority"]) ? 1 : (a["Priority"] > b["Priority"] ? -1 : 0))

	for item in items
	{
		DynamicHotstring_RegisterDefinition(item["Definition"], config)
	}
}

DynamicHotstring_RegisterDefinition(definition, config)
{
	if !IsObject(definition)
	{
		return
	}

	try
	{
		if DynamicHotstring_HasProperty(definition, ["Enabled", "enabled"])
		{
			enabledValue := ""
			if DynamicHotstring_TryGet(definition, ["Enabled", "enabled"], &enabledValue)
			{
				if !DynamicHotstring_IsTruthy(enabledValue)
				{
					return
				}
			}
		}

		pattern := DynamicHotstring_BuildPattern(definition, config["Defaults"])
		if (pattern = "")
		{
			return
		}

		replacementValue := ""
		if !DynamicHotstring_TryGet(definition, ["Text", "text", "Replacement", "replacement", "Content", "content"], &replacementValue)
		{
			return
		}

		replacement := "" . replacementValue
		replacement := DynamicHotstring_ApplyPlaceholders(replacement)

		sendMode := ""
		if DynamicHotstring_TryGet(definition, ["SendMode", "sendMode"], &sendMode)
		{
			sendMode := StrLower(Trim("" . sendMode))
		}

                scopeInfo := DynamicHotstring_PrepareScopeContext(definition, config)
                if !scopeInfo["ShouldRegister"]
                {
                        return
                }

                predicate := scopeInfo["Predicate"]
                if predicate
                {
                        HotIf(predicate)
                }

                try
                {
                        registered := false
                        switch sendMode
                        {
                                case "text":
                                Hotstring(pattern, (*) => SendText(replacement))
                                registered := true
                                case "raw":
                        Hotstring(pattern, (*) => Send("{Raw}" . replacement))
                                registered := true
                                default:
                                Hotstring(pattern, replacement)
                                registered := true
                        }
                }
                catch Error as e
                {
        OutputDebug(Format("[DynamicHotstring] Failed to register hotstring. Message: {1}, What: {2}", e.Message, e.What))
                }
                finally
                {
                        if predicate
                        {
                                HotIf()
                        }
                }

                if registered
                {
                        DynamicHotstrings_RecordRegistration(pattern, replacement, sendMode, scopeInfo)
                }
        }
        catch Error as e
        {
OutputDebug(Format("[DynamicHotstring] Failed to process definition. Message: {1}, What: {2}", e.Message, e.What))
        }
}

DynamicHotstring_PrepareScopeContext(definition, config)
{
        result := Map(
                "ShouldRegister", true
                , "Predicate", 0
                , "IncludeNames", []
                , "ExcludeNames", []
                , "AllowEverywhere", false
        )

        defaults := config.Has("Defaults") ? config["Defaults"] : Map()
        aliases := config.Has("ScopeAliases") ? config["ScopeAliases"] : Map()

        includeData := DynamicHotstring_NormalizeScopeItems(definition, aliases, ["IncludeScopes", "includeScopes"])
        excludeData := DynamicHotstring_NormalizeScopeItems(definition, aliases, ["ExcludeScopes", "excludeScopes"])

        includeScopes := includeData["Scopes"]
        excludeScopes := excludeData["Scopes"]
        result["IncludeNames"] := includeData["Names"]
        result["ExcludeNames"] := excludeData["Names"]

        hasWildcard := includeData["HasWildcard"]
        hasIncludeProperty := DynamicHotstring_HasProperty(definition, ["IncludeScopes", "includeScopes"])
        hasExcludeProperty := DynamicHotstring_HasProperty(definition, ["ExcludeScopes", "excludeScopes"])

        allowEverywhere := false
        if !hasIncludeProperty && !hasExcludeProperty
        {
                allowEverywhere := true
        }
        else if hasWildcard
        {
                allowEverywhere := true
        }
        else if (includeScopes.Length = 0)
        {
                if (excludeScopes.Length > 0)
                {
                        allowEverywhere := true
                }
                else
                {
                        scopeMode := defaults.Has("ScopeMode") ? defaults["ScopeMode"] : "include"
                        scopeMode := StrLower("" . scopeMode)
                        if (scopeMode = "exclude")
                        {
                                allowEverywhere := true
                        }
                        else
                        {
                                result["ShouldRegister"] := false
                                return result
                        }
                }
        }

        predicate := DynamicHotstring_CreateScopePredicate(includeScopes, excludeScopes, allowEverywhere)
        result["Predicate"] := predicate
        result["AllowEverywhere"] := allowEverywhere
        return result
}

DynamicHotstring_CreateScopePredicate(includeScopes, excludeScopes, allowEverywhere)
{
	hasInclude := includeScopes.Length > 0
	hasExclude := excludeScopes.Length > 0

	if allowEverywhere && !hasInclude && !hasExclude
	{
		return 0
	}

	if !allowEverywhere && !hasInclude
	{
		return 0
	}

	return (*) => DynamicHotstring_EvaluateScope(includeScopes, excludeScopes, allowEverywhere)
}

DynamicHotstring_EvaluateScope(includeScopes, excludeScopes, allowEverywhere)
{
	info := DynamicHotstring_GetActiveWindowInfo()

	for scope in excludeScopes
	{
		if DynamicHotstring_WindowMatchesScope(scope, info)
		{
			return false
		}
	}

	if allowEverywhere
	{
		if (includeScopes.Length = 0)
		{
			return true
		}

		for scope in includeScopes
		{
			if DynamicHotstring_WindowMatchesScope(scope, info)
			{
				return true
			}
		}

		return true
	}

	for scope in includeScopes
	{
		if DynamicHotstring_WindowMatchesScope(scope, info)
		{
			return true
		}
	}

	return false
}

DynamicHotstring_GetActiveWindowInfo()
{
	info := Map("Process", "", "Class", "", "Title", "")

	try
	{
		info["Process"] := StrLower("" . WinGetProcessName("A"))
	}
	catch
	{
		info["Process"] := ""
	}

	try
	{
		info["Class"] := "" . WinGetClass("A")
	}
	catch
	{
		info["Class"] := ""
	}

	try
	{
		info["Title"] := "" . WinGetTitle("A")
	}
	catch
	{
		info["Title"] := ""
	}

	return info
}

DynamicHotstring_WindowMatchesScope(scope, info)
{
	if !IsObject(scope)
	{
		return false
	}

	if scope.Has("Processes")
	{
		processes := scope["Processes"]
		if (processes.Length > 0)
		{
			if !DynamicHotstring_ArrayContains(processes, info["Process"])
			{
				return false
			}
		}
	}

	if scope.Has("Classes")
	{
		classes := scope["Classes"]
		if (classes.Length > 0)
		{
			if !DynamicHotstring_ArrayContains(classes, info["Class"], false)
			{
				return false
			}
		}
	}

	if scope.Has("TitleRegex")
	{
		titlePattern := scope["TitleRegex"]
		if (titlePattern != "")
		{
			if !RegExMatch(info["Title"], "" . titlePattern)
			{
				return false
			}
		}
	}

	return true
}

DynamicHotstring_ArrayContains(collection, value, caseInsensitive := true)
{
	if !IsObject(collection)
	{
		return false
	}

	needle := "" . value
	needle := caseInsensitive ? StrLower(needle) : needle

	for item in collection
	{
		candidate := "" . item
		candidate := caseInsensitive ? StrLower(candidate) : candidate
		if (candidate = needle)
		{
			return true
		}
	}

	return false
}

DynamicHotstring_NormalizeScopeItems(definition, aliases, propertyNames)
{
        result := Map("Scopes", [], "Names", [], "HasWildcard", false)
        value := ""
        if !DynamicHotstring_TryGet(definition, propertyNames, &value)
        {
                return result
        }

        items := DynamicHotstrings_ToArray(value)
        for item in items
        {
                if item is String
                {
                        scopeName := Trim("" . item)
                        if (scopeName = "")
                        {
                                continue
                        }

                        if (scopeName = "*")
                        {
                                result["HasWildcard"] := true
                                result["Names"].Push("*")
                                continue
                        }

                        aliasKey := StrLower(scopeName)
                        if aliases.Has(aliasKey)
                        {
                                result["Scopes"].Push(aliases[aliasKey])
                                result["Names"].Push(scopeName)
                        }
                        else
                        {
                        OutputDebug(Format("[DynamicHotstring] Unknown scope alias: {1}", scopeName))
                        }
                }
                else if IsObject(item)
                {
                        scopeDefinition := DynamicHotstrings_NormalizeScope(item)
                        if IsObject(scopeDefinition)
                        {
                                result["Scopes"].Push(scopeDefinition)
                                result["Names"].Push(DynamicHotstrings_FormatScopeDescriptor(scopeDefinition))
                        }
                }
        }

        return result
}

DynamicHotstrings_FormatScopeDescriptor(scopeDefinition)
{
        if !IsObject(scopeDefinition)
        {
                return "[custom]"
        }

        if scopeDefinition.Has("Name")
        {
                return "" . scopeDefinition["Name"]
        }

        parts := []
        if scopeDefinition.Has("Processes")
        {
                processes := scopeDefinition["Processes"]
                if IsObject(processes) && (processes.Length > 0)
                {
                        parts.Push("proc=" . processes.Join("|"))
                }
        }

        if scopeDefinition.Has("Classes")
        {
                classes := scopeDefinition["Classes"]
                if IsObject(classes) && (classes.Length > 0)
                {
                        parts.Push("class=" . classes.Join("|"))
                }
        }

        if scopeDefinition.Has("TitleRegex")
        {
                title := "" . scopeDefinition["TitleRegex"]
                if (title != "")
                {
                        parts.Push("title=" . title)
                }
        }

        if (parts.Length = 0)
        {
                return "[custom]"
        }

        return "[" . parts.Join(", ") . "]"
}

DynamicHotstrings_ParseConfiguration(rawConfig)
{
        if !IsObject(rawConfig)
        {
                return ""
	}

	config := Map()
	config["Defaults"] := DynamicHotstrings_ParseDefaults(rawConfig)
	config["ScopeAliases"] := DynamicHotstrings_ParseScopeAliases(rawConfig)
	config["Hotstrings"] := DynamicHotstrings_ParseDefinitionList(rawConfig)
	return config
}

DynamicHotstrings_ParseDefaults(rawConfig)
{
	defaults := Map("Options", "*", "ScopeMode", "include")

	if (Type(rawConfig) = "Map") && rawConfig.Has("defaults")
	{
		defaultsObject := rawConfig["defaults"]
		if IsObject(defaultsObject)
		{
			value := ""
			if DynamicHotstring_TryGet(defaultsObject, ["Options", "options"], &value)
			{
				defaults["Options"] := "" . value
			}

			if DynamicHotstring_TryGet(defaultsObject, ["ScopeMode", "scopeMode"], &value)
			{
				scopeMode := StrLower(Trim("" . value))
				if !(scopeMode = "include" || scopeMode = "exclude")
				{
					scopeMode := "include"
				}

				defaults["ScopeMode"] := scopeMode
			}
		}
	}

	return defaults
}

DynamicHotstrings_ParseScopeAliases(rawConfig)
{
	aliases := Map()

	if (Type(rawConfig) = "Map") && rawConfig.Has("scopes")
	{
		scopesValue := rawConfig["scopes"]
		if IsObject(scopesValue) && scopesValue.Has("aliases")
		{
			aliasContainer := scopesValue["aliases"]
			if IsObject(aliasContainer)
			{
				for aliasName, aliasDefinition in aliasContainer
				{
					normalized := DynamicHotstrings_NormalizeScope(aliasDefinition)
					if IsObject(normalized)
					{
						normalized["Name"] := aliasName
						aliases[StrLower("" . aliasName)] := normalized
					}
				}
			}
		}
	}

	return aliases
}

DynamicHotstrings_NormalizeScope(scopeDefinition)
{
	if !IsObject(scopeDefinition)
	{
		return ""
	}

	result := Map()

	processValue := ""
	if DynamicHotstring_TryGet(scopeDefinition, ["Process", "process", "Processes", "processes"], &processValue)
	{
		processes := DynamicHotstrings_ToArray(processValue)
		if (processes.Length > 0)
		{
			list := []
			for item in processes
			{
				list.Push(StrLower(Trim("" . item)))
			}
			result["Processes"] := list
		}
	}

	classValue := ""
	if DynamicHotstring_TryGet(scopeDefinition, ["Class", "class", "Classes", "classes"], &classValue)
	{
		classes := DynamicHotstrings_ToArray(classValue)
		if (classes.Length > 0)
		{
			list := []
			for item in classes
			{
				list.Push("" . item)
			}
			result["Classes"] := list
		}
	}

	titleValue := ""
	if DynamicHotstring_TryGet(scopeDefinition, ["TitleRegex", "titleRegex"], &titleValue)
	{
		titlePattern := Trim("" . titleValue)
		if (titlePattern != "")
		{
			result["TitleRegex"] := titlePattern
		}
	}

	return result.Count > 0 ? result : Map()
}

DynamicHotstrings_ParseDefinitionList(rawConfig)
{
	definitions := []
	typeName := Type(rawConfig)

	switch typeName
	{
		case "Array":
		for item in rawConfig
		{
			if IsObject(item)
			{
				definitions.Push(item)
			}
		}
		case "Map":
		if rawConfig.Has("hotstrings")
		{
			list := rawConfig["hotstrings"]
			if IsObject(list) && Type(list) = "Array"
			{
				for item in list
				{
					if IsObject(item)
					{
						definitions.Push(item)
					}
				}
			}
		}
		else
		{
			for _, item in rawConfig
			{
				if IsObject(item)
				{
					definitions.Push(item)
				}
			}
		}
	}

	return definitions
}

DynamicHotstrings_ToArray(value)
{
	result := []
	if !IsSet(value)
	{
		return result
	}

	if IsObject(value) && (Type(value) = "Array")
	{
		for item in value
		{
			result.Push(item)
		}
	}
	else
	{
		if (value != "")
		{
			result.Push(value)
		}
	}

	return result
}

DynamicHotstring_BuildPattern(definition, defaults)
{
	patternValue := ""
	if DynamicHotstring_TryGet(definition, ["Pattern", "pattern"], &patternValue)
	{
		return DynamicHotstring_NormalizePattern(patternValue)
	}

	triggerValue := ""
	if !DynamicHotstring_TryGet(definition, ["Trigger", "trigger"], &triggerValue)
	{
		return ""
	}

	trigger := Trim("" . triggerValue)
	if (trigger = "")
	{
		return ""
	}

	optionsValue := ""
	if DynamicHotstring_TryGet(definition, ["Options", "options"], &optionsValue)
	{
		options := "" . optionsValue
	}
	else
	{
		options := defaults.Has("Options") ? ("" . defaults["Options"]) : ""
	}

	pattern := DynamicHotstring_ComposePattern(options, trigger)
	return DynamicHotstring_NormalizePattern(pattern)
}

DynamicHotstring_ComposePattern(options, trigger)
{
	options := Trim("" . options)
	if (options = "")
	{
		return "::" . trigger
	}

	if (SubStr(options, 1, 1) != ":")
	{
		options := ":" . options
	}

	if (SubStr(options, -1) != ":")
	{
		options .= ":"
	}

	return options . trigger
}

DynamicHotstring_TryGet(source, propertyNames, &value)
{
	if !IsObject(propertyNames)
	{
		return false
	}

	if !IsObject(source)
	{
		return false
	}

	for propertyName in propertyNames
	{
		if source.Has(propertyName)
		{
			value := source[propertyName]
			return true
		}
	}

	return false
}

DynamicHotstring_HasProperty(source, propertyNames)
{
	value := ""
	return DynamicHotstring_TryGet(source, propertyNames, &value)
}

DynamicHotstring_GetPriority(definition)
{
	priorityValue := 0
	if DynamicHotstring_TryGet(definition, ["Priority", "priority"], &priorityValue)
	{
		try
		{
			return priorityValue + 0
		}
		catch
		{
			return 0
		}
	}

	return 0
}

DynamicHotstring_ApplyPlaceholders(value)
{
	result := "" . value

	while RegExMatch(result, "%\{DateTime:([^}]+)\}", &match)
	{
		format := Trim(match[1])
		replacement := ""
		if (format != "")
		{
			try
			{
				replacement := FormatTime(A_Now, format)
			}
			catch
			{
				replacement := ""
			}
		}

		result := StrReplace(result, match[0], replacement, , 1)
	}

	return result
}

DynamicHotstring_NormalizePattern(pattern)
{
        pattern := "" . pattern
        pattern := Trim(pattern)

        while (StrLen(pattern) > 0 && SubStr(pattern, -1) = ":")
        {
                pattern := SubStr(pattern, 1, StrLen(pattern) - 1)
        }

        if (pattern != "" && !InStr(pattern, ":"))
        {
                pattern := "::" . pattern
        }

        return pattern
}

DynamicHotstrings_RecordRegistration(pattern, replacement, sendMode, scopeInfo)
{
        global DynamicHotstrings_Registry

        if !IsSet(DynamicHotstrings_Registry)
        {
                DynamicHotstrings_Registry := []
        }

        info := Map()
        info["Pattern"] := pattern
        info["SendMode"] := (sendMode = "") ? "default" : sendMode
        info["ScopeSummary"] := DynamicHotstrings_FormatScopeSummary(scopeInfo)
        info["ReplacementPreview"] := DynamicHotstrings_CreatePreview(replacement)

        DynamicHotstrings_Registry.Push(info)

        OutputDebug(Format("[DynamicHotstring] Registered {1} (mode: {2}, scope: {3})"
                , pattern
                , StrUpper(info["SendMode"])
                , info["ScopeSummary"]
        ))
}

DynamicHotstrings_CreatePreview(value)
{
        text := "" . value
        if (text = "")
        {
                return ""
        }

        text := StrReplace(text, "`r`n", " ⏎ ")
        text := StrReplace(text, "`n", " ⏎ ")
        text := StrReplace(text, "`r", " ⏎ ")
        text := StrReplace(text, "`t", " ⇥ ")
        text := Trim(text)

        maxLength := 120
        if (StrLen(text) > maxLength)
        {
                text := SubStr(text, 1, maxLength - 3) . "..."
        }

        return text
}

DynamicHotstrings_FormatScopeSummary(scopeInfo)
{
        if !IsObject(scopeInfo)
        {
                return "unknown"
        }

        includeNames := scopeInfo.Has("IncludeNames") ? scopeInfo["IncludeNames"] : []
        excludeNames := scopeInfo.Has("ExcludeNames") ? scopeInfo["ExcludeNames"] : []
        allowEverywhere := scopeInfo.Has("AllowEverywhere") ? scopeInfo["AllowEverywhere"] : false

        includeText := (IsObject(includeNames) && includeNames.Length > 0) ? includeNames.Join(", ") : ""
        excludeText := (IsObject(excludeNames) && excludeNames.Length > 0) ? excludeNames.Join(", ") : ""

        if (allowEverywhere && (includeText = "") && (excludeText = ""))
        {
                return "Everywhere"
        }

        parts := []
        if (includeText != "")
        {
                parts.Push("Include: " . includeText)
        }
        else if allowEverywhere
        {
                parts.Push("Include: *")
        }

        if (excludeText != "")
        {
                parts.Push("Exclude: " . excludeText)
        }

        if (parts.Length = 0)
        {
                return allowEverywhere ? "Everywhere" : "No scope"
        }

        return parts.Join(" | ")
}

DynamicHotstrings_ShowDiagnostics(*)
{
        global DynamicHotstrings_Registry
        global DynamicHotstrings_DiagnosticsGui

        if IsObject(DynamicHotstrings_DiagnosticsGui)
        {
                try DynamicHotstrings_DiagnosticsGui.Destroy()
                catch
                {
                }
                DynamicHotstrings_DiagnosticsGui := 0
        }

        if !IsSet(DynamicHotstrings_Registry) || (DynamicHotstrings_Registry.Length = 0)
        {
                MsgBox("Brak dynamicznych hotstringów do wyświetlenia.")
                return
        }

        gui := Gui("+Resize", "Dynamic Hotstrings")
        gui.OnEvent("Close", DynamicHotstrings_OnDiagnosticsClose)
        gui.OnEvent("Escape", DynamicHotstrings_OnDiagnosticsClose)

        header := ["Trigger", "Send mode", "Scopes", "Preview"]
        listView := gui.AddListView("w760 r16", header)
        listView.ModifyCol(1, 150)
        listView.ModifyCol(2, 90)
        listView.ModifyCol(3, 230)
        listView.ModifyCol(4, 260)

        for item in DynamicHotstrings_Registry
        {
                sendMode := StrUpper("" . item["SendMode"])
                scopeSummary := "" . item["ScopeSummary"]
                preview := "" . item["ReplacementPreview"]
                listView.Add("", item["Pattern"], sendMode, scopeSummary, preview)
        }

        listView.ModifyCol()

        button := gui.AddButton("xm y+10", "Pokaż ListHotkeys")
        button.OnEvent("Click", (*) => ListHotkeys())

        DynamicHotstrings_DiagnosticsGui := gui
        gui.Show()
}

DynamicHotstrings_OnDiagnosticsClose(gui, *)
{
        global DynamicHotstrings_DiagnosticsGui

        try gui.Destroy()
        catch
        {
        }

        DynamicHotstrings_DiagnosticsGui := 0
}

DynamicHotstring_IsTruthy(value)
{
        if value is String
        {
                normalized := StrLower(Trim(value))
                switch normalized
                {
                        case "", "0", "false", "no", "off":
                                return false
                        default:
                                return true
                }
        }

        return value ? true : false
}

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