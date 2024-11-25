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