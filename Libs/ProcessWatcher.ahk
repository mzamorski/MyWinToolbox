#Requires AutoHotkey v2.0

; Tracks process arrival/departure (not foreground windows). Each rule runs
; once on arrival, and optionally stops only the helper it actually launched.
; INI: Game.exe = ahk|C:\Scripts\GameHelper.ahk|stop
;      Editor.exe = exe|notepad.exe|run
class ProcessWatcher
{
    static IntervalMs := 3000
    static AHK := "ahk"
    static EXE := "exe"

    __New(entries := [])
    {
        this.Rules := []
        this.TimerCallback := ObjBindMethod(this, "Tick")
        for entry in entries
        {
            state := Map(
                "Trigger", entry["Trigger"],
                "Type", entry["Type"],
                "Path", entry["Path"],
                "StopOnExit", entry["StopOnExit"],
                "WasPresent", false,
                "OwnedPid", 0,
                "OwnedHandle", 0
            )
            this.Rules.Push(state)
        }
    }

    static ValidateTrigger(name)
    {
        name := Trim("" name)
        if (
            name = ""
            || !RegExMatch(name, "i)^[^\\/:*?<>|]+\.exe$")
            || InStr(name, Chr(34))
        )
        {
            throw Error("Trigger must be a process executable name (e.g. Game.exe): " name)
        }
        return name
    }

    static IsExecutableName(path)
    {
        ; A basename is resolved by the Windows Run/ShellExecute mechanism.
        ; Do not confuse it with a relative path such as Tools\Helper.exe.
        return !!RegExMatch(path, "i)^[^\\/:*?<>|]+\.exe$")
    }

    static ValidatePath(type, value)
    {
        path := Trim("" value)
        if (type = ProcessWatcher.AHK)
        {
            return AhkScriptManager.ValidateScriptPath(path)
        }
        if (
            type != ProcessWatcher.EXE
            || path = ""
            || InStr(path, Chr(34))
            || RegExMatch(path, "[\x00-\x1F]")
            || !RegExMatch(path, "i)\.exe$")
            || (
                !ProcessWatcher.IsExecutableName(path)
                && !RegExMatch(path, "i)^(?:[a-z]:\\|\\\\[^\\]+\\[^\\]+\\)")
            )
        )
        {
            throw Error("EXE action needs a filename (notepad.exe) or an absolute path: " value)
        }
        return path
    }

    static ValidateEntries(entries)
    {
        seen := Map()
        for entry in entries
        {
            trigger := ProcessWatcher.ValidateTrigger(entry["Trigger"])
            type := StrLower(Trim("" entry["Type"]))
            ProcessWatcher.ValidatePath(type, entry["Path"])
            key := StrLower(trigger)
            if (seen.Has(key))
            {
                throw Error("Duplicate ProcessWatcher trigger: " trigger)
            }
            seen[key] := true
            if (entry["StopOnExit"] != true && entry["StopOnExit"] != false)
            {
                throw Error("Invalid StopOnExit for " trigger)
            }
        }
        return true
    }

    static FromIniEntries(entries)
    {
        result := []
        for entry in entries
        {
            parts := StrSplit(entry["Value"], "|")
            if (parts.Length != 3)
            {
                throw Error("ProcessWatcher: " entry["Name"] " must be type|path|run_or_stop.")
            }
            type := StrLower(Trim(parts[1]))
            behavior := StrLower(Trim(parts[3]))
            ; Existing configurations using 'keep' remain readable, but
            ; Configurator always writes the canonical 'run' spelling.
            if (behavior != "stop" && behavior != "run" && behavior != "keep")
            {
                throw Error("ProcessWatcher: use 'run' or 'stop' for " entry["Name"])
            }
            result.Push(Map(
                "Trigger", Trim(entry["Name"]),
                "Type", type,
                "Path", Trim(parts[2]),
                "StopOnExit", behavior = "stop"
            ))
        }
        ProcessWatcher.ValidateEntries(result)
        return result
    }

    static ToIniEntries(entries)
    {
        ProcessWatcher.ValidateEntries(entries)
        result := []
        for entry in entries
        {
            result.Push(Map(
                "Name", Trim(entry["Trigger"]),
                "Value", StrLower(entry["Type"]) "|" Trim(entry["Path"])
                    "|" (entry["StopOnExit"] ? "stop" : "run")
            ))
        }
        return result
    }

    Start()
    {
        if (this.Rules.Length = 0)
        {
            return
        }
        ; Register first, then inspect existing processes immediately.
        SetTimer(this.TimerCallback, ProcessWatcher.IntervalMs)
        this.Tick()
    }

    Stop()
    {
        SetTimer(this.TimerCallback, 0)
    }

    Shutdown(*)
    {
        this.Stop()
        for rule in this.Rules
        {
            pid := rule["OwnedPid"]
            shouldStop := pid && rule["StopOnExit"] && rule["OwnedHandle"]
            this.Leave(rule)
            if (shouldStop)
            {
                ; On Reload, finish the old helper's shutdown before the
                ; replacement toolbox checks whether that helper is running.
                try ProcessWaitClose(pid, 3)
            }
        }
    }

    Tick(*)
    {
        for rule in this.Rules
        {
            try
            {
                present := !!this.FindProcess(rule["Trigger"])
                if (present && !rule["WasPresent"])
                {
                    ; Mark before launching: failures do not cause a new
                    ; launch attempt every three seconds.
                    rule["WasPresent"] := true
                    if (!this.IsActionRunning(rule))
                    {
                        pid := this.StartAction(rule)
                        rule["OwnedPid"] := pid
                        rule["OwnedHandle"] := this.OpenOwnedHandle(pid)
                        Logger.Info("Started " rule["Path"] " for " rule["Trigger"], "ProcessWatcher")
                    }
                    else
                    {
                        Logger.Info("Helper already running; not taking ownership: "
                            rule["Path"], "ProcessWatcher")
                    }
                }
                else if (!present && rule["WasPresent"])
                {
                    rule["WasPresent"] := false
                    this.Leave(rule)
                }
            }
            catch Error as e
            {
                Logger.Error(rule["Trigger"] ": " e.Message " (" e.File ":" e.Line ")",
                    "ProcessWatcher")
            }
        }
    }

    Leave(rule)
    {
        try
        {
            if (rule["OwnedPid"] && rule["StopOnExit"])
            {
                this.StopAction(rule)
                Logger.Info("Stopped helper for " rule["Trigger"], "ProcessWatcher")
            }
        }
        catch Error as e
        {
            Logger.Error("Cannot stop helper for " rule["Trigger"] ": " e.Message,
                "ProcessWatcher")
        }
        finally
        {
            if (rule["OwnedHandle"])
            {
                DllCall("Kernel32\CloseHandle", "Ptr", rule["OwnedHandle"])
            }
            rule["OwnedHandle"] := 0
            rule["OwnedPid"] := 0
        }
    }

    FindProcess(exeName)
    {
        return ProcessExist(exeName)
    }

    IsActionRunning(rule)
    {
        if (rule["Type"] = ProcessWatcher.AHK)
        {
            return AhkScriptManager.IsRunning(rule["Path"])
        }
        SplitPath(rule["Path"], &exeName)
        return !!ProcessExist(exeName)
    }

    static BuildLaunchSpec(rule)
    {
        type := StrLower(rule["Type"])
        path := ProcessWatcher.ValidatePath(type, rule["Path"])
        shortExe := type = ProcessWatcher.EXE && ProcessWatcher.IsExecutableName(path)
        workingDir := ""
        if (!shortExe)
        {
            SplitPath(path, , &workingDir)
        }

        if (type = ProcessWatcher.AHK)
        {
            command := '"' A_AhkPath '" "' path '"'
        }
        else
        {
            ; No preflight FileExist for a short EXE: let Windows resolve it
            ; from its normal executable search locations / App Paths.
            command := shortExe ? path : '"' path '"'
        }
        return Map(
            "Command", command,
            "WorkingDir", workingDir,
            "RequiresFile", !shortExe
        )
    }

    StartAction(rule)
    {
        spec := ProcessWatcher.BuildLaunchSpec(rule)
        path := rule["Path"]
        if (rule["Type"] = ProcessWatcher.AHK && A_IsCompiled)
        {
            throw Error("AHK actions require an AHK v2 interpreter.")
        }
        if (
            spec["RequiresFile"]
            && (!FileExist(path) || InStr(FileExist(path), "D"))
        )
        {
            throw Error("Helper file not found: " path)
        }

        pid := 0
        try
        {
            Run(spec["Command"], spec["WorkingDir"], , &pid)
        }
        catch Error as e
        {
            throw Error("Cannot launch helper '" path "': " e.Message)
        }
        if (!pid)
        {
            throw Error("The helper did not return a process ID: " path)
        }
        return pid
    }

    OpenOwnedHandle(pid)
    {
        ; Holding the process object prevents its PID from being recycled
        ; while this watcher is responsible for stopping the helper.
        return DllCall(
            "Kernel32\OpenProcess",
            "UInt", 0x00100000 | 0x1000, ; SYNCHRONIZE | QUERY_LIMITED_INFORMATION
            "Int", 0,
            "UInt", pid,
            "Ptr"
        )
    }

    StopAction(rule)
    {
        pid := rule["OwnedPid"]
        handle := rule["OwnedHandle"]
        if (!handle)
        {
            ; Never force-close a PID if we cannot prove it is still ours.
            Logger.Warning("Skipping stop; no owned process handle: " rule["Path"],
                "ProcessWatcher")
            return
        }
        if (DllCall("Kernel32\WaitForSingleObject", "Ptr", handle, "UInt", 0, "UInt") != 0x102)
        {
            return
        }
        if (rule["Type"] = ProcessWatcher.AHK)
        {
            ; WM_CLOSE lets AHK execute its OnExit handlers.
            for hwnd in AhkScriptManager.GetWindows(rule["Path"])
            {
                try
                {
                    if (WinGetPID("ahk_id " hwnd) = pid)
                    {
                        WinClose("ahk_id " hwnd)
                    }
                }
                catch Error
                {
                    ; The window can vanish while the game is closing.
                }
            }
        }
        else
        {
            ; EXE stop policy is explicit and requests process termination.
            ProcessClose(pid)
        }
    }
}
