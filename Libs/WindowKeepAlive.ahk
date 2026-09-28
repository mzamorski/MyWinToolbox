#Requires AutoHotkey v2.0

class WindowKeepAlive
{
    static WM_MOUSEMOVE := 0x0200
    static PulseIntervalMs := 60000
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
            NextCoordinate: 1
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

                coordinate := target.NextCoordinate
                target.NextCoordinate := (coordinate = 1) ? 2 : 1

                lParam := WindowKeepAlive.MakeLParam(coordinate, coordinate)
                PostMessage(WindowKeepAlive.WM_MOUSEMOVE, 0, lParam, , "ahk_id " hwnd)
            }
            catch Error
            {
                ; Keep the target registered. A transient access/message failure should not
                ; silently disable KeepAlive for a still-running window.
            }
        }

        for hwnd in staleWindows
        {
            WindowKeepAlive.Targets.Delete(hwnd)
        }

        WindowKeepAlive.StopTimerIfIdle()
    }

    static MakeLParam(x, y)
    {
        return (x & 0xFFFF) | ((y & 0xFFFF) << 16)
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
