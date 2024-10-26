
class StringUtils
{
	static Replicate(input, count)
	{
		if (count <= 0)
		{
			return input
		}
		
		return StrReplace(Format("{:" count "}","")," ", input)
	}

	static BreakLine(input, maxLineLength := 80, breakOnWords := 1)
	{
		output := ""
		lineLength := 0
		line := ""
	
		; Split input into words or treat as a single "word".
		if (breakOnWords)
		{
			words := StrSplit(input, A_Space) ; Split the input into words.
		}
		else
		{
			words := [input] ; Treat the entire input as a single "word".
		}
	
		for index, word in words
		{
			; Handle long words by breaking them into smaller chunks.
			while (StrLen(word) > maxLineLength)
			{
				; Add the part of the word that fits within the max line length.
				output .= SubStr(word, 1, maxLineLength) . "`n"
				
				; Remove the part that was added.
				word := SubStr(word, maxLineLength + 1)
			}
	
			; Check if adding the word exceeds the max line length.
			if (lineLength + StrLen(word) > maxLineLength)
			{
				; Add the current line to output and start a new line.
				output .= line . "`n"
	
				; Start a new line with the current word.
				line := word 
				lineLength := StrLen(word) 
			}
			else
			{
				; If the line is not empty, add a space.
				if (lineLength > 0) 
				{
					line .= " "
					lineLength++
				}
	
				; Add the word to the current line.
				line .= word 
				lineLength += StrLen(word)
			}
		}
	
		; Add any remaining text in the current line to the output.
		if (lineLength > 0)
		{
			output .= line
		}
	
		return output
	}
	
	static Random(length := 16) 
	{
		chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,<>.?/"
		output := ""
		
		Loop length {
			randomIndex := Random(1, StrLen(chars))
			output .= SubStr(chars, randomIndex, 1)
		}

		return output
	}
}