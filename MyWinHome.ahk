#Requires AutoHotkey v2.0

#Include Constants.ahk
#Include Libs\ConfigUtils.ahk

global ConfigFilePath := A_ScriptName . ".config"

;========================================================================================================================
; HOT-STRINGS
;========================================================================================================================

Hotstring(":0*:@a=", Config_GetShippingAddress())

Config_GetShippingAddress() 
{
	value := IniReadOrDefault(ConfigFilePath, "Settings", "ShippingAddress")

    return StrReplace(value, "\n", "`n")
}