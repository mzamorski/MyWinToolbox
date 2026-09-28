#Requires AutoHotkey v2.0

class TextSnippetsEditor
{
    static Instance := 0

    static Show(data, filePath, onSaved := 0)
    {
        if (TextSnippetsEditor.Instance)
        {
            try
            {
                TextSnippetsEditor.Instance.Gui.Show()
                WinActivate("ahk_id " TextSnippetsEditor.Instance.Gui.Hwnd)
                return
            }
            catch Error
            {
                TextSnippetsEditor.Instance := 0
            }
        }

        TextSnippetsEditor.Instance := TextSnippetsEditor(data, filePath, onSaved)
        TextSnippetsEditor.Instance.Gui.Show("w1040 h650")
    }

    __New(data, filePath, onSaved := 0)
    {
        this.FilePath := filePath
        this.OnSavedCallback := onSaved
        this.Data := TextSnippetsEditor.CloneData(data)
        this.SelectedCategory := ""
        this.SelectedSnippetIndex := 0
        this.Dirty := false
        this.UpdatingControls := false

        this.Gui := Gui("+Resize +MinSize920x560", "Text Snippets Editor")
        this.Gui.SetFont("s9", "Segoe UI")
        this.Gui.OnEvent("Close", ObjBindMethod(this, "OnClose"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "OnClose"))
        this.Gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))

        this.Gui.AddText("x12 y12 w220", "Categories")
        this.Gui.AddText("x248 y12 w280", "Snippets")
        this.Gui.AddText("x544 y12 w470", "Editor")

        this.CategoryList := this.Gui.AddListBox("x12 y36 w220 h460")
        this.CategoryList.OnEvent("Change", ObjBindMethod(this, "OnCategoryChanged"))

        this.SnippetList := this.Gui.AddListView("x248 y36 w280 h460 -Hdr -Multi", ["Snippet"])
        this.SnippetList.ModifyCol(1, 260)
        this.SnippetList.OnEvent("ItemSelect", ObjBindMethod(this, "OnSnippetChanged"))
        this.SnippetList.OnEvent("DoubleClick", ObjBindMethod(this, "OnSnippetDoubleClick"))

        this.Gui.AddText("x544 y38 w80", "Title")
        this.TitleEdit := this.Gui.AddEdit("x544 y58 w470 h25")
        this.TitleEdit.OnEvent("Change", ObjBindMethod(this, "OnEditorChanged"))

        this.Gui.AddText("x544 y96 w100", "Description")
        this.DescriptionEdit := this.Gui.AddEdit("x544 y116 w470 h70")
        this.DescriptionEdit.OnEvent("Change", ObjBindMethod(this, "OnEditorChanged"))

        this.Gui.AddText("x544 y199 w100", "Content")
        this.ContentEdit := this.Gui.AddEdit("x544 y219 w470 h277 WantTab")
        this.ContentEdit.SetFont("s9", "Consolas")
        this.ContentEdit.OnEvent("Change", ObjBindMethod(this, "OnEditorChanged"))

        this.AddCategoryButton := this.Gui.AddButton("x12 y510 w105 h30", "+ Category")
        this.AddCategoryButton.OnEvent("Click", ObjBindMethod(this, "OnAddCategory"))

        this.RenameCategoryButton := this.Gui.AddButton("x127 y510 w105 h30", "Rename")
        this.RenameCategoryButton.OnEvent("Click", ObjBindMethod(this, "OnRenameCategory"))

        this.DeleteCategoryButton := this.Gui.AddButton("x12 y548 w220 h30", "Delete category")
        this.DeleteCategoryButton.OnEvent("Click", ObjBindMethod(this, "OnDeleteCategory"))

        this.AddSnippetButton := this.Gui.AddButton("x248 y510 w86 h30", "+ Snippet")
        this.AddSnippetButton.OnEvent("Click", ObjBindMethod(this, "OnAddSnippet"))

        this.DuplicateSnippetButton := this.Gui.AddButton("x342 y510 w90 h30", "Duplicate")
        this.DuplicateSnippetButton.OnEvent("Click", ObjBindMethod(this, "OnDuplicateSnippet"))

        this.AddSeparatorButton := this.Gui.AddButton("x440 y510 w88 h30", "+ Separator")
        this.AddSeparatorButton.OnEvent("Click", ObjBindMethod(this, "OnAddSeparator"))

        this.MoveUpButton := this.Gui.AddButton("x248 y548 w62 h30", "Up")
        this.MoveUpButton.OnEvent("Click", ObjBindMethod(this, "OnMoveUp"))

        this.MoveDownButton := this.Gui.AddButton("x318 y548 w62 h30", "Down")
        this.MoveDownButton.OnEvent("Click", ObjBindMethod(this, "OnMoveDown"))

        this.DeleteSnippetButton := this.Gui.AddButton("x388 y548 w140 h30", "Delete snippet")
        this.DeleteSnippetButton.OnEvent("Click", ObjBindMethod(this, "OnDeleteSnippet"))

        this.StatusText := this.Gui.AddText("x544 y510 w470 h22", "")

        this.SaveButton := this.Gui.AddButton("x814 y548 w96 h30 Default", "Save")
        this.SaveButton.OnEvent("Click", ObjBindMethod(this, "OnSave"))

        this.CloseButton := this.Gui.AddButton("x918 y548 w96 h30", "Close")
        this.CloseButton.OnEvent("Click", ObjBindMethod(this, "OnClose"))

        this.RefreshCategories()
        this.UpdateEditorEnabledState()
        this.UpdateStatus()
    }

    static CloneData(data)
    {
        json := Jxon_dump(data, 4)
        return jxon_load(&json)
    }

    static ValidateData(data)
    {
        if (!IsObject(data) || !(data is Map))
        {
            throw Error("TextSnippets.json root value must be an object.")
        }

        for categoryName, snippets in data
        {
            if (Type(categoryName) != "String" || Trim(categoryName) = "")
            {
                throw Error("Category names must be non-empty strings.")
            }

            if (!IsObject(snippets) || Type(snippets) != "Array")
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
                hasTitle := snippet.Has("Title") && Type(snippet["Title"]) = "String"
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

    static SaveData(filePath, data)
    {
        TextSnippetsEditor.ValidateData(data)
        json := Jxon_dump(data, 4)
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

    OnResize(guiObj, minMax, width, height)
    {
        if (minMax = -1)
        {
            return
        }

        margin := 12
        footerTop := height - 100
        contentHeight := Max(220, footerTop - 36)

        leftWidth := 220
        middleWidth := 280
        gap := 16
        editorX := margin + leftWidth + gap + middleWidth + gap
        editorWidth := Max(300, width - editorX - margin)

        this.CategoryList.Move(, , leftWidth, contentHeight)
        this.SnippetList.Move(, , middleWidth, contentHeight)
        this.SnippetList.ModifyCol(1, Max(80, middleWidth - 16))

        this.TitleEdit.Move(editorX, , editorWidth)
        this.DescriptionEdit.Move(editorX, , editorWidth)
        this.ContentEdit.Move(editorX, , editorWidth, Max(150, contentHeight - 241))

        this.StatusText.Move(editorX, footerTop, editorWidth - 220)
        this.SaveButton.Move(width - 226, footerTop + 38)
        this.CloseButton.Move(width - 122, footerTop + 38)

        this.AddCategoryButton.Move(, footerTop)
        this.RenameCategoryButton.Move(, footerTop)
        this.DeleteCategoryButton.Move(, footerTop + 38)

        this.AddSnippetButton.Move(, footerTop)
        this.DuplicateSnippetButton.Move(, footerTop)
        this.AddSeparatorButton.Move(, footerTop)
        this.MoveUpButton.Move(, footerTop + 38)
        this.MoveDownButton.Move(, footerTop + 38)
        this.DeleteSnippetButton.Move(, footerTop + 38)
    }

    RefreshCategories(preferredCategory := "")
    {
        categories := []
        for categoryName in this.Data
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

    RefreshSnippets(preferredIndex := 0)
    {
        labels := []
        snippets := this.GetSelectedSnippets()

        if (snippets)
        {
            for index, snippet in snippets
            {
                labels.Push(TextSnippetsEditor.GetSnippetLabel(snippet, index))
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
        this.UpdateEditorEnabledState()
        this.UpdateStatus()
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
            return "──────── separator ────────"
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

    GetSelectedSnippets()
    {
        if (this.SelectedCategory = "" || !this.Data.Has(this.SelectedCategory))
        {
            return 0
        }

        return this.Data[this.SelectedCategory]
    }

    GetSelectedSnippet()
    {
        snippets := this.GetSelectedSnippets()
        if (!snippets || this.SelectedSnippetIndex < 1 || this.SelectedSnippetIndex > snippets.Length)
        {
            return 0
        }

        return snippets[this.SelectedSnippetIndex]
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
        this.UpdateEditorEnabledState()
        this.UpdateStatus()
    }

    OnSnippetDoubleClick(control, rowNumber)
    {
        if (this.TitleEdit.Enabled)
        {
            this.TitleEdit.Focus()
        }
    }

    LoadSelectedSnippet()
    {
        snippet := this.GetSelectedSnippet()

        this.UpdatingControls := true
        try
        {
            if (!snippet)
            {
                this.TitleEdit.Value := ""
                this.DescriptionEdit.Value := ""
                this.ContentEdit.Value := ""
                return
            }

            this.TitleEdit.Value := snippet.Has("Title") ? snippet["Title"] : ""
            this.DescriptionEdit.Value := snippet.Has("Description") ? snippet["Description"] : ""
            this.ContentEdit.Value := snippet.Has("Content") ? snippet["Content"] : ""
        }
        finally
        {
            this.UpdatingControls := false
        }
    }

    OnEditorChanged(*)
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

        title := this.TitleEdit.Value
        description := this.DescriptionEdit.Value
        content := this.ContentEdit.Value

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

        snippet["Content"] := content

        this.SetDirty()
        this.RefreshSnippetLabel()
    }

    RefreshSnippetLabel()
    {
        snippet := this.GetSelectedSnippet()
        if (!snippet || this.SelectedSnippetIndex = 0)
        {
            return
        }

        label := TextSnippetsEditor.GetSnippetLabel(snippet, this.SelectedSnippetIndex)
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
            MsgBox("Category name cannot be empty.", "Text Snippets Editor", "Iconx")
            return
        }

        if (this.Data.Has(categoryName))
        {
            MsgBox("Category already exists: " categoryName, "Text Snippets Editor", "Iconx")
            return
        }

        this.Data[categoryName] := []
        this.SetDirty()
        this.RefreshCategories(categoryName)
    }

    OnRenameCategory(*)
    {
        if (this.SelectedCategory = "")
        {
            return
        }

        oldName := this.SelectedCategory
        result := InputBox("New category name:", "Rename category", "w360 h120", oldName)
        if (result.Result != "OK")
        {
            return
        }

        newName := Trim(result.Value)
        if (newName = "" || newName = oldName)
        {
            return
        }

        if (this.Data.Has(newName))
        {
            MsgBox("Category already exists: " newName, "Text Snippets Editor", "Iconx")
            return
        }

        renamed := Map()
        for categoryName, snippets in this.Data
        {
            renamed[categoryName = oldName ? newName : categoryName] := snippets
        }

        this.Data := renamed
        this.SetDirty()
        this.RefreshCategories(newName)
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
            "Text Snippets Editor",
            "YesNo Icon!"
        )

        if (answer != "Yes")
        {
            return
        }

        this.Data.Delete(categoryName)
        this.SetDirty()
        this.RefreshCategories()
    }

    OnAddSnippet(*)
    {
        snippets := this.GetSelectedSnippets()
        if (!snippets)
        {
            MsgBox("Select or create a category first.", "Text Snippets Editor", "Iconi")
            return
        }

        snippets.Push(Map(
            "Title", "New snippet",
            "Content", ""
        ))

        this.SetDirty()
        this.RefreshSnippets(snippets.Length)
        this.TitleEdit.Focus()
    }

    OnDuplicateSnippet(*)
    {
        snippets := this.GetSelectedSnippets()
        snippet := this.GetSelectedSnippet()
        if (!snippets || !snippet)
        {
            return
        }

        json := Jxon_dump(snippet, 4)
        clone := jxon_load(&json)

        if (clone.Has("Title"))
        {
            clone["Title"] := clone["Title"] " (copy)"
        }

        insertIndex := this.SelectedSnippetIndex + 1
        snippets.InsertAt(insertIndex, clone)

        this.SetDirty()
        this.RefreshSnippets(insertIndex)
    }

    OnAddSeparator(*)
    {
        snippets := this.GetSelectedSnippets()
        if (!snippets)
        {
            MsgBox("Select or create a category first.", "Text Snippets Editor", "Iconi")
            return
        }

        snippets.Push(Map("Content", "--"))
        this.SetDirty()
        this.RefreshSnippets(snippets.Length)
    }

    OnDeleteSnippet(*)
    {
        snippets := this.GetSelectedSnippets()
        snippet := this.GetSelectedSnippet()
        if (!snippets || !snippet)
        {
            return
        }

        label := TextSnippetsEditor.GetSnippetLabel(snippet, this.SelectedSnippetIndex)
        answer := MsgBox(
            "Delete snippet '" label "'?",
            "Text Snippets Editor",
            "YesNo Icon!"
        )

        if (answer != "Yes")
        {
            return
        }

        oldIndex := this.SelectedSnippetIndex
        snippets.RemoveAt(oldIndex)
        this.SetDirty()

        nextIndex := Min(oldIndex, snippets.Length)
        this.RefreshSnippets(nextIndex)
    }

    OnMoveUp(*)
    {
        snippets := this.GetSelectedSnippets()
        index := this.SelectedSnippetIndex

        if (!snippets || index <= 1)
        {
            return
        }

        item := snippets.RemoveAt(index)
        snippets.InsertAt(index - 1, item)
        this.SetDirty()
        this.RefreshSnippets(index - 1)
    }

    OnMoveDown(*)
    {
        snippets := this.GetSelectedSnippets()
        index := this.SelectedSnippetIndex

        if (!snippets || index < 1 || index >= snippets.Length)
        {
            return
        }

        item := snippets.RemoveAt(index)
        snippets.InsertAt(index + 1, item)
        this.SetDirty()
        this.RefreshSnippets(index + 1)
    }

    OnSave(*)
    {
        try
        {
            TextSnippetsEditor.SaveData(this.FilePath, this.Data)
            this.Dirty := false
            this.UpdateWindowTitle()
            this.UpdateStatus("Saved. Backup: " this.FilePath ".bak")

            if (this.OnSavedCallback)
            {
                this.OnSavedCallback.Call(TextSnippetsEditor.CloneData(this.Data))
            }
        }
        catch Error as e
        {
            MsgBox(
                "Unable to save snippets:`n" e.Message,
                "Text Snippets Editor",
                "Iconx"
            )
        }
    }

    OnClose(*)
    {
        if (this.Dirty)
        {
            answer := MsgBox(
                "There are unsaved changes. Close without saving?",
                "Text Snippets Editor",
                "YesNo Icon!"
            )

            if (answer != "Yes")
            {
                return true
            }
        }

        this.Gui.Destroy()
        TextSnippetsEditor.Instance := 0
        return false
    }

    SetDirty()
    {
        if (!this.Dirty)
        {
            this.Dirty := true
            this.UpdateWindowTitle()
        }

        this.UpdateStatus()
    }

    UpdateWindowTitle()
    {
        this.Gui.Title := "Text Snippets Editor" (this.Dirty ? " *" : "")
    }

    UpdateStatus(message := "")
    {
        if (message != "")
        {
            this.StatusText.Value := message
            return
        }

        categoryCount := this.Data.Count
        snippetCount := 0

        for categoryName, snippets in this.Data
        {
            snippetCount += snippets.Length
        }

        this.StatusText.Value := categoryCount " categories, " snippetCount " snippets"
            . (this.Dirty ? " — unsaved changes" : "")
    }

    UpdateEditorEnabledState()
    {
        hasCategory := this.SelectedCategory != ""
        hasSnippet := !!this.GetSelectedSnippet()

        this.RenameCategoryButton.Enabled := hasCategory
        this.DeleteCategoryButton.Enabled := hasCategory

        this.AddSnippetButton.Enabled := hasCategory
        this.AddSeparatorButton.Enabled := hasCategory

        this.TitleEdit.Enabled := hasSnippet
        this.DescriptionEdit.Enabled := hasSnippet
        this.ContentEdit.Enabled := hasSnippet
        this.DuplicateSnippetButton.Enabled := hasSnippet
        this.DeleteSnippetButton.Enabled := hasSnippet
        this.MoveUpButton.Enabled := hasSnippet && this.SelectedSnippetIndex > 1

        snippets := this.GetSelectedSnippets()
        this.MoveDownButton.Enabled := hasSnippet && snippets && this.SelectedSnippetIndex < snippets.Length
    }
}
