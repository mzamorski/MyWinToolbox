#Requires AutoHotkey v2.0

#Include ..\Libs\AhkScriptManager.ahk
#Include ..\Libs\TasksRegistry.ahk
#Include ..\Libs\Logger.ahk
#Include ..\Libs\ProcessWatcher.ahk
#Include ..\Libs\ConfiguratorSettingsTab.ahk
#Include ..\Libs\ConfiguratorProcessWatcherTab.ahk

global Failures := []

Assert(condition, message)
{
    global Failures
    if (!condition)
    {
        Failures.Push(message)
    }
}

AssertThrows(callback, message)
{
    global Failures
    try
    {
        callback.Call()
    }
    catch Error
    {
        return
    }
    Failures.Push(message " (expected error)")
}

class FakeProcessWatcher extends ProcessWatcher
{
    __New(entries)
    {
        this.TriggerRunning := false
        this.HelperRunning := false
        this.Starts := 0
        this.Stops := 0
        this.Notifications := []
        this.ClearedPids := []
        this.WindowList := []
        this.WindowTitles := Map()
        this.LastWindowsProcess := ""
        super.__New(entries)
    }

    FindProcess(name)
    {
        return this.TriggerRunning ? 42 : 0
    }

    FindProcessWindows(name)
    {
        this.LastWindowsProcess := name
        return this.WindowList
    }

    ReadWindowTitle(hwnd)
    {
        if (!this.WindowTitles.Has(hwnd))
        {
            throw Error("Window vanished while getting its title")
        }
        return this.WindowTitles[hwnd]
    }

    IsActionRunning(rule)
    {
        return this.HelperRunning
    }

    StartAction(rule)
    {
        this.Starts++
        this.HelperRunning := true
        return 1200 + this.Starts
    }

    NotifyStarted(rule, pid)
    {
        this.Notifications.Push(Map(
            "Trigger", ProcessWatcher.ToTriggerKey(
                rule["Trigger"], rule.Get("TitleContains", "")
            ),
            "Pid", pid
        ))
    }

    ForgetOwned(rule)
    {
        if (rule["OwnedPid"])
        {
            this.ClearedPids.Push(rule["OwnedPid"])
        }
        super.ForgetOwned(rule)
    }

    OpenOwnedHandle(pid)
    {
        return 0 ; no kernel handles involved in unit tests
    }

    StopAction(rule)
    {
        this.Stops++
        this.HelperRunning := false
    }
}

; Counts actual OS query boundaries without requiring running applications.
class CountingProcessWatcher extends FakeProcessWatcher
{
    __New(entries)
    {
        this.ProcessLookups := Map()
        this.WindowLookups := Map()
        this.TitleLookups := Map()
        super.__New(entries)
    }

    Count(lookups, key)
    {
        lookups[key] := lookups.Get(key, 0) + 1
    }

    FindProcess(name)
    {
        this.Count(this.ProcessLookups, StrLower(name))
        return super.FindProcess(name)
    }

    FindProcessWindows(name)
    {
        this.Count(this.WindowLookups, StrLower(name))
        return super.FindProcessWindows(name)
    }

    ReadWindowTitle(hwnd)
    {
        this.Count(this.TitleLookups, hwnd)
        return super.ReadWindowTitle(hwnd)
    }
}

class FlakyWindowEnumerationWatcher extends CountingProcessWatcher
{
    __New(entries)
    {
        this.FailNextEnumeration := true
        super.__New(entries)
    }

    FindProcessWindows(name)
    {
        if (this.FailNextEnumeration)
        {
            this.FailNextEnumeration := false
            this.Count(this.WindowLookups, StrLower(name))
            throw Error("Test window enumeration failure")
        }
        return super.FindProcessWindows(name)
    }
}

class IndependentProcessWatcher extends FakeProcessWatcher
{
    __New(entries)
    {
        this.ActivePaths := Map()
        this.StartedPaths := []
        this.StoppedPaths := []
        super.__New(entries)
    }

    IsActionRunning(rule)
    {
        return this.ActivePaths.Get(StrLower(rule["Path"]), false)
    }

    StartAction(rule)
    {
        path := StrLower(rule["Path"])
        this.StartedPaths.Push(path)
        this.ActivePaths[path] := true
        return 2000 + this.StartedPaths.Length
    }

    StopAction(rule)
    {
        path := StrLower(rule["Path"])
        this.StoppedPaths.Push(path)
        this.ActivePaths[path] := false
    }
}

class NotificationFailureWatcher extends FakeProcessWatcher
{
    NotifyStarted(rule, pid)
    {
        throw Error("Notification provider unavailable")
    }
}

class FailingProcessWatcher extends FakeProcessWatcher
{
    __New(entries)
    {
        this.FailNext := true
        super.__New(entries)
    }

    StartAction(rule)
    {
        if (this.FailNext)
        {
            this.FailNext := false
            this.Starts++
            throw Error("Expected helper launch failure")
        }
        return super.StartAction(rule)
    }
}

iniEntries := [
    Map("Name", "Game.exe", "Value", "ahk|C:\Tools\GameHelper.ahk|stop"),
    Map("Name", "ShareX.exe", "Value", "exe|notepad.exe|run")
]
rules := ProcessWatcher.FromIniEntries(iniEntries)
Assert(rules.Length = 2, "two watchers should load")
Assert(rules[1]["Mode"] = ProcessWatcher.STOP, "stop policy should parse")
Assert(rules[2]["Mode"] = ProcessWatcher.RUN, "run policy should parse")
saved := ProcessWatcher.ToIniEntries(rules)
Assert(saved[1]["Value"] = iniEntries[1]["Value"], "AHK rule should round-trip")
Assert(saved[2]["Value"] = iniEntries[2]["Value"], "short-name EXE run rule should round-trip")

; 'keep' remains an input alias, but is never written by the Configurator.
legacy := ProcessWatcher.FromIniEntries([
    Map("Name", "Legacy.exe", "Value", "exe|notepad.exe|keep")
])
Assert(legacy[1]["Mode"] = ProcessWatcher.RUN,
    "legacy keep means run (leave helper running)")
Assert(
    ProcessWatcher.ToIniEntries(legacy)[1]["Value"] = "exe|notepad.exe|run",
    "saving an old keep entry should write run"
)

ensureRule := ProcessWatcher.FromIniEntries([
    Map("Name", "ScreenCapture.exe", "Value", "exe|notepad.exe|ensure")
])[1]
Assert(ensureRule["Mode"] = ProcessWatcher.ENSURE,
    "ensure mode must parse")
Assert(ProcessWatcher.ToIniEntries([ensureRule])[1]["Value"] = "exe|notepad.exe|ensure",
    "ensure mode must round-trip without changing its meaning")
ahkEnsure := ProcessWatcher.FromIniEntries([
    Map("Name", "Game2.exe", "Value", "ahk|C:\Tools\Helper.ahk|ensure")
])
Assert(ahkEnsure[1]["Mode"] = ProcessWatcher.ENSURE,
    "ensure should work for AHK helpers too")
Assert(ProcessWatcher.ToIniEntries(ahkEnsure)[1]["Value"]
    = "ahk|C:\Tools\Helper.ahk|ensure",
    "AHK ensure rule must round-trip")

; A window-title filter is an optional part of the source trigger, not
; part of the helper specification. Existing process-only keys stay intact.
windowEntries := [
    Map("Name", "GeForceNOW.exe::Watch_Dogs 2",
        "Value", "exe|notepad.exe|stop"),
    Map("Name", "GeForceNOW.exe::Cyberpunk",
        "Value", "exe|notepad.exe|ensure"),
    Map("Name", "ShareX.exe", "Value", "exe|notepad.exe|run")
]
windowRules := ProcessWatcher.FromIniEntries(windowEntries)
Assert(windowRules.Length = 3,
    "different title filters must be permitted for the same source process")
Assert(windowRules[1]["Trigger"] = "GeForceNOW.exe"
    && windowRules[1]["TitleContains"] = "Watch_Dogs 2",
    "window-title rule should parse executable and title fragment")
Assert(windowRules[2]["TitleContains"] = "Cyberpunk",
    "multiple title fragments for one executable should be independent")
Assert(windowRules[3]["TitleContains"] = "",
    "legacy process-only rules must have an empty title filter")
windowSaved := ProcessWatcher.ToIniEntries(windowRules)
Assert(windowSaved[1]["Name"] = "GeForceNOW.exe::Watch_Dogs 2"
    && windowSaved[2]["Name"] = "GeForceNOW.exe::Cyberpunk",
    "window-filter rule keys should round-trip")
Assert(windowSaved[3]["Name"] = "ShareX.exe",
    "process-only rule names must retain their original serialization")
Assert(
    ProcessWatcher.LaunchNotificationMessage(windowRules[1])
        = "Started: notepad.exe" Chr(10) "Trigger: GeForceNOW.exe::Watch_Dogs 2",
    "launch notification should include helper name and window-title trigger"
)
Assert(
    ProcessWatcher.LaunchNotificationMessage(rules[1])
        = "Started: GameHelper.ahk" Chr(10) "Trigger: Game.exe",
    "AHK notification should show script name and a process-only trigger"
)
AssertThrows(
    () => ProcessWatcher.FromIniEntries([
        Map("Name", "GeForceNOW.exe::Watch_Dogs", "Value", "exe|notepad.exe|run"),
        Map("Name", "geforcenow.EXE::watch_dogs", "Value", "exe|NOTEPAD.exe|stop")
    ]),
    "the same helper on the same title must not be registered twice"
)
AssertThrows(
    () => ProcessWatcher.FromIniEntries([
        Map("Name", "GeForceNOW.exe::", "Value", "exe|notepad.exe|run")
    ]),
    "an explicitly configured empty title fragment should fail"
)
AssertThrows(
    () => ProcessWatcher.ToTriggerKey("GeForceNOW.exe", "a=b"),
    "unrepresentable title filter containing INI separator should fail"
)

; Multiple helpers with the EXACT same trigger are independent rules.
; The INI reader and Configurator intentionally preserve repeated key lines.
multiEntries := [
    Map("Name", "GeForceNOW.exe::WARDOGS",
        "Value", "ahk|C:\Tools\WARDOGS-Hammer.ahk|stop"),
    Map("Name", "geforcenow.EXE::wardogs",
        "Value", "ahk|C:\Tools\WARDOGS-Dodge.ahk|run"),
    Map("Name", "GeForceNOW.exe::WARDOGS",
        "Value", "ahk|C:\Tools\WARDOGS-Run.ahk|ensure")
]
multiRules := ProcessWatcher.FromIniEntries(multiEntries)
Assert(multiRules.Length = 3,
    "multiple distinct helpers must be accepted on one process/title trigger")
multiSaved := ProcessWatcher.ToIniEntries(multiRules)
Assert(multiSaved.Length = 3
    && multiSaved[1]["Name"] = multiSaved[3]["Name"]
    && multiSaved[1]["Value"] != multiSaved[3]["Value"],
    "different helpers on identical keys must be preserved in INI serialization")
Assert(InStr(ConfiguratorProcessWatcherTab.EntryLabel(multiRules[1]),
        "WARDOGS-Hammer.ahk (stop)")
    && InStr(ConfiguratorProcessWatcherTab.EntryLabel(multiRules[2]),
        "WARDOGS-Dodge.ahk (run)"),
    "Configurator list must distinguish entries with the same trigger")
AssertThrows(
    () => ProcessWatcher.ValidateEntries([multiRules[1], multiRules[1]]),
    "a repeated helper on the same trigger must still be rejected"
)

multiWatcher := IndependentProcessWatcher(multiRules)
multiWatcher.WindowList := [123]
multiWatcher.WindowTitles[123] := "WARDOGS via GeForce NOW"
multiWatcher.Tick()
Assert(multiWatcher.StartedPaths.Length = 3
    && multiWatcher.Notifications.Length = 3,
    "all three helpers must start and notify independently")
Assert(multiWatcher.Rules[1]["OwnedPid"] != multiWatcher.Rules[2]["OwnedPid"]
    && multiWatcher.Rules[2]["OwnedPid"] != multiWatcher.Rules[3]["OwnedPid"],
    "helpers must keep distinct owned process IDs")
multiWatcher.Tick()
Assert(multiWatcher.StartedPaths.Length = 3,
    "shared trigger must not start any duplicate helpers on subsequent polls")
runPath := StrLower(multiRules[3]["Path"])
multiWatcher.ActivePaths[runPath] := false
multiWatcher.Tick()
Assert(multiWatcher.StartedPaths.Length = 4
    && multiWatcher.StartedPaths[4] = runPath,
    "ensure must restart only its own helper when it closes")
multiWatcher.WindowList := []
multiWatcher.Tick()
Assert(multiWatcher.StoppedPaths.Length = 1
    && multiWatcher.StoppedPaths[1] = StrLower(multiRules[1]["Path"]),
    "only stop-policy helper must close when the common trigger disappears")
Assert(multiWatcher.ActivePaths[StrLower(multiRules[2]["Path"])]
    && multiWatcher.ActivePaths[StrLower(multiRules[3]["Path"])],
    "run and ensure helpers must remain running on trigger disappearance")
multiWatcher.Shutdown()
Assert(multiWatcher.StoppedPaths.Length = 1,
    "shutdown must not stop run/ensure helpers from the shared trigger")

; Short EXE names must go straight to Windows, not through FileExist or
; an incorrectly inferred working directory.
Assert(
    ProcessWatcher.ValidatePath("exe", "notepad.exe") = "notepad.exe",
    "short executable names should be accepted"
)
shortSpec := ProcessWatcher.BuildLaunchSpec(rules[2])
Assert(shortSpec["Command"] = "notepad.exe", "short EXE should use Run notepad.exe")
Assert(shortSpec["WorkingDir"] = "", "short EXE should have no forced working directory")
Assert(!shortSpec["RequiresFile"], "short EXE must not need a FileExist precheck")

absoluteExe := ProcessWatcher.FromIniEntries([
    Map("Name", "Other.exe", "Value", "exe|E:\Utils\EditorHelper.exe|run")
])[1]
fullSpec := ProcessWatcher.BuildLaunchSpec(absoluteExe)
Assert(fullSpec["Command"] = Chr(34) "E:\Utils\EditorHelper.exe" Chr(34),
    "absolute EXE command must be quoted")
Assert(fullSpec["WorkingDir"] = "E:\Utils", "absolute EXE should use its parent folder")
Assert(fullSpec["RequiresFile"], "absolute EXE must still validate file existence")
Assert(
    ProcessWatcher.ValidatePath("ahk", "C:\Tools\GameHelper.ahk")
        = "C:\Tools\GameHelper.ahk",
    "AHK scripts still require absolute paths"
)
AssertThrows(
    () => ProcessWatcher.ValidatePath("exe", "Tools\notepad.exe"),
    "relative EXE paths must still be rejected"
)
AssertThrows(
    () => ProcessWatcher.ValidatePath("exe", "..\notepad.exe"),
    "parent-relative EXE paths must be rejected"
)

AssertThrows(
    () => ProcessWatcher.FromIniEntries([
        Map("Name", "game.exe", "Value", "ahk|C:\Tools\one.ahk|stop"),
        Map("Name", "GAME.EXE", "Value", "ahk|c:\tools\ONE.ahk|run")
    ]),
    "duplicate actions must fail case-insensitively despite different modes"
)
AssertThrows(
    () => ProcessWatcher.FromIniEntries([
        Map("Name", "Game.exe", "Value", "ahk|relative\helper.ahk|stop")
    ]),
    "relative helper paths must be rejected"
)
AssertThrows(
    () => ProcessWatcher.FromIniEntries([
        Map("Name", "Game.exe", "Value", "exe|C:\Tools\helper.exe|maybe")
    ]),
    "unknown stop policies must be rejected"
)
AssertThrows(
    () => ProcessWatcher.FromIniEntries([
        Map("Name", "C:\Game.exe", "Value", "ahk|C:\Tools\helper.ahk|stop")
    ]),
    "the watched executable must be a basename"
)
AssertThrows(
    () => ProcessWatcher.FromIniEntries([
        Map("Name", "Game.exe", "Value", "bat|C:\Tools\helper.bat|stop")
    ]),
    "unsupported action types must be rejected"
)

watcher := FakeProcessWatcher([rules[1]])
watcher.Tick()
Assert(watcher.Starts = 0, "nothing starts before trigger")
Assert(watcher.Notifications.Length = 0, "no notification before helper launch")
watcher.TriggerRunning := true
watcher.Tick()
watcher.Tick()
Assert(watcher.Starts = 1, "helper starts only once while trigger is present")
Assert(watcher.Notifications.Length = 1
    && watcher.Notifications[1]["Pid"] = 1201,
    "stop mode should notify exactly once after a successful launch")
watcher.TriggerRunning := false
watcher.Tick()
watcher.Tick()
Assert(watcher.Stops = 1, "helper stops once after trigger disappears")
watcher.TriggerRunning := true
watcher.Tick()
Assert(watcher.Starts = 2, "new process appearance starts another helper")
watcher.Shutdown()
Assert(watcher.Stops = 2, "watcher shutdown cleans up its owned helper")

; Detect title fragments only in windows belonging to the source EXE.
; The source may be running without any matching game window, and focus is
; irrelevant. Changing to another game must be treated like source departure.
titleWatcher := FakeProcessWatcher([windowRules[1]])
titleWatcher.TriggerRunning := true
titleWatcher.WindowList := [11, 12]
titleWatcher.WindowTitles[11] := "GeForce NOW"
titleWatcher.WindowTitles[12] := "Watch_Dogs 2 on GeForce NOW"
titleWatcher.Tick()
Assert(titleWatcher.Starts = 1, "matching game title should launch its helper")
Assert(titleWatcher.Notifications.Length = 1
    && titleWatcher.Notifications[1]["Trigger"]
        = "GeForceNOW.exe::Watch_Dogs 2",
    "window-title trigger should be included in launch notification")
Assert(titleWatcher.LastWindowsProcess = "GeForceNOW.exe",
    "window filter must request only windows belonging to configured EXE")
titleWatcher.Tick()
Assert(titleWatcher.Starts = 1, "matched game should not launch a duplicate")
titleWatcher.WindowTitles[12] := "Cyberpunk on GeForce NOW"
titleWatcher.Tick()
Assert(titleWatcher.Stops = 1,
    "stop should close owned helper when window title stops matching")
titleWatcher.WindowTitles[12] := "watch_dogs 2 ON GEFORCE NOW"
titleWatcher.Tick()
Assert(titleWatcher.Starts = 2, "title matching should ignore letter case")
titleWatcher.WindowList := []
titleWatcher.Tick()
Assert(titleWatcher.Stops = 2, "no matching windows should stop source condition")
titleWatcher.WindowList := [99]
titleWatcher.Tick()
Assert(titleWatcher.Starts = 2,
    "vanished window during title read should be safely ignored")

titleEnsure := FakeProcessWatcher([windowRules[2]])
titleEnsure.WindowList := [10]
titleEnsure.WindowTitles[10] := "Cyberpunk on GeForce NOW"
titleEnsure.Tick()
Assert(titleEnsure.Starts = 1, "ensure launches on matching game title")
titleEnsure.HelperRunning := false
titleEnsure.Tick()
Assert(titleEnsure.Starts = 2,
    "ensure restarts a closed helper while matching game window exists")
titleEnsure.WindowTitles[10] := "GeForce NOW launcher"
titleEnsure.Tick()
titleEnsure.HelperRunning := false
titleEnsure.Tick()
Assert(titleEnsure.Starts = 2,
    "ensure should not restart after game title stops matching")

runOnly := FakeProcessWatcher([rules[2]])
runOnly.TriggerRunning := true
runOnly.Tick()
runOnly.HelperRunning := false
runOnly.Tick()
runOnly.Tick()
Assert(runOnly.Starts = 1, "run must not restart a closed helper while trigger runs")
Assert(runOnly.Notifications.Length = 1,
    "run mode should notify once and not on each poll")
runOnly.TriggerRunning := false
runOnly.Tick()
Assert(runOnly.Starts = 1 && runOnly.Stops = 0, "run policy does not stop helper")

ensured := FakeProcessWatcher([ensureRule])
ensured.Tick()
Assert(ensured.Starts = 0, "ensure must not start before trigger")
ensured.TriggerRunning := true
ensured.Tick()
Assert(ensured.Starts = 1, "ensure launches when trigger appears")
ensured.Tick()
Assert(ensured.Starts = 1, "ensure must not launch duplicates while helper runs")
ensured.HelperRunning := false
ensured.Tick()
Assert(ensured.Starts = 2, "ensure restarts a manually closed helper on next poll")
Assert(ensured.Notifications.Length = 2,
    "ensure mode should notify again after a real helper restart")
Assert(ensured.ClearedPids.Length = 1 && ensured.ClearedPids[1] = 1201,
    "ensure must release the former instance's tracked PID before restart")
ensured.Tick()
Assert(ensured.Starts = 2, "ensure must not launch duplicates after restart")
ensured.TriggerRunning := false
ensured.Tick()
Assert(ensured.Stops = 0, "ensure must leave helper running when trigger exits")
ensured.HelperRunning := false
ensured.Tick()
Assert(ensured.Starts = 2, "ensure must not relaunch while trigger is absent")
ensured.TriggerRunning := true
ensured.Tick()
Assert(ensured.Starts = 3, "ensure should launch again after trigger returns")
ensured.Shutdown()
Assert(ensured.Stops = 0, "ensure never stops owned helpers on shutdown")

failedEnsure := FailingProcessWatcher([ensureRule])
failedEnsure.TriggerRunning := true
failedEnsure.Tick()
Assert(failedEnsure.Starts = 1, "ensure should attempt initial launch")
Assert(failedEnsure.Notifications.Length = 0,
    "failed launches must not cause misleading start notifications")
Loop ProcessWatcher.FailedLaunchSkipTicks
{
    failedEnsure.Tick()
}
Assert(failedEnsure.Starts = 1,
    "ensure should delay repeated launches after an error")
failedEnsure.Tick()
Assert(failedEnsure.Starts = 2,
    "ensure should retry after a failed-launch cooldown")
failedEnsure.HelperRunning := false
failedEnsure.Tick()
Assert(failedEnsure.Starts = 3,
    "successful ensure restart must not inherit failure cooldown")

existingEnsure := FakeProcessWatcher([ensureRule])
existingEnsure.TriggerRunning := true
existingEnsure.HelperRunning := true
existingEnsure.Tick()
existingEnsure.Tick()
Assert(existingEnsure.Starts = 0, "ensure must not adopt or duplicate external helpers")
Assert(existingEnsure.Notifications.Length = 0,
    "already-running external helpers should not produce a notification")
existingEnsure.HelperRunning := false
existingEnsure.Tick()
Assert(existingEnsure.Starts = 1, "ensure must recover after external helper exits")
existingEnsure.TriggerRunning := false
existingEnsure.Tick()
Assert(existingEnsure.Stops = 0, "ensure must not close the recovered helper")



notificationFailure := NotificationFailureWatcher([rules[2]])
notificationFailure.TriggerRunning := true
notificationFailure.Tick()
Assert(notificationFailure.Starts = 1,
    "failed notification should not interrupt the running helper")
Assert(notificationFailure.Rules[1]["OwnedPid"] = 1201,
    "failed notification should preserve ownership tracking")
notificationFailure.Tick()
Assert(notificationFailure.Starts = 1,
    "failed notification should not trigger a duplicate run")

external := FakeProcessWatcher([rules[1]])
external.TriggerRunning := true
external.HelperRunning := true
external.Tick()
external.TriggerRunning := false
external.Tick()
Assert(external.Starts = 0 && external.Stops = 0,
    "an already-running helper is never adopted or stopped")

; Multiple independent title filters on the same executable must share
; Windows lookups within ONE tick but not between subsequent 3-second polls.
cacheRules := ProcessWatcher.FromIniEntries([
    Map("Name", "GeForceNOW.exe::Watch_Dogs",
        "Value", "exe|notepad.exe|run"),
    Map("Name", "geforcenow.EXE::Cyberpunk",
        "Value", "exe|notepad.exe|ensure"),
    Map("Name", "GEFORCENOW.exe::Missing",
        "Value", "exe|notepad.exe|stop"),
    Map("Name", "GeForceNOW.exe",
        "Value", "exe|notepad.exe|run")
])
cachedWatcher := CountingProcessWatcher(cacheRules)
cachedWatcher.TriggerRunning := true
cachedWatcher.HelperRunning := true ; do not launch helpers in this test
cachedWatcher.WindowList := [11, 12]
cachedWatcher.WindowTitles[11] := "GeForce NOW launcher"
cachedWatcher.WindowTitles[12] := "Cyberpunk - GeForce NOW"
cachedWatcher.Tick()
Assert(cachedWatcher.WindowLookups["geforcenow.exe"] = 1,
    "title-filtered rules should enumerate one EXE's windows only once per tick")
Assert(cachedWatcher.TitleLookups[11] = 1 && cachedWatcher.TitleLookups[12] = 1,
    "different title fragments should reuse the same successful title reads")
Assert(cachedWatcher.ProcessLookups["geforcenow.exe"] = 1,
    "process-only rule should use one ProcessExist call per tick")
Assert(!cachedWatcher.Rules[1]["WasPresent"]
    && cachedWatcher.Rules[2]["WasPresent"]
    && !cachedWatcher.Rules[3]["WasPresent"]
    && cachedWatcher.Rules[4]["WasPresent"],
    "each rule should evaluate its own title filter despite sharing a snapshot")

cachedWatcher.WindowTitles[12] := "Watch_Dogs - GeForce NOW"
cachedWatcher.Tick()
Assert(cachedWatcher.WindowLookups["geforcenow.exe"] = 2
    && cachedWatcher.TitleLookups[11] = 2
    && cachedWatcher.TitleLookups[12] = 2
    && cachedWatcher.ProcessLookups["geforcenow.exe"] = 2,
    "all discovery caches must expire between successive ticks")
Assert(cachedWatcher.Rules[1]["WasPresent"]
    && !cachedWatcher.Rules[2]["WasPresent"]
    && cachedWatcher.Rules[4]["WasPresent"],
    "changing a window title must switch matching rules on the very next tick")

cachedWatcher.TriggerRunning := false
cachedWatcher.WindowList := []
cachedWatcher.Tick()
Assert(cachedWatcher.WindowLookups["geforcenow.exe"] = 3
    && cachedWatcher.ProcessLookups["geforcenow.exe"] = 3,
    "window and process absence must be refreshed on the next tick")
Assert(!cachedWatcher.Rules[1]["WasPresent"]
    && !cachedWatcher.Rules[2]["WasPresent"]
    && !cachedWatcher.Rules[4]["WasPresent"],
    "previous matching states must be cleared when triggers disappear")

; A window that vanishes during title lookup must not poison cache results.
vanishingWatcher := CountingProcessWatcher(cacheRules)
vanishingWatcher.WindowList := [77]
vanishingWatcher.Tick()
Assert(vanishingWatcher.WindowLookups["geforcenow.exe"] = 1,
    "even when titles cannot be read, window enumeration is shared")
Assert(vanishingWatcher.TitleLookups[77] = 3,
    "failed title reads should not be cached across independent rules")
vanishingWatcher.WindowTitles[77] := "Watch_Dogs"
vanishingWatcher.Tick()
Assert(vanishingWatcher.Rules[1]["WasPresent"],
    "a previously unreadable window must be considered on the next poll")

; A failed WinGetList must not be cached: later rules may succeed.
flakyWatcher := FlakyWindowEnumerationWatcher(cacheRules)
flakyWatcher.WindowList := [88]
flakyWatcher.WindowTitles[88] := "Cyberpunk"
flakyWatcher.HelperRunning := true
flakyWatcher.Tick()
Assert(flakyWatcher.WindowLookups["geforcenow.exe"] = 2,
    "after enumeration fails, a later rule should retry instead of reusing failure")
Assert(flakyWatcher.Rules[2]["WasPresent"],
    "a later title rule should still recognize its trigger after a transient error")

; Integrate the GUI editor with the shared profile INI document.
tempIni := A_Temp "\MyWinToolbox-ProcessWatcher-" A_TickCount ".ini"
try
{
    FileAppend("[Settings]" Chr(13) Chr(10) "Email=test@example.com" Chr(13) Chr(10),
        tempIni, "UTF-8")
    doc := ConfiguratorIniDocument(tempIni)
    tab := ConfiguratorProcessWatcherTab(Gui(), doc)
    tab.Entries := [rules[1], rules[2], ensureRule, windowRules[1], windowRules[2]]
    Assert(tab.Validate(), "valid watcher rules should pass Configurator validation")
    tab.ApplyToDocument()
    doc.SaveWithBackup()

    reloaded := ConfiguratorIniDocument(tempIni)
    entries := reloaded.GetSectionEntries("ProcessWatcher", false)
    Assert(entries.Length = 5,
        "process-only and title-filtered rules should persist together")
    Assert(entries[1]["Value"] = iniEntries[1]["Value"], "INI file must preserve backslashes")
    Assert(entries[2]["Value"] = "exe|notepad.exe|run",
        "Configurator INI save must preserve canonical run and the short EXE name")
    Assert(entries[3]["Value"] = "exe|notepad.exe|ensure",
        "Configurator INI save must preserve ensure mode")
    Assert(entries[4]["Name"] = "GeForceNOW.exe::Watch_Dogs 2"
        && entries[5]["Name"] = "GeForceNOW.exe::Cyberpunk",
        "Configurator INI save must preserve distinct game title filters")
    Assert(reloaded.Get("Settings", "Email") = "test@example.com",
        "watcher save must preserve unrelated settings")

    ; Duplicate key lines must survive Configurator -> INI -> loader.
    tab.Entries := multiRules
    Assert(tab.Validate(), "Configurator should accept several helpers per trigger")
    tab.ApplyToDocument()
    doc.SaveWithBackup()
    repeated := ConfiguratorIniDocument(tempIni)
    repeatedEntries := repeated.GetSectionEntries("ProcessWatcher", false)
    Assert(repeatedEntries.Length = 3
        && repeatedEntries[1]["Name"] = repeatedEntries[3]["Name"]
        && repeatedEntries[1]["Value"] != repeatedEntries[3]["Value"],
        "Configurator must persist multiple helpers using the same INI key")
    Assert(ProcessWatcher.FromIniEntries(
        TasksRegistry.ReadRawSection(tempIni, "ProcessWatcher")).Length = 3,
        "startup raw INI reader must load all helpers with identical triggers")
}
catch Error as e
{
    Failures.Push("INI editor round-trip: " e.Message " / " e.Line)
}
finally
{
    for suffix in ["", ".bak"]
    {
        try FileDelete(tempIni suffix)
    }
}
if (Failures.Length)
{
    for message in Failures
    {
        FileAppend("FAIL: " message Chr(10), "**")
    }
    ExitApp(1)
}
FileAppend("ProcessWatcher tests passed." Chr(10), "*")
ExitApp(0)
