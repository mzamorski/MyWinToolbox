#Requires AutoHotkey v2.0

#Include ..\Libs\ScheduledTasksManager.ahk
#Include ..\Libs\ConfiguratorSettingsTab.ahk
#Include ..\Libs\AhkScriptManager.ahk
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

; A COM-compatible fake lets the Run/Stop contract be tested without
; changing any real Windows Scheduled Tasks.
class FakeRegisteredTask
{
    __New(state := 3, enabled := true)
    {
        this.State := state
        this.Enabled := enabled
        this.StartCalls := 0
        this.StopCalls := 0
    }

    Run(parameters)
    {
        this.StartCalls += 1
        this.State := 4
    }

    Stop(flags)
    {
        if (flags != 0)
        {
            throw Error("Stop should use flags = 0")
        }
        this.StopCalls += 1
        this.State := 3
    }
}

class FakeTaskFolder
{
    __New(task)
    {
        this.Task := task
    }

    GetTask(name)
    {
        if (name != "Test")
        {
            throw Error("Unexpected task name: " name)
        }
        return this.Task
    }
}

class FakeSchedulerService
{
    __New(task)
    {
        this.Task := task
    }

    GetFolder(path)
    {
        if (path != "\Unit")
        {
            throw Error("Unexpected folder path: " path)
        }
        return FakeTaskFolder(this.Task)
    }
}

AssertTrue(
    ScheduledTasksManager.IsRunningState(4),
    "TASK_STATE_RUNNING should set the checkmark"
)
for inactiveState in [0, 1, 2, 3]
{
    AssertTrue(
        !ScheduledTasksManager.IsRunningState(inactiveState),
        "unknown/disabled/queued/ready task must not get a Running checkmark"
    )
}
AssertEqual("Ready", ScheduledTasksManager.GetStateLabel(3), "ready state should be labeled")
AssertEqual("Running", ScheduledTasksManager.GetStateLabel(4), "running state should be labeled")

fakeTask := FakeRegisteredTask(3, true)
fakeService := FakeSchedulerService(fakeTask)

unifiedScheduler := Map(
    "Name", "Test task",
    "Type", TasksRegistry.SCHEDULER,
    "Value", "\Unit\Test"
)
genericStatus := TasksRegistry.GetStatus(unifiedScheduler, &fakeService)
AssertTrue(
    genericStatus["CanToggle"] && !genericStatus["Running"],
    "generic Tasks handler must mark an enabled Ready scheduler task as runnable"
)
AssertTrue(
    !genericStatus.Has("SupportsScheduling")
        && !genericStatus.Has("SchedulingEnabled"),
    "Tasks status should not expose permanent scheduling toggles"
)

futureTask := Map(
    "Name", "Future executable",
    "Type", "exe",
    "Value", "C:\Tools\some-app.exe"
)
futureStatus := TasksRegistry.GetStatus(futureTask, &fakeService)
AssertTrue(
    !futureStatus["Running"] && !futureStatus["CanToggle"]
        && !futureStatus.Has("SupportsScheduling"),
    "unknown future types must be shown as unsupported, never run"
)

status := ScheduledTasksManager.GetTaskStatus(fakeService, "\Unit\Test")
AssertTrue(
    status["Enabled"] && !status["Running"],
    "an enabled but stopped task must have no running checkmark"
)
ScheduledTasksManager.SetRunning("\Unit\Test", true, fakeService)
AssertEqual(1, fakeTask.StartCalls, "Run should be called for a stopped enabled task")
AssertTrue(fakeTask.State = 4, "fake task should enter running state")

ScheduledTasksManager.SetRunning("\Unit\Test", false, fakeService)
AssertEqual(1, fakeTask.StopCalls, "Stop should be called for a running task")
AssertTrue(fakeTask.State = 3, "fake task should return to ready state")

fakeTask.Enabled := false
status := ScheduledTasksManager.GetTaskStatus(fakeService, "\Unit\Test")
AssertTrue(!status["Enabled"] && !status["Running"], "disabled task is not running")
AssertThrows(
    () => ScheduledTasksManager.SetRunning("\Unit\Test", true, fakeService),
    "start should reject disabled tasks"
)
AssertEqual(1, fakeTask.StartCalls, "disabled task should not be started")

; Disabling scheduling does not forcibly stop an already running task.
fakeTask.State := 4
status := ScheduledTasksManager.GetTaskStatus(fakeService, "\Unit\Test")
AssertTrue(
    !status["Enabled"] && status["Running"],
    "running state must remain independent from Enabled"
)
ScheduledTasksManager.SetRunning("\Unit\Test", false, fakeService)
AssertEqual(2, fakeTask.StopCalls, "running task can be stopped despite disabled scheduling")

fakeTask.Enabled := true
fakeTask.State := 2
AssertThrows(
    () => ScheduledTasksManager.SetRunning("\Unit\Test", true, fakeService),
    "queued task should not be run a second time"
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
    taskDefinitions := [
        Map(
            "Name", "Backup",
            "Type", TasksRegistry.SCHEDULER,
            "Value", "\MyJobs\NightlyBackup"
        ),
        Map(
            "Name", "Cleanup",
            "Type", TasksRegistry.SCHEDULER,
            "Value", "\Maintenance\Cleanup"
        )
    ]
    doc.ReplaceSectionEntries("Tasks", TasksRegistry.ToIniEntries(taskDefinitions), false)
    doc.SaveWithBackup()

    reloaded := ConfiguratorIniDocument(tempPath)
    saved := reloaded.GetSectionEntries("Tasks", false)
    AssertEqual(2, saved.Length, "scheduled jobs should survive save in one Tasks section")
    AssertEqual("Backup", saved[1]["Name"], "menu labels should round-trip")
    AssertEqual(
        "scheduler|\MyJobs\NightlyBackup",
        saved[1]["Value"],
        "typed scheduler path should round-trip"
    )
    AssertTrue(!reloaded.HasSection("ScheduledTasks"), "no type-specific section should be created")

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
