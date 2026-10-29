#Requires AutoHotkey v2.0

#Include Logger.ahk
#Include WindowKeepAlive.ahk
#Include AutoPaste.ahk

class ConfiguratorDiagnosticsTab
{
    __New(window, owner)
    {
        this.Window := window
        this.Owner := owner
        this.Snapshot := []

        this.Build()
        this.Refresh()
    }

    Build()
    {
        this.Window.AddText(
            "x25 y48 w250 h24",
            "Runtime health"
        )

        this.HealthList := this.Window.AddListView(
            "x25 y72 w1110 h300 -Multi",
            ["Check", "Status", "Details"]
        )
        this.HealthList.ModifyCol(1, 205)
        this.HealthList.ModifyCol(2, 120)
        this.HealthList.ModifyCol(3, 760)

        this.Window.AddText(
            "x25 y390 w400 h22",
            "Recent ERROR log entries (latest first)"
        )

        this.ErrorEdit := this.Window.AddEdit(
            "x25 y412 w1110 h145 ReadOnly -Wrap VScroll"
        )
        this.ErrorEdit.SetFont("s8", "Consolas")

        this.RefreshButton := this.Window.AddButton(
            "x25 y575 w95 h32",
            "Refresh"
        )
        this.RefreshButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnRefresh")
        )

        this.OpenLogButton := this.Window.AddButton(
            "x130 y575 w105 h32",
            "Open log"
        )
        this.OpenLogButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnOpenLog")
        )

        this.OpenFolderButton := this.Window.AddButton(
            "x245 y575 w145 h32",
            "Open install folder"
        )
        this.OpenFolderButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnOpenInstallFolder")
        )

        this.CopyReportButton := this.Window.AddButton(
            "x400 y575 w115 h32",
            "Copy report"
        )
        this.CopyReportButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnCopyReport")
        )

        this.ReloadButton := this.Window.AddButton(
            "x525 y575 w95 h32",
            "Reload"
        )
        this.ReloadButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnReload")
        )

    }

    Refresh()
    {
        global IsNoSleepTimerOn
        global ClipboardTrimEnabled
        global DebugLogging

        this.HealthList.Delete()
        this.Snapshot := []

        profilePath := this.Owner.SettingsTab.ProfileConfigPath
        profileName := ConfiguratorDiagnosticsTab.GetProfileName(profilePath)
        noSleepActive := IsSet(IsNoSleepTimerOn) ? !!IsNoSleepTimerOn : false
        clipboardTrimActive := IsSet(ClipboardTrimEnabled) ? !!ClipboardTrimEnabled : false
        debugLoggingActive := IsSet(DebugLogging) ? !!DebugLogging : false
        taskInfo := ConfiguratorDiagnosticsTab.GetScheduledTaskInfo(
            "MyWinToolbox"
        )

        snippetCount := ConfiguratorDiagnosticsTab.CountSnippets(
            this.Owner.SnippetsData
        )

        hotStrings := this.Owner.HotStringsState.GetDefinitions()
        hotStringCount := hotStrings.Length
        enabledHotStringCount := ConfiguratorDiagnosticsTab.CountEnabledHotStrings(
            hotStrings
        )

        autoPasteCount := this.Owner.AutoPasteTab.Data.Length
        keepAliveCount := 0

        try
        {
            keepAliveCount := WindowKeepAlive.Targets.Count
        }

        logPath := Logger.LogPath
        logStatus := FileExist(logPath) ? "Available" : "Missing"
        logDetails := logPath

        if FileExist(logPath)
        {
            try
            {
                logDetails .= " (" ConfiguratorDiagnosticsTab.FormatBytes(
                    FileGetSize(logPath)
                ) ")"
            }
        }

        this.AddHealthRow(
            "Active profile",
            "OK",
            profileName " | " profilePath
        )

        this.AddHealthRow(
            "AutoHotkey",
            "OK",
            "v" A_AhkVersion
                . " | "
                . (A_PtrSize = 8 ? "64-bit" : "32-bit")
        )

        this.AddHealthRow(
            "Installation",
            A_IsAdmin ? "Elevated" : "Standard",
            A_ScriptDir
        )

        this.AddHealthRow(
            "Scheduled Task",
            taskInfo["Status"],
            taskInfo["Details"]
        )

        this.AddHealthRow(
            "AutoPaste",
            AutoPaste_IsEnabled() ? "ON" : "OFF",
            autoPasteCount " rule(s)"
        )

        this.AddHealthRow(
            "NoSleep",
            noSleepActive ? "ON" : "OFF",
            "Runtime state"
        )

        this.AddHealthRow(
            "Clipboard Trim",
            clipboardTrimActive ? "ON" : "OFF",
            "Runtime state"
        )

        this.AddHealthRow(
            "KeepAlive",
            keepAliveCount > 0 ? "ACTIVE" : "OFF",
            keepAliveCount " tracked window(s)"
        )

        this.AddHealthRow(
            "HotStrings",
            hotStringCount > 0 ? "Loaded" : "Empty",
            enabledHotStringCount " enabled / " hotStringCount " total"
        )

        this.AddHealthRow(
            "Text Snippets",
            snippetCount > 0 ? "Loaded" : "Empty",
            snippetCount " snippet(s)"
        )

        this.AddHealthRow(
            "Debug logging",
            debugLoggingActive ? "ON" : "OFF",
            "Logger level configuration"
        )

        this.AddHealthRow(
            "Log file",
            logStatus,
            logDetails
        )

        this.HealthList.ModifyCol(1, 205)
        this.HealthList.ModifyCol(2, 120)
        this.HealthList.ModifyCol(3, 760)

        errorText := ConfiguratorDiagnosticsTab.GetRecentErrors(
            logPath,
            8
        )
        this.ErrorEdit.Value := errorText

        this.OpenLogButton.Enabled := !!FileExist(logPath)
    }

    static GetProfileName(profileConfigPath)
    {
        SplitPath(profileConfigPath, &fileName)
        if (fileName = "")
            return A_ScriptName

        return RegExReplace(fileName, "i)\.config$")
    }

    AddHealthRow(checkName, status, details)
    {
        this.HealthList.Add("", checkName, status, details)
        this.Snapshot.Push(
            Map(
                "Check", checkName,
                "Status", status,
                "Details", details
            )
        )
    }

    OnRefresh(*)
    {
        this.Refresh()
    }

    OnOpenLog(*)
    {
        logPath := Logger.LogPath

        if FileExist(logPath)
        {
            try
            {
                Run(logPath)
                return
            }
            catch Error as e
            {
                MsgBox(
                    "Unable to open log file:`n" e.Message,
                    "MyWinToolbox Diagnostics",
                    "Iconx"
                )
                return
            }
        }

        if DirExist(Logger.LogDirectory)
        {
            Run(Logger.LogDirectory)
        }
    }

    OnOpenInstallFolder(*)
    {
        try
        {
            Run(A_ScriptDir)
        }
        catch Error as e
        {
            MsgBox(
                "Unable to open installation folder:`n" e.Message,
                "MyWinToolbox Diagnostics",
                "Iconx"
            )
        }
    }

    OnCopyReport(*)
    {
        this.Refresh()

        report := "MyWinToolbox Diagnostics"
            . "`r`nGenerated: "
            . FormatTime(, "yyyy-MM-dd HH:mm:ss")
            . "`r`n`r`n"

        for row in this.Snapshot
        {
            report .= row["Check"]
                . ": "
                . row["Status"]
                . " | "
                . row["Details"]
                . "`r`n"
        }

        report .= "`r`nRecent errors:`r`n"
            . this.ErrorEdit.Value

        A_Clipboard := report
        TrayTip(
            "MyWinToolbox",
            "Diagnostics report copied to clipboard."
        )
    }

    OnReload(*)
    {
        if (this.Owner.HasUnsavedChanges())
        {
            answer := MsgBox(
                "There are unsaved Configurator changes.`n`n"
                    "Reload will discard them. Continue?",
                "Reload MyWinToolbox",
                "YesNo Icon!"
            )

            if (answer != "Yes")
            {
                return
            }
        }

        Reload()
    }

    static CountSnippets(data)
    {
        count := 0

        if (!IsObject(data) || !(data is Map))
        {
            return 0
        }

        for snippets in data
        {
            if (Type(snippets) != "Array")
            {
                continue
            }

            for snippet in snippets
            {
                if (
                    IsObject(snippet)
                    && snippet is Map
                    && snippet.Has("Content")
                    && snippet["Content"] = "--"
                )
                {
                    continue
                }

                count += 1
            }
        }

        return count
    }

    static CountEnabledHotStrings(definitions)
    {
        if (Type(definitions) != "Array")
        {
            return 0
        }

        count := 0

        for definition in definitions
        {
            if (
                IsObject(definition)
                && definition is Map
                && (!definition.Has("Enabled") || definition["Enabled"])
            )
            {
                count += 1
            }
        }

        return count
    }

    static GetScheduledTaskInfo(taskName)
    {
        try
        {
            service := ComObject("Schedule.Service")
            service.Connect()
            rootFolder := service.GetFolder("\")
            task := rootFolder.GetTask(taskName)

            state := ConfiguratorDiagnosticsTab.DescribeTaskState(
                task.State
            )

            return Map(
                "Status", state,
                "Details", "Task '" taskName "' | "
                    . (task.Enabled ? "enabled" : "disabled")
            )
        }
        catch Error as e
        {
            return Map(
                "Status", "Missing",
                "Details", "Task '" taskName "' was not found or could not be read: "
                    . e.Message
            )
        }
    }

    static DescribeTaskState(state)
    {
        switch state
        {
            case 0:
                return "Unknown"
            case 1:
                return "Disabled"
            case 2:
                return "Queued"
            case 3:
                return "Ready"
            case 4:
                return "Running"
            default:
                return "State " state
        }
    }

    static GetRecentErrors(logPath, maxCount := 8)
    {
        if (!FileExist(logPath))
        {
            return "Log file does not exist yet."
        }

        try
        {
            return ConfiguratorDiagnosticsTab.GetRecentErrorsFromText(
                FileRead(logPath, "UTF-8"),
                maxCount
            )
        }
        catch Error as e
        {
            return "Unable to read log: " e.Message
        }
    }

    static GetRecentErrorsFromText(text, maxCount := 8)
    {
        lines := StrSplit(
            StrReplace(text, "`r", ""),
            "`n"
        )
        errors := []

        Loop lines.Length
        {
            index := lines.Length - A_Index + 1
            line := Trim(lines[index])

            if (line = "" || !InStr(line, "[ERROR]"))
            {
                continue
            }

            errors.Push(line)

            if (errors.Length >= maxCount)
            {
                break
            }
        }

        if (errors.Length = 0)
        {
            return "No ERROR entries found in the current log."
        }

        result := ""
        separator := ""

        for line in errors
        {
            result .= separator line
            separator := "`r`n"
        }

        return result
    }

    static FormatBytes(size)
    {
        if (size < 1024)
        {
            return size " B"
        }

        if (size < 1024 * 1024)
        {
            return Round(size / 1024, 1) " KB"
        }

        return Round(size / (1024 * 1024), 1) " MB"
    }


}
