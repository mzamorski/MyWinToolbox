#Requires AutoHotkey v2.0

; One editor backed by a single [Tasks] INI section with typed entries.
; Legacy sections are imported and removed on the next Save.
class ConfiguratorTasksTab
{
    static SCHEDULER := TasksRegistry.SCHEDULER
    static AHK := TasksRegistry.AHK

    __New(window, profileDoc, onDirtyCallback := 0)
    {
        this.Window := window
        this.ProfileDoc := profileDoc
        this.OnDirtyCallback := onDirtyCallback
        this.HadTasks := profileDoc.HasSection("Tasks")
        this.Entries := TasksRegistry.FromIniEntries(
            profileDoc.GetSectionEntries("Tasks", false)
        )
        this.SelectedIndex := 0
        this.Dirty := false
        this.UpdatingControls := false

        if (this.Entries.Length = 0)
        {
            legacyScheduled := profileDoc.GetSectionEntries("ScheduledTasks", false)
            legacyAhk := profileDoc.GetSectionEntries("AhkScripts", false)
            if (legacyScheduled.Length || legacyAhk.Length)
            {
                root := profileDoc.Get("AhkScriptsSettings", "Root", "")
                this.Entries := TasksRegistry.LegacyEntries(
                    legacyScheduled, legacyAhk, root
                )
                ; Existing legacy tasks will be migrated on Save.
                this.Dirty := true
            }
        }

        this.Build()
        this.RefreshEntries()
    }

    Build()
    {
        this.Window.AddText(
            "x30 y52 w1060 h45",
            "Manage all runnable Tasks in one list. A checkmark means actually running, "
                . "not merely enabled for future scheduled executions."
        )
        this.Window.AddGroupBox("x25 y105 w1110 h500", "Tasks (active Home / Work profile)")
        this.Window.AddText("x45 y135 w385", "Configured tasks")
        this.List := this.Window.AddListBox("x45 y160 w390 h340")
        this.List.OnEvent("Change", ObjBindMethod(this, "OnSelected"))

        this.AddButton := this.Window.AddButton("x45 y521 w100 h32", "+ Add")
        this.AddButton.OnEvent("Click", ObjBindMethod(this, "OnAdd"))
        this.DeleteButton := this.Window.AddButton("x155 y521 w100 h32", "Delete")
        this.DeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDelete"))

        this.Window.AddText("x475 y135 w350", "Task type")
        this.TypeList := this.Window.AddDropDownList(
            "x475 y159 w340",
            ["Scheduled Task", "AHK Script"]
        )
        this.TypeList.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText("x475 y207 w450", "Name displayed in Tasks menu")
        this.NameEdit := this.Window.AddEdit("x475 y232 w610 h26")
        this.NameEdit.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText("x475 y281 w550", "Full task path / absolute path to the .ahk file")
        this.PathEdit := this.Window.AddEdit("x475 y306 w610 h26")
        this.PathEdit.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText(
            "x475 y357 w615 h180",
            "Scheduled Task: \MyTasks\Backup" Chr(10)
                . "AHK Script: C:\Repos\MyWinToolbox-Private\Games\WARDOGS-Hammer.ahk"
                . Chr(10) Chr(10)
                . "For AHK scripts, use the full path. No root folder setting is needed."
                . Chr(10)
                . "Starting/stopping uses the task's actual runtime state. "
                . "A separate Scheduling submenu controls future Windows scheduled runs. "
                . "Closing an AHK script sends a normal close request (OnExit handlers run)."
        )
    }

    RefreshEntries(preferredIndex := 0, reloadEditor := true)
    {
        this.UpdatingControls := true
        try
        {
            this.List.Delete()
            names := []
            for entry in this.Entries
            {
                displayName := Trim("" entry["Name"])
                names.Push(displayName = "" ? "(unnamed)" : displayName)
            }
            if (names.Length)
            {
                this.List.Add(names)
                this.SelectedIndex := preferredIndex >= 1 && preferredIndex <= names.Length
                    ? preferredIndex
                    : 1
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
        entry := this.SelectedIndex > 0 ? this.Entries[this.SelectedIndex] : 0
        this.UpdatingControls := true
        try
        {
            this.TypeList.Choose(
                entry && entry["Type"] = ConfiguratorTasksTab.AHK ? 2 : 1
            )
            this.NameEdit.Value := entry ? entry["Name"] : ""
            this.PathEdit.Value := entry ? entry["Value"] : ""
            this.TypeList.Enabled := !!entry
            this.NameEdit.Enabled := !!entry
            this.PathEdit.Enabled := !!entry
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
        entry["Type"] := this.TypeList.Value = 2
            ? ConfiguratorTasksTab.AHK
            : ConfiguratorTasksTab.SCHEDULER
        entry["Name"] := this.NameEdit.Value
        entry["Value"] := this.PathEdit.Value
        this.SetDirty()
        this.RefreshEntries(this.SelectedIndex, false)
    }

    OnAdd(*)
    {
        result := InputBox(
            "Name displayed in the Tasks menu:",
            "Add task or AHK script",
            "w440 h140"
        )
        if (result.Result != "OK" || Trim(result.Value) = "")
        {
            return
        }
        this.Entries.Push(Map(
            "Type", ConfiguratorTasksTab.SCHEDULER,
            "Name", Trim(result.Value),
            "Value", ""
        ))
        this.RefreshEntries(this.Entries.Length)
        this.SetDirty()
        this.TypeList.Focus()
    }

    OnDelete(*)
    {
        if (this.SelectedIndex < 1)
        {
            return
        }
        name := this.Entries[this.SelectedIndex]["Name"]
        if (
            MsgBox(
                "Remove '" name "' from Tasks?" Chr(10)
                    . "This does not delete or stop the actual task/script.",
                "MyWinToolbox Tasks",
                "YesNo Icon!"
            ) != "Yes"
        )
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
        TasksRegistry.ValidateEntries(this.Entries)
        return true
    }

    ApplyToDocument()
    {
        this.ProfileDoc.ReplaceSectionEntries(
            "Tasks", TasksRegistry.ToIniEntries(this.Entries), false
        )

        ; Migrate users of the previous experimental builds. The new INI has
        ; exactly one task section and no separate AHK root configuration.
        this.ProfileDoc.DeleteSection("ScheduledTasks")
        this.ProfileDoc.DeleteSection("AhkScripts")
        this.ProfileDoc.DeleteSection("AhkScriptsSettings")
    }

    MarkSaved()
    {
        this.HadTasks := this.ProfileDoc.HasSection("Tasks")
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
