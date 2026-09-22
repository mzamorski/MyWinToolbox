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

	; Home/Work config
	global Secret := Ini_ReadOrDefault(ConfigFilePath, "Settings", "Secret")
	global UserSignatures := Ini_GetSectionEntries(ConfigFilePath, "UserSignatures")
	global AudioDeviceHeadphones := Ini_ReadOrDefault(ConfigFilePath, "AudioDevices", "Headphones", STRING_EMPTY)
	global AudioDeviceMonitor := Ini_ReadOrDefault(ConfigFilePath, "AudioDevices", "Monitor", STRING_EMPTY)
	global AudioDeviceLaptop := Ini_ReadOrDefault(ConfigFilePath, "AudioDevices", "Laptop", STRING_EMPTY)
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

try
{
	fileContent := FileRead("TextSnippets.json")
	global TextSnippetsJson := jxon_load(&fileContent)
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

try
{
	hotStringsFilePath := "HotStrings.json"
	if FileExist(hotStringsFilePath)
	{
		fileContent := FileRead(hotStringsFilePath)
		hotstringsJson := jxon_load(&fileContent)

		DynamicHotstrings_Register(hotstringsJson)
		;DynamicHotstrings_ShowDiagnostics()
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

try
{
	autoPastesFilePath := "AutoPastes.json"
	if FileExist(autoPastesFilePath)
	{
		fileContent := FileRead(autoPastesFilePath)
		autoPastesJson := jxon_load(&fileContent)

		AutoPaste_Register(autoPastesJson)
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
