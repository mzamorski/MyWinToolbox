#Requires AutoHotkey v2.0

; Toggles independent AHK v2 scripts, including scripts launched outside
; MyWinToolbox. Identifies each running script using its exact hidden
; AutoHotkey main-window title, not a shared interpreter PID or filename.
class AhkScriptManager
{
    static ValidateScriptPath(value)
    {
        path := Trim("" value)
        if (
            path = ""
            || InStr(path, Chr(34))
            || RegExMatch(path, "[\x00-\x1F]")
            || !RegExMatch(path, "i)\.ahk$")
            || !RegExMatch(path, "i)^(?:[a-z]:\\|\\\\[^\\]+\\[^\\]+\\)")
        )
        {
            throw Error("Provide a full absolute path to a .ahk script: " value)
        }

        return path
    }

    static ValidateEntries(entries)
    {
        names := Map()
        paths := Map()

        for entry in entries
        {
            name := Trim("" entry["Name"])
            if (
                name = ""
                || InStr(name, "=")
                || SubStr(name, 1, 1) = ";"
                || RegExMatch(name, "[\x00-\x1F]")
            )
            {
                throw Error("Invalid AHK script label: " name)
            }

            key := StrLower(name)
            if (names.Has(key))
            {
                throw Error("Duplicate AHK script label: " name)
            }
            names[key] := true

            scriptPath := AhkScriptManager.ValidateScriptPath(entry["Value"])
            key := StrLower(StrReplace(scriptPath, "/", "\"))
            if (paths.Has(key))
            {
                throw Error("Duplicate AHK script path: " scriptPath)
            }
            paths[key] := true
        }

        return true
    }

    static ResolveScriptPath(scriptPath)
    {
        path := StrReplace(AhkScriptManager.ValidateScriptPath(scriptPath), "/", "\")
        ; A fully qualified path without dot components is already canonical.
        ; Avoid Win32 path-resolution calls during each menu refresh when no
        ; normalization is needed (including non-system drives such as E:).
        if (!RegExMatch(path, "(^|\\)\.{1,2}(\\|$)"))
        {
            return path
        }

        ; Resolve paths containing . or .. for exact AHK window matching.
        buffer := Buffer(32768 * 2, 0)
        length := DllCall(
            "Kernel32\GetFullPathNameW",
            "Str", path,
            "UInt", 32768,
            "Ptr", buffer.Ptr,
            "Ptr", 0,
            "UInt"
        )
        if (length = 0 || length >= 32768)
        {
            throw Error("Unable to resolve AHK script path: " path)
        }

        return StrGet(buffer.Ptr)
    }

    static MainWindowMatches(windowTitle, fullPath)
    {
        title := StrLower(Trim("" windowTitle))
        path := StrLower(fullPath)
        prefix := path " - autohotkey"
        return SubStr(title, 1, StrLen(prefix)) = prefix
    }

    static GetWindows(fullPath)
    {
        matches := []
        ; The AHK main window is hidden, including for scripts with hotkeys
        ; and no GUI. Temporarily enable hidden-window discovery.
        oldDetectHidden := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        try
        {
            for hwnd in WinGetList("ahk_class AutoHotkey")
            {
                try
                {
                    if (AhkScriptManager.MainWindowMatches(
                        WinGetTitle("ahk_id " hwnd),
                        fullPath
                    ))
                    {
                        matches.Push(hwnd)
                    }
                }
                catch Error
                {
                    ; Another process may exit during enumeration.
                }
            }
        }
        finally
        {
            DetectHiddenWindows(oldDetectHidden)
        }

        return matches
    }

    static IsRunning(fullPath)
    {
        return AhkScriptManager.GetWindows(fullPath).Length > 0
    }

    static Toggle(scriptPath)
    {
        fullPath := AhkScriptManager.ResolveScriptPath(scriptPath)
        windows := AhkScriptManager.GetWindows(fullPath)
        if (windows.Length > 0)
        {
            ; AHK receives WM_CLOSE and executes registered OnExit handlers,
            ; unlike ProcessClose which can leave held game keys pressed.
            for hwnd in windows
            {
                try
                {
                    WinClose("ahk_id " hwnd)
                }
                catch Error as e
                {
                    throw Error("Unable to close AHK script: " fullPath ". " e.Message)
                }
            }

            return false
        }

        if (!FileExist(fullPath) || InStr(FileExist(fullPath), "D"))
        {
            throw Error("AHK script file was not found: " fullPath)
        }
        if (A_IsCompiled)
        {
            throw Error("Starting other .ahk scripts requires a non-compiled MyWinToolbox with an AHK v2 interpreter.")
        }

        SplitPath(fullPath, , &workingDir)
        Run('"' A_AhkPath '" "' fullPath '"', workingDir)
        return true
    }
}
