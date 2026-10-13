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
; Windows Task Scheduler tasks, configured per profile in [ScheduledTasks].
; Checkmarks always describe *running instances*, not the Enabled setting.

Menu_TaskRunner_ToggleScheduledTaskRunning(taskPath, displayName, *)
{
    try
    {
        wasRunning := ScheduledTasksManager.IsRunning(taskPath)
        ScheduledTasksManager.SetRunning(taskPath, !wasRunning)

        TrayTip(
            "Scheduled Tasks",
            displayName ": "
                . (wasRunning ? "stop requested" : "start requested")
                . ". Check the menu again for the actual state."
        )
    }
    catch Error as e
    {
        MsgBox(
            "Could not start/stop scheduled task '" displayName "' (" taskPath "):"
                . Chr(10) e.Message,
            "MyWinToolbox - Scheduled Tasks",
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
            "Scheduled Tasks",
            displayName ": scheduling " (enabled ? "enabled" : "disabled")
                . ". This does not start/stop a running instance."
        )
    }
    catch Error as e
    {
        MsgBox(
            "Could not change scheduling for '" displayName "' (" taskPath "):"
                . Chr(10) e.Message,
            "MyWinToolbox - Scheduled Tasks",
            "Iconx"
        )
    }
}

Menu_TaskRunner_RefreshScheduledTasks()
{
    global scheduledTasksMenu, scheduledTasksEnabledMenu, ProfileConfigFilePath

    scheduledTasksMenu.Delete()
    scheduledTasksEnabledMenu.Delete()
    try
    {
        entries := Ini_GetSectionEntries(ProfileConfigFilePath, "ScheduledTasks")
        if (entries.Count = 0)
        {
            scheduledTasksMenu.Add("(no configured tasks)", (*) => 0)
            scheduledTasksMenu.Disable("(no configured tasks)")
            return
        }

        service := ScheduledTasksManager.Connect()
        for displayName, taskPath in entries
        {
            try
            {
                path := ScheduledTasksManager.NormalizePath(taskPath)
                status := ScheduledTasksManager.GetTaskStatus(service, path)
                state := status["State"]
                isRunning := status["Running"]
                isEnabled := status["Enabled"]

                ; The main task toggle controls the current process run state.
                ; Its checkmark means Running, even if scheduling is enabled.
                taskLabel := displayName " [" ScheduledTasksManager.GetStateLabel(state) "]"
                scheduledTasksMenu.Add(
                    taskLabel,
                    Menu_TaskRunner_ToggleScheduledTaskRunning.Bind(path, displayName)
                )
                if (isRunning)
                {
                    scheduledTasksMenu.Check(taskLabel)
                }
                else if (state = 2 || state = 0 || !isEnabled)
                {
                    ; Queued/unknown/disabled tasks cannot be started here.
                    ; Use the scheduling submenu to enable a disabled task.
                    scheduledTasksMenu.Disable(taskLabel)
                }

                ; Separate controls govern whether scheduled triggers can run.
                scheduledTasksEnabledMenu.Add(
                    displayName,
                    Menu_TaskRunner_ToggleScheduledTaskEnabled.Bind(path, displayName)
                )
                if (isEnabled)
                {
                    scheduledTasksEnabledMenu.Check(displayName)
                }
            }
            catch Error as e
            {
                Logger.Warning(displayName ": " e.Message, "ScheduledTasks")
                unavailableLabel := displayName " [unavailable]"
                scheduledTasksMenu.Add(unavailableLabel, (*) => 0)
                scheduledTasksMenu.Disable(unavailableLabel)
                scheduledTasksEnabledMenu.Add(unavailableLabel, (*) => 0)
                scheduledTasksEnabledMenu.Disable(unavailableLabel)
            }
        }

        scheduledTasksMenu.Add()
        scheduledTasksMenu.Add(
            "Scheduling (Enable / Disable)",
            scheduledTasksEnabledMenu
        )
    }
    catch Error as e
    {
        Logger.Error(e.Message, "ScheduledTasks")
        scheduledTasksMenu.Delete()
        scheduledTasksEnabledMenu.Delete()
        scheduledTasksMenu.Add("(Task Scheduler unavailable)", (*) => 0)
        scheduledTasksMenu.Disable("(Task Scheduler unavailable)")
    }
}

; --------------------------------------------------------------------------------
; Independent AutoHotkey v2 scripts, configured in [AhkScripts].
; A checkmark means the exact script has a running AHK main window.

Menu_TaskRunner_ToggleAhkScript(scriptPath, rootPath, displayName, *)
{
    try
    {
        started := AhkScriptManager.Toggle(scriptPath, rootPath)
        TrayTip(
            "AHK Scripts",
            displayName ": " (started ? "start requested" : "close requested")
        )
    }
    catch Error as e
    {
        MsgBox(
            "Could not toggle AHK script '" displayName "':" Chr(10) e.Message,
            "MyWinToolbox - AHK Scripts",
            "Iconx"
        )
    }
}

Menu_TaskRunner_RefreshAhkScripts()
{
    global ahkScriptsMenu, ProfileConfigFilePath

    ahkScriptsMenu.Delete()

    try
    {
        entries := Ini_GetSectionEntries(ProfileConfigFilePath, "AhkScripts")
        rootPath := Ini_ReadOrDefault(
            ProfileConfigFilePath, "AhkScriptsSettings", "Root", ""
        )

        if (entries.Count = 0)
        {
            ahkScriptsMenu.Add("(no configured scripts)", (*) => 0)
            ahkScriptsMenu.Disable("(no configured scripts)")
            return
        }

        for displayName, scriptPath in entries
        {
            try
            {
                fullPath := AhkScriptManager.ResolveScriptPath(scriptPath, rootPath)
                isRunning := AhkScriptManager.IsRunning(fullPath)

                if (!isRunning && !FileExist(fullPath))
                {
                    label := displayName " [missing]"
                    ahkScriptsMenu.Add(label, (*) => 0)
                    ahkScriptsMenu.Disable(label)
                    continue
                }

                label := displayName (isRunning ? " [Running]" : " [Stopped]")
                ahkScriptsMenu.Add(
                    label,
                    Menu_TaskRunner_ToggleAhkScript.Bind(scriptPath, rootPath, displayName)
                )
                if (isRunning)
                {
                    ahkScriptsMenu.Check(label)
                }
            }
            catch Error as e
            {
                Logger.Warning(displayName ": " e.Message, "AhkScripts")
                label := displayName " [unavailable]"
                ahkScriptsMenu.Add(label, (*) => 0)
                ahkScriptsMenu.Disable(label)
            }
        }
    }
    catch Error as e
    {
        Logger.Error(e.Message, "AhkScripts")
        ahkScriptsMenu.Delete()
        ahkScriptsMenu.Add("(AHK scripts configuration unavailable)", (*) => 0)
        ahkScriptsMenu.Disable("(AHK scripts configuration unavailable)")
    }
}

taskRunnerMenu := Menu()
taskRunnerMenu.SetColor("edf39f")
taskRunnerMenu.Add("NoSleep", Menu_TaskRunner_NoSleep)
taskRunnerMenu.Add("AutoPaste", Menu_TaskRunner_AutoPaste)

scheduledTasksMenu := Menu()
scheduledTasksEnabledMenu := Menu()
scheduledTasksMenu.Add("(open to refresh)", (*) => 0)
scheduledTasksMenu.Disable("(open to refresh)")
taskRunnerMenu.Add("Scheduled Tasks", scheduledTasksMenu)

ahkScriptsMenu := Menu()
ahkScriptsMenu.Add("(open to refresh)", (*) => 0)
ahkScriptsMenu.Disable("(open to refresh)")
taskRunnerMenu.Add("AHK Scripts", ahkScriptsMenu)

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
    Menu_TaskRunner_RefreshScheduledTasks()
    Menu_TaskRunner_RefreshAhkScripts()
    taskRunnerMenu.Show()
}
