#Requires AutoHotkey v2.0

; Edits the active profile's [ProcessWatcher] section in the existing
; Configurator. Shares its INI document, backup and UAC save mechanism.
class ConfiguratorProcessWatcherTab
{
    __New(window, profileDoc, onDirtyCallback := 0)
    {
        this.Window := window
        this.ProfileDoc := profileDoc
        this.OnDirtyCallback := onDirtyCallback
        this.Entries := ProcessWatcher.FromIniEntries(
            profileDoc.GetSectionEntries("ProcessWatcher", false)
        )
        this.SelectedIndex := 0
        this.Dirty := false
        this.UpdatingControls := false
        this.Build()
        this.RefreshEntries()
    }

    Build()
    {
        this.Window.AddText(
            "x30 y52 w1060 h45",
            "Watch for a process, optionally requiring a window-title fragment. "
                . "Choose run, stop or ensure for each helper."
        )
        this.Window.AddGroupBox("x25 y105 w1110 h500", "Process Watcher (active Home / Work profile)")
        this.Window.AddText("x45 y135 w390", "Watched executables")
        this.List := this.Window.AddListBox("x45 y160 w390 h340")
        this.List.OnEvent("Change", ObjBindMethod(this, "OnSelected"))

        this.AddButton := this.Window.AddButton("x45 y521 w100 h32", "+ Add")
        this.AddButton.OnEvent("Click", ObjBindMethod(this, "OnAdd"))
        this.DeleteButton := this.Window.AddButton("x155 y521 w100 h32", "Delete")
        this.DeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDelete"))
        this.TestButton := this.Window.AddButton("x265 y521 w165 h32", "Test notification")
        this.TestButton.OnEvent("Click", ObjBindMethod(this, "OnTestNotification"))

        this.Window.AddText("x475 y135 w500", "Trigger process name (e.g. GeForceNOW.exe)")
        this.TriggerEdit := this.Window.AddEdit("x475 y157 w610 h26")
        this.TriggerEdit.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText("x475 y194 w570", "Window title contains (optional; case-insensitive)")
        this.TitleEdit := this.Window.AddEdit("x475 y217 w610 h26")
        this.TitleEdit.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText("x475 y257 w380", "Helper type")
        this.TypeList := this.Window.AddDropDownList(
            "x475 y279 w340",
            ["AHK Script", "Executable (.exe)"]
        )
        this.TypeList.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText("x475 y317 w610", "Helper: EXE name or full path; AHK needs full path")
        this.PathEdit := this.Window.AddEdit("x475 y339 w610 h26")
        this.PathEdit.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText("x475 y378 w450", "Action when trigger matches")
        this.ModeList := this.Window.AddDropDownList(
            "x475 y400 w340",
            ["run - launch once", "stop - close on exit", "ensure - keep running"]
        )
        this.ModeList.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText(
            "x475 y451 w615 h136",
            "Example: GeForceNOW.exe::Watch_Dogs 2 (process + window title)." Chr(10)
                . "Window-title filter matches ANY window of the process, not only active."
                . Chr(10)
                . "run: start once; stop: close helper when title stops matching."
                . Chr(10)
                . "ensure: relaunch a closed helper while title still matches." Chr(10)
                . "Without a title filter, only the process name is checked." Chr(10)
                . "Save + Reload applies edited rules."
        )
    }

    RefreshEntries(preferredIndex := 0, reloadEditor := true)
    {
        this.UpdatingControls := true
        try
        {
            this.List.Delete()
            labels := []
            for entry in this.Entries
            {
                title := entry.Get("TitleContains", "")
                label := entry["Trigger"] (title = "" ? "" : "::" title)
                labels.Push(label = "" ? "(unnamed)" : label)
            }
            if (labels.Length)
            {
                this.List.Add(labels)
                this.SelectedIndex := preferredIndex >= 1 && preferredIndex <= labels.Length
                    ? preferredIndex : 1
                this.List.Choose(this.SelectedIndex)
            }
            else
            {
                this.SelectedIndex := 0
            }
        }
        finally
        {
            this.UpdatingControls := false
        }
        if (reloadEditor)
        {
            this.LoadSelected()
        }
        this.DeleteButton.Enabled := this.SelectedIndex > 0
    }

    LoadSelected()
    {
        entry := this.SelectedIndex ? this.Entries[this.SelectedIndex] : 0
        this.UpdatingControls := true
        try
        {
            this.TriggerEdit.Value := entry ? entry["Trigger"] : ""
            this.TitleEdit.Value := entry ? entry.Get("TitleContains", "") : ""
            this.TypeList.Choose(entry && entry["Type"] = ProcessWatcher.EXE ? 2 : 1)
            this.PathEdit.Value := entry ? entry["Path"] : ""
            mode := entry ? entry["Mode"] : ProcessWatcher.RUN
            this.ModeList.Choose(
                mode = ProcessWatcher.ENSURE ? 3
                    : mode = ProcessWatcher.STOP ? 2 : 1
            )
            this.TriggerEdit.Enabled := !!entry
            this.TitleEdit.Enabled := !!entry
            this.TypeList.Enabled := !!entry
            this.PathEdit.Enabled := !!entry
            this.ModeList.Enabled := !!entry
        }
        finally
        {
            this.UpdatingControls := false
        }
    }

    OnSelected(*)
    {
        if (this.UpdatingControls || this.List.Value < 1)
        {
            return
        }
        this.SelectedIndex := this.List.Value
        this.LoadSelected()
    }

    OnChanged(*)
    {
        if (this.UpdatingControls || this.SelectedIndex < 1)
        {
            return
        }
        entry := this.Entries[this.SelectedIndex]
        entry["Trigger"] := this.TriggerEdit.Value
        entry["TitleContains"] := this.TitleEdit.Value
        entry["Type"] := this.TypeList.Value = 2 ? ProcessWatcher.EXE : ProcessWatcher.AHK
        entry["Path"] := this.PathEdit.Value
        entry["Mode"] := this.ModeList.Value = 3 ? ProcessWatcher.ENSURE
            : this.ModeList.Value = 2 ? ProcessWatcher.STOP : ProcessWatcher.RUN
        this.SetDirty()
        this.RefreshEntries(this.SelectedIndex, false)
    }

    OnAdd(*)
    {
        result := InputBox(
            "Executable to monitor (e.g. Game.exe):",
            "Add Process Watcher",
            "w440 h140"
        )
        if (result.Result != "OK" || Trim(result.Value) = "")
        {
            return
        }
        this.Entries.Push(Map(
            "Trigger", Trim(result.Value),
            "TitleContains", "",
            "Type", ProcessWatcher.AHK,
            "Path", "",
            "Mode", ProcessWatcher.RUN
        ))
        this.RefreshEntries(this.Entries.Length)
        this.SetDirty()
        this.PathEdit.Focus()
    }

    OnTestNotification(*)
    {
        try
        {
            message := this.SelectedIndex
                ? ProcessWatcher.LaunchNotificationMessage(this.Entries[this.SelectedIndex])
                : "Started: example-helper.ahk" Chr(10) "Trigger: ExampleGame.exe"
            ProcessWatcherToast.Show(message)
        }
        catch Error as e
        {
            MsgBox("Unable to show test notification: " e.Message,
                "Process Watcher", "Iconx")
        }
    }

    OnDelete(*)
    {
        if (this.SelectedIndex < 1)
        {
            return
        }
        selected := this.Entries[this.SelectedIndex]
        trigger := selected["Trigger"] (selected.Get("TitleContains", "") = ""
            ? "" : "::" selected["TitleContains"])
        if (MsgBox(
            "Remove watcher for '" trigger "'? This does not stop any process.",
            "Process Watcher",
            "YesNo Icon!"
        ) != "Yes")
        {
            return
        }
        oldIndex := this.SelectedIndex
        this.Entries.RemoveAt(oldIndex)
        this.RefreshEntries(Min(oldIndex, this.Entries.Length))
        this.SetDirty()
    }

    Validate()
    {
        return ProcessWatcher.ValidateEntries(this.Entries)
    }

    ApplyToDocument()
    {
        this.ProfileDoc.ReplaceSectionEntries(
            "ProcessWatcher", ProcessWatcher.ToIniEntries(this.Entries), false
        )
    }

    MarkSaved()
    {
        this.Dirty := false
    }

    SetDirty()
    {
        this.Dirty := true
        if (this.OnDirtyCallback)
        {
            this.OnDirtyCallback.Call()
        }
    }
}
