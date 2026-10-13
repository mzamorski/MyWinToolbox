#Requires AutoHotkey v2.0

; A tab in the existing Configurator. Uses the same profile INI document as
; Settings, so simultaneous edits are saved together without lost updates.
class ConfiguratorScheduledTasksTab
{
    __New(window, profileDocument, onDirtyCallback := 0)
    {
        this.Window := window
        this.ProfileDoc := profileDocument
        this.OnDirtyCallback := onDirtyCallback
        this.Tasks := profileDocument.GetSectionEntries("ScheduledTasks")
        this.HadSection := profileDocument.HasSection("ScheduledTasks")
        this.SelectedIndex := 0
        this.Dirty := false
        this.UpdatingControls := false

        this.Build()
        this.RefreshTasks()
    }

    Build()
    {
        this.Window.AddText(
            "x30 y52 w1070 h40",
            "Choose tasks from Windows Task Scheduler to toggle in the Ctrl+Win+T menu. "
                . "Disabling a task prevents future scheduled runs; it does not stop a running instance."
        )

        this.Window.AddGroupBox("x25 y102 w1110 h500", "Scheduled tasks (active Home / Work profile)")
        this.Window.AddText("x45 y137 w390", "Menu label")
        this.TaskList := this.Window.AddListBox("x45 y162 w390 h336")
        this.TaskList.OnEvent("Change", ObjBindMethod(this, "OnSelected"))

        this.AddButton := this.Window.AddButton("x45 y519 w100 h32", "+ Add")
        this.AddButton.OnEvent("Click", ObjBindMethod(this, "OnAdd"))

        this.DeleteButton := this.Window.AddButton("x155 y519 w100 h32", "Delete")
        this.DeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDelete"))

        this.Window.AddText("x475 y145 w600", "Name displayed in the menu")
        this.NameEdit := this.Window.AddEdit("x475 y168 w610 h28")
        this.NameEdit.OnEvent("Change", ObjBindMethod(this, "OnValueChanged"))

        this.Window.AddText("x475 y219 w600", "Full Task Scheduler path")
        this.PathEdit := this.Window.AddEdit("x475 y242 w610 h28")
        this.PathEdit.OnEvent("Change", ObjBindMethod(this, "OnValueChanged"))

        this.Window.AddText(
            "x475 y288 w600 h105",
            "Examples:" Chr(10)
                . "  \MyTask" Chr(10)
                . "  \MyTasks\DailyCleanup" Chr(10) Chr(10)
                . "Use the task's actual name and folder path, not its executable or Windows service name."
        )

        this.Window.AddText(
            "x475 y410 w600 h110",
            "The menu reads each task's real Enabled state every time it opens. "
                . "Missing or inaccessible tasks are shown as unavailable. "
                . "Changes to this list take effect after Save (no reload required). "
                . "Windows may require administrator approval to toggle protected tasks."
        )
    }

    RefreshTasks(preferredIndex := 0, reloadInputs := true)
    {
        this.UpdatingControls := true
        try
        {
            this.TaskList.Delete()
            names := []
            for entry in this.Tasks
            {
                name := Trim(entry["Name"])
                names.Push(name = "" ? "(unnamed task)" : name)
            }

            if (names.Length)
            {
                this.TaskList.Add(names)
                index := preferredIndex >= 1 && preferredIndex <= names.Length
                    ? preferredIndex
                    : 1
                this.TaskList.Choose(index)
                this.SelectedIndex := index
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

        if (reloadInputs)
        {
            this.LoadSelected()
        }
        this.DeleteButton.Enabled := this.SelectedIndex > 0
    }

    LoadSelected()
    {
        this.UpdatingControls := true
        try
        {
            entry := this.SelectedIndex > 0 ? this.Tasks[this.SelectedIndex] : 0
            this.NameEdit.Value := entry ? entry["Name"] : ""
            this.PathEdit.Value := entry ? entry["Value"] : ""
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
        if (this.UpdatingControls || this.TaskList.Value < 1)
        {
            return
        }

        this.SelectedIndex := this.TaskList.Value
        this.LoadSelected()
    }

    OnValueChanged(*)
    {
        if (this.UpdatingControls || this.SelectedIndex < 1)
        {
            return
        }

        entry := this.Tasks[this.SelectedIndex]
        entry["Name"] := this.NameEdit.Value
        entry["Value"] := this.PathEdit.Value
        this.SetDirty()
        this.RefreshTasks(this.SelectedIndex, false)
    }

    OnAdd(*)
    {
        result := InputBox("Name displayed in the menu:", "Add scheduled task", "w430 h140")
        if (result.Result != "OK")
        {
            return
        }

        name := Trim(result.Value)
        if (name = "")
        {
            return
        }

        for entry in this.Tasks
        {
            if (StrLower(Trim(entry["Name"])) = StrLower(name))
            {
                MsgBox("This menu label already exists: " name, "Scheduled tasks", "Iconx")
                return
            }
        }

        this.Tasks.Push(Map("Name", name, "Value", "\"))
        this.RefreshTasks(this.Tasks.Length)
        this.SetDirty()
        this.PathEdit.Focus()
    }

    OnDelete(*)
    {
        if (this.SelectedIndex < 1)
        {
            return
        }

        name := this.Tasks[this.SelectedIndex]["Name"]
        message := "Remove '" name "' from the menu?" Chr(10)
            . "The Windows task itself will not be deleted."
        if (MsgBox(message, "Scheduled tasks", "YesNo Icon!") != "Yes")
        {
            return
        }

        oldIndex := this.SelectedIndex
        this.Tasks.RemoveAt(oldIndex)
        this.RefreshTasks(Min(oldIndex, this.Tasks.Length))
        this.SetDirty()
    }

    SetDirty()
    {
        this.Dirty := true
        if (this.OnDirtyCallback)
        {
            this.OnDirtyCallback.Call()
        }
    }

    Validate()
    {
        return ScheduledTasksManager.ValidateEntries(this.Tasks)
    }

    ApplyToDocument()
    {
        if (this.HadSection || this.Tasks.Length > 0)
        {
            this.ProfileDoc.ReplaceSectionEntries("ScheduledTasks", this.Tasks)
        }
    }

    MarkSaved()
    {
        this.HadSection := this.ProfileDoc.HasSection("ScheduledTasks")
        this.Dirty := false
    }
}
