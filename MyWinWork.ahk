#Requires AutoHotkey v2.0

#Include Constants.ahk
#Include Libs\ConfigUtils.ahk
#Include Libs\WinAPI.ahk

global ConfigFilePath := A_ScriptName . CONFIG_FILE_EXTENSION

Config_GetEmail() 
{
	return Ini_ReadOrDefault(ConfigFilePath, "Settings", "Email")
}

; SQL_Snippet_TryCatch()
; {
; 	return "BEGIN TRY{Enter 2}END TRY{Enter 2}BEGIN CATCH{Enter 2}END CATCH{Esc}{Up 4}"
; }

; SQL_Snippet_Break()
; {
; 	return "THROW 50000, 'This script should not be run as a whole. It contains manual operations (step-by-step).', 1"
; }

;========================================================================================================================
; HOTSTRINGS
;========================================================================================================================

Hotstring(":0*:@k=", Config_GetEmail())

#HotIf WinActive("ahk_exe ssms.exe")

	:*:try::BEGIN TRY{Enter 2}END TRY{Enter 2}BEGIN CATCH{Enter 2}END CATCH{Esc}{Up 5}

	:*:break::THROW 50000, 'This script should not be run as a whole. It contains manual operations (step-by-step).', 1

#HotIf

;========================================================================================================================
; HOTKEYS
;========================================================================================================================

global IsNoSleepTimerOn := false

OnNoSleep()
{
	WinAPI_SetThreadExecutionState_DisplayRequired()
	WinAPI_SetThreadExecutionState_SystemRequired()
	
	/*
	; Mouse move if idle...
	if ( A_TimeIdle > 10000 ) 
	{
		MouseMove, 10 , 0,, R
		Sleep, 1000
		MouseMove, -10, 0,, R
	}
	*/	
}

^#a::
{	 
	global IsNoSleepTimerOn

	if (!IsNoSleepTimerOn)
	{
		SetTimer(OnNoSleep, 60000)
		IsNoSleepTimerOn := true
		
		Traytip("NoSleep", "Activated")
	}
	else
	{
		WinAPI_SetThreadExecutionState_Continuous()
		
		SetTimer(OnNoSleep, 0)
		IsNoSleepTimerOn := false

		Traytip("NoSleep", "Deactivated")
	}

	return
}

;========================================================================================================================
; CONTEXT-MENUS
;========================================================================================================================

Menu_TaskRunner_NoSleep(itemName, itemPos, menu)
{
	Send("^#a")

	menu.ToggleCheck(itemName)
}

;--------------------------------------------------------------------------------
; Create menus. 

taskRunnerMenu := Menu()
taskRunnerMenu.SetColor("edf39f")

taskRunnerMenu.Add("NoSleep", Menu_TaskRunner_NoSleep)

;--------------------------------------------------------------------------------

^#t::
{
	if (IsNoSleepTimerOn)
	{
		taskRunnerMenu.Check("NoSleep")
	}
	else
	{
		taskRunnerMenu.Uncheck("NoSleep")
	}

	taskRunnerMenu.Show()
}
