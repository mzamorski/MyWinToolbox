#Requires AutoHotkey v2.0

; Single editor for both Task Scheduler entries and external AHK scripts.
; Two INI sections preserve compatibility with existing profile configurations.
class ConfiguratorTasksTab
{
    static SCHEDULER := "Scheduled Task"
    static AHK := "AHK Script"

    __New(window, profileDoc, onDirtyCallback := 0)
    {
        this.Window := window
        this.ProfileDoc := profileDoc
        this.OnDirtyCallback := onDirtyCallback
        this.HadScheduled := profileDoc.HasSection("ScheduledTasks")
        this.HadAhk := profileDoc.HasSection("AhkScripts")
        this.Entries := []
        this.SelectedIndex := 0
        this.Dirty := false
        this.UpdatingControls := false

        for entry in profileDoc.GetSectionEntries("ScheduledTasks")
        {
            this.Entries.Push(Map(
                "Type", ConfiguratorTasksTab.SCHEDULER,
                "Name", entry["Name"],
                "Value", entry["Value"]
            ))
        }
        for entry in profileDoc.GetSectionEntries("AhkScripts")
        {
            this.Entries.Push(Map(
                "Type", ConfiguratorTasksTab.AHK,
                "Name", entry["Name"],
                "Value", entry["Value"]
            ))
        }

        this.Build()
        this.RefreshEntries()
    }

    Build()
    {
        this.Window.AddText(
            "x30 y52 w1060 h45",
            "Manage Windows Task Scheduler entries and external AHK v2 scripts in one Tasks menu. "
                . "A checkmark means an instance is currently running; statuses refresh on each menu opening."
        )
        this.Window.AddGroupBox("x25 y105 w1110 h500", "Tasks (active Home / Work profile)")
        this.Window.AddText("x45 y135 w385", "Configured tasks and scripts")
        this.List := this.Window.AddListBox("x45 y160 w390 h340")
        this.List.OnEvent("Change", ObjBindMethod(this, "OnSelected"))

        this.AddButton := this.Window.AddButton("x45 y521 w100 h32", "+ Add")
        this.AddButton.OnEvent("Click", ObjBindMethod(this, "OnAdd"))
        this.DeleteButton := this.Window.AddButton("x155 y521 w100 h32", "Delete")
        this.DeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDelete"))

        this.Window.AddText("x475 y135 w350", "Task type")
        this.TypeList := this.Window.AddDropDownList(
            "x475 y159 w340",
            [ConfiguratorTasksTab.SCHEDULER, ConfiguratorTasksTab.AHK]
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
                typeLabel := entry["Type"] = ConfiguratorTasksTab.AHK
                    ? "AHK"
                    : "Scheduler"
                displayName := Trim("" entry["Name"])
                names.Push("[" typeLabel "] " (
                    displayName = "" ? "(unnamed)" : displayName
                ))
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

    GetEntriesByType(typeName)
    {
        result := []
        for entry in this.Entries
        {
            if (entry["Type"] = typeName)
            {
                result.Push(Map("Name", entry["Name"], "Value", entry["Value"]))
            }
        }
        return result
    }

    Validate()
    {
        ScheduledTasksManager.ValidateEntries(
            this.GetEntriesByType(ConfiguratorTasksTab.SCHEDULER)
        )
        AhkScriptManager.ValidateEntries(
            this.GetEntriesByType(ConfiguratorTasksTab.AHK)
        )
        return true
    }

    ApplyToDocument()
    {
        scheduled := this.GetEntriesByType(ConfiguratorTasksTab.SCHEDULER)
        scripts := this.GetEntriesByType(ConfiguratorTasksTab.AHK)
        if (this.HadScheduled || scheduled.Length)
        {
            this.ProfileDoc.ReplaceSectionEntries("ScheduledTasks", scheduled)
        }
        if (this.HadAhk || scripts.Length)
        {
            this.ProfileDoc.ReplaceSectionEntries("AhkScripts", scripts)
        }
    }

    MarkSaved()
    {
        this.HadScheduled := this.ProfileDoc.HasSection("ScheduledTasks")
        this.HadAhk := this.ProfileDoc.HasSection("AhkScripts")
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
