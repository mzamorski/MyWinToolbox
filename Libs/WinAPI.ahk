#Requires AutoHotkey v2.0

WinAPI_UuidCreate(mode := 1, format := "", &UUID?)
{
	UuidCreate := "Rpcrt4\UuidCreate"
    
	if InStr("02", mode)
	{
		UuidCreate .= mode ? "Sequential" : "Nil"
	}
	
	UUID := Buffer(16)

	if (
		DllCall(UuidCreate, "Ptr", UUID) == 0)
		&& 
		(DllCall("Rpcrt4\UuidToString", "Ptr", UUID, "Ptr*", &pString := 0) == 0
	)
	{
		output := StrGet(pString)

		DllCall("Rpcrt4\RpcStringFree", "Ptr*", pString)
		if InStr(format, "U")
		{
			DllCall("CharUpper", "Ptr", StrPtr(output))
		}

		return InStr(format, "{") 
			? "{" . output . "}" 
			: output
	}
}

; Forces the display to be on by resetting the display idle timer.
WinAPI_SetThreadExecutionState_DisplayRequired()
{
	static ES_DISPLAY_REQUIRED := 0x00000002

	DllCall("SetThreadExecutionState", "UInt", ES_DISPLAY_REQUIRED)
	return
}

; Allow display to go idle
WinAPI_SetThreadExecutionState_Continuous()
{
	static ES_CONTINUOUS := 0x80000000

	DllCall("SetThreadExecutionState", "UInt", ES_CONTINUOUS)
	return
}

; Forces the system to be in the working state by resetting the system idle timer.
WinAPI_SetThreadExecutionState_SystemRequired()
{
	static ES_SYSTEM_REQUIRED := 0x00000001

	DllCall("SetThreadExecutionState", "UInt", ES_SYSTEM_REQUIRED)
	return
}

global MAX_PATH := 260 * 2
global MAX_TEMP_FILE_PREFIX_LEN := 3

WinAPI_GetTempFilePath(directoryPath := A_Temp, prefix := STRING_EMPTY)
{
	; if (StrLen(prefix) > MAX_TEMP_FILE_PREFIX_LEN)
	; {
	; }

	static len := MAX_PATH + 1 
	output := Buffer(len)

	unique  := DllCall("Kernel32.dll\GetTempFileName", "Str", directoryPath, "Str", prefix, "UInt", 0, "Ptr", output)

	; MSDN: 
	; If the function succeeds, the return value specifies the unique numeric value used in the temporary file name.
	; If the function fails, the return value is zero.
    if (unique == 0)
	{
        errorCode := DllCall("Kernel32.dll\GetLastError")
        throw OSError("Failed to generate a temporary file name.", errorCode)
	}

	path := StrGet(output.Ptr)
	if (!path)
	{
		throw Error("Invalid file path!")
	}
	
    return path
}

WinAPI_GetWindowIcon(hwnd) {
    ; Try WM_GETICON small2, small, big; then class icons
    WM_GETICON := 0x7F
    ICON_SMALL2 := 2, ICON_SMALL := 0, ICON_BIG := 1

    for iconType in [ICON_SMALL2, ICON_SMALL, ICON_BIG] {
        hIcon := SendMessage(WM_GETICON, iconType, 0, , "ahk_id " hwnd)
        if hIcon
            return hIcon
    }

    ; Class small icon
    GCLP_HICONSM := -34

    hIcon := DllCall("GetClassLongPtr", "ptr",hwnd, "int",GCLP_HICONSM, "ptr")
    if hIcon
        return hIcon

    ; Class big icon
    GCLP_HICON := -14

    return DllCall("GetClassLongPtr", "ptr",hwnd, "int",GCLP_HICON, "ptr")
}

WinAPI_HwndUnderMouse() {
    ; Get the window under the mouse.
    ; MouseGetPos (v2): 3rd output = window HWND, 4th = control under cursor.
    MouseGetPos(&mx, &my, &hWin, &hCtrl)

    ; Coerce to numeric (if we accidentally get a class/control name, this becomes 0)
    hw := hWin + 0
    if !hw
        return 0

    ; Return the top-level ancestor (GA_ROOT = 2)
    return DllCall("GetAncestor", "ptr", hw, "uint", 2, "ptr")
}

; Returns WM_NCHITTEST code at the current cursor position for the given hwnd.
; Useful if you want the hotkey to work only on caption/minimize button.
WinAPI_HitTestAtCursor(hwnd) {
    MouseGetPos(&mx, &my)
	
    return WinAPI_NcHitTest(hwnd, mx, my)
}

/*
; Gets WM_NCHITTEST code at the current cursor position for the given hwnd.
WinAPI_HitTestAtCursor(hwnd) {
    ; Always read screen coords directly from WinAPI (independent of CoordMode)
    pt := Buffer(8, 0)  ; POINT { LONG x; LONG y; }
    if !DllCall("GetCursorPos", "ptr", pt, "int")
        return 0
    x := NumGet(pt, 0, "Int")
    y := NumGet(pt, 4, "Int")
    return WinAPI_NcHitTest(hwnd, x, y)
}

*/

; Performs WM_NCHITTEST for arbitrary screen coords (x,y).
WinAPI_NcHitTest(hwnd, x, y) {
    ; Pack screen coords into LPARAM (signed low/high word)
    lParam := (y & 0xFFFF) << 16 | (x & 0xFFFF)
    return DllCall("SendMessageW", "ptr", hwnd, "uint", 0x84, "ptr", 0, "ptr", lParam, "int") ; WM_NCHITTEST
}

/*

; Performs WM_NCHITTEST for screen coords (x,y).
WinAPI_NcHitTest(hwnd, x, y) {
    ; Optional guard: ensure point is within the top-level window rect.
    rect := Buffer(16, 0) ; RECT { left, top, right, bottom }
    if DllCall("GetWindowRect", "ptr", hwnd, "ptr", rect, "int") {
        left   := NumGet(rect,  0, "Int")
        top    := NumGet(rect,  4, "Int")
        right  := NumGet(rect,  8, "Int")
        bottom := NumGet(rect, 12, "Int")
        if (x < left || x >= right || y < top || y >= bottom)
            return 0  ; outside -> HTNOWHERE
    }

    ; Pack screen coords into LPARAM like MAKELPARAM(x, y).
    ; Low word = x, High word = y (both 16-bit, sign handled by the window proc).
    lParam := (y & 0xFFFF) << 16 | (x & 0xFFFF)

    ; Send WM_NCHITTEST; returns HT* code (>0) or 0 if nowhere.
    return DllCall("SendMessageW", "ptr", hwnd, "uint", 0x84, "ptr", 0, "ptr", lParam, "int") ; WM_NCHITTEST
}

*/

; Convenience predicates (optional)
WinAPI_IsCursorOnCaption(hwnd) {
    return WinAPI_HitTestAtCursor(hwnd) = 2   ; HTCAPTION
}
WinAPI_IsCursorOnMinButton(hwnd) {
    return WinAPI_HitTestAtCursor(hwnd) = 8   ; HTMINBUTTON
}