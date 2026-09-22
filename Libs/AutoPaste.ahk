#Requires AutoHotkey v2.0

#Include Std.ahk
#Include Browser.ahk

global TimerIntervalInMs := 500

global AutoPasteEntries := []
global ProcessedHwnds := Map()
global NotifiedMatches := Map()

; --------------------------------------------------------------------------------
; Create watcher for `AutoPaste` functionality.

AutoPaste_Register(entries)
{
    global AutoPasteEntries, ProcessedHwnds, NotifiedMatches

    AutoPasteEntries := entries
    ProcessedHwnds.Clear()
    NotifiedMatches.Clear()

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
    global AutoPasteEntries, ProcessedHwnds, NotifiedMatches

    hwnd := WinExist("A")
    if (!hwnd)
    {
        return
    }

    if (!ProcessedHwnds.Has(hwnd))
    {
        ProcessedHwnds[hwnd] := Map()
    }

    if (!NotifiedMatches.Has(hwnd))
    {
        NotifiedMatches[hwnd] := Map()
    }

    processedEntries := ProcessedHwnds[hwnd]
    notifiedEntries := NotifiedMatches[hwnd]
    matchContext := Map(
        "urlLoaded", false,
        "url", ""
    )

    for entryIndex, entry in AutoPasteEntries
    {
        if (!AutoPaste_IsMatched(hwnd, entry, matchContext))
        {
            ; URL rules may become valid again after navigating away and back.
            if (entry.Has("url"))
            {
                if (processedEntries.Has(entryIndex))
                {
                    processedEntries.Delete(entryIndex)
                }

                if (notifiedEntries.Has(entryIndex))
                {
                    notifiedEntries.Delete(entryIndex)
                }
            }

            continue
        }

        processedValue := entry.Has("url")
            ? matchContext["url"]
            : "__matched__"

        if (
            entry.Has("notifyOnMatch")
            && entry["notifyOnMatch"]
            && (
                !notifiedEntries.Has(entryIndex)
                || notifiedEntries[entryIndex] != processedValue
            )
        )
        {
            AutoPaste_ShowMatchNotification(hwnd, entry, matchContext)
            notifiedEntries[entryIndex] := processedValue
        }

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

AutoPaste_ShowMatchNotification(hwnd, entry, matchContext)
{
    ruleName := entry.Has("name") ? entry["name"] : "(unnamed)"
    winExe := WinGetProcessName("ahk_id " hwnd)
    winTitle := AutoPaste_Truncate(WinGetTitle("ahk_id " hwnd), 120)

    message := "Rule: " ruleName
        . "`nEXE: " winExe

    if (winTitle != "")
    {
        message .= "`nTitle: " winTitle
    }

    if (entry.Has("url"))
    {
        url := AutoPaste_Truncate(matchContext["url"], 180)
        if (url != "")
        {
            message .= "`nURL: " url
        }
    }

    TrayTip(message, "AutoPaste matched")
}

AutoPaste_Truncate(value, maxLength)
{
    if (StrLen(value) <= maxLength)
    {
        return value
    }

    return SubStr(value, 1, maxLength - 3) . "..."
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

    if (!AutoPaste_ApplyFocus(entry))
    {
        return false
    }

    text := AutoPaste_GetText(entry)
    Std_Paste(text)

    return true
}

AutoPaste_ApplyFocus(entry)
{
    if (!entry.Has("focus"))
    {
        return true
    }

    focus := entry["focus"]
    method := focus.Has("method")
        ? StrLower(focus["method"])
        : "keys"

    if (method = "keys")
    {
        if (!focus.Has("keys"))
        {
            return false
        }

        Send(focus["keys"])
    }
    else
    {
        return false
    }

    delay := entry.Has("focusDelay")
        ? entry["focusDelay"]
        : 0

    if (delay > 0)
    {
        Sleep(delay)
    }

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
