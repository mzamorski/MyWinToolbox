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
        ; Apply the execution-state request immediately without triggering the
        ; idle mouse nudge that belongs to the periodic maintenance callback.
        WinAPI_SetThreadExecutionState_DisplayRequired()
        WinAPI_SetThreadExecutionState_SystemRequired()
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

; --------------------------------------------------------------------------------
; Unified Tasks menu: Task Scheduler instances and external AHK scripts.
; Checkmarks mean *currently running*, never simply enabled in the scheduler.

Menu_TaskRunner_ToggleScheduledTaskRunning(taskPath, displayName, *)
{
    try
    {
        wasRunning := ScheduledTasksManager.IsRunning(taskPath)
        ScheduledTasksManager.SetRunning(taskPath, !wasRunning)
        TrayTip(
            "Tasks",
            displayName ": " (wasRunning ? "stop requested" : "start requested")
                . ". Reopen the menu to check the current state."
        )
    }
    catch Error as e
    {
        MsgBox(
            "Could not start/stop scheduled task '" displayName "' (" taskPath "):"
                . Chr(10) e.Message,
            "MyWinToolbox - Tasks",
            "Iconx"
        )
    }
}

Menu_TaskRunner_ToggleScheduledTaskEnabled(taskPath, displayName, *)
{
    try
    {
        enabled := ScheduledTasksManager.SetEnabled(
            taskPath,
            !ScheduledTasksManager.IsEnabled(taskPath)
        )
        TrayTip(
            "Tasks",
            displayName ": scheduling " (enabled ? "enabled" : "disabled")
                . ". This does not start/stop running instances."
        )
    }
    catch Error as e
    {
        MsgBox(
            "Could not change scheduling for '" displayName "' (" taskPath "):"
                . Chr(10) e.Message,
            "MyWinToolbox - Tasks",
            "Iconx"
        )
    }
}

Menu_TaskRunner_ToggleAhkScript(scriptPath, displayName, *)
{
    try
    {
        started := AhkScriptManager.Toggle(scriptPath)
        TrayTip(
            "Tasks",
            displayName ": " (started ? "start requested" : "close requested")
        )
    }
    catch Error as e
    {
        MsgBox(
            "Could not toggle AHK script '" displayName "':" Chr(10) e.Message,
            "MyWinToolbox - Tasks",
            "Iconx"
        )
    }
}

Menu_TaskRunner_RefreshTasks()
{
    global tasksMenu, tasksEnabledMenu, ProfileConfigFilePath

    tasksMenu.Delete()
    tasksEnabledMenu.Delete()
    count := 0

    ; Scheduler COM errors should never hide unrelated configured AHK scripts.
    try
    {
        scheduled := Ini_GetSectionEntries(ProfileConfigFilePath, "ScheduledTasks")
        if (scheduled.Count > 0)
        {
            try
            {
                service := ScheduledTasksManager.Connect()
                for displayName, taskPath in scheduled
                {
                    try
                    {
                        path := ScheduledTasksManager.NormalizePath(taskPath)
                        status := ScheduledTasksManager.GetTaskStatus(service, path)
                        state := status["State"]
                        isRunning := status["Running"]
                        isEnabled := status["Enabled"]

                        label := "Scheduler: " displayName
                            . " [" ScheduledTasksManager.GetStateLabel(state) "]"
                        tasksMenu.Add(
                            label,
                            Menu_TaskRunner_ToggleScheduledTaskRunning.Bind(path, displayName)
                        )
                        if (isRunning)
                        {
                            tasksMenu.Check(label)
                        }
                        else if (state = 2 || state = 0 || !isEnabled)
                        {
                            tasksMenu.Disable(label)
                        }

                        tasksEnabledMenu.Add(
                            displayName,
                            Menu_TaskRunner_ToggleScheduledTaskEnabled.Bind(path, displayName)
                        )
                        if (isEnabled)
                        {
                            tasksEnabledMenu.Check(displayName)
                        }
                    }
                    catch Error as e
                    {
                        Logger.Warning(displayName ": " e.Message, "Tasks")
                        label := "Scheduler: " displayName " [unavailable]"
                        tasksMenu.Add(label, (*) => 0)
                        tasksMenu.Disable(label)
                    }
                    count += 1
                }
            }
            catch Error as e
            {
                Logger.Error(e.Message, "Tasks")
                tasksMenu.Add("(Task Scheduler unavailable)", (*) => 0)
                tasksMenu.Disable("(Task Scheduler unavailable)")
                count += 1
            }
        }
    }
    catch Error as e
    {
        Logger.Error(e.Message, "Tasks")
    }

    try
    {
        scripts := Ini_GetSectionEntries(ProfileConfigFilePath, "AhkScripts")
        if (scripts.Count > 0 && count > 0)
        {
            tasksMenu.Add()
        }

        for displayName, scriptPath in scripts
        {
            try
            {
                fullPath := AhkScriptManager.ResolveScriptPath(scriptPath)
                running := AhkScriptManager.IsRunning(fullPath)
                if (!running && !FileExist(fullPath))
                {
                    label := "AHK: " displayName " [missing]"
                    tasksMenu.Add(label, (*) => 0)
                    tasksMenu.Disable(label)
                    continue
                }

                label := "AHK: " displayName (running ? " [Running]" : " [Stopped]")
                tasksMenu.Add(
                    label,
                    Menu_TaskRunner_ToggleAhkScript.Bind(fullPath, displayName)
                )
                if (running)
                {
                    tasksMenu.Check(label)
                }
            }
            catch Error as e
            {
                Logger.Warning(displayName ": " e.Message, "Tasks")
                label := "AHK: " displayName " [unavailable]"
                tasksMenu.Add(label, (*) => 0)
                tasksMenu.Disable(label)
            }
            count += 1
        }
    }
    catch Error as e
    {
        Logger.Error(e.Message, "Tasks")
    }

    if (tasksEnabledMenu.GetCount() > 0)
    {
        tasksMenu.Add()
        tasksMenu.Add("Scheduling (Enable / Disable)", tasksEnabledMenu)
    }

    if (count = 0)
    {
        tasksMenu.Add("(no configured tasks)", (*) => 0)
        tasksMenu.Disable("(no configured tasks)")
    }
}

taskRunnerMenu := Menu()
taskRunnerMenu.SetColor("edf39f")
taskRunnerMenu.Add("NoSleep", Menu_TaskRunner_NoSleep)
taskRunnerMenu.Add("AutoPaste", Menu_TaskRunner_AutoPaste)

tasksMenu := Menu()
tasksEnabledMenu := Menu()
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
