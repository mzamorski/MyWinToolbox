#Requires AutoHotkey v2.0

#Include Constants.ahk
#Include Libs\ConfigUtils.ahk

global ConfigFilePath := A_ScriptName . ".config"

;========================================================================================================================
; HOT-STRINGS
;========================================================================================================================

Hotstring(":0*:@k=", Config_GetEmail())

Config_GetEmail() 
{
	return IniReadOrDefault(ConfigFilePath, "Settings", "Email")
}