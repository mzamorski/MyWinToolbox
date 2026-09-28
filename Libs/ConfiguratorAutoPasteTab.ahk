#Requires AutoHotkey v2.0

class ConfiguratorAutoPasteTab
{
    __New(window, data, filePath, onDirtyCallback := 0, onSavedCallback := 0)
    {
        this.Window := window
        this.Data := ConfiguratorJsonStore.Clone(data)
        this.FilePath := filePath
        this.OnDirtyCallback := onDirtyCallback
        this.OnSavedCallback := onSavedCallback
        this.Dirty := false
        this.UpdatingControls := false
        this.SelectedRuleIndex := 0
        this.SelectedActionIndex := 0

        if (Type(this.Data) != "Array")
        {
            throw Error("AutoPastes.json root value must be an array.")
        }

        this.NormalizeLegacyRules()
        this.Build()
        this.RefreshRules()
    }

    NormalizeLegacyRules()
    {
        for rule in this.Data
        {
            if (!IsObject(rule) || !(rule is Map) || rule.Has("actions"))
            {
                continue
            }

            actions := AutoPaste_GetActions(rule)
            if (actions.Length = 0)
            {
                continue
            }

            rule["actions"] := ConfiguratorJsonStore.Clone(actions)

            for legacyField in ["focus", "focusDelay", "passwordKey", "text"]
            {
                if (rule.Has(legacyField))
                {
                    rule.Delete(legacyField)
                }
            }
        }
    }

    Build()
    {
        this.Window.AddText("x25 y50 w330", "Rules")
        this.RuleList := this.Window.AddListView(
            "x25 y72 w330 h478 -Multi",
            ["Name", "Match"]
        )
        this.RuleList.ModifyCol(1, 130)
        this.RuleList.ModifyCol(2, 175)
        this.RuleList.OnEvent("ItemSelect", ObjBindMethod(this, "OnRuleSelected"))

        this.Window.AddText("x375 y50 w760", "Rule")

        this.Window.AddText("x375 y78 w60", "Name")
        this.NameEdit := this.Window.AddEdit("x375 y98 w235 h25")
        this.NameEdit.OnEvent("Change", ObjBindMethod(this, "OnRuleEditorChanged"))

        this.Window.AddText("x625 y78 w60", "EXE")
        this.ExeEdit := this.Window.AddEdit("x625 y98 w235 h25")
        this.ExeEdit.OnEvent("Change", ObjBindMethod(this, "OnRuleEditorChanged"))

        this.Window.AddText("x875 y78 w60", "Class")
        this.ClassEdit := this.Window.AddEdit("x875 y98 w260 h25")
        this.ClassEdit.OnEvent("Change", ObjBindMethod(this, "OnRuleEditorChanged"))

        this.Window.AddText("x375 y136 w60", "Title")
        this.TitleEdit := this.Window.AddEdit("x375 y156 w360 h25")
        this.TitleEdit.OnEvent("Change", ObjBindMethod(this, "OnRuleEditorChanged"))

        this.TitleMode := this.Window.AddDropDownList(
            "x745 y156 w115",
            ["contains", "equals"]
        )
        this.TitleMode.OnEvent("Change", ObjBindMethod(this, "OnRuleEditorChanged"))

        this.Window.AddText("x875 y136 w60", "URL")
        this.UrlEdit := this.Window.AddEdit("x875 y156 w260 h25")
        this.UrlEdit.OnEvent("Change", ObjBindMethod(this, "OnRuleEditorChanged"))

        this.Window.AddText("x375 y194 w90", "URL mode")
        this.UrlMode := this.Window.AddDropDownList(
            "x445 y191 w115",
            ["contains", "equals"]
        )
        this.UrlMode.OnEvent("Change", ObjBindMethod(this, "OnRuleEditorChanged"))

        this.Window.AddText("x575 y194 w90", "Trigger")
        this.TriggerMode := this.Window.AddDropDownList(
            "x635 y191 w145",
            ["oncePerWindow", "oncePerUrl", "always"]
        )
        this.TriggerMode.OnEvent("Change", ObjBindMethod(this, "OnRuleEditorChanged"))

        this.NotifyCheck := this.Window.AddCheckBox(
            "x800 y193 w130 h24",
            "Notify on match"
        )
        this.NotifyCheck.OnEvent("Click", ObjBindMethod(this, "OnRuleEditorChanged"))

        this.Window.AddText("x945 y194 w80", "Delay ms")
        this.DelayEdit := this.Window.AddEdit("x1010 y191 w125 h25 Number")
        this.DelayEdit.OnEvent("Change", ObjBindMethod(this, "OnRuleEditorChanged"))

        this.Window.AddText("x375 y235 w340", "Actions")
        this.ActionList := this.Window.AddListView(
            "x375 y257 w380 h260 -Multi",
            ["Type", "Value"]
        )
        this.ActionList.ModifyCol(1, 95)
        this.ActionList.ModifyCol(2, 260)
        this.ActionList.OnEvent("ItemSelect", ObjBindMethod(this, "OnActionSelected"))

        this.Window.AddText("x775 y235 w360", "Action editor")
        this.Window.AddText("x775 y263 w55", "Type")
        this.ActionType := this.Window.AddDropDownList(
            "x825 y259 w150",
            ["text", "passwordKey", "keys", "delay"]
        )
        this.ActionType.OnEvent("Change", ObjBindMethod(this, "OnActionEditorChanged"))

        this.Window.AddText("x775 y300 w60", "Value")
        this.ActionValue := this.Window.AddEdit("x775 y320 w360 h145 WantTab")
        this.ActionValue.SetFont("s9", "Consolas")
        this.ActionValue.OnEvent("Change", ObjBindMethod(this, "OnActionEditorChanged"))

        this.ActionAddButton := this.Window.AddButton("x775 y478 w76 h30", "+ Action")
        this.ActionAddButton.OnEvent("Click", ObjBindMethod(this, "OnAddAction"))

        this.ActionDuplicateButton := this.Window.AddButton("x859 y478 w82 h30", "Duplicate")
        this.ActionDuplicateButton.OnEvent("Click", ObjBindMethod(this, "OnDuplicateAction"))

        this.ActionDeleteButton := this.Window.AddButton("x949 y478 w70 h30", "Delete")
        this.ActionDeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDeleteAction"))

        this.ActionUpButton := this.Window.AddButton("x1027 y478 w50 h30", "Up")
        this.ActionUpButton.OnEvent("Click", ObjBindMethod(this, "OnActionMoveUp"))

        this.ActionDownButton := this.Window.AddButton("x1085 y478 w50 h30", "Down")
        this.ActionDownButton.OnEvent("Click", ObjBindMethod(this, "OnActionMoveDown"))

        this.RuleAddButton := this.Window.AddButton("x25 y570 w72 h30", "+ Rule")
        this.RuleAddButton.OnEvent("Click", ObjBindMethod(this, "OnAddRule"))

        this.RuleDuplicateButton := this.Window.AddButton("x105 y570 w82 h30", "Duplicate")
        this.RuleDuplicateButton.OnEvent("Click", ObjBindMethod(this, "OnDuplicateRule"))

        this.RuleDeleteButton := this.Window.AddButton("x195 y570 w66 h30", "Delete")
        this.RuleDeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDeleteRule"))

        this.RuleUpButton := this.Window.AddButton("x269 y570 w38 h30", "Up")
        this.RuleUpButton.OnEvent("Click", ObjBindMethod(this, "OnRuleMoveUp"))

        this.RuleDownButton := this.Window.AddButton("x315 y570 w40 h30", "Dn")
        this.RuleDownButton.OnEvent("Click", ObjBindMethod(this, "OnRuleMoveDown"))

        this.CaptureWindowButton := this.Window.AddButton(
            "x375 y570 w130 h30",
            "Capture window..."
        )
        this.CaptureWindowButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnCaptureWindow")
        )

        this.TestMatchButton := this.Window.AddButton(
            "x515 y570 w115 h30",
            "Test match..."
        )
        this.TestMatchButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnTestMatch")
        )

        this.Window.AddText(
            "x645 y566 w490 h48",
            "Capture/Test hides the Configurator temporarily. Click the target window. "
            "Browser URL is read non-interactively through UI Automation."
        )
    }

    Validate()
    {
        AutoPaste_ValidateEntries(this.Data)
        return true
    }

    Save()
    {
        this.Validate()
        ConfiguratorJsonStore.SaveWithBackup(this.FilePath, this.Data)
        this.Dirty := false

        if (this.OnSavedCallback)
        {
            this.OnSavedCallback.Call(ConfiguratorJsonStore.Clone(this.Data))
        }
    }

    SetDirty()
    {
        this.Dirty := true

        if (this.OnDirtyCallback)
        {
            this.OnDirtyCallback.Call()
        }
    }

    GetSelectedRule()
    {
        if (this.SelectedRuleIndex < 1 || this.SelectedRuleIndex > this.Data.Length)
        {
            return 0
        }

        return this.Data[this.SelectedRuleIndex]
    }

    GetActions(rule := 0)
    {
        if (!rule)
        {
            rule := this.GetSelectedRule()
        }

        if (!rule || !rule.Has("actions") || Type(rule["actions"]) != "Array")
        {
            return 0
        }

        return rule["actions"]
    }

    GetSelectedAction()
    {
        actions := this.GetActions()

        if (
            !actions
            || this.SelectedActionIndex < 1
            || this.SelectedActionIndex > actions.Length
        )
        {
            return 0
        }

        return actions[this.SelectedActionIndex]
    }

    RefreshRules(preferredIndex := 0)
    {
        this.UpdatingControls := true
        try
        {
            this.RuleList.Delete()

            for index, rule in this.Data
            {
                name := rule.Has("name") && Trim("" rule["name"]) != ""
                    ? rule["name"]
                    : "Rule #" index

                this.RuleList.Add(
                    "",
                    name,
                    ConfiguratorAutoPasteTab.GetRuleMatchSummary(rule)
                )
            }

            if (this.Data.Length > 0)
            {
                selectedIndex := preferredIndex
                if (selectedIndex < 1 || selectedIndex > this.Data.Length)
                {
                    selectedIndex := 1
                }

                this.RuleList.Modify(selectedIndex, "Select Focus Vis")
                this.SelectedRuleIndex := selectedIndex
            }
            else
            {
                this.SelectedRuleIndex := 0
            }
        }
        finally
        {
            this.UpdatingControls := false
        }

        this.LoadSelectedRule()
        this.UpdateRuleButtons()
    }

    static GetRuleMatchSummary(rule)
    {
        parts := []

        for fieldName in ["exe", "class", "title", "url"]
        {
            if (rule.Has(fieldName) && Trim("" rule[fieldName]) != "")
            {
                parts.Push(fieldName "=" rule[fieldName])
            }
        }

        if (parts.Length = 0)
        {
            return "<no matcher>"
        }

        summary := ConfiguratorJsonStore.JoinList(parts)
        return StrLen(summary) > 45 ? SubStr(summary, 1, 42) "..." : summary
    }

    OnRuleSelected(control, rowNumber, selected)
    {
        if (this.UpdatingControls || !selected || rowNumber = 0)
        {
            return
        }

        this.SelectedRuleIndex := rowNumber
        this.LoadSelectedRule()
        this.UpdateRuleButtons()
    }

    LoadSelectedRule()
    {
        rule := this.GetSelectedRule()

        this.UpdatingControls := true
        try
        {
            if (!rule)
            {
                this.NameEdit.Value := ""
                this.ExeEdit.Value := ""
                this.ClassEdit.Value := ""
                this.TitleEdit.Value := ""
                this.TitleMode.Choose(1)
                this.UrlEdit.Value := ""
                this.UrlMode.Choose(1)
                this.TriggerMode.Choose(1)
                this.NotifyCheck.Value := 0
                this.DelayEdit.Value := ""
                this.RefreshActions()
                return
            }

            this.NameEdit.Value := rule.Has("name") ? rule["name"] : ""
            this.ExeEdit.Value := rule.Has("exe") ? rule["exe"] : ""
            this.ClassEdit.Value := rule.Has("class") ? rule["class"] : ""
            this.TitleEdit.Value := rule.Has("title") ? rule["title"] : ""
            this.TitleMode.Choose(
                rule.Has("titleMatchMode")
                    && StrLower("" rule["titleMatchMode"]) = "equals"
                    ? 2
                    : 1
            )

            this.UrlEdit.Value := rule.Has("url") ? rule["url"] : ""
            this.UrlMode.Choose(
                rule.Has("urlMatchMode")
                    && StrLower("" rule["urlMatchMode"]) = "equals"
                    ? 2
                    : 1
            )

            triggerMode := rule.Has("triggerMode")
                ? StrLower("" rule["triggerMode"])
                : "onceperwindow"

            this.TriggerMode.Choose(
                triggerMode = "onceperurl"
                    ? 2
                    : (triggerMode = "always" ? 3 : 1)
            )

            this.NotifyCheck.Value := rule.Has("notifyOnMatch")
                && rule["notifyOnMatch"]
                ? 1
                : 0

            this.DelayEdit.Value := rule.Has("delay") ? rule["delay"] : ""
        }
        finally
        {
            this.UpdatingControls := false
        }

        this.RefreshActions()
    }

    OnRuleEditorChanged(*)
    {
        if (this.UpdatingControls)
        {
            return
        }

        rule := this.GetSelectedRule()
        if (!rule)
        {
            return
        }

        this.SetOrDeleteString(rule, "name", this.NameEdit.Value, true)
        this.SetOrDeleteString(rule, "exe", this.ExeEdit.Value)
        this.SetOrDeleteString(rule, "class", this.ClassEdit.Value)
        this.SetOrDeleteString(rule, "title", this.TitleEdit.Value)
        this.SetOrDeleteString(rule, "url", this.UrlEdit.Value)

        if (rule.Has("title"))
        {
            if (this.TitleMode.Text = "equals")
            {
                rule["titleMatchMode"] := "equals"
            }
            else if (rule.Has("titleMatchMode"))
            {
                rule.Delete("titleMatchMode")
            }
        }
        else if (rule.Has("titleMatchMode"))
        {
            rule.Delete("titleMatchMode")
        }

        if (rule.Has("url"))
        {
            if (this.UrlMode.Text = "equals")
            {
                rule["urlMatchMode"] := "equals"
            }
            else if (rule.Has("urlMatchMode"))
            {
                rule.Delete("urlMatchMode")
            }
        }
        else if (rule.Has("urlMatchMode"))
        {
            rule.Delete("urlMatchMode")
        }

        rule["triggerMode"] := this.TriggerMode.Text
        rule["notifyOnMatch"] := this.NotifyCheck.Value ? true : false

        delayText := Trim(this.DelayEdit.Value)
        if (delayText = "")
        {
            if (rule.Has("delay"))
            {
                rule.Delete("delay")
            }
        }
        else
        {
            rule["delay"] := IsNumber(delayText) ? (delayText + 0) : delayText
        }

        this.SetDirty()
        this.RefreshRuleRow()
    }

    SetOrDeleteString(target, fieldName, value, allowEmpty := false)
    {
        value := "" value

        if (!allowEmpty && Trim(value) = "")
        {
            if (target.Has(fieldName))
            {
                target.Delete(fieldName)
            }

            return
        }

        if (allowEmpty && value = "")
        {
            if (target.Has(fieldName))
            {
                target.Delete(fieldName)
            }

            return
        }

        target[fieldName] := value
    }

    RefreshRuleRow()
    {
        rule := this.GetSelectedRule()
        if (!rule || this.SelectedRuleIndex = 0)
        {
            return
        }

        name := rule.Has("name") && Trim("" rule["name"]) != ""
            ? rule["name"]
            : "Rule #" this.SelectedRuleIndex

        this.RuleList.Modify(
            this.SelectedRuleIndex,
            "",
            name,
            ConfiguratorAutoPasteTab.GetRuleMatchSummary(rule)
        )
    }

    RefreshActions(preferredIndex := 0)
    {
        actions := this.GetActions()

        this.UpdatingControls := true
        try
        {
            this.ActionList.Delete()

            if (actions)
            {
                for action in actions
                {
                    operation := ConfiguratorAutoPasteTab.GetActionOperation(action)
                    actionType := operation["Type"]
                    actionValue := operation["Value"]

                    preview := StrReplace(StrReplace("" actionValue, "`r", " "), "`n", " ")
                    if (StrLen(preview) > 42)
                    {
                        preview := SubStr(preview, 1, 39) "..."
                    }

                    this.ActionList.Add("", actionType, preview)
                }
            }

            if (actions && actions.Length > 0)
            {
                selectedIndex := preferredIndex
                if (selectedIndex < 1 || selectedIndex > actions.Length)
                {
                    selectedIndex := 1
                }

                this.ActionList.Modify(selectedIndex, "Select Focus Vis")
                this.SelectedActionIndex := selectedIndex
            }
            else
            {
                this.SelectedActionIndex := 0
            }
        }
        finally
        {
            this.UpdatingControls := false
        }

        this.LoadSelectedAction()
        this.UpdateActionButtons()
    }

    static GetActionOperation(action)
    {
        for actionType in ["text", "passwordKey", "keys", "delay"]
        {
            if (action.Has(actionType))
            {
                return Map(
                    "Type", actionType,
                    "Value", action[actionType]
                )
            }
        }

        return Map("Type", "text", "Value", "")
    }

    OnActionSelected(control, rowNumber, selected)
    {
        if (this.UpdatingControls || !selected || rowNumber = 0)
        {
            return
        }

        this.SelectedActionIndex := rowNumber
        this.LoadSelectedAction()
        this.UpdateActionButtons()
    }

    LoadSelectedAction()
    {
        action := this.GetSelectedAction()

        this.UpdatingControls := true
        try
        {
            if (!action)
            {
                this.ActionType.Choose(1)
                this.ActionValue.Value := ""
                return
            }

            operation := ConfiguratorAutoPasteTab.GetActionOperation(action)
            actionType := operation["Type"]

            this.ActionType.Choose(
                actionType = "passwordKey"
                    ? 2
                    : (actionType = "keys"
                        ? 3
                        : (actionType = "delay" ? 4 : 1))
            )

            this.ActionValue.Value := operation["Value"]
        }
        finally
        {
            this.UpdatingControls := false
        }
    }

    OnActionEditorChanged(*)
    {
        if (this.UpdatingControls)
        {
            return
        }

        action := this.GetSelectedAction()
        if (!action)
        {
            return
        }

        actionType := this.ActionType.Text
        actionValue := this.ActionValue.Value

        action.Clear()

        if (actionType = "delay")
        {
            action["delay"] := IsNumber(Trim(actionValue))
                ? (Trim(actionValue) + 0)
                : actionValue
        }
        else
        {
            action[actionType] := actionValue
        }

        this.SetDirty()
        this.RefreshActionRow()
    }

    RefreshActionRow()
    {
        action := this.GetSelectedAction()
        if (!action || this.SelectedActionIndex = 0)
        {
            return
        }

        operation := ConfiguratorAutoPasteTab.GetActionOperation(action)
        preview := StrReplace(
            StrReplace("" operation["Value"], "`r", " "),
            "`n",
            " "
        )

        if (StrLen(preview) > 42)
        {
            preview := SubStr(preview, 1, 39) "..."
        }

        this.ActionList.Modify(
            this.SelectedActionIndex,
            "",
            operation["Type"],
            preview
        )
    }

    OnAddRule(*)
    {
        this.Data.Push(
            Map(
                "name", "New rule",
                "exe", "notepad.exe",
                "triggerMode", "oncePerWindow",
                "notifyOnMatch", false,
                "actions", [Map("text", "")]
            )
        )

        this.SetDirty()
        this.RefreshRules(this.Data.Length)
        this.NameEdit.Focus()
    }

    OnDuplicateRule(*)
    {
        rule := this.GetSelectedRule()
        if (!rule)
        {
            return
        }

        clone := ConfiguratorJsonStore.Clone(rule)
        if (clone.Has("name"))
        {
            clone["name"] := clone["name"] " (copy)"
        }

        insertIndex := this.SelectedRuleIndex + 1
        this.Data.InsertAt(insertIndex, clone)

        this.SetDirty()
        this.RefreshRules(insertIndex)
    }

    OnDeleteRule(*)
    {
        rule := this.GetSelectedRule()
        if (!rule)
        {
            return
        }

        label := rule.Has("name") && rule["name"] != ""
            ? rule["name"]
            : "rule #" this.SelectedRuleIndex

        answer := MsgBox(
            "Delete AutoPaste rule '" label "'?",
            "MyWinToolbox Configurator",
            "YesNo Icon!"
        )

        if (answer != "Yes")
        {
            return
        }

        oldIndex := this.SelectedRuleIndex
        this.Data.RemoveAt(oldIndex)

        this.SetDirty()
        this.RefreshRules(Min(oldIndex, this.Data.Length))
    }

    OnRuleMoveUp(*)
    {
        index := this.SelectedRuleIndex
        if (index <= 1)
        {
            return
        }

        item := this.Data.RemoveAt(index)
        this.Data.InsertAt(index - 1, item)

        this.SetDirty()
        this.RefreshRules(index - 1)
    }

    OnRuleMoveDown(*)
    {
        index := this.SelectedRuleIndex
        if (index < 1 || index >= this.Data.Length)
        {
            return
        }

        item := this.Data.RemoveAt(index)
        this.Data.InsertAt(index + 1, item)

        this.SetDirty()
        this.RefreshRules(index + 1)
    }

    OnAddAction(*)
    {
        rule := this.GetSelectedRule()
        if (!rule)
        {
            return
        }

        if (!rule.Has("actions") || Type(rule["actions"]) != "Array")
        {
            rule["actions"] := []
        }

        actions := rule["actions"]
        actions.Push(Map("text", ""))

        this.SetDirty()
        this.RefreshActions(actions.Length)
        this.ActionValue.Focus()
    }

    OnDuplicateAction(*)
    {
        actions := this.GetActions()
        action := this.GetSelectedAction()

        if (!actions || !action)
        {
            return
        }

        insertIndex := this.SelectedActionIndex + 1
        actions.InsertAt(insertIndex, ConfiguratorJsonStore.Clone(action))

        this.SetDirty()
        this.RefreshActions(insertIndex)
    }

    OnDeleteAction(*)
    {
        actions := this.GetActions()
        action := this.GetSelectedAction()

        if (!actions || !action)
        {
            return
        }

        oldIndex := this.SelectedActionIndex
        actions.RemoveAt(oldIndex)

        this.SetDirty()
        this.RefreshActions(Min(oldIndex, actions.Length))
    }

    OnActionMoveUp(*)
    {
        actions := this.GetActions()
        index := this.SelectedActionIndex

        if (!actions || index <= 1)
        {
            return
        }

        item := actions.RemoveAt(index)
        actions.InsertAt(index - 1, item)

        this.SetDirty()
        this.RefreshActions(index - 1)
    }

    OnActionMoveDown(*)
    {
        actions := this.GetActions()
        index := this.SelectedActionIndex

        if (!actions || index < 1 || index >= actions.Length)
        {
            return
        }

        item := actions.RemoveAt(index)
        actions.InsertAt(index + 1, item)

        this.SetDirty()
        this.RefreshActions(index + 1)
    }

    OnCaptureWindow(*)
    {
        rule := this.GetSelectedRule()
        if (!rule)
        {
            return
        }

        target := this.PickTargetWindow(
            "Click the window to capture for this AutoPaste rule."
        )

        if (!target)
        {
            return
        }

        info := this.GetTargetWindowInfo(target)

        if (info["exe"] != "")
        {
            rule["exe"] := info["exe"]
        }

        if (info["class"] != "")
        {
            rule["class"] := info["class"]
        }

        if (info["title"] != "")
        {
            rule["title"] := info["title"]

            if (rule.Has("titleMatchMode"))
            {
                rule.Delete("titleMatchMode")
            }
        }

        if (info["url"] != "")
        {
            rule["url"] := info["url"]

            if (rule.Has("urlMatchMode"))
            {
                rule.Delete("urlMatchMode")
            }
        }

        if (
            (!rule.Has("name") || Trim("" rule["name"]) = "" || rule["name"] = "New rule")
            && info["exe"] != ""
        )
        {
            suggestedName := RegExReplace(info["exe"], "i)\.exe$", "")
            rule["name"] := suggestedName
        }

        this.SetDirty()
        this.RefreshRuleRow()
        this.LoadSelectedRule()

        message := "Captured:`n"
            . "EXE: " info["exe"] "`n"
            . "Class: " info["class"] "`n"
            . "Title: " info["title"]

        if (info["isBrowser"])
        {
            message .= "`nURL: " (
                info["url"] != ""
                    ? info["url"]
                    : "<not available through UI Automation>"
            )
        }

        MsgBox(
            message,
            "AutoPaste — Capture window",
            "Iconi"
        )
    }

    OnTestMatch(*)
    {
        rule := this.GetSelectedRule()
        if (!rule)
        {
            return
        }

        target := this.PickTargetWindow(
            "Click the window to test against the selected AutoPaste rule."
        )

        if (!target)
        {
            return
        }

        info := this.GetTargetWindowInfo(target)
        result := ConfiguratorAutoPasteTab.EvaluateRuleMatchers(rule, info)

        message := result["Matched"]
            ? "MATCH — all configured criteria passed."
            : "NO MATCH — one or more criteria failed."

        message .= "`n`n" result["Details"]
            . "`n`nTarget:"
            . "`nEXE: " info["exe"]
            . "`nClass: " info["class"]
            . "`nTitle: " info["title"]

        if (rule.Has("url") || info["isBrowser"])
        {
            message .= "`nURL: " (
                info["url"] != ""
                    ? info["url"]
                    : "<not available through UI Automation>"
            )
        }

        MsgBox(
            message,
            "AutoPaste — Test match",
            result["Matched"] ? "Iconi" : "Icon!"
        )
    }

    PickTargetWindow(instruction)
    {
        targetHwnd := 0
        configHwnd := this.Window.Hwnd

        try
        {
            this.Window.Hide()
            Sleep(150)

            ToolTip(
                instruction
                    . "`n`nClick the target window within 10 seconds."
            )

            if (!KeyWait("LButton", "D T10"))
            {
                return 0
            }

            MouseGetPos(, , &targetHwnd)
            KeyWait("LButton")

            if (!targetHwnd)
            {
                return 0
            }

            rootHwnd := DllCall(
                "GetAncestor",
                "Ptr", targetHwnd,
                "UInt", 2,
                "Ptr"
            )

            if (rootHwnd)
            {
                targetHwnd := rootHwnd
            }

            if (
                !targetHwnd
                || targetHwnd = configHwnd
                || !WinExist("ahk_id " targetHwnd)
                || !WindowApp.IsRealWindow(targetHwnd)
            )
            {
                targetHwnd := 0
            }

            return targetHwnd
        }
        finally
        {
            ToolTip()
            this.Window.Show()
            WinActivate("ahk_id " this.Window.Hwnd)
        }
    }

    GetTargetWindowInfo(hwnd)
    {
        info := Map(
            "hwnd", hwnd,
            "exe", "",
            "class", "",
            "title", "",
            "url", "",
            "isBrowser", false
        )

        AutoPaste_TryGetProcessName(hwnd, &exeName)
        AutoPaste_TryGetClass(hwnd, &className)
        AutoPaste_TryGetTitle(hwnd, &title)

        info["exe"] := exeName
        info["class"] := className
        info["title"] := title

        for browserExe in WindowApp.KnownBrowsers
        {
            if (StrLower(browserExe) = StrLower(exeName))
            {
                info["isBrowser"] := true
                break
            }
        }

        if (info["isBrowser"])
        {
            selector := "ahk_id " hwnd

            try
            {
                if (!WinActive(selector))
                {
                    WinActivate(selector)
                    WinWaitActive(selector, , 1)
                }

                if (WinActive(selector))
                {
                    info["url"] := Browser.GetURL(false)
                }
            }
            catch Error
            {
                info["url"] := ""
            }
        }

        return info
    }

    static EvaluateRuleMatchers(rule, info)
    {
        lines := []
        allMatched := true
        matcherCount := 0

        if (rule.Has("exe"))
        {
            matcherCount += 1
            matched := StrLower(info["exe"]) = StrLower(rule["exe"])
            allMatched := allMatched && matched

            lines.Push(
                ConfiguratorAutoPasteTab.FormatMatcherResult(
                    matched,
                    "EXE",
                    rule["exe"],
                    info["exe"]
                )
            )
        }

        if (rule.Has("class"))
        {
            matcherCount += 1
            matched := StrLower(info["class"]) = StrLower(rule["class"])
            allMatched := allMatched && matched

            lines.Push(
                ConfiguratorAutoPasteTab.FormatMatcherResult(
                    matched,
                    "Class",
                    rule["class"],
                    info["class"]
                )
            )
        }

        if (rule.Has("title"))
        {
            matcherCount += 1
            mode := rule.Has("titleMatchMode")
                ? rule["titleMatchMode"]
                : "contains"

            matched := AutoPaste_MatchesValue(
                info["title"],
                rule["title"],
                mode
            )
            allMatched := allMatched && matched

            lines.Push(
                ConfiguratorAutoPasteTab.FormatMatcherResult(
                    matched,
                    "Title (" mode ")",
                    rule["title"],
                    info["title"]
                )
            )
        }

        if (rule.Has("url"))
        {
            matcherCount += 1
            mode := rule.Has("urlMatchMode")
                ? rule["urlMatchMode"]
                : "contains"

            matched := info["url"] != ""
                && AutoPaste_MatchesValue(
                    info["url"],
                    rule["url"],
                    mode
                )

            allMatched := allMatched && matched

            lines.Push(
                ConfiguratorAutoPasteTab.FormatMatcherResult(
                    matched,
                    "URL (" mode ")",
                    rule["url"],
                    info["url"] != ""
                        ? info["url"]
                        : "<unavailable>"
                )
            )
        }

        if (matcherCount = 0)
        {
            return Map(
                "Matched", false,
                "Details", "✗ Rule has no configured matcher."
            )
        }

        return Map(
            "Matched", allMatched,
            "Details", ConfiguratorAutoPasteTab.JoinLines(lines)
        )
    }

    static FormatMatcherResult(matched, label, expected, actual)
    {
        marker := matched ? "✓" : "✗"

        expectedText := ConfiguratorAutoPasteTab.TruncateDiagnostic(
            "" expected,
            90
        )

        actualText := ConfiguratorAutoPasteTab.TruncateDiagnostic(
            "" actual,
            120
        )

        return marker " " label
            . "`n    expected: " expectedText
            . "`n    actual:   " actualText
    }

    static TruncateDiagnostic(value, maxLength)
    {
        value := StrReplace(StrReplace(value, "`r", " "), "`n", " ")

        return StrLen(value) > maxLength
            ? SubStr(value, 1, maxLength - 3) "..."
            : value
    }

    static JoinLines(lines)
    {
        result := ""
        separator := ""

        for line in lines
        {
            result .= separator line
            separator := "`n"
        }

        return result
    }

    UpdateRuleButtons()
    {
        hasRule := !!this.GetSelectedRule()

        for control in [
            this.NameEdit,
            this.ExeEdit,
            this.ClassEdit,
            this.TitleEdit,
            this.TitleMode,
            this.UrlEdit,
            this.UrlMode,
            this.TriggerMode,
            this.NotifyCheck,
            this.DelayEdit,
            this.RuleDuplicateButton,
            this.RuleDeleteButton,
            this.ActionAddButton,
            this.CaptureWindowButton,
            this.TestMatchButton
        ]
        {
            control.Enabled := hasRule
        }

        this.RuleUpButton.Enabled := hasRule && this.SelectedRuleIndex > 1
        this.RuleDownButton.Enabled := hasRule
            && this.SelectedRuleIndex < this.Data.Length

        this.UpdateActionButtons()
    }

    UpdateActionButtons()
    {
        action := this.GetSelectedAction()
        hasAction := !!action

        this.ActionType.Enabled := hasAction
        this.ActionValue.Enabled := hasAction
        this.ActionDuplicateButton.Enabled := hasAction
        this.ActionDeleteButton.Enabled := hasAction
        this.ActionUpButton.Enabled := hasAction && this.SelectedActionIndex > 1

        actions := this.GetActions()
        this.ActionDownButton.Enabled := hasAction
            && actions
            && this.SelectedActionIndex < actions.Length
    }
}
