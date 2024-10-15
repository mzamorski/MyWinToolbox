#Requires AutoHotkey v2.0

Std_Paste(text, inputType := 0) 
{
	if (inputType = 1)
	{
		SendInput(text)
	}
	else
	{
        A_Clipboard := text
        Send("^v")
		ClipWait()
	}
}