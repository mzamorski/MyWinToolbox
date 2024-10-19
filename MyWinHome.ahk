#Requires AutoHotkey v2.0

#Include Constants.ahk

global ConfigFilePath := A_ScriptName . ".config"

;========================================================================================================================
; HOT-STRINGS
;========================================================================================================================

Hotstring(":0*:@a=", Config_GetShippingAddress())

Config_GetShippingAddress() 
{
	value := IniRead(ConfigFilePath, "Settings", "ShippingAddress", UNKNOWN)

    return StrReplace(value, "\n", "`n")
}