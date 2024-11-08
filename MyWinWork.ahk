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
if WinExist(conflictingScriptName)
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

	::try::BEGIN TRY{Enter 2}END TRY{Enter 2}BEGIN CATCH{Enter 2}END CATCH{Esc}{Up 5}

	::break::THROW 50000, 'This script should not be run as a whole. It contains manual operations (step-by-step).', 1

	::nl::WITH (NOLOCK)

#HotIf



;========================================================================================================================
; HOTKEYS
;========================================================================================================================

global IsNoSleepTimerOn := false

OnNoSleep()
{
	WinAPI_SetThreadExecutionState_DisplayRequired()
	WinAPI_SetThreadExecutionState_SystemRequired()
	
	if ( A_TimeIdle > 10 * SECOND_IN_MILLISECONDS) 
	{
		MouseMove(1, 0, , "R")
		Sleep(1000)
		MouseMove(-1, 0, , "R")
	}	
}

^#a::
{	 
	global IsNoSleepTimerOn

	if (!IsNoSleepTimerOn)
	{
		SetTimer(OnNoSleep, 60 * SECOND_IN_MILLISECONDS)
		IsNoSleepTimerOn := true
		
		TrayTip("NoSleep", "Activated")
	}
	else
	{
		WinAPI_SetThreadExecutionState_Continuous()
		
		SetTimer(OnNoSleep, 0)
		IsNoSleepTimerOn := false

		TrayTip("NoSleep", "Deactivated")
	}

	return
}



;========================================================================================================================
; CONTEXT-MENUS
;========================================================================================================================

OnTimerShutdown()
{
	TrayTip("Shutdown", "The system is now shutting down.")	
	Sleep(3 * SECOND_IN_MILLISECONDS)
	Shutdown(0) 
}

OnTaskRunnerShutdown(delayInSeconds)
{
	SetTimer(OnTimerShutdown, delayInSeconds * SECOND_IN_MILLISECONDS)

	TrayTip("Shutdown", "The system will shut down in " . delayInSeconds . " seconds.")	
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

	TrayTip("Shutdown", "Canceled.")
}

;--------------------------------------------------------------------------------
; Create menus. 

taskRunnerMenu := Menu()
taskRunnerMenu.SetColor("edf39f")

; "NoSleep"

taskRunnerMenu.Add("NoSleep", Menu_TaskRunner_NoSleep)

; "Shutdown"

shutdownMenu := Menu()
shutdownMenu.Add("1h", Menu_TaskRunner_Shutdown_1h)
shutdownMenu.Add("2h", Menu_TaskRunner_Shutdown_2h)
shutdownMenu.Add()
shutdownMenu.Add("Cancel", Menu_TaskRunner_Shutdown_Cancel)

taskRunnerMenu.Add("Shutdown", shutdownMenu)

; "Clipboard"

global ClipboardTrimEnabled := false
global LastClipboard := STRING_EMPTY

OnTaskRunnerClipboardTrim()
{
	global ClipboardTrimEnabled, LastClipboard

    if (!ClipboardTrimEnabled)
	{
        return
	}

    if (A_Clipboard != LastClipboard) 
    {
        LastClipboard := A_Clipboard

        try
        {
            ;A_Clipboard := RegExReplace(LastClipboard, "^\s+|\s+$", STRING_EMPTY)
			A_Clipboard := Trim(LastClipboard, " `t`r`n")
        }
        catch Error as e
        {
            TrayTip(e.What . ": " . e.Message, "TaskRunner")
        }
    }
}

Menu_TaskRunner_Clipboard_Trim(itemName, itemPos, menu)
{
	global ClipboardTrimEnabled
	
	ClipboardTrimEnabled := !ClipboardTrimEnabled

	if (ClipboardTrimEnabled)
	{
		SetTimer(OnTaskRunnerClipboardTrim, 500) 
		menu.Check(itemName)
	}
	else
	{
		SetTimer(OnTaskRunnerClipboardTrim, 0) 
		menu.Uncheck(itemName)
	}

	TrayTip("Monitoring clipboard " . (ClipboardTrimEnabled ? "enabled" : "disabled"))
}

subMenu := Menu()
subMenu.Add("Trim", Menu_TaskRunner_Clipboard_Trim)

taskRunnerMenu.Add("Clipboard", subMenu)

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
