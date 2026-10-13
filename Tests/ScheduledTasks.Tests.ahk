#Requires AutoHotkey v2.0

#Include ..\Libs\ScheduledTasksManager.ahk
#Include ..\Libs\ConfiguratorSettingsTab.ahk
#Include ..\Libs\ConfiguratorScheduledTasksTab.ahk

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

AssertEqual(
    "\Maintenance\Cleanup",
    ScheduledTasksManager.NormalizePath("Maintenance\Cleanup"),
    "relative path should become an absolute Task Scheduler path"
)
AssertEqual(
    "\RootTask",
    ScheduledTasksManager.NormalizePath("\RootTask"),
    "root task path should be unchanged"
)

for badPath in ["", "\", "\Broken\", "\Double\\Separator", "Bad/Task", "Bad" Chr(34) "Task"]
{
    AssertThrows(
        () => ScheduledTasksManager.NormalizePath(badPath),
        "invalid task path should be rejected"
    )
}

validTasks := [
    Map("Name", "Backup", "Value", "\MyJobs\NightlyBackup"),
    Map("Name", "Cleanup", "Value", "\Maintenance\Cleanup")
]
AssertTrue(
    ScheduledTasksManager.ValidateEntries(validTasks),
    "two distinct scheduled tasks should be accepted"
)

AssertThrows(
    () => ScheduledTasksManager.ValidateEntries([
        Map("Name", "Backup", "Value", "\First"),
        Map("Name", "backup", "Value", "\Second")
    ]),
    "duplicate labels should be rejected case-insensitively"
)
AssertThrows(
    () => ScheduledTasksManager.ValidateEntries([
        Map("Name", "First", "Value", "\MyTask"),
        Map("Name", "Second", "Value", "mytask")
    ]),
    "duplicate paths should be rejected case-insensitively"
)
AssertThrows(
    () => ScheduledTasksManager.ValidateEntries([
        Map("Name", "Bad=Name", "Value", "\MyTask")
    ]),
    "INI-breaking menu labels should be rejected"
)

tempPath := A_Temp "\MyWinToolbox-ScheduledTasks-" A_TickCount ".ini"
try
{
    FileAppend(
        "[Settings]" Chr(13) Chr(10)
            . "Email = user@example.com" Chr(13) Chr(10),
        tempPath,
        "UTF-8"
    )

    doc := ConfiguratorIniDocument(tempPath)
    doc.ReplaceSectionEntries("ScheduledTasks", validTasks)
    doc.SaveWithBackup()

    reloaded := ConfiguratorIniDocument(tempPath)
    saved := reloaded.GetSectionEntries("ScheduledTasks")
    AssertEqual(2, saved.Length, "scheduled task entries should survive an INI save")
    AssertEqual("Backup", saved[1]["Name"], "menu labels should round-trip")
    AssertEqual("\MyJobs\NightlyBackup", saved[1]["Value"], "task paths should round-trip")
    AssertEqual(
        "user@example.com",
        reloaded.Get("Settings", "Email"),
        "scheduled task configuration should preserve other INI settings"
    )
}
catch Error as e
{
    TestFailures.Push("ScheduledTasks INI round-trip: " e.Message)
}
finally
{
    for path in [tempPath, tempPath ".bak", tempPath ".tmp"]
    {
        if FileExist(path)
        {
            FileDelete(path)
        }
    }
}

if (TestFailures.Length)
{
    for failure in TestFailures
    {
        FileAppend("FAIL: " failure Chr(10), "**")
    }
    ExitApp(1)
}

FileAppend("ScheduledTasks tests passed." Chr(10), "*")
ExitApp(0)
