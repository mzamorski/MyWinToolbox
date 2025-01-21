#Requires AutoHotkey v2.0

#Include Std.ahk

Clipboard_Copy() 
{
    Send("^c")
	Sleep(100)	; Add a short delay to allow the clipboard to update
    ClipWait(2)

    return A_Clipboard
}

Clipboard_Paste(value)
{
	Std_Paste(value)
}

Clipboard_ToUpper(*) 
{
	input:= Clipboard_Copy()
	output := StrUpper(input)

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
	output := "'" . input . "'"
	
	Clipboard_Paste(output)
}

Clipboard_ToDoubleQuoted(*)
{
	input:= Clipboard_Copy()
	output := '"' . input . '"'
	
	Clipboard_Paste(output)
}

Clipboard_Replicate_80(*)
{
	input := Clipboard_Copy()
	output := StringUtils.Replicate(input, 80)
	
	Clipboard_Paste(output)
}

Clipboard_Replicate_120(*)
{
	input := Clipboard_Copy()
	output := StringUtils.Replicate(input, 120)
	
	Clipboard_Paste(output)
}

Clipboard_ToSingleBackslash(*)
{
	input := Clipboard_Copy()
	output := RegExReplace(input, "\\{2,}" , "\")
	
	Clipboard_Paste(output)
}

Clipboard_ToDoubleBackslash(*)
{
	input := Clipboard_Copy()
	output := RegExReplace(input, "(?<!\\)\\(?!\\)" , "\\")
	
	Clipboard_Paste(output)
}

Clipboard_AddBraket(*)
{
	input := Clipboard_Copy()
	output := RegExReplace(input, "\b(?<!\[)(\w+)(?!\[)\b" , "[$1]")
	
	Clipboard_Paste(output)
}

Clipboard_RemoveBraket(*)
{
	input := Clipboard_Copy()
	output := RegExReplace(input, "\[(\w+)\]" , "$1")
	
	Clipboard_Paste(output)
}

Clipboard_AddThousandsSeparators(*)
{
	input := Clipboard_Copy()
	output := RegExReplace(input, "\G\d+?(?=(\d{3})+(?:\D|$))", "$0.")

	Clipboard_Paste(output)
}

Clipboard_BreakLines_80(*)
{
	input := Clipboard_Copy()
	output := StringUtils.BreakLine(input, 80)
	
	Clipboard_Paste(output)
}

Clipboard_BreakLines_120(*)
{
	input := Clipboard_Copy()
	output := StringUtils.BreakLine(input, 120)
	
	Clipboard_Paste(output)
}