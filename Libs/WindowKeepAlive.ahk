#Requires AutoHotkey v2.0

class WindowKeepAlive
{
    static PulseIntervalMs := 5 * 60 * 1000
    static Targets := Map()
    static TimerCallback := 0
    static IsTimerRunning := false

    static ToggleWindow(hwnd)
    {
        if (!hwnd || !WinExist("ahk_id " hwnd))
        {
            throw Error("The target window no longer exists.")
        }

        if (WindowKeepAlive.Targets.Has(hwnd))
        {
            WindowKeepAlive.Targets.Delete(hwnd)
            WindowKeepAlive.StopTimerIfIdle()
            return false
        }

        processId := WinGetPID("ahk_id " hwnd)
        WindowKeepAlive.Targets[hwnd] := {
            ProcessId: processId,
            NextDelta: 1
        }

        WindowKeepAlive.EnsureTimer()
        return true
    }

    static Tick()
    {
        staleWindows := []

        for hwnd, target in WindowKeepAlive.Targets
        {
            try
            {
                if (!WinExist("ahk_id " hwnd) || WinGetPID("ahk_id " hwnd) != target.ProcessId)
                {
                    staleWindows.Push(hwnd)
                    continue
                }

                WindowKeepAlive.PulseWindow(hwnd, target)
            }
            catch Error
            {
                ; Keep the target registered. A transient activation/input failure should not
                ; silently disable KeepAlive for a still-running window.
            }
        }

        for hwnd in staleWindows
        {
            WindowKeepAlive.Targets.Delete(hwnd)
        }

        WindowKeepAlive.StopTimerIfIdle()
    }

    static PulseWindow(hwnd, target)
    {
        selector := "ahk_id " hwnd
        previousHwnd := WinExist("A")
        wasMinimized := WinGetMinMax(selector) = -1
        previousCoordMode := A_CoordModeMouse

        CoordMode("Mouse", "Screen")
        MouseGetPos(&mouseX, &mouseY)

        try
        {
            if (wasMinimized)
            {
                WinRestore(selector)
            }

            WinActivate(selector)
            if (!WinWaitActive(selector, , 2))
            {
                throw Error("Unable to activate the target window.")
            }

            ; Put the pointer inside the target without generating a large SendInput
            ; movement, then inject only a one-pixel foreground movement.
            WinGetPos(&windowX, &windowY, &windowWidth, &windowHeight, selector)
            targetX := Round(windowX + windowWidth / 2)
            targetY := Round(windowY + windowHeight / 2)
            DllCall("SetCursorPos", "Int", targetX, "Int", targetY)

            delta := target.NextDelta
            target.NextDelta := -delta

            MouseMove(delta, delta, 0, "R")
            Sleep(50)
        }
        finally
        {
            if (previousHwnd && previousHwnd != hwnd && WinExist("ahk_id " previousHwnd))
            {
                try
                {
                    WinActivate("ahk_id " previousHwnd)
                    WinWaitActive("ahk_id " previousHwnd, , 2)
                }
            }

            if (wasMinimized && WinExist(selector))
            {
                try
                {
                    WinMinimize(selector)
                }
            }

            ; Warp back without injecting a large reverse movement into the target.
            DllCall("SetCursorPos", "Int", mouseX, "Int", mouseY)
            CoordMode("Mouse", previousCoordMode)
        }
    }

    static EnsureTimer()
    {
        if (WindowKeepAlive.IsTimerRunning)
        {
            return
        }

        if (!WindowKeepAlive.TimerCallback)
        {
            WindowKeepAlive.TimerCallback := ObjBindMethod(WindowKeepAlive, "Tick")
        }

        SetTimer(WindowKeepAlive.TimerCallback, WindowKeepAlive.PulseIntervalMs)
        WindowKeepAlive.IsTimerRunning := true
    }

    static StopTimerIfIdle()
    {
        if (WindowKeepAlive.Targets.Count != 0 || !WindowKeepAlive.IsTimerRunning)
        {
            return
        }

        SetTimer(WindowKeepAlive.TimerCallback, 0)
        WindowKeepAlive.IsTimerRunning := false
    }

    static ShowToolTip(message, duration := 2000)
    {
        ToolTip(message)
        SetTimer(() => ToolTip(), -duration)
    }
}
