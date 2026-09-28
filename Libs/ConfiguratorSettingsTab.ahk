#Requires AutoHotkey v2.0

class ConfiguratorIniDocument
{
    __New(filePath)
    {
        this.FilePath := filePath
        this.Lines := []

        if (FileExist(filePath))
        {
            content := FileRead(filePath, "UTF-8")
            this.Lines := StrSplit(content, "`n", "`r")
        }
    }

    static EncodeValue(value)
    {
        value := StrReplace("" value, "`r", "")
        return StrReplace(value, "`n", "\n")
    }

    static DecodeValue(value)
    {
        value := StringUtils.RemoveComments(Trim("" value))
        return StrReplace(value, "\n", "`n")
    }

    FindSection(sectionName, &startIndex, &endIndex)
    {
        startIndex := 0
        endIndex := this.Lines.Length + 1
        currentSection := ""

        for index, line in this.Lines
        {
            trimmed := Trim(line)
            if RegExMatch(trimmed, "^\[(.*)\]$", &match)
            {
                foundSection := Trim(match[1])

                if (startIndex && StrLower(foundSection) != StrLower(sectionName))
                {
                    endIndex := index
                    return true
                }

                if (StrLower(foundSection) = StrLower(sectionName))
                {
                    startIndex := index
                }
            }
        }

        return !!startIndex
    }

    Get(sectionName, keyName, defaultValue := "")
    {
        if (!this.FindSection(sectionName, &startIndex, &endIndex))
        {
            return defaultValue
        }

        Loop endIndex - startIndex - 1
        {
            index := startIndex + A_Index
            line := this.Lines[index]
            trimmed := Trim(line)

            if (trimmed = "" || SubStr(trimmed, 1, 1) = ";")
            {
                continue
            }

            separatorPos := InStr(line, "=")
            if (!separatorPos)
            {
                continue
            }

            candidateKey := Trim(SubStr(line, 1, separatorPos - 1))
            if (StrLower(candidateKey) = StrLower(keyName))
            {
                return ConfiguratorIniDocument.DecodeValue(
                    SubStr(line, separatorPos + 1)
                )
            }
        }

        return defaultValue
    }

    Set(sectionName, keyName, value)
    {
        encodedValue := ConfiguratorIniDocument.EncodeValue(value)
        replacement := keyName " = " encodedValue

        if (!this.FindSection(sectionName, &startIndex, &endIndex))
        {
            if (this.Lines.Length > 0 && Trim(this.Lines[this.Lines.Length]) != "")
            {
                this.Lines.Push("")
            }

            this.Lines.Push("[" sectionName "]")
            this.Lines.Push(replacement)
            return
        }

        Loop endIndex - startIndex - 1
        {
            index := startIndex + A_Index
            line := this.Lines[index]
            separatorPos := InStr(line, "=")

            if (!separatorPos)
            {
                continue
            }

            candidateKey := Trim(SubStr(line, 1, separatorPos - 1))
            if (StrLower(candidateKey) = StrLower(keyName))
            {
                this.Lines[index] := replacement
                return
            }
        }

        this.Lines.InsertAt(endIndex, replacement)
    }

    GetSectionEntries(sectionName)
    {
        entries := []

        if (!this.FindSection(sectionName, &startIndex, &endIndex))
        {
            return entries
        }

        Loop endIndex - startIndex - 1
        {
            index := startIndex + A_Index
            line := this.Lines[index]
            trimmed := Trim(line)

            if (trimmed = "" || SubStr(trimmed, 1, 1) = ";")
            {
                continue
            }

            separatorPos := InStr(line, "=")
            if (!separatorPos)
            {
                continue
            }

            keyName := Trim(SubStr(line, 1, separatorPos - 1))
            value := ConfiguratorIniDocument.DecodeValue(
                SubStr(line, separatorPos + 1)
            )

            entries.Push(Map("Name", keyName, "Value", value))
        }

        return entries
    }

    ReplaceSectionEntries(sectionName, entries)
    {
        newLines := []

        for entry in entries
        {
            name := Trim("" entry["Name"])
            if (name = "")
            {
                continue
            }

            newLines.Push(
                name " = " ConfiguratorIniDocument.EncodeValue(entry["Value"])
            )
        }

        if (!this.FindSection(sectionName, &startIndex, &endIndex))
        {
            if (this.Lines.Length > 0 && Trim(this.Lines[this.Lines.Length]) != "")
            {
                this.Lines.Push("")
            }

            this.Lines.Push("[" sectionName "]")

            for line in newLines
            {
                this.Lines.Push(line)
            }

            return
        }

        removeCount := endIndex - startIndex - 1
        if (removeCount > 0)
        {
            this.Lines.RemoveAt(startIndex + 1, removeCount)
        }

        insertIndex := startIndex + 1
        for line in newLines
        {
            this.Lines.InsertAt(insertIndex, line)
            insertIndex += 1
        }
    }

    Render()
    {
        output := ""
        separator := ""

        for line in this.Lines
        {
            output .= separator line
            separator := "`r`n"
        }

        if (output != "" && SubStr(output, -1) != "`n")
        {
            output .= "`r`n"
        }

        return output
    }

    SaveWithBackup()
    {
        tempPath := this.FilePath ".tmp"
        backupPath := this.FilePath ".bak"

        if FileExist(tempPath)
        {
            FileDelete(tempPath)
        }

        FileAppend(this.Render(), tempPath, "UTF-8")

        try
        {
            if FileExist(this.FilePath)
            {
                FileCopy(this.FilePath, backupPath, true)
            }

            FileMove(tempPath, this.FilePath, true)
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
}

class ConfiguratorSettingsTab
{
    __New(window, sharedConfigPath, profileConfigPath, onDirtyCallback := 0)
    {
        this.Window := window
        this.SharedConfigPath := sharedConfigPath
        this.ProfileConfigPath := profileConfigPath
        this.OnDirtyCallback := onDirtyCallback
        this.SharedDoc := ConfiguratorIniDocument(sharedConfigPath)
        this.ProfileDoc := ConfiguratorIniDocument(profileConfigPath)
        this.Signatures := this.ProfileDoc.GetSectionEntries("UserSignatures")
        this.Passwords := this.ProfileDoc.GetSectionEntries("Passwords")
        this.SelectedSignatureIndex := 0
        this.SelectedPasswordIndex := 0
        this.Dirty := false
        this.UpdatingControls := false
        this.OriginalSecret := this.ProfileDoc.Get("Settings", "Secret", "")

        this.Build()
        this.LoadFields()
        this.RefreshSignatures()
        this.RefreshPasswords()
    }

    Build()
    {
        this.Window.AddGroupBox("x25 y50 w535 h580", "Shared + profile settings")

        this.Window.AddText("x45 y82 w120", "Spaces per indent")
        this.SpacesEdit := this.Window.AddEdit("x165 y79 w70 h25 Number")
        this.SpacesEdit.OnEvent("Change", ObjBindMethod(this, "OnFieldChanged"))

        this.DebugCheck := this.Window.AddCheckBox("x260 y80 w140 h24", "Debug logging")
        this.DebugCheck.OnEvent("Click", ObjBindMethod(this, "OnFieldChanged"))

        this.Window.AddText("x45 y120 w100", "Dummy text")
        this.DummyTextEdit := this.Window.AddEdit("x45 y140 w495 h120 WantTab")
        this.DummyTextEdit.OnEvent("Change", ObjBindMethod(this, "OnFieldChanged"))

        this.Window.AddText("x45 y278 w100", "Email")
        this.EmailEdit := this.Window.AddEdit("x45 y298 w495 h25")
        this.EmailEdit.OnEvent("Change", ObjBindMethod(this, "OnFieldChanged"))

        this.Window.AddText("x45 y335 w100", "Secret")
        this.SecretEdit := this.Window.AddEdit("x45 y355 w390 h25 Password")
        this.SecretEdit.OnEvent("Change", ObjBindMethod(this, "OnFieldChanged"))

        this.ShowSecretCheck := this.Window.AddCheckBox("x445 y356 w95 h24", "Show")
        this.ShowSecretCheck.OnEvent("Click", ObjBindMethod(this, "OnToggleSecret"))

        this.Window.AddText("x45 y392 w140", "Shipping address")
        this.ShippingEdit := this.Window.AddEdit("x45 y412 w495 h80 WantTab")
        this.ShippingEdit.OnEvent("Change", ObjBindMethod(this, "OnFieldChanged"))

        this.Window.AddText("x45 y510 w95", "Headphones")
        this.HeadphonesEdit := this.Window.AddEdit("x140 y507 w400 h25")
        this.HeadphonesEdit.OnEvent("Change", ObjBindMethod(this, "OnFieldChanged"))

        this.Window.AddText("x45 y548 w95", "Monitor")
        this.MonitorEdit := this.Window.AddEdit("x140 y545 w400 h25")
        this.MonitorEdit.OnEvent("Change", ObjBindMethod(this, "OnFieldChanged"))

        this.Window.AddText("x45 y586 w95", "Laptop")
        this.LaptopEdit := this.Window.AddEdit("x140 y583 w400 h25")
        this.LaptopEdit.OnEvent("Change", ObjBindMethod(this, "OnFieldChanged"))

        this.Window.AddGroupBox("x580 y50 w555 h265", "User signatures")
        this.SignatureList := this.Window.AddListBox("x600 y82 w180 h170")
        this.SignatureList.OnEvent("Change", ObjBindMethod(this, "OnSignatureSelected"))

        this.Window.AddText("x800 y82 w80", "Name")
        this.SignatureNameEdit := this.Window.AddEdit("x800 y102 w315 h25 ReadOnly")

        this.Window.AddText("x800 y140 w80", "Value")
        this.SignatureValueEdit := this.Window.AddEdit("x800 y160 w315 h92 WantTab")
        this.SignatureValueEdit.OnEvent(
            "Change",
            ObjBindMethod(this, "OnSignatureValueChanged")
        )

        this.SignatureAddButton := this.Window.AddButton("x600 y266 w68 h28", "+ Add")
        this.SignatureAddButton.OnEvent("Click", ObjBindMethod(this, "OnAddSignature"))

        this.SignatureRenameButton := this.Window.AddButton("x676 y266 w78 h28", "Rename")
        this.SignatureRenameButton.OnEvent("Click", ObjBindMethod(this, "OnRenameSignature"))

        this.SignatureDeleteButton := this.Window.AddButton("x762 y266 w72 h28", "Delete")
        this.SignatureDeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDeleteSignature"))

        this.Window.AddGroupBox("x580 y330 w555 h300", "Passwords")
        this.PasswordList := this.Window.AddListBox("x600 y362 w180 h190")
        this.PasswordList.OnEvent("Change", ObjBindMethod(this, "OnPasswordSelected"))

        this.Window.AddText("x800 y362 w80", "Name")
        this.PasswordNameEdit := this.Window.AddEdit("x800 y382 w315 h25 ReadOnly")

        this.Window.AddText("x800 y420 w120", "Encrypted value")
        this.PasswordValueEdit := this.Window.AddEdit("x800 y440 w315 h65")
        this.PasswordValueEdit.OnEvent(
            "Change",
            ObjBindMethod(this, "OnPasswordValueChanged")
        )

        this.PasswordAddButton := this.Window.AddButton("x600 y566 w68 h28", "+ Add")
        this.PasswordAddButton.OnEvent("Click", ObjBindMethod(this, "OnAddPassword"))

        this.PasswordRenameButton := this.Window.AddButton("x676 y566 w78 h28", "Rename")
        this.PasswordRenameButton.OnEvent("Click", ObjBindMethod(this, "OnRenamePassword"))

        this.PasswordDeleteButton := this.Window.AddButton("x762 y566 w72 h28", "Delete")
        this.PasswordDeleteButton.OnEvent("Click", ObjBindMethod(this, "OnDeletePassword"))

        this.PasswordSetPlainButton := this.Window.AddButton(
            "x850 y566 w130 h28",
            "Set plaintext..."
        )
        this.PasswordSetPlainButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnSetPasswordPlaintext")
        )

        this.Window.AddText(
            "x800 y515 w315 h38",
            "Changing Secret does not re-encrypt existing passwords."
        )
    }

    LoadFields()
    {
        this.UpdatingControls := true
        try
        {
            this.SpacesEdit.Value := this.SharedDoc.Get(
                "Settings",
                "SpacesPerIndent",
                "4"
            )

            debugText := StrLower(
                Trim(this.SharedDoc.Get("Logging", "Debug", "false"))
            )
            this.DebugCheck.Value := (
                debugText = "true"
                || debugText = "1"
                || debugText = "yes"
            ) ? 1 : 0

            this.DummyTextEdit.Value := this.SharedDoc.Get(
                "Content",
                "DummyText",
                ""
            )

            this.EmailEdit.Value := this.ProfileDoc.Get(
                "Settings",
                "Email",
                ""
            )

            this.SecretEdit.Value := this.ProfileDoc.Get(
                "Settings",
                "Secret",
                ""
            )

            this.ShippingEdit.Value := this.ProfileDoc.Get(
                "Settings",
                "ShippingAddress",
                ""
            )

            this.HeadphonesEdit.Value := this.ProfileDoc.Get(
                "AudioDevices",
                "Headphones",
                ""
            )

            this.MonitorEdit.Value := this.ProfileDoc.Get(
                "AudioDevices",
                "Monitor",
                ""
            )

            this.LaptopEdit.Value := this.ProfileDoc.Get(
                "AudioDevices",
                "Laptop",
                ""
            )
        }
        finally
        {
            this.UpdatingControls := false
        }
    }

    OnToggleSecret(*)
    {
        this.SecretEdit.Opt(this.ShowSecretCheck.Value ? "-Password" : "+Password")
    }

    OnFieldChanged(*)
    {
        if (this.UpdatingControls)
        {
            return
        }

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
        spacesText := Trim(this.SpacesEdit.Value)

        if (!IsInteger(spacesText) || (spacesText + 0) < 1 || (spacesText + 0) > 32)
        {
            throw Error("SpacesPerIndent must be an integer from 1 to 32.")
        }

        if (Trim(this.SecretEdit.Value) = "")
        {
            throw Error("Profile Secret cannot be empty.")
        }

        ConfiguratorSettingsTab.ValidateNamedEntries(
            this.Signatures,
            "User signature"
        )
        ConfiguratorSettingsTab.ValidateNamedEntries(
            this.Passwords,
            "Password"
        )

        return true
    }

    static ValidateNamedEntries(entries, label)
    {
        names := Map()

        for entry in entries
        {
            name := Trim("" entry["Name"])
            if (name = "")
            {
                throw Error(label " name cannot be empty.")
            }

            normalized := StrLower(name)
            if (names.Has(normalized))
            {
                throw Error("Duplicate " label " name: " name)
            }

            names[normalized] := true
        }
    }

    ConfirmDangerousChanges()
    {
        newSecret := this.SecretEdit.Value

        if (
            newSecret != this.OriginalSecret
            && this.Passwords.Length > 0
        )
        {
            answer := MsgBox(
                "The profile Secret changed while encrypted passwords exist.`n`n"
                    "Existing password values are NOT automatically re-encrypted and may stop decrypting.`n`n"
                    "Save anyway?",
                "MyWinToolbox Configurator",
                "YesNo Icon!"
            )

            return answer = "Yes"
        }

        return true
    }

    ApplyControlsToDocuments()
    {
        this.SharedDoc.Set(
            "Settings",
            "SpacesPerIndent",
            Trim(this.SpacesEdit.Value)
        )

        this.SharedDoc.Set(
            "Logging",
            "Debug",
            this.DebugCheck.Value ? "true" : "false"
        )

        this.SharedDoc.Set(
            "Content",
            "DummyText",
            this.DummyTextEdit.Value
        )

        this.ProfileDoc.Set(
            "Settings",
            "Email",
            this.EmailEdit.Value
        )

        this.ProfileDoc.Set(
            "Settings",
            "Secret",
            this.SecretEdit.Value
        )

        this.ProfileDoc.Set(
            "Settings",
            "ShippingAddress",
            this.ShippingEdit.Value
        )

        this.ProfileDoc.Set(
            "AudioDevices",
            "Headphones",
            this.HeadphonesEdit.Value
        )

        this.ProfileDoc.Set(
            "AudioDevices",
            "Monitor",
            this.MonitorEdit.Value
        )

        this.ProfileDoc.Set(
            "AudioDevices",
            "Laptop",
            this.LaptopEdit.Value
        )

        this.ProfileDoc.ReplaceSectionEntries(
            "UserSignatures",
            this.Signatures
        )

        this.ProfileDoc.ReplaceSectionEntries(
            "Passwords",
            this.Passwords
        )
    }

    Save()
    {
        this.Validate()
        this.ApplyControlsToDocuments()

        this.SharedDoc.SaveWithBackup()

        try
        {
            this.ProfileDoc.SaveWithBackup()
        }
        catch Error as e
        {
            throw Error(
                "Shared config was saved, but profile config failed: " e.Message
            )
        }

        this.OriginalSecret := this.SecretEdit.Value
        this.Dirty := false
    }

    RefreshSignatures(preferredIndex := 0)
    {
        this.UpdatingControls := true
        try
        {
            this.SignatureList.Delete()

            names := []
            for entry in this.Signatures
            {
                names.Push(entry["Name"])
            }

            if (names.Length > 0)
            {
                this.SignatureList.Add(names)

                selectedIndex := preferredIndex
                if (selectedIndex < 1 || selectedIndex > names.Length)
                {
                    selectedIndex := 1
                }

                this.SignatureList.Choose(selectedIndex)
                this.SelectedSignatureIndex := selectedIndex
            }
            else
            {
                this.SelectedSignatureIndex := 0
            }
        }
        finally
        {
            this.UpdatingControls := false
        }

        this.LoadSelectedSignature()
        this.UpdateSignatureButtons()
    }

    GetSelectedSignature()
    {
        if (
            this.SelectedSignatureIndex < 1
            || this.SelectedSignatureIndex > this.Signatures.Length
        )
        {
            return 0
        }

        return this.Signatures[this.SelectedSignatureIndex]
    }

    OnSignatureSelected(*)
    {
        if (this.UpdatingControls || this.SignatureList.Value = 0)
        {
            return
        }

        this.SelectedSignatureIndex := this.SignatureList.Value
        this.LoadSelectedSignature()
        this.UpdateSignatureButtons()
    }

    LoadSelectedSignature()
    {
        entry := this.GetSelectedSignature()

        this.UpdatingControls := true
        try
        {
            this.SignatureNameEdit.Value := entry ? entry["Name"] : ""
            this.SignatureValueEdit.Value := entry ? entry["Value"] : ""
        }
        finally
        {
            this.UpdatingControls := false
        }
    }

    OnSignatureValueChanged(*)
    {
        if (this.UpdatingControls)
        {
            return
        }

        entry := this.GetSelectedSignature()
        if (!entry)
        {
            return
        }

        entry["Value"] := this.SignatureValueEdit.Value
        this.SetDirty()
    }

    OnAddSignature(*)
    {
        result := InputBox(
            "Signature name:",
            "Add user signature",
            "w360 h120"
        )

        if (result.Result != "OK")
        {
            return
        }

        name := Trim(result.Value)
        if (name = "")
        {
            return
        }

        if (this.EntryNameExists(this.Signatures, name))
        {
            MsgBox("Signature already exists: " name, "MyWinToolbox Configurator", "Iconx")
            return
        }

        this.Signatures.Push(Map("Name", name, "Value", ""))
        this.SetDirty()
        this.RefreshSignatures(this.Signatures.Length)
        this.SignatureValueEdit.Focus()
    }

    OnRenameSignature(*)
    {
        entry := this.GetSelectedSignature()
        if (!entry)
        {
            return
        }

        result := InputBox(
            "New signature name:",
            "Rename user signature",
            "w360 h120",
            entry["Name"]
        )

        if (result.Result != "OK")
        {
            return
        }

        name := Trim(result.Value)
        if (name = "" || name = entry["Name"])
        {
            return
        }

        if (this.EntryNameExists(this.Signatures, name, this.SelectedSignatureIndex))
        {
            MsgBox("Signature already exists: " name, "MyWinToolbox Configurator", "Iconx")
            return
        }

        entry["Name"] := name
        this.SetDirty()
        this.RefreshSignatures(this.SelectedSignatureIndex)
    }

    OnDeleteSignature(*)
    {
        entry := this.GetSelectedSignature()
        if (!entry)
        {
            return
        }

        answer := MsgBox(
            "Delete user signature '" entry["Name"] "'?",
            "MyWinToolbox Configurator",
            "YesNo Icon!"
        )

        if (answer != "Yes")
        {
            return
        }

        oldIndex := this.SelectedSignatureIndex
        this.Signatures.RemoveAt(oldIndex)
        this.SetDirty()
        this.RefreshSignatures(Min(oldIndex, this.Signatures.Length))
    }

    RefreshPasswords(preferredIndex := 0)
    {
        this.UpdatingControls := true
        try
        {
            this.PasswordList.Delete()

            names := []
            for entry in this.Passwords
            {
                names.Push(entry["Name"])
            }

            if (names.Length > 0)
            {
                this.PasswordList.Add(names)

                selectedIndex := preferredIndex
                if (selectedIndex < 1 || selectedIndex > names.Length)
                {
                    selectedIndex := 1
                }

                this.PasswordList.Choose(selectedIndex)
                this.SelectedPasswordIndex := selectedIndex
            }
            else
            {
                this.SelectedPasswordIndex := 0
            }
        }
        finally
        {
            this.UpdatingControls := false
        }

        this.LoadSelectedPassword()
        this.UpdatePasswordButtons()
    }

    GetSelectedPassword()
    {
        if (
            this.SelectedPasswordIndex < 1
            || this.SelectedPasswordIndex > this.Passwords.Length
        )
        {
            return 0
        }

        return this.Passwords[this.SelectedPasswordIndex]
    }

    OnPasswordSelected(*)
    {
        if (this.UpdatingControls || this.PasswordList.Value = 0)
        {
            return
        }

        this.SelectedPasswordIndex := this.PasswordList.Value
        this.LoadSelectedPassword()
        this.UpdatePasswordButtons()
    }

    LoadSelectedPassword()
    {
        entry := this.GetSelectedPassword()

        this.UpdatingControls := true
        try
        {
            this.PasswordNameEdit.Value := entry ? entry["Name"] : ""
            this.PasswordValueEdit.Value := entry ? entry["Value"] : ""
        }
        finally
        {
            this.UpdatingControls := false
        }
    }

    OnPasswordValueChanged(*)
    {
        if (this.UpdatingControls)
        {
            return
        }

        entry := this.GetSelectedPassword()
        if (!entry)
        {
            return
        }

        entry["Value"] := this.PasswordValueEdit.Value
        this.SetDirty()
    }

    OnAddPassword(*)
    {
        result := InputBox(
            "Password key name:",
            "Add password",
            "w360 h120"
        )

        if (result.Result != "OK")
        {
            return
        }

        name := Trim(result.Value)
        if (name = "")
        {
            return
        }

        if (this.EntryNameExists(this.Passwords, name))
        {
            MsgBox("Password key already exists: " name, "MyWinToolbox Configurator", "Iconx")
            return
        }

        this.Passwords.Push(Map("Name", name, "Value", ""))
        this.SetDirty()
        this.RefreshPasswords(this.Passwords.Length)
        this.PasswordSetPlainButton.Focus()
    }

    OnRenamePassword(*)
    {
        entry := this.GetSelectedPassword()
        if (!entry)
        {
            return
        }

        result := InputBox(
            "New password key name:",
            "Rename password",
            "w360 h120",
            entry["Name"]
        )

        if (result.Result != "OK")
        {
            return
        }

        name := Trim(result.Value)
        if (name = "" || name = entry["Name"])
        {
            return
        }

        if (this.EntryNameExists(this.Passwords, name, this.SelectedPasswordIndex))
        {
            MsgBox("Password key already exists: " name, "MyWinToolbox Configurator", "Iconx")
            return
        }

        entry["Name"] := name
        this.SetDirty()
        this.RefreshPasswords(this.SelectedPasswordIndex)
    }

    OnDeletePassword(*)
    {
        entry := this.GetSelectedPassword()
        if (!entry)
        {
            return
        }

        answer := MsgBox(
            "Delete password '" entry["Name"] "'?",
            "MyWinToolbox Configurator",
            "YesNo Icon!"
        )

        if (answer != "Yes")
        {
            return
        }

        oldIndex := this.SelectedPasswordIndex
        this.Passwords.RemoveAt(oldIndex)
        this.SetDirty()
        this.RefreshPasswords(Min(oldIndex, this.Passwords.Length))
    }

    OnSetPasswordPlaintext(*)
    {
        entry := this.GetSelectedPassword()
        if (!entry)
        {
            return
        }

        secret := this.SecretEdit.Value
        if (Trim(secret) = "")
        {
            MsgBox(
                "Set a profile Secret first.",
                "MyWinToolbox Configurator",
                "Iconx"
            )
            return
        }

        result := InputBox(
            "Plaintext password for '" entry["Name"] "':",
            "Set encrypted password",
            "w420 h140 Password"
        )

        if (result.Result != "OK")
        {
            return
        }

        entry["Value"] := CryptoUtils.Encrypt(result.Value, secret)
        this.SetDirty()
        this.LoadSelectedPassword()
    }

    EntryNameExists(entries, name, ignoredIndex := 0)
    {
        needle := StrLower(Trim(name))

        for index, entry in entries
        {
            if (index = ignoredIndex)
            {
                continue
            }

            if (StrLower(Trim("" entry["Name"])) = needle)
            {
                return true
            }
        }

        return false
    }

    UpdateSignatureButtons()
    {
        hasEntry := !!this.GetSelectedSignature()
        this.SignatureNameEdit.Enabled := hasEntry
        this.SignatureValueEdit.Enabled := hasEntry
        this.SignatureRenameButton.Enabled := hasEntry
        this.SignatureDeleteButton.Enabled := hasEntry
    }

    UpdatePasswordButtons()
    {
        hasEntry := !!this.GetSelectedPassword()
        this.PasswordNameEdit.Enabled := hasEntry
        this.PasswordValueEdit.Enabled := hasEntry
        this.PasswordRenameButton.Enabled := hasEntry
        this.PasswordDeleteButton.Enabled := hasEntry
        this.PasswordSetPlainButton.Enabled := hasEntry
    }
}
