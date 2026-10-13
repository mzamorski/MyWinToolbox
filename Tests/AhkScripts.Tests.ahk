#Requires AutoHotkey v2.0

#Include ..\Libs\AhkScriptManager.ahk
#Include ..\Libs\ConfiguratorSettingsTab.ahk
#Include ..\Libs\ScheduledTasksManager.ahk
#Include ..\Libs\TasksRegistry.ahk
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
    AhkScriptManager.ResolveScriptPath(root "\Games\..\Games\WARDOGS-Hammer.ahk"),
    "absolute path components should be canonicalized"
)

AssertThrows(
    () => AhkScriptManager.ResolveScriptPath("Games\WARDOGS-Hammer.ahk"),
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
    Map("Name", "Minecraft", "Value", "C:\new-tools\Minecraft.ahk")
]
AssertTrue(AhkScriptManager.ValidateEntries(entries), "valid AHK entries should pass")
AssertThrows(
    () => AhkScriptManager.ValidateEntries([
        Map("Name", "WARDOGS", "Value", expected),
        Map("Name", "wardogs", "Value", root "\Games\Minecraft.ahk")
    ]),
    "duplicate menu labels should fail case-insensitively"
)
AssertThrows(
    () => AhkScriptManager.ValidateEntries([
        Map("Name", "First", "Value", expected),
        Map("Name", "Second", "Value", "c:\repos\mywintoolbox-private\games\wardogs-hammer.ahk")
    ]),
    "duplicate script paths should fail case-insensitively"
)

for invalidPath in ["", "file.exe", "Games\file.ahk", "Games\file.ahk" Chr(34), "Games\broken" Chr(10) "file.ahk"]
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
    window := Gui()
    tasksTab := ConfiguratorTasksTab(window, doc)
    ; Deliberately interleave types: no per-type grouping on save or load.
    tasksTab.Entries := [
        Map(
            "Type", ConfiguratorTasksTab.AHK,
            "Name", entries[1]["Name"],
            "Value", entries[1]["Value"]
        ),
        Map(
            "Type", ConfiguratorTasksTab.SCHEDULER,
            "Name", "Backup",
            "Value", "\MyJobs\Backup"
        ),
        Map(
            "Type", ConfiguratorTasksTab.AHK,
            "Name", entries[2]["Name"],
            "Value", entries[2]["Value"]
        )
    ]
    AssertTrue(tasksTab.Validate(), "unified Tasks tab should validate both task types")
    tasksTab.ApplyToDocument()
    doc.SaveWithBackup()

    reloaded := ConfiguratorIniDocument(tempIni)
    savedEntries := reloaded.GetSectionEntries("Tasks", false)
    AssertEqual(3, savedEntries.Length, "both types should share one Tasks section")
    AssertEqual(entries[1]["Name"], savedEntries[1]["Name"], "AHK entry should stay first")
    AssertEqual("Backup", savedEntries[2]["Name"], "Scheduler entry should stay second")
    AssertEqual(entries[2]["Name"], savedEntries[3]["Name"], "second AHK entry stays third")
    AssertEqual(
        "ahk|" expected,
        savedEntries[1]["Value"],
        "AHK script should use an absolute path in the Tasks section"
    )
    AssertEqual(
        "scheduler|\MyJobs\Backup",
        savedEntries[2]["Value"],
        "scheduled task should be stored between AHK entries"
    )
    runtimeTasks := TasksRegistry.LoadProfile(tempIni)
    AssertEqual(3, runtimeTasks.Length, "runtime should load all Tasks from one section")
    AssertEqual("WARDOGS Hammer", runtimeTasks[1]["Name"], "runtime should keep mixed-type order")
    AssertEqual(
        "scheduler",
        TasksRegistry.Parse(
            runtimeTasks[2]["Name"], runtimeTasks[2]["Definition"]
        )["Type"],
        "runtime should dispatch the scheduler entry by its type"
    )
    AssertThrows(
        () => TasksRegistry.Parse("Broken", "C:\Tools\broken.ahk"),
        "untyped entries should be rejected rather than guessed"
    )
    AssertEqual(
        "ahk|C:\new-tools\Minecraft.ahk",
        savedEntries[3]["Value"],
        "literal \n in an absolute Windows path must not become a newline"
    )
    AssertTrue(!reloaded.HasSection("ScheduledTasks"), "no old scheduled section")
    AssertTrue(!reloaded.HasSection("AhkScripts"), "no old scripts section")
    AssertTrue(!reloaded.HasSection("AhkScriptsSettings"), "no AHK root settings")
    AssertThrows(
        () => TasksRegistry.ValidateEntries([
            Map("Name", "Backup", "Type", "scheduler", "Value", "\Tasks\Backup"),
            Map("Name", "backup", "Type", "ahk", "Value", expected)
        ]),
        "duplicate task labels must be rejected even across different types"
    )
    AssertThrows(
        () => TasksRegistry.ValidateEntries([
            Map("Name", "Future App", "Type", "exe", "Value", "C:\Tools\app.exe")
        ]),
        "unsupported future types must not be accidentally executed"
    )
    AssertEqual(
        "example@example.com",
        reloaded.Get("Settings", "Email"),
        "AHK scripts save should not overwrite profile settings"
    )

    ; A pre-unification profile should import then remove its type-specific
    ; sections when the Tasks tab is saved.
    reloaded.DeleteSection("Tasks")
    reloaded.ReplaceSectionEntries(
        "ScheduledTasks",
        [Map("Name", "Nightly", "Value", "\Maintenance\Nightly")]
    )
    reloaded.ReplaceSectionEntries(
        "AhkScripts",
        [Map("Name", "WARDOGS", "Value", expected)]
    )
    reloaded.SaveWithBackup()

    legacyDoc := ConfiguratorIniDocument(tempIni)
    legacyTab := ConfiguratorTasksTab(Gui(), legacyDoc)
    AssertTrue(legacyTab.Dirty, "legacy sections should trigger a migration save")
    AssertEqual(2, legacyTab.Entries.Length, "legacy entries should be imported")
    AssertTrue(legacyTab.Validate(), "legacy entries should convert to valid Tasks")
    legacyTab.ApplyToDocument()
    legacyDoc.SaveWithBackup()

    migrated := ConfiguratorIniDocument(tempIni)
    AssertTrue(migrated.HasSection("Tasks"), "migration should create one Tasks section")
    AssertTrue(!migrated.HasSection("ScheduledTasks"), "migration should remove scheduler section")
    AssertTrue(!migrated.HasSection("AhkScripts"), "migration should remove scripts section")
    AssertEqual(2, migrated.GetSectionEntries("Tasks").Length, "migration should preserve entries")
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
