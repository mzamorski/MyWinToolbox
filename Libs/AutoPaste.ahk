#Requires AutoHotkey v2.0

#Include Std.ahk
#Include Browser.ahk
#Include Logger.ahk

global TimerIntervalInMs := 500

global AutoPasteEntries := []
global AutoPasteEnabled := false
global ProcessedHwnds := Map()
global NotifiedMatches := Map()
global AutoPasteLastCleanupTick := 0
global AutoPasteCleanupIntervalInMs := 5000

; --------------------------------------------------------------------------------
; Create watcher for `AutoPaste` functionality.

AutoPaste_Register(entries)
{
    global AutoPasteEntries, ProcessedHwnds, NotifiedMatches

    AutoPaste_ValidateEntries(entries)

    AutoPasteEntries := entries
    ProcessedHwnds.Clear()
    NotifiedMatches.Clear()

    if (AutoPasteEntries.Length > 0)
    {
        AutoPaste_SetEnabled(true)
        Logger.Info("Registered " AutoPasteEntries.Length " rule(s).", "AutoPaste")

        for entryIndex, entry in AutoPasteEntries
        {
            Logger.Debug(
                AutoPaste_GetRuleLabel(entry, entryIndex)
                    . " triggerMode=" AutoPaste_GetTriggerMode(entry),
                "AutoPaste"
            )
        }
    }
    else
    {
        AutoPaste_SetEnabled(false)
    }
}

AutoPaste_IsEnabled()
{
    global AutoPasteEnabled

    return AutoPasteEnabled
}

AutoPaste_SetEnabled(enabled)
{
    global AutoPasteEnabled, AutoPasteEntries, TimerIntervalInMs

    AutoPasteEnabled := enabled && AutoPasteEntries.Length > 0
    SetTimer(AutoPaste_Run, AutoPasteEnabled ? TimerIntervalInMs : 0)

    return AutoPasteEnabled
}

AutoPaste_Toggle()
{
    return AutoPaste_SetEnabled(!AutoPaste_IsEnabled())
}

AutoPaste_CleanupStaleWindows()
{
    global ProcessedHwnds, NotifiedMatches
    global AutoPasteLastCleanupTick, AutoPasteCleanupIntervalInMs

    currentTick := A_TickCount
    if (
        AutoPasteLastCleanupTick != 0
        && currentTick >= AutoPasteLastCleanupTick
        && currentTick - AutoPasteLastCleanupTick < AutoPasteCleanupIntervalInMs
    )
    {
        return
    }

    AutoPasteLastCleanupTick := currentTick
    staleHwnds := []

    for trackedHwnd, processedState in ProcessedHwnds
    {
        if (!WinExist("ahk_id " trackedHwnd))
        {
            staleHwnds.Push(trackedHwnd)
        }
    }

    for trackedHwnd in staleHwnds
    {
        if (ProcessedHwnds.Has(trackedHwnd))
        {
            ProcessedHwnds.Delete(trackedHwnd)
        }

        if (NotifiedMatches.Has(trackedHwnd))
        {
            NotifiedMatches.Delete(trackedHwnd)
        }

        Logger.Debug("Removed stale state for HWND " trackedHwnd ".", "AutoPaste")
    }
}

AutoPaste_ValidateEntries(entries)
{
    if (!IsObject(entries) || Type(entries) != "Array")
    {
        throw Error("AutoPastes.json: root value must be an array.")
    }

    allowedEntryFields := Map(
        "name", true,
        "exe", true,
        "class", true,
        "title", true,
        "titleMatchMode", true,
        "url", true,
        "urlMatchMode", true,
        "notifyOnMatch", true,
        "triggerMode", true,
        "delay", true,
        "focus", true,
        "focusDelay", true,
        "passwordKey", true,
        "text", true,
        "actions", true
    )

    for entryIndex, entry in entries
    {
        ruleLabel := AutoPaste_GetRuleLabel(entry, entryIndex)

        if (!IsObject(entry) || !(entry is Map))
        {
            throw Error("AutoPastes.json / " ruleLabel ": rule must be an object.")
        }

        for fieldName, fieldValue in entry
        {
            if (!allowedEntryFields.Has(fieldName))
            {
                throw Error("AutoPastes.json / " ruleLabel ": unknown field '" fieldName "'.")
            }
        }

        hasMatcher := entry.Has("exe")
            || entry.Has("class")
            || entry.Has("title")
            || entry.Has("url")

        if (!hasMatcher)
        {
            throw Error("AutoPastes.json / " ruleLabel ": at least one matcher (exe, class, title, url) is required.")
        }

        for fieldName in ["name", "exe", "class", "title", "url", "text", "passwordKey"]
        {
            if (entry.Has(fieldName) && Type(entry[fieldName]) != "String")
            {
                throw Error("AutoPastes.json / " ruleLabel ": '" fieldName "' must be a string.")
            }
        }

        for fieldName in ["exe", "class", "title", "url", "passwordKey"]
        {
            if (entry.Has(fieldName) && Trim(entry[fieldName]) = "")
            {
                throw Error("AutoPastes.json / " ruleLabel ": '" fieldName "' cannot be empty.")
            }
        }

        for fieldName in ["titleMatchMode", "urlMatchMode"]
        {
            if (entry.Has(fieldName))
            {
                mode := StrLower("" entry[fieldName])
                if (mode != "contains" && mode != "equals")
                {
                    throw Error("AutoPastes.json / " ruleLabel ": '" fieldName "' must be 'contains' or 'equals'.")
                }
            }
        }

        if (entry.Has("triggerMode"))
        {
            triggerMode := StrLower("" entry["triggerMode"])
            if (triggerMode != "onceperwindow" && triggerMode != "onceperurl" && triggerMode != "always")
            {
                throw Error("AutoPastes.json / " ruleLabel ": 'triggerMode' must be 'oncePerWindow', 'oncePerUrl', or 'always'.")
            }

            if (triggerMode = "onceperurl" && !entry.Has("url"))
            {
                throw Error("AutoPastes.json / " ruleLabel ": triggerMode 'oncePerUrl' requires a 'url' matcher.")
            }
        }

        for fieldName in ["delay", "focusDelay"]
        {
            if (entry.Has(fieldName))
            {
                value := entry[fieldName]
                if (!IsNumber(value) || value < 0)
                {
                    throw Error("AutoPastes.json / " ruleLabel ": '" fieldName "' must be a non-negative number.")
                }
            }
        }

        if (entry.Has("notifyOnMatch"))
        {
            value := entry["notifyOnMatch"]
            if (!IsNumber(value) || (value != 0 && value != 1))
            {
                throw Error("AutoPastes.json / " ruleLabel ": 'notifyOnMatch' must be true or false.")
            }
        }

        if (entry.Has("focus"))
        {
            focus := entry["focus"]
            if (!IsObject(focus) || !(focus is Map))
            {
                throw Error("AutoPastes.json / " ruleLabel ": legacy 'focus' must be an object.")
            }

            for fieldName, fieldValue in focus
            {
                if (fieldName != "method" && fieldName != "keys")
                {
                    throw Error("AutoPastes.json / " ruleLabel ": unknown focus field '" fieldName "'.")
                }
            }

            method := focus.Has("method") ? StrLower("" focus["method"]) : "keys"
            if (method != "keys")
            {
                throw Error("AutoPastes.json / " ruleLabel ": legacy focus method must be 'keys'.")
            }

            if (!focus.Has("keys") || Type(focus["keys"]) != "String" || focus["keys"] = "")
            {
                throw Error("AutoPastes.json / " ruleLabel ": legacy focus requires non-empty 'keys'.")
            }
        }
        else if (entry.Has("focusDelay"))
        {
            throw Error("AutoPastes.json / " ruleLabel ": 'focusDelay' requires legacy 'focus'.")
        }

        sourceCount := 0
        for fieldName in ["actions", "passwordKey", "text"]
        {
            if (entry.Has(fieldName))
            {
                sourceCount += 1
            }
        }

        if (sourceCount > 1)
        {
            throw Error("AutoPastes.json / " ruleLabel ": use only one of actions, passwordKey, or text.")
        }

        if (entry.Has("actions"))
        {
            AutoPaste_ValidateActions(entry["actions"], ruleLabel)
        }
        else if (sourceCount = 0 && !entry.Has("focus"))
        {
            throw Error("AutoPastes.json / " ruleLabel ": rule has no executable action.")
        }
    }
}

AutoPaste_ValidateActions(actions, ruleLabel)
{
    if (!IsObject(actions) || Type(actions) != "Array" || actions.Length = 0)
    {
        throw Error("AutoPastes.json / " ruleLabel ": 'actions' must be a non-empty array.")
    }

    allowedActionFields := Map(
        "keys", true,
        "delay", true,
        "passwordKey", true,
        "text", true
    )

    for actionIndex, action in actions
    {
        actionLabel := ruleLabel " / action #" actionIndex

        if (!IsObject(action) || !(action is Map))
        {
            throw Error("AutoPastes.json / " actionLabel ": action must be an object.")
        }

        for fieldName, fieldValue in action
        {
            if (!allowedActionFields.Has(fieldName))
            {
                throw Error("AutoPastes.json / " actionLabel ": unknown field '" fieldName "'.")
            }
        }

        operationCount := 0
        for fieldName in ["keys", "delay", "passwordKey", "text"]
        {
            if (action.Has(fieldName))
            {
                operationCount += 1
            }
        }

        if (operationCount != 1)
        {
            throw Error("AutoPastes.json / " actionLabel ": action must contain exactly one operation (keys, delay, passwordKey, text).")
        }

        if (action.Has("delay"))
        {
            value := action["delay"]
            if (!IsNumber(value) || value < 0)
            {
                throw Error("AutoPastes.json / " actionLabel ": 'delay' must be a non-negative number.")
            }
        }
        else
        {
            for fieldName in ["keys", "passwordKey", "text"]
            {
                if (action.Has(fieldName) && Type(action[fieldName]) != "String")
                {
                    throw Error("AutoPastes.json / " actionLabel ": '" fieldName "' must be a string.")
                }
            }

            for fieldName in ["keys", "passwordKey"]
            {
                if (action.Has(fieldName) && Trim(action[fieldName]) = "")
                {
                    throw Error("AutoPastes.json / " actionLabel ": '" fieldName "' cannot be empty.")
                }
            }
        }
    }
}

AutoPaste_GetRuleLabel(entry, entryIndex)
{
    if (IsObject(entry) && entry is Map && entry.Has("name") && Type(entry["name"]) = "String" && entry["name"] != "")
    {
        return entry["name"] " (#" entryIndex ")"
    }

    return "rule #" entryIndex
}

AutoPaste_Run(*)
{
    global AutoPasteEntries, ProcessedHwnds, NotifiedMatches

    AutoPaste_CleanupStaleWindows()

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
            ; Notifications may fire again after navigating away and back,
            ; but a successful paste remains processed for this HWND.
            if (entry.Has("url") && notifiedEntries.Has(entryIndex))
            {
                notifiedEntries.Delete(entryIndex)
            }

            continue
        }

        notificationValue := entry.Has("url")
            ? matchContext["url"]
            : "__matched__"

        if (
            entry.Has("notifyOnMatch")
            && entry["notifyOnMatch"]
            && (
                !notifiedEntries.Has(entryIndex)
                || notifiedEntries[entryIndex] != notificationValue
            )
        )
        {
            AutoPaste_ShowMatchNotification(hwnd, entry, matchContext)
            notifiedEntries[entryIndex] := notificationValue
        }

        triggerKey := AutoPaste_GetTriggerKey(entry, matchContext)

        if (
            triggerKey != ""
            && processedEntries.Has(entryIndex)
            && processedEntries[entryIndex].Has(triggerKey)
        )
        {
            continue
        }

        if (AutoPaste_Paste(hwnd, entry))
        {
            Logger.Info("Executed " AutoPaste_GetRuleLabel(entry, entryIndex) " for HWND " hwnd ".", "AutoPaste")

            if (triggerKey = "")
            {
                continue
            }

            if (!processedEntries.Has(entryIndex))
            {
                processedEntries[entryIndex] := Map()
            }

            processedEntries[entryIndex][triggerKey] := true
        }
    }
}

AutoPaste_GetTriggerMode(entry)
{
    if (!entry.Has("triggerMode"))
    {
        return "onceperwindow"
    }

    return StrLower("" entry["triggerMode"])
}

AutoPaste_GetTriggerKey(entry, matchContext)
{
    triggerMode := AutoPaste_GetTriggerMode(entry)

    if (triggerMode = "always")
    {
        return ""
    }

    if (triggerMode = "onceperurl")
    {
        return matchContext["url"]
    }

    return "__window__"
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
