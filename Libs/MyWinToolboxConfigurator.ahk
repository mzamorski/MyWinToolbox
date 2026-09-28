#Requires AutoHotkey v2.0

class ConfiguratorJsonStore
{
    static Clone(value)
    {
        json := Jxon_dump(value, 4)
        return jxon_load(&json)
    }

    static SaveWithBackup(filePath, value)
    {
        json := Jxon_dump(value, 4)
        tempPath := filePath ".tmp"
        backupPath := filePath ".bak"

        if FileExist(tempPath)
        {
            FileDelete(tempPath)
        }

        FileAppend(json, tempPath, "UTF-8")

        try
        {
            if FileExist(filePath)
            {
                FileCopy(filePath, backupPath, true)
            }

            FileMove(tempPath, filePath, true)
        }
        catch Error as e
        {
            if FileExist(tempPath)
            {
                FileDelete(tempPath)
            }

            throw e
        }
    }

    static ParseList(value)
    {
        result := []
        normalized := StrReplace(value, "`r", "")
        normalized := StrReplace(normalized, "`n", ",")

        for item in StrSplit(normalized, ",")
        {
            item := Trim(item)
            if (item != "")
            {
                result.Push(item)
            }
        }

        return result
    }

    static JoinList(values)
    {
        if (!IsObject(values) || Type(values) != "Array")
        {
            return ""
        }

        result := ""
        separator := ""

        for value in values
        {
            result .= separator value
            separator := ", "
        }

        return result
    }
}

class ConfiguratorHotStringsState
{
    __New(data, filePath)
    {
        this.Data := ConfiguratorJsonStore.Clone(data)
        this.FilePath := filePath
        this.Dirty := false
        this.EnsureStructure()
    }

    EnsureStructure()
    {
        if (!IsObject(this.Data) || !(this.Data is Map))
        {
            throw Error("HotStrings.json root value must be an object.")
        }

        if (!this.Data.Has("Version"))
        {
            this.Data["Version"] := 1
        }

        if (!this.Data.Has("Defaults") || !IsObject(this.Data["Defaults"]))
        {
            this.Data["Defaults"] := Map()
        }

        defaults := this.Data["Defaults"]
        if (!defaults.Has("Options"))
        {
            defaults["Options"] := "*"
        }

        if (!defaults.Has("ScopeMode"))
        {
            defaults["ScopeMode"] := "include"
        }

        if (!this.Data.Has("Scopes") || !IsObject(this.Data["Scopes"]))
        {
            this.Data["Scopes"] := Map()
        }

        scopes := this.Data["Scopes"]
        if (!scopes.Has("Aliases") || !IsObject(scopes["Aliases"]))
        {
            scopes["Aliases"] := Map()
        }

        if (!this.Data.Has("HotStrings") || Type(this.Data["HotStrings"]) != "Array")
        {
            this.Data["HotStrings"] := []
        }
    }

    GetDefinitions()
    {
        return this.Data["HotStrings"]
    }

    GetAliases()
    {
        return this.Data["Scopes"]["Aliases"]
    }

    SetDirty()
    {
        this.Dirty := true
    }

    Validate()
    {
        definitions := this.GetDefinitions()
        aliases := this.GetAliases()
        defaults := this.Data["Defaults"]
        ids := Map()
        aliasNames := Map()

        if (!defaults.Has("Options") || Type(defaults["Options"]) != "String")
        {
            throw Error("HotStrings Defaults.Options must be a string.")
        }

        scopeMode := defaults.Has("ScopeMode")
            ? StrLower(Trim("" defaults["ScopeMode"]))
            : "include"

        if (scopeMode != "include" && scopeMode != "exclude")
        {
            throw Error("HotStrings Defaults.ScopeMode must be include or exclude.")
        }

        for aliasName, aliasDefinition in aliases
        {
            normalizedAliasName := StrLower(Trim("" aliasName))
            if (aliasNames.Has(normalizedAliasName))
            {
                throw Error("Duplicate HotString scope name: " aliasName)
            }

            aliasNames[normalizedAliasName] := true
            if (Trim("" aliasName) = "")
            {
                throw Error("HotString scope names cannot be empty.")
            }

            if (!IsObject(aliasDefinition) || !(aliasDefinition is Map))
            {
                throw Error("Scope '" aliasName "' must be an object.")
            }

            for fieldName in ["Process", "Class"]
            {
                if (aliasDefinition.Has(fieldName))
                {
                    value := aliasDefinition[fieldName]
                    if (Type(value) != "Array" && Type(value) != "String")
                    {
                        throw Error("Scope '" aliasName "' field '" fieldName "' must be a string or array.")
                    }
                }
            }

            if (aliasDefinition.Has("TitleRegex"))
            {
                if (Type(aliasDefinition["TitleRegex"]) != "String")
                {
                    throw Error("Scope '" aliasName "' field 'TitleRegex' must be a string.")
                }

                titleRegex := aliasDefinition["TitleRegex"]
                if (titleRegex != "")
                {
                    try
                    {
                        RegExMatch("", titleRegex)
                    }
                    catch Error
                    {
                        throw Error("Scope '" aliasName "' contains an invalid TitleRegex.")
                    }
                }
            }
        }

        for index, definition in definitions
        {
            if (!IsObject(definition) || !(definition is Map))
            {
                throw Error("HotString #" index " must be an object.")
            }

            trigger := definition.Has("Trigger") ? Trim("" definition["Trigger"]) : ""
            pattern := definition.Has("Pattern") ? Trim("" definition["Pattern"]) : ""

            if (trigger = "" && pattern = "")
            {
                throw Error("HotString #" index " requires Trigger or Pattern.")
            }

            if (!definition.Has("Text") || Type(definition["Text"]) != "String")
            {
                throw Error("HotString #" index " requires string Text.")
            }

            for stringField in ["Id", "Trigger", "Pattern", "Options", "Description", "SendMode"]
            {
                if (definition.Has(stringField) && Type(definition[stringField]) != "String")
                {
                    throw Error(
                        "HotString #" index " field '" stringField "' must be a string."
                    )
                }
            }

            if (definition.Has("Id") && Trim("" definition["Id"]) != "")
            {
                id := StrLower(Trim("" definition["Id"]))
                if (ids.Has(id))
                {
                    throw Error("Duplicate HotString Id: " definition["Id"])
                }

                ids[id] := true
            }

            if (definition.Has("SendMode"))
            {
                sendMode := StrLower(Trim("" definition["SendMode"]))
                if (sendMode != "" && sendMode != "text" && sendMode != "raw")
                {
                    throw Error("HotString #" index " SendMode must be empty, text, or raw.")
                }
            }

            for fieldName in ["Tags", "IncludeScopes", "ExcludeScopes"]
            {
                if (definition.Has(fieldName) && Type(definition[fieldName]) != "Array")
                {
                    throw Error("HotString #" index " field '" fieldName "' must be an array.")
                }
            }

            for scopeField in ["IncludeScopes", "ExcludeScopes"]
            {
                if (!definition.Has(scopeField))
                {
                    continue
                }

                for scopeName in definition[scopeField]
                {
                    scopeName := Trim("" scopeName)
                    if (scopeName != "*" && scopeName != "" && !ConfiguratorHotStringsState.HasAlias(aliases, scopeName))
                    {
                        throw Error(
                            "HotString #" index " references unknown scope '" scopeName "'."
                        )
                    }
                }
            }
        }

        return true
    }

    static HasAlias(aliases, name)
    {
        needle := StrLower(Trim(name))

        for aliasName in aliases
        {
            if (StrLower(Trim(aliasName)) = needle)
            {
                return true
            }
        }

        return false
    }

    Save()
    {
        this.Validate()
        ConfiguratorJsonStore.SaveWithBackup(this.FilePath, this.Data)
        this.Dirty := false
    }
}

class MyWinToolboxConfigurator
{
    static Instance := 0

    static Show(
        snippetsData,
        snippetsFilePath,
        hotStringsData,
        hotStringsFilePath,
        autoPasteData,
        autoPasteFilePath,
        sharedConfigPath,
        profileConfigPath,
        onSnippetsSaved := 0,
        onHotStringsSaved := 0,
        onAutoPasteSaved := 0
    )
    {
        if (MyWinToolboxConfigurator.Instance)
        {
            try
            {
                MyWinToolboxConfigurator.Instance.Window.Show()
                WinActivate("ahk_id " MyWinToolboxConfigurator.Instance.Window.Hwnd)
                return
            }
            catch Error
            {
                MyWinToolboxConfigurator.Instance := 0
            }
        }

        try
        {
            MyWinToolboxConfigurator.Instance := MyWinToolboxConfigurator(
                snippetsData,
                snippetsFilePath,
                hotStringsData,
                hotStringsFilePath,
                autoPasteData,
                autoPasteFilePath,
                sharedConfigPath,
                profileConfigPath,
                onSnippetsSaved,
                onHotStringsSaved,
                onAutoPasteSaved
            )

            MyWinToolboxConfigurator.Instance.Window.Show("w1180 h750")
        }
        catch Error as e
        {
            MyWinToolboxConfigurator.Instance := 0
            MsgBox(
                "Unable to open MyWinToolbox Configurator:`n" e.Message,
                "MyWinToolbox Configurator",
                "Iconx"
            )
        }
    }

    __New(
        snippetsData,
        snippetsFilePath,
        hotStringsData,
        hotStringsFilePath,
        autoPasteData,
        autoPasteFilePath,
        sharedConfigPath,
        profileConfigPath,
        onSnippetsSaved := 0,
        onHotStringsSaved := 0,
        onAutoPasteSaved := 0
    )
    {
        this.SnippetsData := ConfiguratorJsonStore.Clone(snippetsData)
        this.SnippetsFilePath := snippetsFilePath
        this.SnippetsDirty := false

        this.HotStringsState := ConfiguratorHotStringsState(hotStringsData, hotStringsFilePath)

        this.OnSnippetsSavedCallback := onSnippetsSaved
        this.OnHotStringsSavedCallback := onHotStringsSaved

        this.SelectedCategory := ""
        this.SelectedSnippetIndex := 0
        this.SelectedHotStringIndex := 0
        this.SelectedScopeName := ""
        this.UpdatingControls := false

        this.Window := Gui("+MinSize1180x750", "MyWinToolbox Configurator")
        this.Window.SetFont("s9", "Segoe UI")
        this.Window.OnEvent("Close", ObjBindMethod(this, "OnClose"))
        this.Window.OnEvent("Escape", ObjBindMethod(this, "OnClose"))

        this.Tabs := this.Window.AddTab3(
            "x10 y10 w1160 h665",
            [
                "Text Snippets",
                "HotStrings",
                "HotString Scopes",
                "AutoPaste",
                "Settings",
                "Backup / Restore"
            ]
        )

        this.Tabs.UseTab(1)
        this.BuildTextSnippetsTab()

        this.Tabs.UseTab(2)
        this.BuildHotStringsTab()

        this.Tabs.UseTab(3)
        this.BuildHotStringScopesTab()

        this.Tabs.UseTab(4)
        this.AutoPasteTab := ConfiguratorAutoPasteTab(
            this.Window,
            autoPasteData,
            autoPasteFilePath,
            ObjBindMethod(this, "OnDirtyStateChanged"),
            onAutoPasteSaved
        )

        this.Tabs.UseTab(5)
        this.SettingsTab := ConfiguratorSettingsTab(
            this.Window,
            sharedConfigPath,
            profileConfigPath,
            ObjBindMethod(this, "OnDirtyStateChanged")
        )

        this.Tabs.UseTab(6)
        this.BackupTab := ConfiguratorBackupTab(
            this.Window,
            [
                profileConfigPath,
                sharedConfigPath,
                snippetsFilePath,
                hotStringsFilePath,
                autoPasteFilePath
            ],
            profileConfigPath,
            ObjBindMethod(this, "CanRestoreBackup")
        )

        this.Tabs.UseTab()

        this.StatusText := this.Window.AddText("x20 y690 w720 h25", "")
        this.SaveButton := this.Window.AddButton("x820 y685 w105 h32 Default", "Save")
        this.SaveButton.OnEvent("Click", ObjBindMethod(this, "OnSave"))

        this.SaveReloadButton := this.Window.AddButton("x935 y685 w125 h32", "Save + Reload")
        this.SaveReloadButton.OnEvent("Click", ObjBindMethod(this, "OnSaveAndReload"))

        this.CloseButton := this.Window.AddButton("x1070 y685 w90 h32", "Close")
        this.CloseButton.OnEvent("Click", ObjBindMethod(this, "OnClose"))

        this.RefreshCategories()
        this.RefreshHotStringDefaults()
        this.RefreshHotStrings()
        this.RefreshScopes()
        this.UpdateWindowTitle()
        this.UpdateStatus()
    }

    OpenAutoPasteDraft(rule)
    {
        this.Tabs.Choose(4)
        this.AutoPasteTab.AddRule(rule)
        this.Window.Show()
        WinActivate("ahk_id " this.Window.Hwnd)
    }

    ; ========================================================================
    ; Text Snippets
    ; ========================================================================

    BuildTextSnippetsTab()
    {
        this.Window.AddText("x25 y48 w200", "Categories")
        this.Window.AddText("x240 y48 w280", "Snippets")
        this.Window.AddText("x535 y48 w600", "Editor")

        this.CategoryList := this.Window.AddListBox("x25 y70 w200 h490")
        this.CategoryList.OnEvent("Change", ObjBindMethod(this, "OnCategoryChanged"))

        this.SnippetList := this.Window.AddListView(
            "x240 y70 w280 h490 -Hdr -Multi",
            ["Snippet"]
        )
        this.SnippetList.ModifyCol(1, 260)
        this.SnippetList.OnEvent("ItemSelect", ObjBindMethod(this, "OnSnippetChanged"))
        this.SnippetList.OnEvent("DoubleClick", ObjBindMethod(this, "OnSnippetDoubleClick"))

        this.Window.AddText("x535 y72 w80", "Title")
        this.SnippetTitleEdit := this.Window.AddEdit("x535 y92 w600 h26")
        this.SnippetTitleEdit.OnEvent("Change", ObjBindMethod(this, "OnSnippetEditorChanged"))

        this.Window.AddText("x535 y130 w100", "Description")
        this.SnippetDescriptionEdit := this.Window.AddEdit("x535 y150 w600 h80")
        this.SnippetDescriptionEdit.OnEvent("Change", ObjBindMethod(this, "OnSnippetEditorChanged"))

        this.Window.AddText("x535 y242 w100", "Content")
        this.SnippetContentEdit := this.Window.AddEdit("x535 y262 w600 h298 WantTab")
        this.SnippetContentEdit.SetFont("s9", "Consolas")
        this.SnippetContentEdit.OnEvent("Change", ObjBindMethod(this, "OnSnippetEditorChanged"))

        this.SnippetAddCategoryButton := this.Window.AddButton("x25 y575 w96 h30", "+ Category")
        this.SnippetAddCategoryButton.OnEvent("Click", ObjBindMethod(this, "OnAddCategory"))

        this.SnippetRenameCategoryButton := this.Window.AddButton("x129 y575 w96 h30", "Rename")
        this.SnippetRenameCategoryButton.OnEvent("Click", ObjBindMethod(this, "OnRenameCategory"))

        this.SnippetDeleteCategoryButton := this.Window.AddButton("x25 y613 w200 h30", "Delete category")
        this.SnippetDeleteCategoryButton.OnEvent("Click", ObjBindMethod(this, "OnDeleteCategory"))

        this.SnippetAddButton := this.Window.AddButton("x240 y575 w82 h30", "+ Snippet")
        this.SnippetAddButton.OnEvent("Click", ObjBindMethod(this, "OnAddSnippet"))

        this.SnippetDuplicateButton := this.Window.AddButton("x330 y575 w86 h30", "Duplicate")
        this.SnippetDuplicateButton.OnEvent("Click", ObjBindMethod(this, "OnDuplicateSnippet"))

        this.SnippetSeparatorButton := this.Window.AddButton("x424 y575 w96 h30", "+ Separator")
        this.SnippetSeparatorButton.OnEvent("Click", ObjBindMethod(this, "OnAddSeparator"))

        this.SnippetUpButton := this.Window.AddButton("x240 y613 w62 h30", "Up")
        this.SnippetUpButton.OnEvent("Click", ObjBindMethod(this, "OnSnippetMoveUp"))

        this.SnippetDownButton := this.Window.AddButton("x310 y613 w62 h30", "Down")
        this.SnippetDownButton.OnEvent("Click", ObjBindMethod(this, "OnSnippetMoveDown"))

        this.SnippetDeleteButton := this.Window.AddButton("x380 y613 w140 h30", "Delete snippet")
        this.SnippetDeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDeleteSnippet"))
    }

    static ValidateSnippets(data)
    {
        if (!IsObject(data) || !(data is Map))
        {
            throw Error("TextSnippets.json root value must be an object.")
        }

        for categoryName, snippets in data
        {
            if (Trim("" categoryName) = "")
            {
                throw Error("Snippet category names cannot be empty.")
            }

            if (Type(snippets) != "Array")
            {
                throw Error("Category '" categoryName "' must contain an array.")
            }

            for snippetIndex, snippet in snippets
            {
                if (!IsObject(snippet) || !(snippet is Map))
                {
                    throw Error("Category '" categoryName "', snippet #" snippetIndex " must be an object.")
                }

                if (!snippet.Has("Content") || Type(snippet["Content"]) != "String")
                {
                    throw Error("Category '" categoryName "', snippet #" snippetIndex " requires string Content.")
                }

                content := snippet["Content"]
                hasTitle := snippet.Has("Title")
                    && Type(snippet["Title"]) = "String"
                    && Trim(snippet["Title"]) != ""

                if (content != "--" && !hasTitle && Trim(content) = "")
                {
                    throw Error(
                        "Category '" categoryName "', snippet #" snippetIndex
                        " requires a Title or non-empty Content."
                    )
                }

                for optionalField in ["Title", "Description"]
                {
                    if (snippet.Has(optionalField) && Type(snippet[optionalField]) != "String")
                    {
                        throw Error(
                            "Category '" categoryName "', snippet #" snippetIndex
                            " field '" optionalField "' must be a string."
                        )
                    }
                }
            }
        }

        return true
    }

    RefreshCategories(preferredCategory := "")
    {
        categories := []
        for categoryName in this.SnippetsData
        {
            categories.Push(categoryName)
        }

        this.UpdatingControls := true
        try
        {
            this.CategoryList.Delete()

            if (categories.Length > 0)
            {
                this.CategoryList.Add(categories)

                selectedIndex := 1
                if (preferredCategory != "")
                {
                    for index, categoryName in categories
                    {
                        if (categoryName = preferredCategory)
                        {
                            selectedIndex := index
                            break
                        }
                    }
                }

                this.CategoryList.Choose(selectedIndex)
                this.SelectedCategory := categories[selectedIndex]
            }
            else
            {
                this.SelectedCategory := ""
            }
        }
        finally
        {
            this.UpdatingControls := false
        }

        this.RefreshSnippets()
    }

    GetSelectedSnippets()
    {
        if (this.SelectedCategory = "" || !this.SnippetsData.Has(this.SelectedCategory))
        {
            return 0
        }

        return this.SnippetsData[this.SelectedCategory]
    }

    GetSelectedSnippet()
    {
        snippets := this.GetSelectedSnippets()

        if (
            !snippets
            || this.SelectedSnippetIndex < 1
            || this.SelectedSnippetIndex > snippets.Length
        )
        {
            return 0
        }

        return snippets[this.SelectedSnippetIndex]
    }

    RefreshSnippets(preferredIndex := 0)
    {
        snippets := this.GetSelectedSnippets()
        labels := []

        if (snippets)
        {
            for index, snippet in snippets
            {
                labels.Push(MyWinToolboxConfigurator.GetSnippetLabel(snippet, index))
            }
        }

        this.UpdatingControls := true
        try
        {
            this.SnippetList.Delete()

            if (labels.Length > 0)
            {
                for label in labels
                {
                    this.SnippetList.Add("", label)
                }

                selectedIndex := preferredIndex
                if (selectedIndex < 1 || selectedIndex > labels.Length)
                {
                    selectedIndex := 1
                }

                this.SnippetList.Modify(selectedIndex, "Select Focus Vis")
                this.SelectedSnippetIndex := selectedIndex
            }
            else
            {
                this.SelectedSnippetIndex := 0
            }
        }
        finally
        {
            this.UpdatingControls := false
        }

        this.LoadSelectedSnippet()
        this.UpdateSnippetButtons()
    }

    static GetSnippetLabel(snippet, index)
    {
        if (!IsObject(snippet) || !(snippet is Map))
        {
            return "#" index " <invalid>"
        }

        content := snippet.Has("Content") ? snippet["Content"] : ""

        if (content = "--")
        {
            return "-------- separator --------"
        }

        if (snippet.Has("Title") && Trim("" snippet["Title"]) != "")
        {
            return snippet["Title"]
        }

        if (content != "")
        {
            preview := StrReplace(StrReplace(content, "`r", " "), "`n", " ")
            return StrLen(preview) > 42 ? SubStr(preview, 1, 39) "..." : preview
        }

        return "#" index " <empty>"
    }

    LoadSelectedSnippet()
    {
        snippet := this.GetSelectedSnippet()

        this.UpdatingControls := true
        try
        {
            if (!snippet)
            {
                this.SnippetTitleEdit.Value := ""
                this.SnippetDescriptionEdit.Value := ""
                this.SnippetContentEdit.Value := ""
                return
            }

            this.SnippetTitleEdit.Value := snippet.Has("Title") ? snippet["Title"] : ""
            this.SnippetDescriptionEdit.Value := snippet.Has("Description") ? snippet["Description"] : ""
            this.SnippetContentEdit.Value := snippet.Has("Content") ? snippet["Content"] : ""
        }
        finally
        {
            this.UpdatingControls := false
        }
    }

    OnCategoryChanged(*)
    {
        if (this.UpdatingControls || this.CategoryList.Value = 0)
        {
            return
        }

        this.SelectedCategory := this.CategoryList.Text
        this.RefreshSnippets()
    }

    OnSnippetChanged(control, rowNumber, selected)
    {
        if (this.UpdatingControls || !selected || rowNumber = 0)
        {
            return
        }

        this.SelectedSnippetIndex := rowNumber
        this.LoadSelectedSnippet()
        this.UpdateSnippetButtons()
    }

    OnSnippetDoubleClick(control, rowNumber)
    {
        if (rowNumber > 0 && this.SnippetTitleEdit.Enabled)
        {
            this.SnippetTitleEdit.Focus()
        }
    }

    OnSnippetEditorChanged(*)
    {
        if (this.UpdatingControls)
        {
            return
        }

        snippet := this.GetSelectedSnippet()
        if (!snippet)
        {
            return
        }

        title := this.SnippetTitleEdit.Value
        description := this.SnippetDescriptionEdit.Value

        if (title = "")
        {
            if (snippet.Has("Title"))
            {
                snippet.Delete("Title")
            }
        }
        else
        {
            snippet["Title"] := title
        }

        if (description = "")
        {
            if (snippet.Has("Description"))
            {
                snippet.Delete("Description")
            }
        }
        else
        {
            snippet["Description"] := description
        }

        snippet["Content"] := this.SnippetContentEdit.Value

        this.SnippetsDirty := true
        this.RefreshSnippetLabel()
        this.OnDirtyStateChanged()
    }

    RefreshSnippetLabel()
    {
        snippet := this.GetSelectedSnippet()

        if (!snippet || this.SelectedSnippetIndex = 0)
        {
            return
        }

        label := MyWinToolboxConfigurator.GetSnippetLabel(
            snippet,
            this.SelectedSnippetIndex
        )
        this.SnippetList.Modify(this.SelectedSnippetIndex, "", label)
    }

    OnAddCategory(*)
    {
        result := InputBox("Category name:", "Add category", "w360 h120")
        if (result.Result != "OK")
        {
            return
        }

        categoryName := Trim(result.Value)
        if (categoryName = "")
        {
            MsgBox("Category name cannot be empty.", "MyWinToolbox Configurator", "Iconx")
            return
        }

        if (this.SnippetsData.Has(categoryName))
        {
            MsgBox("Category already exists: " categoryName, "MyWinToolbox Configurator", "Iconx")
            return
        }

        this.SnippetsData[categoryName] := []
        this.SnippetsDirty := true
        this.RefreshCategories(categoryName)
        this.OnDirtyStateChanged()
    }

    OnRenameCategory(*)
    {
        if (this.SelectedCategory = "")
        {
            return
        }

        oldName := this.SelectedCategory
        result := InputBox(
            "New category name:",
            "Rename category",
            "w360 h120",
            oldName
        )

        if (result.Result != "OK")
        {
            return
        }

        newName := Trim(result.Value)
        if (newName = "" || newName = oldName)
        {
            return
        }

        if (this.SnippetsData.Has(newName))
        {
            MsgBox("Category already exists: " newName, "MyWinToolbox Configurator", "Iconx")
            return
        }

        renamed := Map()
        for categoryName, snippets in this.SnippetsData
        {
            renamed[categoryName = oldName ? newName : categoryName] := snippets
        }

        this.SnippetsData := renamed
        this.SnippetsDirty := true
        this.RefreshCategories(newName)
        this.OnDirtyStateChanged()
    }

    OnDeleteCategory(*)
    {
        if (this.SelectedCategory = "")
        {
            return
        }

        categoryName := this.SelectedCategory
        answer := MsgBox(
            "Delete category '" categoryName "' and all of its snippets?",
            "MyWinToolbox Configurator",
            "YesNo Icon!"
        )

        if (answer != "Yes")
        {
            return
        }

        this.SnippetsData.Delete(categoryName)
        this.SnippetsDirty := true
        this.RefreshCategories()
        this.OnDirtyStateChanged()
    }

    OnAddSnippet(*)
    {
        snippets := this.GetSelectedSnippets()
        if (!snippets)
        {
            MsgBox("Select or create a category first.", "MyWinToolbox Configurator", "Iconi")
            return
        }

        snippets.Push(Map(
            "Title", "New snippet",
            "Content", ""
        ))

        this.SnippetsDirty := true
        this.RefreshSnippets(snippets.Length)
        this.SnippetTitleEdit.Focus()
        this.OnDirtyStateChanged()
    }

    OnDuplicateSnippet(*)
    {
        snippets := this.GetSelectedSnippets()
        snippet := this.GetSelectedSnippet()

        if (!snippets || !snippet)
        {
            return
        }

        clone := ConfiguratorJsonStore.Clone(snippet)
        if (clone.Has("Title"))
        {
            clone["Title"] := clone["Title"] " (copy)"
        }

        insertIndex := this.SelectedSnippetIndex + 1
        snippets.InsertAt(insertIndex, clone)

        this.SnippetsDirty := true
        this.RefreshSnippets(insertIndex)
        this.OnDirtyStateChanged()
    }

    OnAddSeparator(*)
    {
        snippets := this.GetSelectedSnippets()

        if (!snippets)
        {
            MsgBox("Select or create a category first.", "MyWinToolbox Configurator", "Iconi")
            return
        }

        snippets.Push(Map("Content", "--"))
        this.SnippetsDirty := true
        this.RefreshSnippets(snippets.Length)
        this.OnDirtyStateChanged()
    }

    OnDeleteSnippet(*)
    {
        snippets := this.GetSelectedSnippets()
        snippet := this.GetSelectedSnippet()

        if (!snippets || !snippet)
        {
            return
        }

        label := MyWinToolboxConfigurator.GetSnippetLabel(
            snippet,
            this.SelectedSnippetIndex
        )

        answer := MsgBox(
            "Delete snippet '" label "'?",
            "MyWinToolbox Configurator",
            "YesNo Icon!"
        )

        if (answer != "Yes")
        {
            return
        }

        oldIndex := this.SelectedSnippetIndex
        snippets.RemoveAt(oldIndex)
        this.SnippetsDirty := true

        nextIndex := Min(oldIndex, snippets.Length)
        this.RefreshSnippets(nextIndex)
        this.OnDirtyStateChanged()
    }

    OnSnippetMoveUp(*)
    {
        snippets := this.GetSelectedSnippets()
        index := this.SelectedSnippetIndex

        if (!snippets || index <= 1)
        {
            return
        }

        item := snippets.RemoveAt(index)
        snippets.InsertAt(index - 1, item)
        this.SnippetsDirty := true
        this.RefreshSnippets(index - 1)
        this.OnDirtyStateChanged()
    }

    OnSnippetMoveDown(*)
    {
        snippets := this.GetSelectedSnippets()
        index := this.SelectedSnippetIndex

        if (!snippets || index < 1 || index >= snippets.Length)
        {
            return
        }

        item := snippets.RemoveAt(index)
        snippets.InsertAt(index + 1, item)
        this.SnippetsDirty := true
        this.RefreshSnippets(index + 1)
        this.OnDirtyStateChanged()
    }

    UpdateSnippetButtons()
    {
        hasCategory := this.SelectedCategory != ""
        snippet := this.GetSelectedSnippet()
        hasSnippet := !!snippet

        this.SnippetRenameCategoryButton.Enabled := hasCategory
        this.SnippetDeleteCategoryButton.Enabled := hasCategory
        this.SnippetAddButton.Enabled := hasCategory
        this.SnippetSeparatorButton.Enabled := hasCategory

        isSeparator := hasSnippet
            && snippet.Has("Content")
            && snippet["Content"] = "--"

        this.SnippetTitleEdit.Enabled := hasSnippet && !isSeparator
        this.SnippetDescriptionEdit.Enabled := hasSnippet && !isSeparator
        this.SnippetContentEdit.Enabled := hasSnippet && !isSeparator

        this.SnippetDuplicateButton.Enabled := hasSnippet
        this.SnippetDeleteButton.Enabled := hasSnippet
        this.SnippetUpButton.Enabled := hasSnippet && this.SelectedSnippetIndex > 1

        snippets := this.GetSelectedSnippets()
        this.SnippetDownButton.Enabled := hasSnippet
            && snippets
            && this.SelectedSnippetIndex < snippets.Length
    }

    ; ========================================================================
    ; HotStrings
    ; ========================================================================

    BuildHotStringsTab()
    {
        defaults := this.HotStringsState.Data["Defaults"]

        this.Window.AddText("x25 y50 w95", "Default options")
        this.HotStringDefaultOptionsEdit := this.Window.AddEdit("x120 y47 w100 h25")
        this.HotStringDefaultOptionsEdit.OnEvent(
            "Change",
            ObjBindMethod(this, "OnHotStringDefaultsChanged")
        )

        this.Window.AddText("x240 y50 w120", "Default scope mode")
        this.HotStringDefaultScopeMode := this.Window.AddDropDownList(
            "x365 y47 w120",
            ["include", "exclude"]
        )
        this.HotStringDefaultScopeMode.OnEvent(
            "Change",
            ObjBindMethod(this, "OnHotStringDefaultsChanged")
        )

        this.Window.AddText("x25 y83 w350", "HotStrings")
        this.HotStringList := this.Window.AddListView(
            "x25 y105 w350 h455 -Multi",
            ["On", "Trigger", "Description"]
        )
        this.HotStringList.ModifyCol(1, 38)
        this.HotStringList.ModifyCol(2, 100)
        this.HotStringList.ModifyCol(3, 190)
        this.HotStringList.OnEvent("ItemSelect", ObjBindMethod(this, "OnHotStringSelected"))

        this.Window.AddText("x395 y83 w740", "Editor")

        this.HotStringEnabled := this.Window.AddCheckBox("x395 y108 w90 h25", "Enabled")
        this.HotStringEnabled.OnEvent("Click", ObjBindMethod(this, "OnHotStringEditorChanged"))

        this.Window.AddText("x500 y88 w100", "Trigger")
        this.HotStringTriggerEdit := this.Window.AddEdit("x500 y108 w180 h25")
        this.HotStringTriggerEdit.OnEvent("Change", ObjBindMethod(this, "OnHotStringEditorChanged"))

        this.Window.AddText("x695 y88 w70", "Id")
        this.HotStringIdEdit := this.Window.AddEdit("x695 y108 w180 h25")
        this.HotStringIdEdit.OnEvent("Change", ObjBindMethod(this, "OnHotStringEditorChanged"))

        this.HotStringUseDefaultOptions := this.Window.AddCheckBox(
            "x890 y108 w160 h25",
            "Use default options"
        )
        this.HotStringUseDefaultOptions.OnEvent(
            "Click",
            ObjBindMethod(this, "OnHotStringEditorChanged")
        )

        this.Window.AddText("x395 y148 w80", "Options")
        this.HotStringOptionsEdit := this.Window.AddEdit("x395 y168 w140 h25")
        this.HotStringOptionsEdit.OnEvent("Change", ObjBindMethod(this, "OnHotStringEditorChanged"))

        this.Window.AddText("x550 y148 w90", "Send mode")
        this.HotStringSendMode := this.Window.AddDropDownList(
            "x550 y168 w130",
            ["default", "text", "raw"]
        )
        this.HotStringSendMode.OnEvent("Change", ObjBindMethod(this, "OnHotStringEditorChanged"))

        this.Window.AddText("x695 y148 w90", "Tags")
        this.HotStringTagsEdit := this.Window.AddEdit("x695 y168 w440 h25")
        this.HotStringTagsEdit.OnEvent("Change", ObjBindMethod(this, "OnHotStringEditorChanged"))

        this.Window.AddText("x395 y205 w100", "Description")
        this.HotStringDescriptionEdit := this.Window.AddEdit("x395 y225 w740 h60")
        this.HotStringDescriptionEdit.OnEvent(
            "Change",
            ObjBindMethod(this, "OnHotStringEditorChanged")
        )

        this.Window.AddText("x395 y298 w100", "Text")
        this.HotStringTextEdit := this.Window.AddEdit("x395 y318 w740 h135 WantTab")
        this.HotStringTextEdit.SetFont("s9", "Consolas")
        this.HotStringTextEdit.OnEvent("Change", ObjBindMethod(this, "OnHotStringEditorChanged"))

        this.Window.AddText("x395 y466 w160", "Include scopes (comma-separated)")
        this.HotStringIncludeScopesEdit := this.Window.AddEdit("x395 y486 w355 h50")
        this.HotStringIncludeScopesEdit.OnEvent(
            "Change",
            ObjBindMethod(this, "OnHotStringEditorChanged")
        )

        this.Window.AddText("x770 y466 w160", "Exclude scopes (comma-separated)")
        this.HotStringExcludeScopesEdit := this.Window.AddEdit("x770 y486 w365 h50")
        this.HotStringExcludeScopesEdit.OnEvent(
            "Change",
            ObjBindMethod(this, "OnHotStringEditorChanged")
        )

        this.HotStringAddButton := this.Window.AddButton("x25 y575 w78 h30", "+ Add")
        this.HotStringAddButton.OnEvent("Click", ObjBindMethod(this, "OnAddHotString"))

        this.HotStringDuplicateButton := this.Window.AddButton("x111 y575 w86 h30", "Duplicate")
        this.HotStringDuplicateButton.OnEvent("Click", ObjBindMethod(this, "OnDuplicateHotString"))

        this.HotStringDeleteButton := this.Window.AddButton("x205 y575 w80 h30", "Delete")
        this.HotStringDeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDeleteHotString"))

        this.HotStringUpButton := this.Window.AddButton("x293 y575 w38 h30", "Up")
        this.HotStringUpButton.OnEvent("Click", ObjBindMethod(this, "OnHotStringMoveUp"))

        this.HotStringDownButton := this.Window.AddButton("x337 y575 w38 h30", "Dn")
        this.HotStringDownButton.OnEvent("Click", ObjBindMethod(this, "OnHotStringMoveDown"))

        this.Window.AddText(
            "x395 y575 w740 h50",
            "HotStrings are saved immediately to HotStrings.json, but registered hotstrings "
            "change only after MyWinToolbox reload. Use Save + Reload to apply them."
        )
    }

    RefreshHotStringDefaults()
    {
        defaults := this.HotStringsState.Data["Defaults"]

        this.UpdatingControls := true
        try
        {
            this.HotStringDefaultOptionsEdit.Value := defaults.Has("Options")
                ? defaults["Options"]
                : "*"

            scopeMode := defaults.Has("ScopeMode")
                ? StrLower("" defaults["ScopeMode"])
                : "include"

            this.HotStringDefaultScopeMode.Choose(scopeMode = "exclude" ? 2 : 1)
        }
        finally
        {
            this.UpdatingControls := false
        }
    }

    OnHotStringDefaultsChanged(*)
    {
        if (this.UpdatingControls)
        {
            return
        }

        defaults := this.HotStringsState.Data["Defaults"]
        defaults["Options"] := this.HotStringDefaultOptionsEdit.Value
        defaults["ScopeMode"] := this.HotStringDefaultScopeMode.Text

        this.HotStringsState.SetDirty()
        this.OnDirtyStateChanged()
    }

    RefreshHotStrings(preferredIndex := 0)
    {
        definitions := this.HotStringsState.GetDefinitions()

        this.UpdatingControls := true
        try
        {
            this.HotStringList.Delete()

            for definition in definitions
            {
                enabled := !definition.Has("Enabled") || definition["Enabled"]
                    ? "Yes"
                    : "No"

                trigger := definition.Has("Trigger")
                    ? definition["Trigger"]
                    : (definition.Has("Pattern") ? definition["Pattern"] : "")

                description := definition.Has("Description")
                    ? definition["Description"]
                    : ""

                this.HotStringList.Add("", enabled, trigger, description)
            }

            if (definitions.Length > 0)
            {
                selectedIndex := preferredIndex
                if (selectedIndex < 1 || selectedIndex > definitions.Length)
                {
                    selectedIndex := 1
                }

                this.HotStringList.Modify(selectedIndex, "Select Focus Vis")
                this.SelectedHotStringIndex := selectedIndex
            }
            else
            {
                this.SelectedHotStringIndex := 0
            }
        }
        finally
        {
            this.UpdatingControls := false
        }

        this.LoadSelectedHotString()
        this.UpdateHotStringButtons()
    }

    GetSelectedHotString()
    {
        definitions := this.HotStringsState.GetDefinitions()

        if (
            this.SelectedHotStringIndex < 1
            || this.SelectedHotStringIndex > definitions.Length
        )
        {
            return 0
        }

        return definitions[this.SelectedHotStringIndex]
    }

    OnHotStringSelected(control, rowNumber, selected)
    {
        if (this.UpdatingControls || !selected || rowNumber = 0)
        {
            return
        }

        this.SelectedHotStringIndex := rowNumber
        this.LoadSelectedHotString()
        this.UpdateHotStringButtons()
    }

    LoadSelectedHotString()
    {
        definition := this.GetSelectedHotString()

        this.UpdatingControls := true
        try
        {
            if (!definition)
            {
                this.HotStringEnabled.Value := 0
                this.HotStringTriggerEdit.Value := ""
                this.HotStringIdEdit.Value := ""
                this.HotStringUseDefaultOptions.Value := 1
                this.HotStringOptionsEdit.Value := ""
                this.HotStringSendMode.Choose(1)
                this.HotStringTagsEdit.Value := ""
                this.HotStringDescriptionEdit.Value := ""
                this.HotStringTextEdit.Value := ""
                this.HotStringIncludeScopesEdit.Value := ""
                this.HotStringExcludeScopesEdit.Value := ""
                return
            }

            this.HotStringEnabled.Value := !definition.Has("Enabled") || definition["Enabled"]
            this.HotStringTriggerEdit.Value := definition.Has("Trigger")
                ? definition["Trigger"]
                : ""

            this.HotStringIdEdit.Value := definition.Has("Id")
                ? definition["Id"]
                : ""

            useDefaultOptions := !definition.Has("Options")
            this.HotStringUseDefaultOptions.Value := useDefaultOptions ? 1 : 0
            this.HotStringOptionsEdit.Value := definition.Has("Options")
                ? definition["Options"]
                : this.HotStringDefaultOptionsEdit.Value
            this.HotStringOptionsEdit.Enabled := !useDefaultOptions

            sendMode := definition.Has("SendMode")
                ? StrLower(Trim("" definition["SendMode"]))
                : ""

            this.HotStringSendMode.Choose(
                sendMode = "text" ? 2 : (sendMode = "raw" ? 3 : 1)
            )

            this.HotStringTagsEdit.Value := definition.Has("Tags")
                ? ConfiguratorJsonStore.JoinList(definition["Tags"])
                : ""

            this.HotStringDescriptionEdit.Value := definition.Has("Description")
                ? definition["Description"]
                : ""

            this.HotStringTextEdit.Value := definition.Has("Text")
                ? definition["Text"]
                : ""

            this.HotStringIncludeScopesEdit.Value := definition.Has("IncludeScopes")
                ? ConfiguratorJsonStore.JoinList(definition["IncludeScopes"])
                : ""

            this.HotStringExcludeScopesEdit.Value := definition.Has("ExcludeScopes")
                ? ConfiguratorJsonStore.JoinList(definition["ExcludeScopes"])
                : ""
        }
        finally
        {
            this.UpdatingControls := false
        }
    }

    OnHotStringEditorChanged(*)
    {
        if (this.UpdatingControls)
        {
            return
        }

        definition := this.GetSelectedHotString()
        if (!definition)
        {
            return
        }

        definition["Enabled"] := this.HotStringEnabled.Value ? true : false

        trigger := Trim(this.HotStringTriggerEdit.Value)
        if (trigger = "")
        {
            if (definition.Has("Trigger"))
            {
                definition.Delete("Trigger")
            }
        }
        else
        {
            definition["Trigger"] := trigger
        }

        id := Trim(this.HotStringIdEdit.Value)
        if (id = "")
        {
            if (definition.Has("Id"))
            {
                definition.Delete("Id")
            }
        }
        else
        {
            definition["Id"] := id
        }

        useDefaultOptions := !!this.HotStringUseDefaultOptions.Value
        this.HotStringOptionsEdit.Enabled := !useDefaultOptions

        if (useDefaultOptions)
        {
            if (definition.Has("Options"))
            {
                definition.Delete("Options")
            }
        }
        else
        {
            definition["Options"] := this.HotStringOptionsEdit.Value
        }

        sendMode := this.HotStringSendMode.Text
        if (sendMode = "default")
        {
            if (definition.Has("SendMode"))
            {
                definition.Delete("SendMode")
            }
        }
        else
        {
            definition["SendMode"] := sendMode
        }

        tags := ConfiguratorJsonStore.ParseList(this.HotStringTagsEdit.Value)
        if (tags.Length = 0)
        {
            if (definition.Has("Tags"))
            {
                definition.Delete("Tags")
            }
        }
        else
        {
            definition["Tags"] := tags
        }

        description := this.HotStringDescriptionEdit.Value
        if (description = "")
        {
            if (definition.Has("Description"))
            {
                definition.Delete("Description")
            }
        }
        else
        {
            definition["Description"] := description
        }

        definition["Text"] := this.HotStringTextEdit.Value

        includeScopes := ConfiguratorJsonStore.ParseList(
            this.HotStringIncludeScopesEdit.Value
        )
        excludeScopes := ConfiguratorJsonStore.ParseList(
            this.HotStringExcludeScopesEdit.Value
        )

        if (includeScopes.Length = 0 && excludeScopes.Length = 0)
        {
            includeScopes.Push("*")
        }

        definition["IncludeScopes"] := includeScopes
        definition["ExcludeScopes"] := excludeScopes

        this.HotStringsState.SetDirty()
        this.RefreshHotStringRow()
        this.OnDirtyStateChanged()
    }

    RefreshHotStringRow()
    {
        definition := this.GetSelectedHotString()
        if (!definition || this.SelectedHotStringIndex = 0)
        {
            return
        }

        enabled := !definition.Has("Enabled") || definition["Enabled"] ? "Yes" : "No"
        trigger := definition.Has("Trigger")
            ? definition["Trigger"]
            : (definition.Has("Pattern") ? definition["Pattern"] : "")
        description := definition.Has("Description") ? definition["Description"] : ""

        this.HotStringList.Modify(
            this.SelectedHotStringIndex,
            "",
            enabled,
            trigger,
            description
        )
    }

    MakeUniqueHotStringValue(fieldName, baseValue)
    {
        definitions := this.HotStringsState.GetDefinitions()
        candidate := baseValue
        suffix := 2

        while true
        {
            exists := false

            for definition in definitions
            {
                if (
                    definition.Has(fieldName)
                    && StrLower(Trim("" definition[fieldName]))
                        = StrLower(Trim(candidate))
                )
                {
                    exists := true
                    break
                }
            }

            if (!exists)
            {
                return candidate
            }

            candidate := baseValue suffix
            suffix += 1
        }
    }

    OnAddHotString(*)
    {
        definitions := this.HotStringsState.GetDefinitions()

        newId := this.MakeUniqueHotStringValue("Id", "new")
        newTrigger := this.MakeUniqueHotStringValue("Trigger", "new")

        definitions.Push(Map(
            "Id", newId,
            "Trigger", newTrigger,
            "Text", "",
            "IncludeScopes", ["*"],
            "ExcludeScopes", [],
            "Enabled", true
        ))

        this.HotStringsState.SetDirty()
        this.RefreshHotStrings(definitions.Length)
        this.HotStringTriggerEdit.Focus()
        this.OnDirtyStateChanged()
    }

    OnDuplicateHotString(*)
    {
        definitions := this.HotStringsState.GetDefinitions()
        definition := this.GetSelectedHotString()

        if (!definition)
        {
            return
        }

        clone := ConfiguratorJsonStore.Clone(definition)

        if (clone.Has("Id"))
        {
            clone["Id"] := this.MakeUniqueHotStringValue(
                "Id",
                clone["Id"] "-copy"
            )
        }

        if (clone.Has("Trigger"))
        {
            clone["Trigger"] := this.MakeUniqueHotStringValue(
                "Trigger",
                clone["Trigger"] "-copy"
            )
        }

        insertIndex := this.SelectedHotStringIndex + 1
        definitions.InsertAt(insertIndex, clone)

        this.HotStringsState.SetDirty()
        this.RefreshHotStrings(insertIndex)
        this.OnDirtyStateChanged()
    }

    OnDeleteHotString(*)
    {
        definitions := this.HotStringsState.GetDefinitions()
        definition := this.GetSelectedHotString()

        if (!definition)
        {
            return
        }

        trigger := definition.Has("Trigger")
            ? definition["Trigger"]
            : "#" this.SelectedHotStringIndex

        answer := MsgBox(
            "Delete HotString '" trigger "'?",
            "MyWinToolbox Configurator",
            "YesNo Icon!"
        )

        if (answer != "Yes")
        {
            return
        }

        oldIndex := this.SelectedHotStringIndex
        definitions.RemoveAt(oldIndex)
        this.HotStringsState.SetDirty()
        this.RefreshHotStrings(Min(oldIndex, definitions.Length))
        this.OnDirtyStateChanged()
    }

    OnHotStringMoveUp(*)
    {
        definitions := this.HotStringsState.GetDefinitions()
        index := this.SelectedHotStringIndex

        if (index <= 1)
        {
            return
        }

        item := definitions.RemoveAt(index)
        definitions.InsertAt(index - 1, item)
        this.HotStringsState.SetDirty()
        this.RefreshHotStrings(index - 1)
        this.OnDirtyStateChanged()
    }

    OnHotStringMoveDown(*)
    {
        definitions := this.HotStringsState.GetDefinitions()
        index := this.SelectedHotStringIndex

        if (index < 1 || index >= definitions.Length)
        {
            return
        }

        item := definitions.RemoveAt(index)
        definitions.InsertAt(index + 1, item)
        this.HotStringsState.SetDirty()
        this.RefreshHotStrings(index + 1)
        this.OnDirtyStateChanged()
    }

    UpdateHotStringButtons()
    {
        definition := this.GetSelectedHotString()
        hasDefinition := !!definition

        for control in [
            this.HotStringEnabled,
            this.HotStringTriggerEdit,
            this.HotStringIdEdit,
            this.HotStringUseDefaultOptions,
            this.HotStringSendMode,
            this.HotStringTagsEdit,
            this.HotStringDescriptionEdit,
            this.HotStringTextEdit,
            this.HotStringIncludeScopesEdit,
            this.HotStringExcludeScopesEdit,
            this.HotStringDuplicateButton,
            this.HotStringDeleteButton
        ]
        {
            control.Enabled := hasDefinition
        }

        this.HotStringOptionsEdit.Enabled := hasDefinition
            && !this.HotStringUseDefaultOptions.Value

        this.HotStringUpButton.Enabled := hasDefinition
            && this.SelectedHotStringIndex > 1

        definitions := this.HotStringsState.GetDefinitions()
        this.HotStringDownButton.Enabled := hasDefinition
            && this.SelectedHotStringIndex < definitions.Length
    }

    ; ========================================================================
    ; HotString scope aliases
    ; ========================================================================

    BuildHotStringScopesTab()
    {
        this.Window.AddText("x25 y50 w300", "Scope aliases")
        this.ScopeList := this.Window.AddListBox("x25 y72 w300 h488")
        this.ScopeList.OnEvent("Change", ObjBindMethod(this, "OnScopeSelected"))

        this.Window.AddText("x345 y50 w790", "Scope editor")

        this.Window.AddText("x345 y78 w90", "Name")
        this.ScopeNameEdit := this.Window.AddEdit("x345 y98 w300 h25 ReadOnly")
        this.ScopeRenameButton := this.Window.AddButton("x655 y96 w90 h29", "Rename")
        this.ScopeRenameButton.OnEvent("Click", ObjBindMethod(this, "OnRenameScope"))

        this.Window.AddText("x345 y138 w180", "Processes (comma-separated)")
        this.ScopeProcessesEdit := this.Window.AddEdit("x345 y158 w790 h80")
        this.ScopeProcessesEdit.OnEvent("Change", ObjBindMethod(this, "OnScopeEditorChanged"))

        this.Window.AddText("x345 y253 w180", "Window classes (comma-separated)")
        this.ScopeClassesEdit := this.Window.AddEdit("x345 y273 w790 h80")
        this.ScopeClassesEdit.OnEvent("Change", ObjBindMethod(this, "OnScopeEditorChanged"))

        this.Window.AddText("x345 y368 w120", "Title regex")
        this.ScopeTitleRegexEdit := this.Window.AddEdit("x345 y388 w790 h70")
        this.ScopeTitleRegexEdit.OnEvent("Change", ObjBindMethod(this, "OnScopeEditorChanged"))

        this.ScopeAddButton := this.Window.AddButton("x25 y575 w94 h30", "+ Scope")
        this.ScopeAddButton.OnEvent("Click", ObjBindMethod(this, "OnAddScope"))

        this.ScopeDeleteButton := this.Window.AddButton("x127 y575 w94 h30", "Delete")
        this.ScopeDeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDeleteScope"))

        this.Window.AddText(
            "x345 y485 w790 h80",
            "Use these alias names in Include scopes / Exclude scopes on the HotStrings tab. "
            "Use * in Include scopes for a HotString that should work everywhere."
        )
    }

    RefreshScopes(preferredName := "")
    {
        aliases := this.HotStringsState.GetAliases()
        names := []

        for aliasName in aliases
        {
            names.Push(aliasName)
        }

        this.UpdatingControls := true
        try
        {
            this.ScopeList.Delete()

            if (names.Length > 0)
            {
                this.ScopeList.Add(names)

                selectedIndex := 1
                if (preferredName != "")
                {
                    for index, aliasName in names
                    {
                        if (aliasName = preferredName)
                        {
                            selectedIndex := index
                            break
                        }
                    }
                }

                this.ScopeList.Choose(selectedIndex)
                this.SelectedScopeName := names[selectedIndex]
            }
            else
            {
                this.SelectedScopeName := ""
            }
        }
        finally
        {
            this.UpdatingControls := false
        }

        this.LoadSelectedScope()
        this.UpdateScopeButtons()
    }

    GetSelectedScope()
    {
        aliases := this.HotStringsState.GetAliases()

        if (this.SelectedScopeName = "" || !aliases.Has(this.SelectedScopeName))
        {
            return 0
        }

        return aliases[this.SelectedScopeName]
    }

    OnScopeSelected(*)
    {
        if (this.UpdatingControls || this.ScopeList.Value = 0)
        {
            return
        }

        this.SelectedScopeName := this.ScopeList.Text
        this.LoadSelectedScope()
        this.UpdateScopeButtons()
    }

    LoadSelectedScope()
    {
        scope := this.GetSelectedScope()

        this.UpdatingControls := true
        try
        {
            if (!scope)
            {
                this.ScopeNameEdit.Value := ""
                this.ScopeProcessesEdit.Value := ""
                this.ScopeClassesEdit.Value := ""
                this.ScopeTitleRegexEdit.Value := ""
                return
            }

            this.ScopeNameEdit.Value := this.SelectedScopeName

            this.ScopeProcessesEdit.Value := scope.Has("Process")
                ? ConfiguratorJsonStore.JoinList(
                    Type(scope["Process"]) = "Array"
                        ? scope["Process"]
                        : [scope["Process"]]
                )
                : ""

            this.ScopeClassesEdit.Value := scope.Has("Class")
                ? ConfiguratorJsonStore.JoinList(
                    Type(scope["Class"]) = "Array"
                        ? scope["Class"]
                        : [scope["Class"]]
                )
                : ""

            this.ScopeTitleRegexEdit.Value := scope.Has("TitleRegex")
                ? scope["TitleRegex"]
                : ""
        }
        finally
        {
            this.UpdatingControls := false
        }
    }

    OnScopeEditorChanged(*)
    {
        if (this.UpdatingControls)
        {
            return
        }

        scope := this.GetSelectedScope()
        if (!scope)
        {
            return
        }

        processes := ConfiguratorJsonStore.ParseList(this.ScopeProcessesEdit.Value)
        classes := ConfiguratorJsonStore.ParseList(this.ScopeClassesEdit.Value)
        titleRegex := this.ScopeTitleRegexEdit.Value

        this.SetOrDeleteArray(scope, "Process", processes)
        this.SetOrDeleteArray(scope, "Class", classes)

        if (titleRegex = "")
        {
            if (scope.Has("TitleRegex"))
            {
                scope.Delete("TitleRegex")
            }
        }
        else
        {
            scope["TitleRegex"] := titleRegex
        }

        this.HotStringsState.SetDirty()
        this.OnDirtyStateChanged()
    }

    OnRenameScope(*)
    {
        if (this.SelectedScopeName = "")
        {
            return
        }

        aliases := this.HotStringsState.GetAliases()
        oldName := this.SelectedScopeName

        result := InputBox(
            "New scope name:",
            "Rename HotString scope",
            "w360 h120",
            oldName
        )

        if (result.Result != "OK")
        {
            return
        }

        newName := Trim(result.Value)
        if (newName = "" || newName = oldName)
        {
            return
        }

        if (aliases.Has(newName))
        {
            MsgBox(
                "Scope already exists: " newName,
                "MyWinToolbox Configurator",
                "Iconx"
            )
            return
        }

        renamedAliases := Map()
        for aliasName, aliasDefinition in aliases
        {
            renamedAliases[aliasName = oldName ? newName : aliasName] := aliasDefinition
        }

        this.HotStringsState.Data["Scopes"]["Aliases"] := renamedAliases
        this.RenameScopeReferences(oldName, newName)
        this.SelectedScopeName := newName
        this.HotStringsState.SetDirty()

        this.RefreshScopes(newName)
        this.RefreshHotStrings(this.SelectedHotStringIndex)
        this.OnDirtyStateChanged()
    }

    SetOrDeleteArray(target, fieldName, values)
    {
        if (values.Length = 0)
        {
            if (target.Has(fieldName))
            {
                target.Delete(fieldName)
            }
        }
        else
        {
            target[fieldName] := values
        }
    }

    RenameScopeReferences(oldName, newName)
    {
        for definition in this.HotStringsState.GetDefinitions()
        {
            for fieldName in ["IncludeScopes", "ExcludeScopes"]
            {
                if (!definition.Has(fieldName) || Type(definition[fieldName]) != "Array")
                {
                    continue
                }

                values := definition[fieldName]
                for index, scopeName in values
                {
                    if (scopeName = oldName)
                    {
                        values[index] := newName
                    }
                }
            }
        }
    }

    OnAddScope(*)
    {
        aliases := this.HotStringsState.GetAliases()

        result := InputBox(
            "Scope name:",
            "Add HotString scope",
            "w360 h120"
        )

        if (result.Result != "OK")
        {
            return
        }

        scopeName := Trim(result.Value)
        if (scopeName = "")
        {
            MsgBox("Scope name cannot be empty.", "MyWinToolbox Configurator", "Iconx")
            return
        }

        if (aliases.Has(scopeName))
        {
            MsgBox("Scope already exists: " scopeName, "MyWinToolbox Configurator", "Iconx")
            return
        }

        aliases[scopeName] := Map()
        this.HotStringsState.SetDirty()
        this.RefreshScopes(scopeName)
        this.ScopeProcessesEdit.Focus()
        this.OnDirtyStateChanged()
    }

    OnDeleteScope(*)
    {
        if (this.SelectedScopeName = "")
        {
            return
        }

        scopeName := this.SelectedScopeName

        answer := MsgBox(
            "Delete HotString scope '" scopeName "'?`n`n"
                "HotStrings referencing it will fail validation until you update their scopes.",
            "MyWinToolbox Configurator",
            "YesNo Icon!"
        )

        if (answer != "Yes")
        {
            return
        }

        this.HotStringsState.GetAliases().Delete(scopeName)
        this.HotStringsState.SetDirty()
        this.RefreshScopes()
        this.OnDirtyStateChanged()
    }

    UpdateScopeButtons()
    {
        hasScope := !!this.GetSelectedScope()

        this.ScopeNameEdit.Enabled := hasScope
        this.ScopeRenameButton.Enabled := hasScope
        this.ScopeProcessesEdit.Enabled := hasScope
        this.ScopeClassesEdit.Enabled := hasScope
        this.ScopeTitleRegexEdit.Enabled := hasScope
        this.ScopeDeleteButton.Enabled := hasScope
    }

    ; ========================================================================
    ; Save / close
    ; ========================================================================

    OnSave(*)
    {
        this.SaveAll()
    }

    OnSaveAndReload(*)
    {
        if (this.SaveAll())
        {
            Reload
        }
    }

    SaveAll()
    {
        try
        {
            snippetsSaved := false
            hotStringsSaved := false
            autoPasteSaved := false
            settingsSaved := false

            ; Validate every modified document before writing any of them.
            if (this.SnippetsDirty)
            {
                MyWinToolboxConfigurator.ValidateSnippets(this.SnippetsData)
            }

            if (this.HotStringsState.Dirty)
            {
                this.HotStringsState.Validate()
            }

            if (this.AutoPasteTab.Dirty)
            {
                this.AutoPasteTab.Validate()
            }

            if (this.SettingsTab.Dirty)
            {
                this.SettingsTab.Validate()

                if (!this.SettingsTab.ConfirmDangerousChanges())
                {
                    return false
                }
            }

            if (this.SnippetsDirty)
            {
                ConfiguratorJsonStore.SaveWithBackup(
                    this.SnippetsFilePath,
                    this.SnippetsData
                )
                this.SnippetsDirty := false
                snippetsSaved := true

                if (this.OnSnippetsSavedCallback)
                {
                    this.OnSnippetsSavedCallback.Call(
                        ConfiguratorJsonStore.Clone(this.SnippetsData)
                    )
                }
            }

            if (this.HotStringsState.Dirty)
            {
                this.HotStringsState.Save()
                hotStringsSaved := true

                if (this.OnHotStringsSavedCallback)
                {
                    this.OnHotStringsSavedCallback.Call(
                        ConfiguratorJsonStore.Clone(this.HotStringsState.Data)
                    )
                }
            }

            if (this.AutoPasteTab.Dirty)
            {
                this.AutoPasteTab.Save()
                autoPasteSaved := true
            }

            if (this.SettingsTab.Dirty)
            {
                this.SettingsTab.Save()
                settingsSaved := true
            }

            this.UpdateWindowTitle()

            if (hotStringsSaved || settingsSaved)
            {
                this.SetStatus(
                    "Saved. HotStrings/Settings require reload; use Save + Reload to apply."
                )
            }
            else if (snippetsSaved || autoPasteSaved)
            {
                this.SetStatus(
                    "Saved. Text Snippets and AutoPaste changes are active."
                )
            }
            else
            {
                this.SetStatus("No changes to save.")
            }

            return true
        }
        catch Error as e
        {
            MsgBox(
                "Unable to save configuration:`n" e.Message,
                "MyWinToolbox Configurator",
                "Iconx"
            )
            return false
        }
    }

    HasUnsavedChanges()
    {
        return this.SnippetsDirty
            || this.HotStringsState.Dirty
            || this.AutoPasteTab.Dirty
            || this.SettingsTab.Dirty
    }

    CanRestoreBackup()
    {
        if (!this.HasUnsavedChanges())
        {
            return true
        }

        answer := MsgBox(
            "There are unsaved Configurator changes.`n`n"
                "Restore will discard those in-memory changes and reload MyWinToolbox.`n`n"
                "Continue with restore?",
            "Restore MyWinToolbox configuration",
            "YesNo Icon!"
        )

        return answer = "Yes"
    }

    OnClose(*)
    {
        if (this.HasUnsavedChanges())
        {
            answer := MsgBox(
                "There are unsaved changes. Close without saving?",
                "MyWinToolbox Configurator",
                "YesNo Icon!"
            )

            if (answer != "Yes")
            {
                return true
            }
        }

        this.Window.Destroy()
        MyWinToolboxConfigurator.Instance := 0
        return false
    }

    OnDirtyStateChanged()
    {
        this.UpdateWindowTitle()
        this.UpdateStatus()
    }

    UpdateWindowTitle()
    {
        dirty := this.HasUnsavedChanges()

        this.Window.Title := "MyWinToolbox Configurator" (dirty ? " *" : "")
    }

    UpdateStatus()
    {
        states := []

        if (this.SnippetsDirty)
        {
            states.Push("Text Snippets modified")
        }

        if (this.HotStringsState.Dirty)
        {
            states.Push("HotStrings modified")
        }

        if (this.AutoPasteTab.Dirty)
        {
            states.Push("AutoPaste modified")
        }

        if (this.SettingsTab.Dirty)
        {
            states.Push("Settings modified")
        }

        if (states.Length = 0)
        {
            this.StatusText.Value := "Ready."
            return
        }

        this.StatusText.Value := ConfiguratorJsonStore.JoinList(states)
    }

    SetStatus(message)
    {
        this.StatusText.Value := message
    }
}
