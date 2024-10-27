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
