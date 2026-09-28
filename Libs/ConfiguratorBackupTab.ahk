#Requires AutoHotkey v2.0

class ConfiguratorBackupStore
{
    static ManifestFileName := "MyWinToolboxBackup.json"
    static ManifestVersion := 1

    static GetFileName(filePath)
    {
        return RegExReplace(filePath, "^.*[\\/]", "")
    }

    static GetDefaultBackupFolder()
    {
        return A_MyDocuments "\MyWinToolbox\Backups"
    }

    static BuildBackupPath(profileConfigPath, label := "")
    {
        profileName := ConfiguratorBackupStore.GetFileName(profileConfigPath)
        profileName := RegExReplace(profileName, "i)\.ahk\.config$", "")
        timestamp := FormatTime(A_Now, "yyyyMMdd-HHmmss")
            . "-"
            . Format("{:03}", A_MSec)
        middle := label != "" ? "-" label : ""

        return ConfiguratorBackupStore.GetDefaultBackupFolder()
            . "\MyWinToolbox-" profileName middle "-" timestamp ".zip"
    }

    static CreateBackup(filePaths, profileConfigPath, destinationPath)
    {
        if (Type(filePaths) != "Array" || filePaths.Length = 0)
        {
            throw Error("Backup requires at least one configured file path.")
        }

        destinationFolder := RegExReplace(destinationPath, "[\\/][^\\/]+$", "")
        if (destinationFolder = destinationPath)
        {
            destinationFolder := A_WorkingDir
        }

        DirCreate(destinationFolder)

        stageDir := A_Temp
            . "\MyWinToolbox-Backup-"
            . A_TickCount
            . "-"
            . Random(100000, 999999)

        DirCreate(stageDir)

        includedFiles := []

        try
        {
            for filePath in filePaths
            {
                if (!FileExist(filePath))
                {
                    continue
                }

                fileName := ConfiguratorBackupStore.GetFileName(filePath)
                FileCopy(filePath, stageDir "\" fileName, true)
                includedFiles.Push(fileName)
            }

            profileFileName := ConfiguratorBackupStore.GetFileName(
                profileConfigPath
            )

            if (!ConfiguratorBackupStore.ArrayContains(
                includedFiles,
                profileFileName
            ))
            {
                throw Error(
                    "Active profile config is missing and cannot be backed up: "
                        profileConfigPath
                )
            }

            manifest := Map(
                "Version", ConfiguratorBackupStore.ManifestVersion,
                "CreatedUtc", FormatTime(A_NowUTC, "yyyy-MM-ddTHH:mm:ssZ"),
                "ProfileConfigFile", profileFileName,
                "Files", includedFiles,
                "DpapiScope", "CurrentUser"
            )

            manifestJson := Jxon_dump(manifest, 4)
            FileAppend(
                manifestJson,
                stageDir "\" ConfiguratorBackupStore.ManifestFileName,
                "UTF-8"
            )

            if FileExist(destinationPath)
            {
                FileDelete(destinationPath)
            }

            script :=
            (
            "$ErrorActionPreference = 'Stop'`n"
            "Add-Type -AssemblyName System.IO.Compression.FileSystem`n"
            "[System.IO.Compression.ZipFile]::CreateFromDirectory("
                ConfiguratorBackupStore.PsQuote(stageDir)
                ", "
                ConfiguratorBackupStore.PsQuote(destinationPath)
                ")`n"
            )

            ConfiguratorBackupStore.RunPowerShell(script)

            if (!FileExist(destinationPath))
            {
                throw Error("Backup archive was not created.")
            }

            return destinationPath
        }
        finally
        {
            try
            {
                if DirExist(stageDir)
                {
                    DirDelete(stageDir, true)
                }
            }
        }
    }

    static ExtractAndValidate(
        archivePath,
        expectedProfileConfigPath,
        allowedTargetPaths
    )
    {
        if (!FileExist(archivePath))
        {
            throw Error("Backup archive does not exist: " archivePath)
        }

        extractDir := A_Temp
            . "\MyWinToolbox-Restore-"
            . A_TickCount
            . "-"
            . Random(100000, 999999)

        DirCreate(extractDir)

        try
        {
            manifestPath := extractDir
                . "\"
                . ConfiguratorBackupStore.ManifestFileName

            script :=
            (
            "$ErrorActionPreference = 'Stop'`n"
            "Add-Type -AssemblyName System.IO.Compression.FileSystem`n"
            "$zip = [System.IO.Compression.ZipFile]::OpenRead("
                ConfiguratorBackupStore.PsQuote(archivePath)
                ")`n"
            "try {`n"
            "  $entry = $zip.GetEntry("
                ConfiguratorBackupStore.PsQuote(
                    ConfiguratorBackupStore.ManifestFileName
                )
                ")`n"
            "  if ($null -eq $entry) { throw 'Backup manifest is missing.' }`n"
            "  [System.IO.Compression.ZipFileExtensions]::ExtractToFile("
                "$entry, "
                ConfiguratorBackupStore.PsQuote(manifestPath)
                ", $true)`n"
            "} finally { $zip.Dispose() }`n"
            )

            ConfiguratorBackupStore.RunPowerShell(script)

            if (!FileExist(manifestPath))
            {
                throw Error(
                    "This ZIP is not a MyWinToolbox backup: manifest is missing."
                )
            }

            manifestText := FileRead(manifestPath, "UTF-8")
            manifest := jxon_load(&manifestText)

            ConfiguratorBackupStore.ValidateManifest(
                manifest,
                expectedProfileConfigPath,
                allowedTargetPaths
            )

            extractScript :=
                "$ErrorActionPreference = 'Stop'`n"
                . "Add-Type -AssemblyName System.IO.Compression.FileSystem`n"
                . "$zip = [System.IO.Compression.ZipFile]::OpenRead("
                . ConfiguratorBackupStore.PsQuote(archivePath)
                . ")`n"
                . "try {`n"

            for fileName in manifest["Files"]
            {
                sourcePath := extractDir "\" fileName

                extractScript .=
                    "  $entry = $zip.GetEntry("
                    . ConfiguratorBackupStore.PsQuote(fileName)
                    . ")`n"
                    . "  if ($null -eq $entry) { throw "
                    . ConfiguratorBackupStore.PsQuote(
                        "Backup file is missing: " fileName
                    )
                    . " }`n"
                    . "  [System.IO.Compression.ZipFileExtensions]::ExtractToFile("
                    . "$entry, "
                    . ConfiguratorBackupStore.PsQuote(sourcePath)
                    . ", $true)`n"
            }

            extractScript .= "} finally { $zip.Dispose() }`n"

            ConfiguratorBackupStore.RunPowerShell(extractScript)

            restoreItems := []
            targetByName := Map()

            for targetPath in allowedTargetPaths
            {
                targetByName[
                    StrLower(ConfiguratorBackupStore.GetFileName(targetPath))
                ] := targetPath
            }

            for fileName in manifest["Files"]
            {
                sourcePath := extractDir "\" fileName
                normalizedName := StrLower(fileName)

                if (!FileExist(sourcePath))
                {
                    throw Error(
                        "Backup manifest references a missing file: " fileName
                    )
                }

                restoreItems.Push(
                    Map(
                        "Name", fileName,
                        "Source", sourcePath,
                        "Target", targetByName[normalizedName]
                    )
                )
            }

            return Map(
                "ExtractDir", extractDir,
                "Manifest", manifest,
                "Items", restoreItems
            )
        }
        catch Error as e
        {
            try
            {
                if DirExist(extractDir)
                {
                    DirDelete(extractDir, true)
                }
            }

            throw e
        }
    }

    static ValidateManifest(
        manifest,
        expectedProfileConfigPath,
        allowedTargetPaths
    )
    {
        if (!IsObject(manifest) || !(manifest is Map))
        {
            throw Error("Backup manifest must be a JSON object.")
        }

        if (
            !manifest.Has("Version")
            || manifest["Version"] != ConfiguratorBackupStore.ManifestVersion
        )
        {
            throw Error("Unsupported MyWinToolbox backup version.")
        }

        if (
            !manifest.Has("ProfileConfigFile")
            || Type(manifest["ProfileConfigFile"]) != "String"
        )
        {
            throw Error("Backup manifest is missing ProfileConfigFile.")
        }

        expectedProfileName := ConfiguratorBackupStore.GetFileName(
            expectedProfileConfigPath
        )

        if (
            StrLower(manifest["ProfileConfigFile"])
                != StrLower(expectedProfileName)
        )
        {
            throw Error(
                "Backup profile mismatch. Archive is for '"
                    manifest["ProfileConfigFile"]
                    "', but the active profile uses '"
                    expectedProfileName
                    "'."
            )
        }

        if (!manifest.Has("Files") || Type(manifest["Files"]) != "Array")
        {
            throw Error("Backup manifest Files must be an array.")
        }

        allowedNames := Map()

        for targetPath in allowedTargetPaths
        {
            fileName := ConfiguratorBackupStore.GetFileName(targetPath)
            allowedNames[StrLower(fileName)] := true
        }

        seenNames := Map()

        for fileName in manifest["Files"]
        {
            if (Type(fileName) != "String" || Trim(fileName) = "")
            {
                throw Error("Backup contains an invalid file name.")
            }

            if (
                InStr(fileName, "\")
                || InStr(fileName, "/")
                || InStr(fileName, "..")
                || ConfiguratorBackupStore.GetFileName(fileName) != fileName
            )
            {
                throw Error(
                    "Backup contains an unsafe file path: " fileName
                )
            }

            normalizedName := StrLower(fileName)

            if (!allowedNames.Has(normalizedName))
            {
                throw Error(
                    "Backup contains an unsupported configuration file: "
                        fileName
                )
            }

            if (seenNames.Has(normalizedName))
            {
                throw Error("Backup contains duplicate file: " fileName)
            }

            seenNames[normalizedName] := true
        }

        if (!seenNames.Has(StrLower(expectedProfileName)))
        {
            throw Error("Backup does not contain the active profile config.")
        }

        return true
    }

    static RestoreItems(restoreItems)
    {
        if (Type(restoreItems) != "Array" || restoreItems.Length = 0)
        {
            throw Error("Backup does not contain any restorable files.")
        }

        script := "$ErrorActionPreference = 'Stop'`n"

        for item in restoreItems
        {
            sourcePath := item["Source"]
            targetPath := item["Target"]
            tempTarget := targetPath ".restore-tmp"

            script .=
            (
            "Copy-Item -LiteralPath "
                ConfiguratorBackupStore.PsQuote(sourcePath)
                " -Destination "
                ConfiguratorBackupStore.PsQuote(tempTarget)
                " -Force`n"
            )
        }

        for item in restoreItems
        {
            targetPath := item["Target"]
            tempTarget := targetPath ".restore-tmp"

            script .=
            (
            "Move-Item -LiteralPath "
                ConfiguratorBackupStore.PsQuote(tempTarget)
                " -Destination "
                ConfiguratorBackupStore.PsQuote(targetPath)
                " -Force`n"
            )
        }

        ConfiguratorBackupStore.RunPowerShell(script, true)
    }

    static RunPowerShell(scriptContent, elevated := false)
    {
        scriptPath := A_Temp
            . "\MyWinToolbox-"
            . A_TickCount
            . "-"
            . Random(100000, 999999)
            . ".ps1"

        FileAppend(scriptContent, scriptPath, "UTF-8")

        try
        {
            powerShellPath := A_WinDir
                . "\System32\WindowsPowerShell\v1.0\powershell.exe"

            if (!FileExist(powerShellPath))
            {
                powerShellPath := "powershell.exe"
            }

            quote := Chr(34)
            command := (elevated ? "*RunAs " : "")
                . quote
                . powerShellPath
                . quote
                . " -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "
                . quote
                . scriptPath
                . quote

            exitCode := RunWait(command, , "Hide")

            if (exitCode != 0)
            {
                throw Error(
                    "PowerShell operation failed with exit code " exitCode "."
                )
            }
        }
        finally
        {
            try
            {
                if FileExist(scriptPath)
                {
                    FileDelete(scriptPath)
                }
            }
        }
    }

    static PsQuote(value)
    {
        return "'" StrReplace("" value, "'", "''") "'"
    }

    static ArrayContains(values, expected)
    {
        for value in values
        {
            if (StrLower("" value) = StrLower("" expected))
            {
                return true
            }
        }

        return false
    }
}

class ConfiguratorBackupTab
{
    __New(
        window,
        filePaths,
        profileConfigPath,
        canRestoreCallback := 0
    )
    {
        this.Window := window
        this.FilePaths := filePaths
        this.ProfileConfigPath := profileConfigPath
        this.CanRestoreCallback := canRestoreCallback
        this.BackupFolder := ConfiguratorBackupStore.GetDefaultBackupFolder()

        this.Build()
        this.RefreshFileList()
    }

    Build()
    {
        this.Window.AddGroupBox(
            "x25 y50 w1110 h555",
            "Configuration backup / restore"
        )

        this.Window.AddText(
            "x45 y82 w1040 h46",
            "Backup contains the active profile config, shared config, TextSnippets.json, "
                "HotStrings.json and AutoPastes.json. Script files and logs are not included."
        )

        this.FileList := this.Window.AddListView(
            "x45 y135 w1040 h235 -Multi",
            ["File", "Status", "Path"]
        )
        this.FileList.ModifyCol(1, 210)
        this.FileList.ModifyCol(2, 90)
        this.FileList.ModifyCol(3, 710)

        this.Window.AddText("x45 y390 w150", "Default backup folder")
        this.BackupFolderEdit := this.Window.AddEdit(
            "x45 y412 w1040 h25 ReadOnly",
            this.BackupFolder
        )

        this.CreateButton := this.Window.AddButton(
            "x45 y460 w150 h34",
            "Backup all"
        )
        this.CreateButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnCreateBackup")
        )

        this.OpenFolderButton := this.Window.AddButton(
            "x205 y460 w150 h34",
            "Open backup folder"
        )
        this.OpenFolderButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnOpenBackupFolder")
        )

        this.RestoreButton := this.Window.AddButton(
            "x375 y460 w170 h34",
            "Restore from ZIP..."
        )
        this.RestoreButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnRestoreBackup")
        )

        this.RefreshButton := this.Window.AddButton(
            "x555 y460 w110 h34",
            "Refresh"
        )
        this.RefreshButton.OnEvent(
            "Click",
            ObjBindMethod(this, "OnRefresh")
        )

        this.StatusText := this.Window.AddText(
            "x45 y515 w1040 h35",
            "Ready."
        )

        this.Window.AddText(
            "x45 y555 w1040 h42",
            "Restore first creates a safety backup of the current on-disk configuration. "
                "DPAPI password blobs work only in the Windows user context that created them."
        )
    }

    RefreshFileList()
    {
        this.FileList.Delete()

        for filePath in this.FilePaths
        {
            fileName := ConfiguratorBackupStore.GetFileName(filePath)
            exists := !!FileExist(filePath)

            this.FileList.Add(
                "",
                fileName,
                exists ? "present" : "missing",
                filePath
            )
        }
    }

    OnRefresh(*)
    {
        this.RefreshFileList()
        this.SetStatus("File status refreshed.")
    }

    OnCreateBackup(*)
    {
        try
        {
            destinationPath := ConfiguratorBackupStore.BuildBackupPath(
                this.ProfileConfigPath
            )

            this.SetStatus("Creating backup...")

            createdPath := ConfiguratorBackupStore.CreateBackup(
                this.FilePaths,
                this.ProfileConfigPath,
                destinationPath
            )

            this.SetStatus("Backup created: " createdPath)

            MsgBox(
                "Backup created successfully:`n`n" createdPath,
                "MyWinToolbox Configurator",
                "Iconi"
            )
        }
        catch Error as e
        {
            this.SetStatus("Backup failed.")

            MsgBox(
                "Unable to create backup:`n" e.Message,
                "MyWinToolbox Configurator",
                "Iconx"
            )
        }
    }

    OnOpenBackupFolder(*)
    {
        try
        {
            DirCreate(this.BackupFolder)
            Run(this.BackupFolder)
        }
        catch Error as e
        {
            MsgBox(
                "Unable to open backup folder:`n" e.Message,
                "MyWinToolbox Configurator",
                "Iconx"
            )
        }
    }

    OnRestoreBackup(*)
    {
        archivePath := FileSelect(
            1,
            this.BackupFolder,
            "Select MyWinToolbox backup",
            "ZIP archives (*.zip)"
        )

        if (archivePath = "")
        {
            return
        }

        if (
            this.CanRestoreCallback
            && !this.CanRestoreCallback.Call()
        )
        {
            return
        }

        restoreData := 0

        try
        {
            this.SetStatus("Validating backup...")

            restoreData := ConfiguratorBackupStore.ExtractAndValidate(
                archivePath,
                this.ProfileConfigPath,
                this.FilePaths
            )

            safetyBackupPath := ConfiguratorBackupStore.BuildBackupPath(
                this.ProfileConfigPath,
                "pre-restore"
            )

            ConfiguratorBackupStore.CreateBackup(
                this.FilePaths,
                this.ProfileConfigPath,
                safetyBackupPath
            )

            fileNames := []
            for item in restoreData["Items"]
            {
                fileNames.Push(item["Name"])
            }

            answer := MsgBox(
                "Restore " fileNames.Length " configuration file(s) from:`n"
                    archivePath
                    "`n`nA safety backup was created at:`n"
                    safetyBackupPath
                    "`n`nFiles in the backup will replace the matching active-profile files. "
                    "Files not present in the backup are left unchanged."
                    "`n`nContinue?",
                "Restore MyWinToolbox configuration",
                "YesNo Icon!"
            )

            if (answer != "Yes")
            {
                this.SetStatus(
                    "Restore cancelled. Safety backup was kept."
                )
                return
            }

            this.SetStatus("Restoring configuration...")

            ConfiguratorBackupStore.RestoreItems(
                restoreData["Items"]
            )

            this.SetStatus("Restore completed. Reloading MyWinToolbox...")

            MsgBox(
                "Configuration restored successfully.`n`n"
                    "MyWinToolbox will now reload.",
                "MyWinToolbox Configurator",
                "Iconi"
            )

            Reload()
        }
        catch Error as e
        {
            this.SetStatus("Restore failed.")

            MsgBox(
                "Unable to restore backup:`n" e.Message,
                "MyWinToolbox Configurator",
                "Iconx"
            )
        }
        finally
        {
            try
            {
                if (
                    restoreData
                    && restoreData.Has("ExtractDir")
                    && DirExist(restoreData["ExtractDir"])
                )
                {
                    DirDelete(restoreData["ExtractDir"], true)
                }
            }
        }
    }

    SetStatus(text)
    {
        this.StatusText.Value := text
    }
}
