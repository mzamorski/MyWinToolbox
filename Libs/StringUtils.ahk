
class StringUtils
{
	static ToSingleLine(input)
	{
		return RegExReplace(input, "[`r`n]+", " ")
	}

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
	
	static WordWrap(input, column := 80, indentChar := "")
	{
		indentLength := StrLen(indentChar)
		out := ""

		for line in StrSplit(input, "`n") ; Dzieli tekst na linie
		{
			if (StrLen(line) > column)
			{
				pos := 1
				wordList := StrSplit(line, " ")

				for word in wordList
				{
					loopLength := StrLen(word)
					if (pos + loopLength <= column)
					{
						out .= (pos = 1 ? "" : " ") word
						pos += loopLength + 1
					}
					else
					{
						pos := loopLength + 1 + indentLength
						out .= "`n" indentChar word
					}
				}
				out .= "`n"
			}
			else
			{
				out .= line "`n"
			}
		}

		return SubStr(out, 1, -1)
	}

	static Random(length := 16) 
	{
		static chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,<>.?/"
		output := ""
		
		Loop length {
			randomIndex := Random(1, StrLen(chars))
			output .= SubStr(chars, randomIndex, 1)
		}

		return output
	}

	static RemoveComments(value, commentChars := ";#")
	{
		return RegExReplace(value, "\s*[" . commentChars . "].*$", "")
	}

	static EndsWith(value, char)
	{
		return (SubStr(value, -1) == char)
	}

	static IsNullOrWhiteSpace(value)
	{
		return (!value || Trim(value) = STRING_EMPTY)
	}

	; --------------------------------------------------------------------------------
	; AHK-specific.

	class AHK
	{
		/**
		 * Replaces matches of a regular expression pattern with a formatted string.
		 *
		 * This function scans a string for repeated occurrences of a specific 
		 * pattern (e.g., `\n\n`) and replaces them with a formatted string 
		 * that can include the count of consecutive matches. 
		 * 
		 * The format string can use placeholders such as `{1:d}` for the match count.
		 * 
		 * Examples:
 		 * - "{Enter {1:d}}", "{Tab {1:d}}"
		 */
		static Replace(input, pattern, replacementFormat)
		{
			output := ""
			startIndex := 1

			while pos := RegExMatch(input, pattern, &match, startIndex)
			{
				partLen := pos - startIndex
				part := SubStr(input, startIndex, partLen)
				
				replacement := Format(replacementFormat, match.Len)
				output := output part replacement
				
				startIndex := pos + match.Len
			}

			partLen := StrLen(input)
			if (startIndex <= partLen)
			{
				part := SubStr(input, startIndex, partLen)
				output := output part
			}

			return output
		}
	}
}