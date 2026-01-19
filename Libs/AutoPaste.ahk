#Requires AutoHotkey v2.0

#Include Std.ahk

global TimerIntervalInMs := 500

global AutoPasteEntries := []
global ProcessedHwnds := Map()

; --------------------------------------------------------------------------------
; Create watcher for `AutoPaste` functionality.

AutoPaste_Register(entries) 
{
    global AutoPasteEntries
    AutoPasteEntries := entries
    
    if (AutoPasteEntries.Length > 0)
    {
        SetTimer(AutoPaste_Run, TimerIntervalInMs)
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
	
	if (ProcessedHwnds.Has(hwnd))
	{
        return
	}

	for _, entry in AutoPasteEntries
	{
		if (AutoPaste_IsMatched(hwnd, entry))
		{
			ProcessedHwnds[hwnd] := true

			AutoPaste_Paste(hwnd, entry)
		}
	}
}

AutoPaste_IsMatched(hwnd, entry)
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

		matchValue := entry["title"]
		matchMode := entry.Has("titleMatchMode") ? entry["titleMatchMode"] : "contains"

		if (matchMode = "equals")
		{
			if (winTitle != matchValue)
			{
                return false
			}
		}
		else
		{
			if (!InStr(winTitle, matchValue, false))
			{
				return false
			}
		}
	}

	return true
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

	Std_Paste(entry["text"])

	return true
}

; --------------------------------------------------------------------------------