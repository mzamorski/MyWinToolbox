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

global ProfileConfigFilePath := A_ScriptDir "\" MainScriptName . CONFIG_FILE_EXTENSION
global SharedConfigAbsolutePath := A_ScriptDir "\" CurrentScriptName . CONFIG_FILE_EXTENSION
global ConfigFilePath := ProfileConfigFilePath
global SharedConfigFilePath := SharedConfigAbsolutePath

Logger.Configure(false)

; --------------------------------------------------------------------------------
; Config/Main/INI

try
{
	; Shared config
	global SpacesPerIndent  := Ini_ReadOrDefault(SharedConfigFilePath, "Settings", "SpacesPerIndent")
	global DummyText := Ini_ReadOrDefault(SharedConfigFilePath, "Content", "DummyText")
	debugLoggingText := StrLower(Trim("" Ini_ReadOrDefault(SharedConfigFilePath, "Logging", "Debug", "false")))
	global DebugLogging := (debugLoggingText = "true" || debugLoggingText = "1")
	Logger.Configure(DebugLogging)
	if (DebugLogging)
	{
		Logger.Debug("Debug logging enabled.", "Startup")
	}

	; Home/Work config
	global Secret := Ini_ReadOrDefault(ConfigFilePath, "Settings", "Secret")
	global UserSignatures := Ini_GetSectionEntries(ConfigFilePath, "UserSignatures")
	global AudioDeviceHeadphones := Ini_ReadOrDefault(ConfigFilePath, "AudioDevices", "Headphones", STRING_EMPTY)
	global AudioDeviceMonitor := Ini_ReadOrDefault(ConfigFilePath, "AudioDevices", "Monitor", STRING_EMPTY)
	global AudioDeviceLaptop := Ini_ReadOrDefault(ConfigFilePath, "AudioDevices", "Laptop", STRING_EMPTY)

	; Per-profile startup defaults.
	global StartupNoSleepEnabled := Ini_ReadBoolOrDefault(
		ConfigFilePath,
		"Startup",
		"NoSleep",
		false
	)
	global StartupAutoPasteEnabled := Ini_ReadBoolOrDefault(
		ConfigFilePath,
		"Startup",
		"AutoPaste",
		false
	)
	global StartupClipboardTrimEnabled := Ini_ReadBoolOrDefault(
		ConfigFilePath,
		"Startup",
		"ClipboardTrim",
		false
	)
}
catch Error as e
{
	Logger.Error(e.Message . " | Line: " . e.Line . " / " . e.What, "Config")
	MsgBox(e.Message . "`nLine: " . e.Line . " / " . e.What
		,"Config error"
	)

	ExitApp(-1)
}

; --------------------------------------------------------------------------------
; Config/TextSnippets/JSON

global TextSnippetsJson := Map()
global TextSnippetsFilePath := A_ScriptDir "\TextSnippets.json"

try
{
	if FileExist(TextSnippetsFilePath)
	{
		fileContent := FileRead(TextSnippetsFilePath)
		TextSnippetsJson := jxon_load(&fileContent)
	}
	else
	{
		Logger.Warning(TextSnippetsFilePath . " was not found; the Text Snippets menu will be empty.", "Config")
	}
}
catch Error as e
{
	Logger.Error(e.Message . " | Line: " . e.Line . " / " . e.What, "Config")
	MsgBox(e.Message . "`nLine: " . e.Line . " / " . e.What
		,"Config error"
	)
}

; --------------------------------------------------------------------------------
; Config/HotStrings/JSON

global HotStringsJson := Map()
global HotStringsFilePath := A_ScriptDir "\HotStrings.json"

try
{
	if FileExist(HotStringsFilePath)
	{
		fileContent := FileRead(HotStringsFilePath)
		HotStringsJson := jxon_load(&fileContent)

		DynamicHotstrings_Register(HotStringsJson)
		;DynamicHotstrings_ShowDiagnostics()
	}
	else
	{
		Logger.Warning(HotStringsFilePath . " was not found; dynamic HotStrings will be empty.", "Config")
	}
}
catch Error as e
{
	Logger.Error(e.Message . " | Line: " . e.Line . " / " . e.What, "Config")
	MsgBox(e.Message . "`nLine: " . e.Line . " / " . e.What
		, "Config error"
	)
}

; --------------------------------------------------------------------------------
; Config/AutoPastes/JSON

global AutoPastesJson := []
global AutoPastesFilePath := A_ScriptDir "\AutoPastes.json"

try
{
	if FileExist(AutoPastesFilePath)
	{
		fileContent := FileRead(AutoPastesFilePath)
		AutoPastesJson := jxon_load(&fileContent)

		AutoPaste_Register(AutoPastesJson)
	}
	else
	{
		Logger.Warning(AutoPastesFilePath . " was not found; AutoPaste rules will be empty.", "Config")
	}
}
catch Error as e
{
	Logger.Error(e.Message . " | Line: " . e.Line . " / " . e.What, "Config")
	MsgBox(e.Message . "`nLine: " . e.Line . " / " . e.What
		, "Config error"
	)
}

;========================================================================================================================
