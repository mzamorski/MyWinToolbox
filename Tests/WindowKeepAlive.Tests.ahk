#Requires AutoHotkey v2.0

#Include ..\Libs\WindowKeepAlive.ahk

try
{
    if (WindowKeepAlive.PulseIntervalMs != 5 * 60 * 1000)
    {
        throw Error("Unexpected KeepAlive interval.")
    }

    WindowKeepAlive.EnsureTimer()

    ; Invoke the exact function object registered with SetTimer. This catches
    ; missing hidden "this" binding on class methods without waiting for the timer.
    WindowKeepAlive.TimerCallback.Call()

    if (WindowKeepAlive.IsTimerRunning)
    {
        throw Error("KeepAlive timer should stop itself when there are no targets.")
    }
}
catch Error as e
{
    FileAppend("FAIL: WindowKeepAlive timer callback: " e.Message "`n", "**")
    ExitApp(1)
}

FileAppend("WindowKeepAlive tests passed.`n", "*")
ExitApp(0)
