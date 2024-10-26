#Requires AutoHotkey v2.0

Std_Paste(text, inputType := 1) 
{
	if (inputType = 1)
	{
		SendInput("{Raw}" . text)
	}
	else
	{
        A_Clipboard := text
		ClipWait(2, 0)
        Send("{Ctrl down}v{Ctrl up}")
	}
}

