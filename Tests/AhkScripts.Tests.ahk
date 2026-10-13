#Requires AutoHotkey v2.0

#Include ..\Libs\AhkScriptManager.ahk
#Include ..\Libs\ConfiguratorSettingsTab.ahk
#Include ..\Libs\ScheduledTasksManager.ahk
#Include ..\Libs\ConfiguratorTasksTab.ahk

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
    AssertTrue(expected = actual, message " | expected: " expected ", actual: " actual)
}

AssertThrows(callback, message)
{
    global TestFailures
    try
    {
        callback.Call()
    }
    catch Error
    {
        return
    }
    TestFailures.Push(message " | expected exception")
}

root := "C:\Repos\MyWinToolbox-Private"
expected := root "\Games\WARDOGS-Hammer.ahk"

AssertEqual(
    expected,
    AhkScriptManager.ResolveScriptPath(expected),
    "an absolute game script path should resolve unchanged"
)

AssertEqual(
    expected,
    AhkScriptManager.ResolveScriptPath(root "\\Games\\..\\Games\\WARDOGS-Hammer.ahk"),
    "absolute path components should be canonicalized"
)

AssertThrows(
    () => AhkScriptManager.ResolveScriptPath("Games\\WARDOGS-Hammer.ahk"),
    "relative script paths must be rejected"
)

AssertTrue(
    AhkScriptManager.MainWindowMatches(
        expected " - AutoHotkey v2.0.19",
        expected
    ),
    "AHK v2 hidden main window should match exact script path"
)
AssertTrue(
    !AhkScriptManager.MainWindowMatches(
        root "\Games\Other.ahk - AutoHotkey v2.0.19",
        expected
    ),
    "a different script should never match merely due to the same interpreter"
)
AssertTrue(
    !AhkScriptManager.MainWindowMatches(
        expected "2 - AutoHotkey v2.0.19",
        expected
    ),
    "prefix collisions must not match"
)
AssertTrue(
    AhkScriptManager.MainWindowMatches(
        StrUpper(expected) " - AutoHotkey v2.0",
        expected
    ),
    "Windows paths should match case-insensitively"
)

entries := [
    Map("Name", "WARDOGS Hammer", "Value", expected),
    Map("Name", "Minecraft", "Value", root "\\Games\\Minecraft.ahk")
]
AssertTrue(AhkScriptManager.ValidateEntries(entries), "valid AHK entries should pass")
AssertThrows(
    () => AhkScriptManager.ValidateEntries([
        Map("Name", "WARDOGS", "Value", expected),
        Map("Name", "wardogs", "Value", root "\\Games\\Minecraft.ahk")
    ]),
    "duplicate menu labels should fail case-insensitively"
)
AssertThrows(
    () => AhkScriptManager.ValidateEntries([
        Map("Name", "First", "Value", expected),
        Map("Name", "Second", "Value", "c:\\repos\\mywintoolbox-private\\games\\wardogs-hammer.ahk")
    ]),
    "duplicate script paths should fail case-insensitively"
)

for invalidPath in ["", "file.exe", "Games\\file.ahk", "Games\\file.ahk" Chr(34), "Games\\broken" Chr(10) "file.ahk"]
{
    AssertThrows(
        () => AhkScriptManager.ValidateScriptPath(invalidPath),
        "bad AHK script path should be rejected"
    )
}

tempIni := A_Temp "\MyWinToolbox-AhkScripts-" A_TickCount ".ini"

try
{
    FileAppend(
        "[Settings]" Chr(13) Chr(10)
            . "Email = example@example.com" Chr(13) Chr(10),
        tempIni,
        "UTF-8"
    )

    doc := ConfiguratorIniDocument(tempIni)
    doc.ReplaceSectionEntries("AhkScripts", entries)
    doc.SaveWithBackup()

    reloaded := ConfiguratorIniDocument(tempIni)
    savedEntries := reloaded.GetSectionEntries("AhkScripts")
    AssertEqual(2, savedEntries.Length, "two AHK scripts should survive INI save")
    AssertTrue(
        !reloaded.HasSection("AhkScriptsSettings"),
        "AHK path configuration should not require any root/settings section"
    )
    AssertEqual(
        entries[1]["Value"],
        savedEntries[1]["Value"],
        "absolute script path should round-trip"
    )
    AssertEqual(
        "example@example.com",
        reloaded.Get("Settings", "Email"),
        "AHK scripts save should not overwrite profile settings"
    )
}
catch Error as e
{
    TestFailures.Push("AHK scripts INI round-trip failed: " e.Message)
}
finally
{
    for filePath in [tempIni, tempIni ".tmp", tempIni ".bak"]
    {
        if FileExist(filePath)
        {
            FileDelete(filePath)
        }
    }
}

if (TestFailures.Length > 0)
{
    for failure in TestFailures
    {
        FileAppend("FAIL: " failure Chr(10), "**")
    }
    ExitApp(1)
}

FileAppend("AhkScripts tests passed." Chr(10), "*")
ExitApp(0)
