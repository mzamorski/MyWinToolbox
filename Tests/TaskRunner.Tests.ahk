#Requires AutoHotkey v2.0

; Simulate the Work profile setting a startup default before the module loads.
global StartupNoSleepEnabled := true

#Include ..\Shared\TaskRunner.ahk

parsedTask := TasksRegistry.Parse("Example", "ahk|C:\Tools\Example.ahk")
if (parsedTask["Type"] != TasksRegistry.AHK)
{
    FileAppend("FAIL: TaskRunner did not load TasksRegistry.`n", "**")
    ExitApp(1)
}

if (!(taskRunnerMenu is Menu))
{
	FileAppend("FAIL: Task Runner menu was not created.`n", "**")
	ExitApp(1)
}

; TaskRunner must preserve the startup setting, while giving omitted flags
; standalone defaults. Calling the module must not show #Warn dialogs.
if (!IsSet(StartupNoSleepEnabled) || !StartupNoSleepEnabled || !IsNoSleepTimerOn)
{
    FileAppend("FAIL: Work NoSleep startup default was overwritten.`n", "**")
    ExitApp(1)
}
if (!IsSet(StartupAutoPasteEnabled) || StartupAutoPasteEnabled
    || !IsSet(StartupClipboardTrimEnabled) || StartupClipboardTrimEnabled)
{
    FileAppend("FAIL: missing startup flags did not default to disabled.`n", "**")
    ExitApp(1)
}

TaskRunner_SetNoSleepEnabled(false, false)

FileAppend("TaskRunner module loaded successfully.`n", "*")
ExitApp(0)
