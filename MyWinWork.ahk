#Requires AutoHotkey v2.0

#Include Libs\ConfigUtils.ahk
#Include Libs\WinAPI.ahk
#Include Constants.ahk
#Include MyWinShared.ahk

;========================================================================================================================
; STARTUP
;========================================================================================================================

conflictingScriptName := "MyWinHome.ahk"
if WinExist(conflictingScriptName)
{
    MsgBox("Another instance of a conflicting script '" . conflictingScriptName . "' is already running.`n`nThis script cannot operate concurrently and will now terminate."
        ,"Execution Blocked", "Iconx"
    )
    ExitApp(-1)
}



global ConfigFilePath := A_ScriptName . CONFIG_FILE_EXTENSION

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

OnTimerShutdown()
{
	Traytip("Shutdown", "The system is now shutting down.")	
	Sleep(3 * 1000)
	Shutdown(0) 
}

OnTaskRunnerShutdown(delayInSeconds)
{
	SetTimer(OnTimerShutdown, delayInSeconds * SECOND_IN_MILLISECONDS)

	Traytip("Shutdown", "The system will shut down in " . delayInSeconds . " seconds.")	
}

Menu_TaskRunner_NoSleep(itemName, itemPos, menu)
{
	Send("^#a")

	menu.ToggleCheck(itemName)
}

Menu_TaskRunner_Shutdown_1h(*)
{
	OnTaskRunnerShutdown(3600 * SECOND_IN_MILLISECONDS)
}

Menu_TaskRunner_Shutdown_2h(*)
{
	OnTaskRunnerShutdown(7200 * SECOND_IN_MILLISECONDS)
}

Menu_TaskRunner_Shutdown_Cancel(*)
{
	SetTimer(OnTimerShutdown, 0)

	Traytip("Shutdown", "Canceled.")
}

;--------------------------------------------------------------------------------
; Create menus. 

taskRunnerMenu := Menu()
taskRunnerMenu.SetColor("edf39f")

taskRunnerMenu.Add("NoSleep", Menu_TaskRunner_NoSleep)

shutdownMenu := Menu()
shutdownMenu.Add("1h", Menu_TaskRunner_Shutdown_1h)
shutdownMenu.Add("2h", Menu_TaskRunner_Shutdown_2h)
shutdownMenu.Add()
shutdownMenu.Add("Cancel", Menu_TaskRunner_Shutdown_Cancel)

taskRunnerMenu.Add("Shutdown", shutdownMenu)

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
