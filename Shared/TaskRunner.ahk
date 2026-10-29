#Requires AutoHotkey v2.0

#Include ..\Libs\Constants.ahk
#Include ..\Libs\WinAPI.ahk
#Include ..\Libs\AutoPaste.ahk
#Include ..\Libs\TasksRegistry.ahk

; Standalone TaskRunner tests do not load Shared/Startup.ahk.
; Do not overwrite per-profile startup settings if Startup already set them.
if (!IsSet(StartupNoSleepEnabled))
    StartupNoSleepEnabled := false
if (!IsSet(StartupAutoPasteEnabled))
    StartupAutoPasteEnabled := false
if (!IsSet(StartupClipboardTrimEnabled))
    StartupClipboardTrimEnabled := false

global IsNoSleepTimerOn := false
global NoSleepNextMouseNudgeTick := 0
global ClipboardTrimEnabled := false
global LastClipboard := STRING_EMPTY

NoSleep_GetRandomMouseIntervalMs()
{
    return Random(60, 300) * SECOND_IN_MILLISECONDS
}

NoSleep_ShouldNudgeMouse(nowTick, idlePhysicalMs, nextNudgeTick)
{
    return (nextNudgeTick > 0
        && nowTick >= nextNudgeTick
        && idlePhysicalMs >= MINUTE_IN_MILLISECONDS)
}

OnNoSleep()
{
    ; Keeping Windows awake is independent of the idle mouse nudge.
    WinAPI_SetThreadExecutionState_DisplayRequired()
    WinAPI_SetThreadExecutionState_SystemRequired()
}

OnNoSleepMouseNudge()
{
    global NoSleepNextMouseNudgeTick

    ; Never move the cursor during normal physical keyboard/mouse activity.
    if (!NoSleep_ShouldNudgeMouse(A_TickCount, A_TimeIdlePhysical, NoSleepNextMouseNudgeTick))
    {
        return
    }

    MouseMove(1, 0, , "R")
    Sleep(1000)
    MouseMove(-1, 0, , "R")

    ; Choose a fresh random delay after every nudge, not only at startup.
    NoSleepNextMouseNudgeTick := A_TickCount + NoSleep_GetRandomMouseIntervalMs()
}

TaskRunner_SetNoSleepEnabled(enabled, notify := true)
{
    global IsNoSleepTimerOn, NoSleepNextMouseNudgeTick

    enabled := !!enabled

    if (enabled)
    {
        ; Apply the execution-state request immediately; schedule mouse activity
        ; separately, at random 1–5 minute intervals while physically idle.
        WinAPI_SetThreadExecutionState_DisplayRequired()
        WinAPI_SetThreadExecutionState_SystemRequired()
        NoSleepNextMouseNudgeTick := A_TickCount + NoSleep_GetRandomMouseIntervalMs()
        SetTimer(OnNoSleep, 60 * SECOND_IN_MILLISECONDS)
        SetTimer(OnNoSleepMouseNudge, 5 * SECOND_IN_MILLISECONDS)
        IsNoSleepTimerOn := true
    }
    else
    {
        SetTimer(OnNoSleep, 0)
        SetTimer(OnNoSleepMouseNudge, 0)
        NoSleepNextMouseNudgeTick := 0
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

; --------------------------------------------------------------------------------
; Unified Tasks menu: Task Scheduler instances and external AHK scripts.
; Checkmarks mean *currently running*, never simply enabled in the scheduler.

Menu_TaskRunner_ToggleTask(entry, *)
{
    try
    {
        result := TasksRegistry.Toggle(entry)
        TrayTip(
            "Tasks",
            entry["Name"] ": " result
                . ". Reopen the menu to check the actual state."
        )
    }
    catch Error as e
    {
        errorDetails := e.Message
            . Chr(10) "Source: " e.File ":" e.Line
        Logger.Error(
            "Cannot toggle '" entry["Name"] "' ("
                . entry["Type"] "|" entry["Value"] "): "
                . e.Message " (" e.File ":" e.Line ")",
            "Tasks"
        )
        MsgBox(
            "Could not toggle task '" entry["Name"] "':" Chr(10) errorDetails,
            "MyWinToolbox - Tasks",
            "Iconx"
        )
    }
}

Menu_TaskRunner_RefreshTasks()
{
    global tasksMenu, ProfileConfigFilePath

    tasksMenu.Delete()
    entries := []
    schedulerService := 0

    try
    {
        entries := TasksRegistry.LoadProfile(ProfileConfigFilePath)
    }
    catch Error as e
    {
        Logger.Error(e.Message, "Tasks")
        tasksMenu.Add("(Tasks configuration unavailable)", (*) => 0)
        tasksMenu.Disable("(Tasks configuration unavailable)")
        return
    }

    if (entries.Length = 0)
    {
        tasksMenu.Add("(no configured tasks)", (*) => 0)
        tasksMenu.Disable("(no configured tasks)")
        return
    }

    ; Type-independent presentation: the registry resolves execution
    ; details. Adding future task types does not add new menu categories.
    for configEntry in entries
    {
        name := configEntry["Name"]
        entry := 0
        try
        {
            entry := TasksRegistry.Parse(name, configEntry["Definition"])
            status := TasksRegistry.GetStatus(entry, &schedulerService)

            label := name " [" status["Status"] "]"
            tasksMenu.Add(label, Menu_TaskRunner_ToggleTask.Bind(entry))
            if (status["Running"])
            {
                tasksMenu.Check(label)
            }
            if (!status["CanToggle"])
            {
                tasksMenu.Disable(label)
            }
        }
        catch Error as e
        {
            Logger.Warning(
                name ": " e.Message " (" e.File ":" e.Line ")"
                    . " | definition=" configEntry["Definition"],
                "Tasks"
            )
            if (IsObject(entry) && entry["Type"] = TasksRegistry.AHK)
            {
                ; Even an unexpected status-rendering error must not disable
                ; a valid AHK definition. Clicking reports the actual failure.
                label := name " [Unknown]"
                tasksMenu.Add(label, Menu_TaskRunner_ToggleTask.Bind(entry))
            }
            else
            {
                ; Malformed definitions and Scheduler failures remain disabled.
                label := name " [unavailable]"
                tasksMenu.Add(label, (*) => 0)
                tasksMenu.Disable(label)
            }
        }
    }

}

taskRunnerMenu := Menu()
taskRunnerMenu.SetColor("edf39f")
taskRunnerMenu.Add("NoSleep", Menu_TaskRunner_NoSleep)
taskRunnerMenu.Add("AutoPaste", Menu_TaskRunner_AutoPaste)

tasksMenu := Menu()
tasksMenu.Add("(open to refresh)", (*) => 0)
tasksMenu.Disable("(open to refresh)")
taskRunnerMenu.Add("Tasks", tasksMenu)

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
    Menu_TaskRunner_RefreshTasks()
    taskRunnerMenu.Show()
}
