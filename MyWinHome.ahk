#Requires AutoHotkey v2.0

#Include Constants.ahk
#Include Libs\ConfigUtils.ahk
#Include Libs\CryptoUtils.ahk

global ConfigFilePath := A_ScriptName . ".config"
global Secret := IniReadOrDefault(ConfigFilePath, "Settings", "Secret")

;========================================================================================================================
; HOT-STRINGS
;========================================================================================================================

Hotstring(":0*:@a=", Config_GetShippingAddress())
Hotstring(":0*:@p1", Config_GetPassword("1"))
Hotstring(":0*:@p2", Config_GetPassword("2"))
Hotstring(":0*:@p3", Config_GetPassword("3"))

Config_GetShippingAddress() 
{
	value := IniReadOrDefault(ConfigFilePath, "Settings", "ShippingAddress")

    return StrReplace(value, "\n", "`n")
}

Config_GetPassword(keyName) 
{
    value := IniReadOrDefault(ConfigFilePath, "Passwords", keyName)
    ;InputBox(, , , CryptoUtils.Encrypt(value, Secret))

    return CryptoUtils.Decrypt(value, Secret)
}