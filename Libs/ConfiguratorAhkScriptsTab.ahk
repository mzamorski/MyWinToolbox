#Requires AutoHotkey v2.0

; AHK script entries share the active profile INI with the Settings and
; Scheduled Tasks tabs. Save them together through the existing backup/UAC flow.
class ConfiguratorAhkScriptsTab
{
    __New(window, profileDocument, onDirtyCallback := 0)
    {
        this.Window := window
        this.ProfileDoc := profileDocument
        this.OnDirtyCallback := onDirtyCallback
        this.Scripts := profileDocument.GetSectionEntries("AhkScripts")
        this.HadSection := profileDocument.HasSection("AhkScripts")
        this.HadRoot := profileDocument.HasKey("AhkScriptsSettings", "Root")
        this.Root := profileDocument.Get("AhkScriptsSettings", "Root", "")
        this.SelectedIndex := 0
        this.Dirty := false
        this.UpdatingControls := false

        this.Build()
        this.RefreshScripts()
    }

    Build()
    {
        this.Window.AddText(
            "x30 y54 w1070 h35",
            "Run or stop other AutoHotkey v2 scripts from Ctrl+Win+T > AHK Scripts. "
                . "Checked means the exact script is running (also when started externally)."
        )

        this.Window.AddGroupBox("x25 y105 w1110 h500", "AHK scripts (active Home / Work profile)")
        this.Window.AddText("x45 y135 w620", "Base folder for relative script paths (optional)")
        this.RootEdit := this.Window.AddEdit("x45 y160 w1030 h28", this.Root)
        this.RootEdit.OnEvent("Change", ObjBindMethod(this, "OnRootChanged"))

        this.Window.AddText("x45 y209 w390", "Menu label")
        this.List := this.Window.AddListBox("x45 y230 w390 h275")
        this.List.OnEvent("Change", ObjBindMethod(this, "OnSelected"))

        this.AddButton := this.Window.AddButton("x45 y519 w100 h32", "+ Add")
        this.AddButton.OnEvent("Click", ObjBindMethod(this, "OnAdd"))

        this.DeleteButton := this.Window.AddButton("x155 y519 w100 h32", "Delete")
        this.DeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDelete"))

        this.Window.AddText("x475 y209 w600", "Name displayed in menu")
        this.NameEdit := this.Window.AddEdit("x475 y230 w610 h28")
        this.NameEdit.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText("x475 y278 w600", "Path to .ahk script (absolute or relative to base folder)")
        this.PathEdit := this.Window.AddEdit("x475 y302 w610 h28")
        this.PathEdit.OnEvent("Change", ObjBindMethod(this, "OnChanged"))

        this.Window.AddText(
            "x475 y353 w610 h170",
            "Example for the MyWinToolbox-Private repository:" Chr(10)
                . "  Base folder: C:\Repos\MyWinToolbox-Private" Chr(10)
                . "  Script path: Games\WARDOGS-Hammer.ahk" Chr(10) Chr(10)
                . "An empty base folder resolves relative paths from the main MyWinToolbox script directory. "
                . "Absolute paths always work regardless of the base folder." Chr(10) Chr(10)
                . "Stopping a script sends it a normal close signal, so its AHK OnExit handlers can run. "
                . "Running scripts started by other means are also detected."
        )
    }

    RefreshScripts(preferredIndex := 0, reloadEditor := true)
    {
        this.UpdatingControls := true
        try
        {
            this.List.Delete()
            names := []
            for entry in this.Scripts
            {
                name := Trim("" entry["Name"])
                names.Push(name != "" ? name : "(unnamed script)")
            }

            if (names.Length > 0)
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
        this.UpdatingControls := true
        try
        {
            entry := this.SelectedIndex > 0 ? this.Scripts[this.SelectedIndex] : 0
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

    OnRootChanged(*)
    {
        if (this.UpdatingControls)
        {
            return
        }
        this.Root := Trim(this.RootEdit.Value)
        this.SetDirty()
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

        entry := this.Scripts[this.SelectedIndex]
        entry["Name"] := this.NameEdit.Value
        entry["Value"] := this.PathEdit.Value
        this.SetDirty()
        this.RefreshScripts(this.SelectedIndex, false)
    }

    OnAdd(*)
    {
        response := InputBox("Display name for the AHK script:", "Add AHK script", "w430 h140")
        if (response.Result != "OK")
        {
            return
        }
        name := Trim(response.Value)
        if (name = "")
        {
            return
        }
        for entry in this.Scripts
        {
            if (StrLower(Trim(entry["Name"])) = StrLower(name))
            {
                MsgBox("Script label already exists: " name, "AHK scripts", "Iconx")
                return
            }
        }

        this.Scripts.Push(Map("Name", name, "Value", ""))
        this.RefreshScripts(this.Scripts.Length)
        this.SetDirty()
        this.PathEdit.Focus()
    }

    OnDelete(*)
    {
        if (this.SelectedIndex < 1)
        {
            return
        }

        name := this.Scripts[this.SelectedIndex]["Name"]
        if (
            MsgBox(
                "Remove '" name "' from the menu?" Chr(10)
                    . "The actual AHK file will not be deleted or stopped.",
                "AHK scripts",
                "YesNo Icon!"
            ) != "Yes"
        )
        {
            return
        }

        oldIndex := this.SelectedIndex
        this.Scripts.RemoveAt(oldIndex)
        this.RefreshScripts(Min(oldIndex, this.Scripts.Length))
        this.SetDirty()
    }

    Validate()
    {
        AhkScriptManager.ValidateEntries(this.Scripts)
        if (this.Root != "")
        {
            AhkScriptManager.FullPath(this.Root, A_ScriptDir)
        }
        return true
    }

    ApplyToDocument()
    {
        if (this.HadSection || this.Scripts.Length > 0)
        {
            this.ProfileDoc.ReplaceSectionEntries("AhkScripts", this.Scripts)
        }

        if (this.HadRoot || this.Root != "")
        {
            this.ProfileDoc.Set("AhkScriptsSettings", "Root", this.Root)
        }
    }

    MarkSaved()
    {
        this.HadSection := this.ProfileDoc.HasSection("AhkScripts")
        this.HadRoot := this.ProfileDoc.HasKey("AhkScriptsSettings", "Root")
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
