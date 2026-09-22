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
        if (!AutoPaste_TryGetProcessName(hwnd, &winExe))
        {
            return false
        }

        if (StrLower(winExe) != StrLower(entry["exe"]))
        {
            return false
        }
    }

    if (entry.Has("class"))
    {
        if (!AutoPaste_TryGetClass(hwnd, &winClass))
        {
            return false
        }

        if (StrLower(winClass) != StrLower(entry["class"]))
        {
            return false
        }
    }

    if (entry.Has("title"))
    {
        if (!AutoPaste_TryGetTitle(hwnd, &winTitle))
        {
            return false
        }

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

AutoPaste_TryGetProcessName(hwnd, &value)
{
    value := ""

    try
    {
        value := WinGetProcessName("ahk_id " hwnd)
        return true
    }
    catch Error
    {
        return false
    }
}

AutoPaste_TryGetClass(hwnd, &value)
{
    value := ""

    try
    {
        value := WinGetClass("ahk_id " hwnd)
        return true
    }
    catch Error
    {
        return false
    }
}

AutoPaste_TryGetTitle(hwnd, &value)
{
    value := ""

    try
    {
        value := WinGetTitle("ahk_id " hwnd)
        return true
    }
    catch Error
    {
        return false
    }
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

    winExe := ""
    AutoPaste_TryGetProcessName(hwnd, &winExe)

    winTitle := ""
    if (AutoPaste_TryGetTitle(hwnd, &rawWinTitle))
    {
        winTitle := AutoPaste_Truncate(rawWinTitle, 120)
    }

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

    return AutoPaste_ExecuteEntry(entry)
}

AutoPaste_ExecuteEntry(entry)
{
    actions := AutoPaste_GetActions(entry)
    if (actions.Length = 0 || !AutoPaste_ActionsAreValid(actions))
    {
        return false
    }

    for action in actions
    {
        if (!AutoPaste_ExecuteAction(action))
        {
            return false
        }
    }

    return true
}

AutoPaste_GetActions(entry)
{
    actions := []

    ; Backward compatibility: normalize the legacy focus/focusDelay fields
    ; into ordinary actions. New configurations should use actions only.
    if (entry.Has("focus"))
    {
        focus := entry["focus"]
        method := focus.Has("method")
            ? StrLower(focus["method"])
            : "keys"

        if (method != "keys" || !focus.Has("keys"))
        {
            return []
        }

        actions.Push(Map("keys", focus["keys"]))

        if (entry.Has("focusDelay") && entry["focusDelay"] > 0)
        {
            actions.Push(Map("delay", entry["focusDelay"]))
        }
    }

    if (entry.Has("actions"))
    {
        for action in entry["actions"]
        {
            actions.Push(action)
        }
    }
    else if (entry.Has("passwordKey"))
    {
        actions.Push(Map("passwordKey", entry["passwordKey"]))
    }
    else if (entry.Has("text"))
    {
        actions.Push(Map("text", entry["text"]))
    }

    return actions
}

AutoPaste_ActionsAreValid(actions)
{
    for action in actions
    {
        if (!AutoPaste_IsValidAction(action))
        {
            return false
        }
    }

    return true
}

AutoPaste_IsValidAction(action)
{
    operationCount := 0
    for propertyName in ["keys", "delay", "passwordKey", "text"]
    {
        if (action.Has(propertyName))
        {
            operationCount += 1
        }
    }

    return operationCount = 1
}

AutoPaste_ExecuteAction(action)
{
    if (!AutoPaste_IsValidAction(action))
    {
        return false
    }

    if (action.Has("keys"))
    {
        Send(action["keys"])
        return true
    }

    if (action.Has("delay"))
    {
        delay := action["delay"]
        if (delay > 0)
        {
            Sleep(delay)
        }

        return true
    }

    Std_Paste(AutoPaste_GetText(action))
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
