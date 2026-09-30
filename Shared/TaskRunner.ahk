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

TaskRunner_SetNoSleepEnabled(enabled, notify := true)
{
    global IsNoSleepTimerOn

    enabled := !!enabled

    if (enabled)
    {
        ; Apply the execution-state request immediately instead of waiting for
        ; the first timer tick.
        OnNoSleep()
        SetTimer(OnNoSleep, 60 * SECOND_IN_MILLISECONDS)
        IsNoSleepTimerOn := true
    }
    else
    {
        SetTimer(OnNoSleep, 0)
        WinAPI_SetThreadExecutionState_Continuous()
        IsNoSleepTimerOn := false
    }

    if (notify)
    {
        TrayTip(
            "NoSleep",
            IsNoSleepTimerOn ? "Activated" : "Deactivated"
        )
    }

    return IsNoSleepTimerOn
}

TaskRunner_SetClipboardTrimEnabled(enabled, notify := true)
{
    global ClipboardTrimEnabled, LastClipboard

    ClipboardTrimEnabled := !!enabled

    if (ClipboardTrimEnabled)
    {
        LastClipboard := A_Clipboard
        SetTimer(OnTaskRunnerClipboardTrim, 500)
    }
    else
    {
        SetTimer(OnTaskRunnerClipboardTrim, 0)
    }

    if (notify)
    {
        TrayTip(
            "TaskRunner",
            "Monitoring clipboard "
                . (ClipboardTrimEnabled ? "enabled" : "disabled")
        )
    }

    return ClipboardTrimEnabled
}

TaskRunner_SetAutoPasteEnabled(enabled, notify := true)
{
    actualState := AutoPaste_SetEnabled(!!enabled)

    if (notify)
    {
        TrayTip(
            "TaskRunner",
            "AutoPaste " . (actualState ? "enabled" : "disabled")
        )
    }

    return actualState
}

TaskRunner_SyncMenuChecks()
{
    global IsNoSleepTimerOn, ClipboardTrimEnabled, taskRunnerMenu, clipboardMenu

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

    if (ClipboardTrimEnabled)
    {
        clipboardMenu.Check("Trim")
    }
    else
    {
        clipboardMenu.Uncheck("Trim")
    }
}

TaskRunner_ApplyStartupDefaults()
{
    global StartupNoSleepEnabled
    global StartupAutoPasteEnabled
    global StartupClipboardTrimEnabled

    TaskRunner_SetNoSleepEnabled(StartupNoSleepEnabled, false)
    TaskRunner_SetAutoPasteEnabled(StartupAutoPasteEnabled, false)
    TaskRunner_SetClipboardTrimEnabled(StartupClipboardTrimEnabled, false)
    TaskRunner_SyncMenuChecks()

    Logger.Info(
        "Startup defaults: NoSleep="
            . (StartupNoSleepEnabled ? "on" : "off")
            . ", AutoPaste="
            . (StartupAutoPasteEnabled ? "on" : "off")
            . ", ClipboardTrim="
            . (StartupClipboardTrimEnabled ? "on" : "off"),
        "TaskRunner"
    )
}

^#a::
{
    global IsNoSleepTimerOn

    TaskRunner_SetNoSleepEnabled(!IsNoSleepTimerOn)
    TaskRunner_SyncMenuChecks()
}

OnTimerShutdown()
{
    TrayTip("Shutdown", "The system is now shutting down.")
    Sleep(3 * SECOND_IN_MILLISECONDS)
    Shutdown(0)
}

OnTaskRunnerShutdown(delayInSeconds)
{
    SetTimer(
        OnTimerShutdown,
        -delayInSeconds * SECOND_IN_MILLISECONDS
    )

    TrayTip(
        "Shutdown",
        "The system will shut down in " . delayInSeconds . " seconds."
    )
}

Menu_TaskRunner_NoSleep(*)
{
    global IsNoSleepTimerOn

    TaskRunner_SetNoSleepEnabled(!IsNoSleepTimerOn)
    TaskRunner_SyncMenuChecks()
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

Menu_TaskRunner_Clipboard_Trim(*)
{
    global ClipboardTrimEnabled

    TaskRunner_SetClipboardTrimEnabled(!ClipboardTrimEnabled)
    TaskRunner_SyncMenuChecks()
}

Menu_TaskRunner_AutoPaste(*)
{
    TaskRunner_SetAutoPasteEnabled(!AutoPaste_IsEnabled())
    TaskRunner_SyncMenuChecks()
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

TaskRunner_ApplyStartupDefaults()

^#t::
{
    TaskRunner_SyncMenuChecks()
    taskRunnerMenu.Show()
}
