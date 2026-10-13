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
            "Watch for process startup/shutdown (not the active window). "
                . "Start a helper once when the trigger appears."
        )
        this.Window.AddGroupBox("x25 y105 w1110 h500", "Process Watcher (active Home / Work profile)")
        this.Window.AddText("x45 y135 w390", "Watched executables")
        this.List := this.Window.AddListBox("x45 y160 w390 h340")
        this.List.OnEvent("Change", ObjBindMethod(this, "OnSelected"))

        this.AddButton := this.Window.AddButton("x45 y521 w100 h32", "+ Add")
        this.AddButton.OnEvent("Click", ObjBindMethod(this, "OnAdd"))
        this.DeleteButton := this.Window.AddButton("x155 y521 w100 h32", "Delete")
        this.DeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDelete"))

        this.Window.AddText("x475 y135 w500", "Trigger process name (e.g. Game.exe)")
        this.TriggerEdit := this.Window.AddEdit("x475 y160 w610 h26")
        this.TriggerEdit.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText("x475 y207 w380", "Helper type")
        this.TypeList := this.Window.AddDropDownList(
            "x475 y231 w340",
            ["AHK Script", "Executable (.exe)"]
        )
        this.TypeList.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText("x475 y281 w550", "Absolute path to helper")
        this.PathEdit := this.Window.AddEdit("x475 y306 w610 h26")
        this.PathEdit.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.StopCheck := this.Window.AddCheckBox(
            "x475 y351 w610 h24",
            "Stop helper when watched process exits"
        )
        this.StopCheck.OnEvent("Click", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText(
            "x475 y401 w615 h145",
            "Example: Game.exe -> C:\Scripts\GameHelper.ahk" Chr(10)
                . "Checks run every 3 seconds, starting with MyWinToolbox startup." Chr(10)
                . "One action is triggered per process appearance, not on every poll."
                . Chr(10)
                . "An already-running helper is never adopted or stopped."
                . Chr(10)
                . "AHK scripts close normally; EXE stop forcibly terminates the helper."
                . Chr(10)
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
                labels.Push(entry["Trigger"] = "" ? "(unnamed)" : entry["Trigger"])
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
            this.TypeList.Choose(entry && entry["Type"] = ProcessWatcher.EXE ? 2 : 1)
            this.PathEdit.Value := entry ? entry["Path"] : ""
            this.StopCheck.Value := entry && entry["StopOnExit"] ? 1 : 0
            this.TriggerEdit.Enabled := !!entry
            this.TypeList.Enabled := !!entry
            this.PathEdit.Enabled := !!entry
            this.StopCheck.Enabled := !!entry
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
        entry["Type"] := this.TypeList.Value = 2 ? ProcessWatcher.EXE : ProcessWatcher.AHK
        entry["Path"] := this.PathEdit.Value
        entry["StopOnExit"] := !!this.StopCheck.Value
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
            "Type", ProcessWatcher.AHK,
            "Path", "",
            "StopOnExit", true
        ))
        this.RefreshEntries(this.Entries.Length)
        this.SetDirty()
        this.PathEdit.Focus()
    }

    OnDelete(*)
    {
        if (this.SelectedIndex < 1)
        {
            return
        }
        trigger := this.Entries[this.SelectedIndex]["Trigger"]
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
