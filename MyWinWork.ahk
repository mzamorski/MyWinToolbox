#Requires AutoHotkey v2.0
#SingleInstance Force

#Include Libs\ConfigUtils.ahk
#Include Libs\WinAPI.ahk
#Include Libs\Constants.ahk
#Include MyWinShared.ahk



;========================================================================================================================
; STARTUP
;========================================================================================================================

conflictingScriptName := "MyWinHome.ahk"
if WinExist(conflictingScriptName . " ahk_class AutoHotkey")
{
    MsgBox("Another instance of a conflicting script '" . conflictingScriptName . "' is already running.`n`nThis script cannot operate concurrently and will now terminate."
        ,"Execution Blocked", "Iconx"
    )
    ExitApp(-1)
}



;========================================================================================================================
; GLOBALS
;========================================================================================================================

global ConfigFilePath := A_ScriptName . CONFIG_FILE_EXTENSION



;========================================================================================================================
; HOTSTRINGS
;========================================================================================================================

Hotstring(":0*:@k=", Config_GetEmail())

#HotIf WinActive("ahk_exe ssms.exe")

	::try=::BEGIN TRY{Enter 2}END TRY{Enter 2}BEGIN CATCH{Enter 2}END CATCH{Esc}{Up 5}

	::break=::THROW 50000, 'This script should not be run as a whole. It contains manual operations (step-by-step).', 1

	::nl=::WITH (NOLOCK)

	::dt=::DROP TABLE IF EXISTS{Space}

	::sel=::
	{
		tableName := A_Clipboard
		sqlCommand := "SELECT TOP 100`n`tt.*`nFROM " . tableName . " AS t WITH (NOLOCK)`nWHERE`n`t"
	
		Send(sqlCommand)
	}

	::dirty::SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

#HotIf
