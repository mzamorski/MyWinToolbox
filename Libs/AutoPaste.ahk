#Requires AutoHotkey v2.0

#Include Std.ahk
#Include Browser.ahk

global TimerIntervalInMs := 500

global AutoPasteEntries := []
global ProcessedHwnds := Map()

; --------------------------------------------------------------------------------
; Create watcher for `AutoPaste` functionality.

AutoPaste_Register(entries)
{
    global AutoPasteEntries, ProcessedHwnds

    AutoPasteEntries := entries
    ProcessedHwnds.Clear()

    if (AutoPasteEntries.Length > 0)
    {
        SetTimer(AutoPaste_Run, TimerIntervalInMs)
    }
    else
    {
        SetTimer(AutoPaste_Run, 0)
    }
}

AutoPaste_Run(*)
{
    global AutoPasteEntries, ProcessedHwnds

    hwnd := WinExist("A")
    if (!hwnd)
    {
        return
    }

    if (!ProcessedHwnds.Has(hwnd))
    {
        ProcessedHwnds[hwnd] := Map()
    }

    processedEntries := ProcessedHwnds[hwnd]
    matchContext := Map(
        "urlLoaded", false,
        "url", ""
    )

    for entryIndex, entry in AutoPasteEntries
    {
        if (!AutoPaste_IsMatched(hwnd, entry, matchContext))
        {
            ; URL rules may become valid again after navigating away and back.
            if (entry.Has("url") && processedEntries.Has(entryIndex))
            {
                processedEntries.Delete(entryIndex)
            }

            continue
        }

        processedValue := entry.Has("url")
            ? matchContext["url"]
            : "__matched__"

        if (
            processedEntries.Has(entryIndex)
            && processedEntries[entryIndex] = processedValue
        )
        {
            continue
        }

        if (AutoPaste_Paste(hwnd, entry))
        {
            processedEntries[entryIndex] := processedValue
        }
    }
}

AutoPaste_IsMatched(hwnd, entry, matchContext)
{
    if (entry.Has("exe"))
    {
        winExe := WinGetProcessName("ahk_id " hwnd)

        if (StrLower(winExe) != StrLower(entry["exe"]))
        {
            return false
        }
    }

    if (entry.Has("class"))
    {
        winClass := WinGetClass("ahk_id " hwnd)

        if (StrLower(winClass) != StrLower(entry["class"]))
        {
            return false
        }
    }

    if (entry.Has("title"))
    {
        winTitle := WinGetTitle("ahk_id " hwnd)
        matchMode := entry.Has("titleMatchMode")
            ? entry["titleMatchMode"]
            : "contains"

        if (!AutoPaste_MatchesValue(winTitle, entry["title"], matchMode))
        {
            return false
        }
    }

    if (entry.Has("url"))
    {
        if (!WindowApp.IsBrowserActive())
        {
            return false
        }

        if (!matchContext["urlLoaded"])
        {
            matchContext["url"] := Browser.GetURL()
            matchContext["urlLoaded"] := true
        }

        url := matchContext["url"]
        if (url = "")
        {
            return false
        }

        matchMode := entry.Has("urlMatchMode")
            ? entry["urlMatchMode"]
            : "contains"

        if (!AutoPaste_MatchesValue(url, entry["url"], matchMode))
        {
            return false
        }
    }

    return true
}

AutoPaste_MatchesValue(actualValue, matchValue, matchMode)
{
    if (matchMode = "equals")
    {
        return actualValue = matchValue
    }

    return InStr(actualValue, matchValue, false) > 0
}

AutoPaste_Paste(hwnd, entry)
{
    if (entry.Has("delay") && entry["delay"] > 0)
    {
        Sleep(entry["delay"])
    }

    if (!WinExist("ahk_id " hwnd))
    {
        return false
    }

    if (!WinActive("ahk_id " hwnd))
    {
        WinActivate("ahk_id " hwnd)

        if (!WinWaitActive("ahk_id " hwnd, , 1))
        {
            return false
        }
    }

    text := AutoPaste_GetText(entry)
    Std_Paste(text)

    return true
}

AutoPaste_GetText(entry)
{
    global ConfigFilePath, Secret

    if (entry.Has("passwordKey"))
    {
        encryptedPassword := Ini_ReadOrDefault(
            ConfigFilePath,
            "Passwords",
            entry["passwordKey"]
        )
        return CryptoUtils.Decrypt(encryptedPassword, Secret)
    }

    return entry["text"]
}

; --------------------------------------------------------------------------------
