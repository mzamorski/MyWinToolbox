#Requires AutoHotkey v2.0

class WindowToolbox
{
    static Show(onCaptureAutoPaste := 0)
    {
        hwnd := WinExist("A")
        if (!hwnd)
        {
            return
        }

        try
        {
            if (!WindowApp.IsRealWindow(hwnd))
            {
                return
            }
        }
        catch Error
        {
            return
        }

        windowMenu := Menu()
        windowMenu.SetColor("d9e8fb")

        header := WindowToolbox.GetWindowLabel(hwnd)
        windowMenu.Add(header, ObjBindMethod(WindowToolbox, "NoOp"))
        windowMenu.Disable(header)
        windowMenu.Add()

        alwaysOnTopLabel := "Always on top"
        windowMenu.Add(
            alwaysOnTopLabel,
            WindowToolbox.ToggleAlwaysOnTop.Bind(hwnd)
        )

        if (WindowToolbox.IsAlwaysOnTop(hwnd))
        {
            windowMenu.Check(alwaysOnTopLabel)
        }

        keepAliveLabel := "KeepAlive"
        windowMenu.Add(
            keepAliveLabel,
            WindowToolbox.ToggleKeepAlive.Bind(hwnd)
        )

        if (WindowKeepAlive.Targets.Has(hwnd))
        {
            windowMenu.Check(keepAliveLabel)
        }

        windowMenu.Add(
            "Toggle process mute",
            WindowToolbox.ToggleMute.Bind(hwnd)
        )

        moveMenu := Menu()
        moveMenu.Add("Center", WindowToolbox.Center.Bind(hwnd))
        moveMenu.Add()
        moveMenu.Add("Left third", WindowToolbox.MoveThird.Bind(hwnd, 1))
        moveMenu.Add("Middle third", WindowToolbox.MoveThird.Bind(hwnd, 2))
        moveMenu.Add("Right third", WindowToolbox.MoveThird.Bind(hwnd, 3))

        if (MonitorGetCount() > 1)
        {
            moveMenu.Add()
            moveMenu.Add(
                "Previous monitor",
                WindowToolbox.MoveMonitor.Bind(hwnd, -1)
            )
            moveMenu.Add(
                "Next monitor",
                WindowToolbox.MoveMonitor.Bind(hwnd, 1)
            )
        }

        windowMenu.Add("Move / resize", moveMenu)
        windowMenu.Add()

        windowMenu.Add(
            "Copy window info",
            WindowToolbox.CopyInfo.Bind(hwnd)
        )

        if (onCaptureAutoPaste)
        {
            windowMenu.Add(
                "Create AutoPaste rule...",
                WindowToolbox.CaptureAutoPaste.Bind(
                    hwnd,
                    onCaptureAutoPaste
                )
            )
        }

        closeMenu := Menu()
        closeMenu.Add(
            "Same title + class",
            WindowToolbox.CloseSimilar.Bind(hwnd, true)
        )
        closeMenu.Add(
            "Same class",
            WindowToolbox.CloseSimilar.Bind(hwnd, false)
        )
        windowMenu.Add("Close windows", closeMenu)

        windowMenu.Show()
    }

    static GetWindowLabel(hwnd)
    {
        exeName := ""
        title := ""

        try
        {
            exeName := WinGetProcessName("ahk_id " hwnd)
        }

        try
        {
            title := WinGetTitle("ahk_id " hwnd)
        }

        if (exeName = "")
        {
            exeName := "Window"
        }

        title := StrReplace(StrReplace(title, "`r", " "), "`n", " ")
        if (StrLen(title) > 48)
        {
            title := SubStr(title, 1, 45) "..."
        }

        return title != ""
            ? exeName " — " title
            : exeName
    }

    static IsAlwaysOnTop(hwnd)
    {
        try
        {
            return !!(WinGetExStyle("ahk_id " hwnd) & 0x00000008)
        }
        catch Error
        {
            return false
        }
    }

    static ToggleAlwaysOnTop(hwnd, *)
    {
        if (!WindowToolbox.IsValidTarget(hwnd))
        {
            return
        }

        isTop := WindowToolbox.IsAlwaysOnTop(hwnd)
        WinSetAlwaysOnTop(!isTop, "ahk_id " hwnd)

        WindowToolbox.ShowTip(
            isTop
                ? "Always-on-top: OFF"
                : "Always-on-top: ON"
        )
    }

    static ToggleKeepAlive(hwnd, *)
    {
        if (!WindowToolbox.IsValidTarget(hwnd))
        {
            return
        }

        try
        {
            isEnabled := WindowKeepAlive.ToggleWindow(hwnd)
            WindowToolbox.ShowTip(
                isEnabled
                    ? "KeepAlive: ON"
                    : "KeepAlive: OFF"
            )
        }
        catch Error as e
        {
            WindowToolbox.ShowTip(
                "Unable to toggle KeepAlive:`n" e.Message,
                5000
            )
        }
    }

    static ToggleMute(hwnd, *)
    {
        if (!WindowToolbox.IsValidTarget(hwnd))
        {
            return
        }

        try
        {
            processId := WinGetPID("ahk_id " hwnd)
            processName := WinGetProcessName("ahk_id " hwnd)
            isMuted := Sound.ToggleProcessMute(processId)

            WindowToolbox.ShowTip(
                (isMuted ? "Muted: " : "Unmuted: ") processName
            )
        }
        catch Error as e
        {
            WindowToolbox.ShowTip(
                "Unable to toggle process mute:`n" e.Message,
                5000
            )
        }
    }

    static Center(hwnd, *)
    {
        if (!WindowToolbox.IsValidTarget(hwnd))
        {
            return
        }

        try
        {
            selector := "ahk_id " hwnd
            WinRestore(selector)
            WinGetPos(&x, &y, &w, &h, selector)
            Monitor_GetWorkAreaFromWindow(hwnd, &left, &top, &right, &bottom)

            workWidth := right - left
            workHeight := bottom - top

            w := Min(w, workWidth)
            h := Min(h, workHeight)

            targetX := left + (workWidth - w) // 2
            targetY := top + (workHeight - h) // 2

            WinMove(targetX, targetY, w, h, selector)
        }
        catch Error as e
        {
            WindowToolbox.ShowTip(
                "Unable to center window:`n" e.Message,
                5000
            )
        }
    }

    static MoveThird(hwnd, thirdIndex, *)
    {
        if (!WindowToolbox.IsValidTarget(hwnd))
        {
            return
        }

        try
        {
            Win_ThirdForWindow(hwnd, thirdIndex)
        }
        catch Error as e
        {
            WindowToolbox.ShowTip(
                "Unable to resize window:`n" e.Message,
                5000
            )
        }
    }

    static MoveMonitor(hwnd, direction, *)
    {
        if (!WindowToolbox.IsValidTarget(hwnd))
        {
            return
        }

        monitorCount := MonitorGetCount()
        if (monitorCount < 2)
        {
            WindowToolbox.ShowTip("Only one monitor is available.")
            return
        }

        try
        {
            sourceMonitor := Monitor_GetIndexFromWindow(hwnd)
            targetMonitor := sourceMonitor + direction

            if (targetMonitor < 1)
            {
                targetMonitor := monitorCount
            }
            else if (targetMonitor > monitorCount)
            {
                targetMonitor := 1
            }

            WindowToolbox.MoveToMonitor(hwnd, sourceMonitor, targetMonitor)
        }
        catch Error as e
        {
            WindowToolbox.ShowTip(
                "Unable to move window to another monitor:`n" e.Message,
                5000
            )
        }
    }

    static MoveToMonitor(hwnd, sourceMonitor, targetMonitor)
    {
        selector := "ahk_id " hwnd
        wasMaximized := WinGetMinMax(selector) = 1

        if (wasMaximized)
        {
            WinRestore(selector)
        }

        WinGetPos(&x, &y, &w, &h, selector)
        MonitorGetWorkArea(
            sourceMonitor,
            &sourceLeft,
            &sourceTop,
            &sourceRight,
            &sourceBottom
        )
        MonitorGetWorkArea(
            targetMonitor,
            &targetLeft,
            &targetTop,
            &targetRight,
            &targetBottom
        )

        sourceWidth := Max(1, sourceRight - sourceLeft)
        sourceHeight := Max(1, sourceBottom - sourceTop)
        targetWidth := targetRight - targetLeft
        targetHeight := targetBottom - targetTop

        relativeX := (x - sourceLeft) / sourceWidth
        relativeY := (y - sourceTop) / sourceHeight

        w := Min(w, targetWidth)
        h := Min(h, targetHeight)

        targetX := targetLeft + Round(relativeX * targetWidth)
        targetY := targetTop + Round(relativeY * targetHeight)

        targetX := Max(targetLeft, Min(targetX, targetRight - w))
        targetY := Max(targetTop, Min(targetY, targetBottom - h))

        WinMove(targetX, targetY, w, h, selector)

        if (wasMaximized)
        {
            WinMaximize(selector)
        }
    }

    static CopyInfo(hwnd, *)
    {
        if (!WindowToolbox.IsValidTarget(hwnd))
        {
            return
        }

        try
        {
            CopyWindowInfo_Copy(hwnd)
        }
        catch Error as e
        {
            WindowToolbox.ShowTip(
                "Unable to copy window info:`n" e.Message,
                5000
            )
        }
    }

    static CaptureAutoPaste(hwnd, callback, *)
    {
        if (!WindowToolbox.IsValidTarget(hwnd))
        {
            return
        }

        try
        {
            callback.Call(hwnd)
        }
        catch Error as e
        {
            WindowToolbox.ShowTip(
                "Unable to create AutoPaste rule:`n" e.Message,
                5000
            )
        }
    }

    static CloseSimilar(hwnd, sameTitle, *)
    {
        if (!WindowToolbox.IsValidTarget(hwnd))
        {
            return
        }

        try
        {
            targetClass := WinGetClass("ahk_id " hwnd)
            targetTitle := WinGetTitle("ahk_id " hwnd)
            windows := WinGetList("ahk_class " targetClass)

            closedCount := 0

            for candidateHwnd in windows
            {
                if (sameTitle)
                {
                    try
                    {
                        if (WinGetTitle("ahk_id " candidateHwnd) != targetTitle)
                        {
                            continue
                        }
                    }
                    catch Error
                    {
                        continue
                    }
                }

                try
                {
                    WinClose("ahk_id " candidateHwnd)
                    closedCount += 1
                }
            }

            WindowToolbox.ShowTip(
                "Close windows: " closedCount " requested."
            )
        }
        catch Error as e
        {
            WindowToolbox.ShowTip(
                "Unable to close similar windows:`n" e.Message,
                5000
            )
        }
    }

    static IsValidTarget(hwnd)
    {
        try
        {
            return hwnd
                && WinExist("ahk_id " hwnd)
                && WindowApp.IsRealWindow(hwnd)
        }
        catch Error
        {
            return false
        }
    }

    static NoOp(*)
    {
    }

    static ShowTip(message, duration := 1800)
    {
        ToolTip(message)
        SetTimer(() => ToolTip(), -duration)
    }
}
