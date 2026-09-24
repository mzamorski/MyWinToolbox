#Requires AutoHotkey v2.0

#Include ..\Shared\TaskRunner.ahk

if (!(taskRunnerMenu is Menu))
{
	FileAppend("FAIL: Task Runner menu was not created.`n", "**")
	ExitApp(1)
}

FileAppend("TaskRunner module loaded successfully.`n", "*")
ExitApp(0)
