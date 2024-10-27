#Requires AutoHotkey v2.0

#Include Constants.ahk
#Include Libs\ConfigUtils.ahk
#Include Libs\CryptoUtils.ahk

global ConfigFilePath := A_ScriptName . CONFIG_FILE_EXTENSION
global Secret := Ini_ReadOrDefault(ConfigFilePath, "Settings", "Secret")

;========================================================================================================================
; HOT-STRINGS
;========================================================================================================================

Hotstring(":0*:@a=", Config_GetShippingAddress())
Hotstring(":0*:@p1", Config_GetPassword("1"))
Hotstring(":0*:@p2", Config_GetPassword("2"))
Hotstring(":0*:@p3", Config_GetPassword("3"))

Config_GetShippingAddress() 
{
	value := Ini_ReadOrDefault(ConfigFilePath, "Settings", "ShippingAddress")

    return StrReplace(value, "\n", "`n")
}

Config_GetPassword(keyName) 
{
    value := Ini_ReadOrDefault(ConfigFilePath, "Passwords", keyName)
    ;InputBox(, , , CryptoUtils.Encrypt(value, Secret))

    return CryptoUtils.Decrypt(value, Secret)
}

;========================================================================================================================
