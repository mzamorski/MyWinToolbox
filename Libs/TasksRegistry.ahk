#Requires AutoHotkey v2.0

; One ordered [Tasks] section for heterogeneous task types. A type-specific
; handler defines how a task is validated and operated; the menu and editor do
; not divide entries into separate categories.
;
; Example: Backup = scheduler|\MyTasks\Backup
;          WARDOGS = ahk|C:\Repo\Games\WARDOGS-Hammer.ahk
class TasksRegistry
{
    static SCHEDULER := "scheduler"
    static AHK := "ahk"

    static Types()
    {
        ; Adding EXE later only requires adding the handler and this option.
        return [TasksRegistry.SCHEDULER, TasksRegistry.AHK]
    }

    static Encode(type, path)
    {
        type := StrLower(Trim("" type))
        if (!TasksRegistry.IsSupported(type))
        {
            throw Error("Unsupported task type: " type)
        }
        return type "|" Trim("" path)
    }

    static IsSupported(type)
    {
        for supportedType in TasksRegistry.Types()
        {
            if (StrLower(type) = supportedType)
            {
                return true
            }
        }
        return false
    }

    static Parse(name, rawValue)
    {
        separator := InStr(rawValue, "|")
        if (!separator)
        {
            throw Error("Task '" name "' must have the format type|path.")
        }
        type := StrLower(Trim(SubStr(rawValue, 1, separator - 1)))
        path := Trim(SubStr(rawValue, separator + 1))
        if (type = "" || path = "")
        {
            throw Error("Task '" name "' needs both a type and a path.")
        }

        return Map("Name", Trim("" name), "Type", type, "Value", path)
    }

    static ValidateEntries(entries)
    {
        seenLabels := Map()
        seenPaths := Map()

        for entry in entries
        {
            name := Trim("" entry["Name"])
            type := StrLower(Trim("" entry["Type"]))
            path := Trim("" entry["Value"])

            if (
                name = ""
                || InStr(name, "=")
                || SubStr(name, 1, 1) = ";"
                || RegExMatch(name, "[\x00-\x1F]")
            )
            {
                throw Error("Invalid Tasks menu label: " name)
            }
            nameKey := StrLower(name)
            if (seenLabels.Has(nameKey))
            {
                throw Error("Duplicate Tasks menu label: " name)
            }
            seenLabels[nameKey] := true

            if (!TasksRegistry.IsSupported(type))
            {
                throw Error("Unsupported task type: " type)
            }

            if (type = TasksRegistry.SCHEDULER)
            {
                normalizedPath := ScheduledTasksManager.NormalizePath(path)
            }
            else if (type = TasksRegistry.AHK)
            {
                normalizedPath := StrLower(
                    StrReplace(AhkScriptManager.ValidateScriptPath(path), "/", "\")
                )
            }

            identity := type "|" StrLower(normalizedPath)
            if (seenPaths.Has(identity))
            {
                throw Error("Duplicate task definition: " name)
            }
            seenPaths[identity] := true
        }
        return true
    }

    static ToIniEntries(entries)
    {
        TasksRegistry.ValidateEntries(entries)
        output := []
        for entry in entries
        {
            output.Push(Map(
                "Name", Trim("" entry["Name"]),
                "Value", TasksRegistry.Encode(entry["Type"], entry["Value"])
            ))
        }
        return output
    }

    static FromIniEntries(entries)
    {
        output := []
        for entry in entries
        {
            output.Push(TasksRegistry.Parse(entry["Name"], entry["Value"]))
        }
        return output
    }

    static LegacyEntries(scheduledEntries, ahkEntries, ahkRoot := "")
    {
        output := []
        for entry in scheduledEntries
        {
            output.Push(Map(
                "Name", entry["Name"],
                "Type", TasksRegistry.SCHEDULER,
                "Value", entry["Value"]
            ))
        }
        for entry in ahkEntries
        {
            path := entry["Value"]
            if (!RegExMatch(path, "i)^(?:[a-z]:\\|\\\\[^\\]+\\[^\\]+\\)"))
            {
                ; Convert old relative script paths to a self-contained
                ; absolute path when migrating older profile configurations.
                root := ahkRoot = "" ? A_ScriptDir : ahkRoot
                if (!RegExMatch(root, "i)^(?:[a-z]:\\|\\\\[^\\]+\\[^\\]+\\)"))
                {
                    root := A_ScriptDir "\" root
                }
                path := RTrim(root, "\") "\" path
            }
            path := AhkScriptManager.ResolveScriptPath(path)
            output.Push(Map(
                "Name", entry["Name"],
                "Type", TasksRegistry.AHK,
                "Value", path
            ))
        }
        return output
    }

    static GetStatus(entry, &schedulerService)
    {
        type := entry["Type"]
        path := entry["Value"]

        if (type = TasksRegistry.SCHEDULER)
        {
            if (!IsObject(schedulerService))
            {
                schedulerService := ScheduledTasksManager.Connect()
            }
            path := ScheduledTasksManager.NormalizePath(path)
            state := ScheduledTasksManager.GetTaskStatus(schedulerService, path)
            running := state["Running"]
            enabled := state["Enabled"]

            return Map(
                "Running", running,
                "Status", ScheduledTasksManager.GetStateLabel(state["State"]),
                "CanToggle", running || (enabled && state["State"] = 3)
            )
        }

        if (type = TasksRegistry.AHK)
        {
            path := AhkScriptManager.ResolveScriptPath(path)
            running := AhkScriptManager.IsRunning(path)
            available := running || (FileExist(path) && !InStr(FileExist(path), "D"))
            return Map(
                "Running", running,
                "Status", !available ? "Missing" : (running ? "Running" : "Stopped"),
                "CanToggle", !!available
            )
        }

        ; New task types require a handler, not a new Tasks menu/category.
        return Map(
            "Running", false,
            "Status", "Unsupported: " type,
            "CanToggle", false
        )
    }

    static Toggle(entry)
    {
        type := entry["Type"]
        path := entry["Value"]

        if (type = TasksRegistry.SCHEDULER)
        {
            wasRunning := ScheduledTasksManager.IsRunning(path)
            ScheduledTasksManager.SetRunning(path, !wasRunning)
            return wasRunning ? "stop requested" : "start requested"
        }

        if (type = TasksRegistry.AHK)
        {
            started := AhkScriptManager.Toggle(path)
            return started ? "start requested" : "close requested"
        }

        throw Error("Unsupported task type: " type)
    }

    static ReadRawSection(profilePath, sectionName)
    {
        if (!FileExist(profilePath))
        {
            throw IOError(profilePath)
        }

        entries := []
        activeSection := false

        ; Preserve file order and literal Windows backslashes.
        for line in StrSplit(FileRead(profilePath, "UTF-8"), "`n", "`r")
        {
            trimmed := Trim(line)
            if (RegExMatch(trimmed, "^\[(.*)\]$", &match))
            {
                activeSection := StrLower(Trim(match[1])) = StrLower(sectionName)
                continue
            }
            if (
                !activeSection || trimmed = ""
                || SubStr(trimmed, 1, 1) = ";"
            )
            {
                continue
            }

            separator := InStr(line, "=")
            if (!separator)
            {
                continue
            }

            name := Trim(SubStr(line, 1, separator - 1))
            value := Trim(SubStr(line, separator + 1))
            entries.Push(Map("Name", name, "Value", value))
        }

        return entries
    }

    static LoadProfile(profilePath)
    {
        configured := TasksRegistry.ReadRawSection(profilePath, "Tasks")
        if (configured.Length > 0)
        {
            result := []
            for entry in configured
            {
                result.Push(Map(
                    "Name", entry["Name"],
                    "Definition", entry["Value"]
                ))
            }
            return result
        }

        ; Compatibility for users who configured the earlier PR builds.
        legacyScheduled := TasksRegistry.ReadRawSection(profilePath, "ScheduledTasks")
        legacyScripts := TasksRegistry.ReadRawSection(profilePath, "AhkScripts")
        result := []
        for entry in legacyScheduled
        {
            result.Push(Map(
                "Name", entry["Name"],
                "Definition", TasksRegistry.Encode(
                    TasksRegistry.SCHEDULER, entry["Value"]
                )
            ))
        }

        rootEntries := TasksRegistry.ReadRawSection(
            profilePath, "AhkScriptsSettings"
        )
        ahkRoot := ""
        for entry in rootEntries
        {
            if (StrLower(entry["Name"]) = "root")
            {
                ahkRoot := entry["Value"]
                break
            }
        }

        for entry in legacyScripts
        {
            name := entry["Name"]
            path := entry["Value"]
            try
            {
                mapped := TasksRegistry.LegacyEntries(
                    [], [Map("Name", name, "Value", path)], ahkRoot
                )
                path := mapped[1]["Value"]
            }
            catch Error
            {
                ; Leave invalid old paths visible as unavailable.
            }

            result.Push(Map(
                "Name", name,
                "Definition", TasksRegistry.Encode(TasksRegistry.AHK, path)
            ))
        }
        return result
    }
}
