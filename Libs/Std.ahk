#Requires AutoHotkey v2.0

Std_Paste(text, inputType := 0) 
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

class IOError extends Error 
{
	static DEFAULT_MESSAGE := "File not found."

    __New(filePath := STRING_EMPTY, message := IOError.DEFAULT_MESSAGE) 
	{
        this.Message := message
		this.FilePath := filePath

		this.Line := A_LineNumber
		this.What := A_ThisFunc 
    }
}