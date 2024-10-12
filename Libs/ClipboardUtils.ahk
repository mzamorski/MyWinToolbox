Clipboard_Copy() 
{
    A_Clipboard := ""
    Send("^c")
    ClipWait()

    return A_Clipboard
}

Clipboard_Paste(value)
{
	A_Clipboard := value
	
	Send("^v")
}

Clipboard_ToUpper(*) 
{
	input:= Clipboard_Copy()
	output := StrUpper(input )

	Clipboard_Paste(output)
}

Clipboard_ToLower(*) 
{
	input:= Clipboard_Copy()
	output := StrLower(input )

	Clipboard_Paste(output)
}

Clipboard_ToSingleQuoted(*)
{
	input:= Clipboard_Copy()
	output := RegExReplace(input, "(\b\w+\b)" , "'$1'")
	
	Clipboard_Paste(output)
}