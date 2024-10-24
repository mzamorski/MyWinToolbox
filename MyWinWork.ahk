#Requires AutoHotkey v2.0

#Include Constants.ahk
#Include Libs\ConfigUtils.ahk

global ConfigFilePath := A_ScriptName . ".config"

Config_GetEmail() 
{
	return IniReadOrDefault(ConfigFilePath, "Settings", "Email")
}

SQL_Snippet_TryCatch()
{
	return "BEGIN TRY{Enter 2}END TRY{Enter 2}BEGIN CATCH{Enter 2}END CATCH{Esc}{Up 4}"
}

SQL_Snippet_Break()
{
	return "THROW 50000, 'This script should not be run as a whole. It contains manual operations (step-by-step).', 1"
}

;========================================================================================================================
; HOT-STRINGS
;========================================================================================================================

Hotstring(":0*:@k=", Config_GetEmail())

Hotstring(":*:try", SQL_Snippet_TryCatch())
Hotstring(":*:break", SQL_Snippet_Break())