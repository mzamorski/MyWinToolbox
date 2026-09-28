#Requires AutoHotkey v2.0

#Include ..\Libs\Externals\_JXON.ahk
#Include ..\Libs\ConfiguratorBackupTab.ahk

global TestFailures := []

AssertTrue(condition, message)
{
    global TestFailures

    if (!condition)
    {
        TestFailures.Push(message)
    }
}

AssertEqual(expected, actual, message)
{
    AssertTrue(
        expected = actual,
        message " | expected: " expected ", actual: " actual
    )
}

AssertThrows(callback, message)
{
    global TestFailures

    try
    {
        callback.Call()
        TestFailures.Push(message " | expected an exception")
    }
    catch Error
    {
    }
}

root := A_Temp
    . "\MyWinToolbox-BackupTest-"
    . A_TickCount
    . "-"
    . Random(100000, 999999)

sourceDir := root "\source"
backupDir := root "\backups"
profilePath := sourceDir "\MyWinHome.ahk.config"
sharedPath := sourceDir "\MyWinShared.ahk.config"
snippetsPath := sourceDir "\TextSnippets.json"
hotStringsPath := sourceDir "\HotStrings.json"
autoPastesPath := sourceDir "\AutoPastes.json"
archivePath := backupDir "\test-backup.zip"

DirCreate(sourceDir)
DirCreate(backupDir)

FileAppend("[Settings] Email=test@example.com", profilePath, "UTF-8")
FileAppend("[Settings] SpacesPerIndent=4", sharedPath, "UTF-8")
FileAppend("{""Test"":[]}", snippetsPath, "UTF-8")
FileAppend("{""Version"":1,""HotStrings"":[]}", hotStringsPath, "UTF-8")
FileAppend("[]", autoPastesPath, "UTF-8")

files := [
    profilePath,
    sharedPath,
    snippetsPath,
    hotStringsPath,
    autoPastesPath
]

restoreData := 0

try
{
    createdPath := ConfiguratorBackupStore.CreateBackup(
        files,
        profilePath,
        archivePath
    )

    AssertEqual(
        archivePath,
        createdPath,
        "CreateBackup should return the archive path"
    )
    AssertTrue(
        !!FileExist(archivePath),
        "CreateBackup should create a ZIP archive"
    )

    restoreData := ConfiguratorBackupStore.ExtractAndValidate(
        archivePath,
        profilePath,
        files
    )

    AssertEqual(
        5,
        restoreData["Items"].Length,
        "Backup should restore all five present config files"
    )

    AssertEqual(
        "MyWinHome.ahk.config",
        restoreData["Manifest"]["ProfileConfigFile"],
        "Manifest should retain active profile config name"
    )

    AssertEqual(
        "CurrentUser",
        restoreData["Manifest"]["DpapiScope"],
        "Manifest should document DPAPI scope"
    )

    AssertThrows(
        () => ConfiguratorBackupStore.ValidateManifest(
            Map(
                "Version", 1,
                "ProfileConfigFile", "MyWinWork.ahk.config",
                "Files", ["MyWinWork.ahk.config"]
            ),
            profilePath,
            files
        ),
        "Restore should reject a backup from another profile"
    )

    AssertThrows(
        () => ConfiguratorBackupStore.ValidateManifest(
            Map(
                "Version", 1,
                "ProfileConfigFile", "MyWinHome.ahk.config",
                "Files", [
                    "MyWinHome.ahk.config",
                    "..\evil.config"
                ]
            ),
            profilePath,
            files
        ),
        "Restore should reject unsafe paths"
    )

    AssertThrows(
        () => ConfiguratorBackupStore.ValidateManifest(
            Map(
                "Version", 1,
                "ProfileConfigFile", "MyWinHome.ahk.config",
                "Files", [
                    "MyWinHome.ahk.config",
                    "Unknown.json"
                ]
            ),
            profilePath,
            files
        ),
        "Restore should reject unsupported file names"
    )
}
catch Error as e
{
    TestFailures.Push("backup/restore unexpected error: " e.Message)
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

    try
    {
        if DirExist(root)
        {
            DirDelete(root, true)
        }
    }
}

if (TestFailures.Length > 0)
{
    for failure in TestFailures
    {
        FileAppend("FAIL: " failure, "**")
    }

    ExitApp(1)
}

FileAppend("Configurator backup tests passed.", "*")
ExitApp(0)
