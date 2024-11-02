#Requires AutoHotkey v2.0

#Include Libs\ConfigUtils.ahk
#Include Libs\CryptoUtils.ahk
#Include Libs\Std.ahk
#Include Libs\Constants.ahk
#Include MyWinShared.ahk

;========================================================================================================================
; STARTUP
;========================================================================================================================

conflictingScriptName := "MyWinWork.ahk"
if WinExist(conflictingScriptName)
{
    MsgBox("Another instance of a conflicting script '" . conflictingScriptName . "' is already running.`n`nThis script cannot operate concurrently and will now terminate."
        ,"Execution Blocked", "Iconx"
    )

    ExitApp(-1)
}

global ConfigFilePath := A_ScriptName . CONFIG_FILE_EXTENSION
global Secret := Ini_ReadOrDefault(ConfigFilePath, "Settings", "Secret")
global PasswordEntries := Ini_GetSectionEntries(ConfigFilePath, "Passwords")



;========================================================================================================================
; FUNCTIONS
;========================================================================================================================

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
; HOTSTRINGS
;========================================================================================================================

Hotstring(":0*:@a=", Config_GetShippingAddress())



;========================================================================================================================
; CONTEXT-MENUS
;========================================================================================================================

Menu_PastePassword(itemName, itemPos, menu)
{
    value := PasswordEntries[itemName]
    output := CryptoUtils.Decrypt(value, Secret)

    Std_Paste(output)
}

;--------------------------------------------------------------------------------
; Create menus. 

passwordMenu := Menu()
passwordMenu.SetColor("ff2d2d")
for key, value in PasswordEntries
{
    passwordMenu.Add(key, Menu_PastePassword, "BarBreak")
}



;========================================================================================================================
; HOTKEYS
;========================================================================================================================

#^p::
{
	passwordMenu.Show()
}