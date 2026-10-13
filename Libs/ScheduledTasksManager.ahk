#Requires AutoHotkey v2.0

; Operates on Windows Task Scheduler tasks (not Windows services).
; Task names are resolved through the Task Scheduler COM API, without shell parsing.
class ScheduledTasksManager
{
    static NormalizePath(taskPath)
    {
        path := Trim("" taskPath)
        if (
            path = ""
            || InStr(path, "/")
            || InStr(path, Chr(34))
            || RegExMatch(path, "[\x00-\x1F]")
        )
        {
            throw Error("Invalid scheduled task path: " taskPath)
        }

        if (SubStr(path, 1, 1) != "\")
        {
            path := "\" path
        }

        if (SubStr(path, -1) = "\" || InStr(path, "\\"))
        {
            throw Error("Scheduled task path must identify a task: " taskPath)
        }

        return path
    }

    static ValidateEntries(entries)
    {
        seenNames := Map()
        seenPaths := Map()

        for entry in entries
        {
            name := Trim("" entry["Name"])
            if (
                name = ""
                || InStr(name, "=")
                || RegExMatch(name, "[\x00-\x1F]")
                || SubStr(name, 1, 1) = ";"
            )
            {
                throw Error("Invalid scheduled task menu label: " name)
            }

            nameKey := StrLower(name)
            if (seenNames.Has(nameKey))
            {
                throw Error("Duplicate scheduled task label: " name)
            }
            seenNames[nameKey] := true

            path := ScheduledTasksManager.NormalizePath(entry["Value"])
            pathKey := StrLower(path)
            if (seenPaths.Has(pathKey))
            {
                throw Error("Duplicate scheduled task path: " path)
            }
            seenPaths[pathKey] := true
        }

        return true
    }

    static Connect()
    {
        service := ComObject("Schedule.Service")
        service.Connect()
        return service
    }

    static GetTask(service, taskPath)
    {
        path := ScheduledTasksManager.NormalizePath(taskPath)
        separator := InStr(path, "\", , -1)
        folderPath := separator = 1 ? "\" : SubStr(path, 1, separator - 1)
        taskName := SubStr(path, separator + 1)
        return service.GetFolder(folderPath).GetTask(taskName)
    }

    static IsEnabled(taskPath)
    {
        service := ScheduledTasksManager.Connect()
        return !!ScheduledTasksManager.GetTask(service, taskPath).Enabled
    }

    ; TASK_STATE values exposed by IRegisteredTask.State.
    static IsRunningState(state)
    {
        return state = 4
    }

    static GetStateLabel(state)
    {
        switch state
        {
            case 1:
                return "Disabled"
            case 2:
                return "Queued"
            case 3:
                return "Ready"
            case 4:
                return "Running"
            default:
                return "Unknown"
        }
    }

    static GetTaskStatus(service, taskPath)
    {
        task := ScheduledTasksManager.GetTask(service, taskPath)
        state := task.State
        return Map(
            "State", state,
            "Running", ScheduledTasksManager.IsRunningState(state),
            "Enabled", !!task.Enabled
        )
    }

    static IsRunning(taskPath)
    {
        service := ScheduledTasksManager.Connect()
        return ScheduledTasksManager.IsRunningState(
            ScheduledTasksManager.GetTask(service, taskPath).State
        )
    }

    ; Running state is independent of whether the task is enabled for
    ; future triggers. Stop ends current instances, Run requests one now.
    static SetRunning(taskPath, shouldRun)
    {
        path := ScheduledTasksManager.NormalizePath(taskPath)
        shouldRun := !!shouldRun

        try
        {
            service := ScheduledTasksManager.Connect()
            task := ScheduledTasksManager.GetTask(service, path)
            state := task.State
            isRunning := ScheduledTasksManager.IsRunningState(state)

            if (shouldRun && !isRunning)
            {
                if (!task.Enabled)
                {
                    throw Error(
                        "Task is disabled in Task Scheduler. "
                            . "Enable it in Scheduling (Enable / Disable) before starting."
                    )
                }

                if (state = 2)
                {
                    throw Error("Task is queued. Wait for the queued run or change its schedule.")
                }

                task.Run("")
            }
            else if (!shouldRun && isRunning)
            {
                ; Stop(0) requests termination of all running instances.
                task.Stop(0)
            }
        }
        catch OSError as e
        {
            if (!ScheduledTasksManager.IsAccessDenied(e.Number))
            {
                throw
            }

            ScheduledTasksManager.SetRunningElevated(path, shouldRun)
        }

        ; Run/Stop can be asynchronous. Requery when the menu next opens;
        ; don't claim immediate success based on a possibly transitional state.
        return shouldRun
    }

    static SetRunningElevated(taskPath, shouldRun)
    {
        quote := Chr(34)
        executable := A_WinDir "\System32\schtasks.exe"
        command := "*RunAs " quote executable quote
            . (shouldRun ? " /Run /TN " : " /End /TN ")
            . quote taskPath quote

        try
        {
            exitCode := RunWait(command, , "Hide")
        }
        catch Error as e
        {
            throw Error("Administrator approval was cancelled or the task request failed. " e.Message)
        }

        if (exitCode != 0)
        {
            throw Error("Elevated schtasks.exe failed (exit code " exitCode ") for " taskPath)
        }
    }

    static IsAccessDenied(errorNumber)
    {
        return errorNumber = 5
            || errorNumber = 0x80070005
            || errorNumber = -2147024891
    }

    static SetEnabled(taskPath, enabled)
    {
        path := ScheduledTasksManager.NormalizePath(taskPath)
        enabled := !!enabled
        try
        {
            service := ScheduledTasksManager.Connect()
            task := ScheduledTasksManager.GetTask(service, path)
            task.Enabled := enabled
        }
        catch OSError as e
        {
            if (!ScheduledTasksManager.IsAccessDenied(e.Number))
            {
                throw
            }

            ; Only the one schtasks.exe operation is elevated, not the entire AHK script.
            ScheduledTasksManager.SetEnabledElevated(path, enabled)
        }

        if (ScheduledTasksManager.IsEnabled(path) != enabled)
        {
            throw Error("The Task Scheduler did not apply the requested state: " path)
        }

        return enabled
    }

    static SetEnabledElevated(taskPath, enabled)
    {
        quote := Chr(34)
        executable := A_WinDir "\System32\schtasks.exe"
        command := "*RunAs " quote executable quote
            . " /Change /TN " quote taskPath quote
            . (enabled ? " /Enable" : " /Disable")

        try
        {
            exitCode := RunWait(command, , "Hide")
        }
        catch Error as e
        {
            throw Error("Administrator approval was cancelled or the task could not be changed. " e.Message)
        }

        if (exitCode != 0)
        {
            throw Error("Elevated schtasks.exe failed (exit code " exitCode ") for " taskPath)
        }
    }
}
