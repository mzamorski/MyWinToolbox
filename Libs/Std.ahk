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

ThrowNotImplementedException(message := "", extra := "") {
    if (message = "")
	{
        message := "Not implemented."
	}

    throw Error(message, A_ThisFunc, extra)
}

; Usage: throw NotImplementedError(A_ThisFunc, "TODO: add SSMS scope predicate")
class NotImplementedError extends Error {
    __New(methodName := "", details := "") {
        message := (methodName != "")
            ? "Not implemented: " . methodName
            : "Not implemented."

        if (details != "")
            message .= " — " . details

        this.Message := message
        this.What := methodName
        this.Extra := details
        this.File := A_ScriptFullPath, this.Line := A_LineNumber
    }
}