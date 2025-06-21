#Requires AutoHotkey v2.0
#SingleInstance Force

#Include Libs\ConfigUtils.ahk
#Include Libs\CryptoUtils.ahk
#Include Libs\Std.ahk
#Include Libs\Constants.ahk
#Include Libs\Browser.ahk
#Include Libs\WindowApp.ahk
#Include Libs\Uri.ahk
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

HandlePassword(appName, entries, secret, outputHandler := Std_Paste) 
{
    for key, value in entries 
    {
        if (key = appName) 
        {
            output := CryptoUtils.Decrypt(value, secret)
            outputHandler.Call(output)

            return true
        }
    }
    
    return false
}

#^p::
{
    found := false

    appName := "KeePass"
    if (WindowApp.IsActive(appName))
    {
        if (HandlePassword(appName, PasswordEntries, Secret))
        {
            found := true
        }
    }
    else if (WindowApp.IsBrowserActive())
    {
        url := Browser.GetURL()

        appName := "XTB"
        if (Uri.Contains(url, appName))
        {
            ;if (HandlePassword(appName, PasswordEntries, Secret, (output) => A_Clipboard := output))
            if (HandlePassword(appName, PasswordEntries, Secret))
            {
                found := true
            }
        }
    }

    if (!found)
    {
        passwordMenu.Show()
    }

    return
}
