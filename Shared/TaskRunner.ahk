#Requires AutoHotkey v2.0

#Include ..\Libs\Constants.ahk
#Include ..\Libs\WinAPI.ahk
#Include ..\Libs\AutoPaste.ahk

global IsNoSleepTimerOn := false
global ClipboardTrimEnabled := false
global LastClipboard := STRING_EMPTY

OnNoSleep()
{
	WinAPI_SetThreadExecutionState_DisplayRequired()
	WinAPI_SetThreadExecutionState_SystemRequired()

	if (A_TimeIdle > 10 * MINUTE_IN_MILLISECONDS)
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
}

OnTimerShutdown()
{
	TrayTip("Shutdown", "The system is now shutting down.")
	Sleep(3 * SECOND_IN_MILLISECONDS)
	Shutdown(0)
}

OnTaskRunnerShutdown(delayInSeconds)
{
	SetTimer(OnTimerShutdown, -delayInSeconds * SECOND_IN_MILLISECONDS)

	TrayTip("Shutdown", "The system will shut down in " . delayInSeconds . " seconds.")
}

Menu_TaskRunner_NoSleep(itemName, itemPos, menu)
{
	Send("^#a")
	menu.ToggleCheck(itemName)
}

Menu_TaskRunner_Shutdown_1h(*)
{
	OnTaskRunnerShutdown(HOUR_IN_SECONDS)
}

Menu_TaskRunner_Shutdown_2h(*)
{
	OnTaskRunnerShutdown(2 * HOUR_IN_SECONDS)
}

Menu_TaskRunner_Shutdown_Cancel(*)
{
	SetTimer(OnTimerShutdown, 0)
	TrayTip("Shutdown", "Canceled.")
}

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

Menu_TaskRunner_AutoPaste(itemName, itemPos, menu)
{
	if (AutoPaste_Toggle())
	{
		menu.Check(itemName)
	}
	else
	{
		menu.Uncheck(itemName)
	}

	TrayTip("AutoPaste " . (AutoPaste_IsEnabled() ? "enabled" : "disabled"))
}

taskRunnerMenu := Menu()
taskRunnerMenu.SetColor("edf39f")
taskRunnerMenu.Add("NoSleep", Menu_TaskRunner_NoSleep)
taskRunnerMenu.Add("AutoPaste", Menu_TaskRunner_AutoPaste)

shutdownMenu := Menu()
shutdownMenu.Add("1h", Menu_TaskRunner_Shutdown_1h)
shutdownMenu.Add("2h", Menu_TaskRunner_Shutdown_2h)
shutdownMenu.Add()
shutdownMenu.Add("Cancel", Menu_TaskRunner_Shutdown_Cancel)
taskRunnerMenu.Add("Shutdown", shutdownMenu)

clipboardMenu := Menu()
clipboardMenu.Add("Trim", Menu_TaskRunner_Clipboard_Trim)
taskRunnerMenu.Add("Clipboard", clipboardMenu)

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

	if (AutoPaste_IsEnabled())
	{
		taskRunnerMenu.Check("AutoPaste")
	}
	else
	{
		taskRunnerMenu.Uncheck("AutoPaste")
	}

	taskRunnerMenu.Show()
}
