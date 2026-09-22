;========================================================================================================================
; MENUS
;========================================================================================================================

Menu_StringGenerator_RandomGuid(*)
{
	guid := ComObject("Scriptlet.TypeLib").GUID
    
	output := StrReplace(guid, "{", "")
    output := StrReplace(output, "}", "")

	Clipboard_Paste(output)
}

Menu_StringGenerator_RandomString_16(*)
{
	output:= StringUtils.Random(16)

	Clipboard_Paste(output)
}

Menu_StringGenerator_RandomString_32(*)
{
	output:= StringUtils.Random(32)

	Clipboard_Paste(output)
}

Menu_StringGenerator_Dummy(*)
{
	Std_Paste(DummyText)
}

Menu_StringGenerator_CurrentDate(*)
{
	output := DateTimeUtils.GetCurrentDate()

	Clipboard_Paste(output)
}

Menu_StringGenerator_CurrentDateTime(*)
{
	output := DateTimeUtils.GetCurrentDate(true)

	Clipboard_Paste(output)
}

Menu_StringGenerator_CurrentDateTime_ISO8601(*)
{
	output := DateTimeUtils.GetCurrentISO8601Date()

	Clipboard_Paste(output)
}

Menu_StringGenerator_Separator_120(*)
{
	output := StringUtils.Replicate("-", 120)

	Clipboard_Paste(output)
}

Menu_StringGenerator_Separator_80(*)
{
	output := StringUtils.Replicate("-", 80)

	Clipboard_Paste(output)
}

Menu_StringGenerator_Separator_50(*)
{
	output := StringUtils.Replicate("-", 50)

	Clipboard_Paste(output)
}


;========================================================================================================================
; CONTEXT-MENUS
;========================================================================================================================

;--------------------------------------------------------------------------------
; Create 'Format' menu. 

Menu_Format_Encrypt_RC4(*)
{
	input:= Clipboard_Copy()
	output := CryptoUtils.Encrypt(input, Secret)

	Clipboard_Paste(output)
}

Menu_Format_Decrypt_RC4(*)
{
	input:= Clipboard_Copy()
	output := CryptoUtils.Decrypt(input, Secret)

	Clipboard_Paste(output)
}

Menu_Format_Encrypt_BASE64(*)
{
	input:= Clipboard_Copy()
	output := CryptoUtils.EncryptBase64(input)

	Clipboard_Paste(output)
}

Menu_Format_Decrypt_BASE64(*)
{
	input:= Clipboard_Copy()
	output := CryptoUtils.DecryptBase64(input)

	Clipboard_Paste(output)
}

Menu_Format_Clipboard_ToLower(*)
{
	input:= Clipboard_Copy()
	output := StringUtils.ToSingleLine(input)

	Clipboard_Paste(output)
}

Menu_Format_AHK_ToSpecialKeys(*)
{
	input:= Clipboard_Copy()
	
	output := StringUtils.AHK.Replace(input, "(`r?`n)+", "{Enter {1:d}}")
	output := StringUtils.AHK.Replace(output, "(`t)+", "{Tab {1:d}}")

	Clipboard_Paste(output)
}

Menu_Format_Sort_Ascending(*)
{
	Menu_Format_Sort(true)
}

Menu_Format_Sort_Descending(*)
{
	Menu_Format_Sort(false)
}

Menu_Format_Sort(ascending := true)
{
	input := Clipboard_Copy()
	if !input 
	{
		return
	}
	
    output := ascending ? Sort(input) : Sort(input, "R")

	Clipboard_Paste(output)
}

Menu_Format_SQL_ToValuesTable(*)
{
	input := Clipboard_Copy()
	if !input 
	{
		return
	}

	lines := StrSplit(input, "`n", "`r")
	values := []

	for line in lines 
	{
		line := Trim(line)
		if (line != "")
		{
			values.Push("('" line "')")
		}
	}

	sqlValues := StringUtils.Join(values, ",`n")
	output := "SELECT *`nFROM (VALUES `n" sqlValues "`n) AS v(Name);"

	Clipboard_Paste(output)
}

Menu_Format_SQL_ToQuotedList(*)
{
	input := Clipboard_Copy()
	output := STRING_EMPTY

	separator := STRING_EMPTY

	lines := StrSplit(input, "`n", "`r")
	for i, line in lines
	{
		line := Trim(line)
		if (!StringUtils.IsNullOrWhiteSpace(line))
		{
			output .= separator . "'" . line . "'`n"
		}

		if (!separator)
		{
			separator := ","
		}
	}

	Clipboard_Paste(output)
}

;--------------------------------------------------------------------------------

formatMenu := Menu()
formatMenu.SetColor("cbe7b6")
formatMenu.Add("To&Upper", Clipboard_ToUpper)
formatMenu.Add("To&Lower", Clipboard_ToLower)

subMenu := Menu()
subMenu.Add("&Ascending", Menu_Format_Sort_Ascending)
subMenu.Add("&Descending", Menu_Format_Sort_Descending)
formatMenu.Add("&Sort", subMenu)

formatMenu.Add("ToSingleLine", Menu_Format_Clipboard_ToLower)
formatMenu.Add("To&Quoted.Single", Clipboard_ToSingleQuoted)
formatMenu.Add("To&Quoted.Double", Clipboard_ToDoubleQuoted)

subMenu := Menu()
subMenu.Add("80", Clipboard_BreakLines_80)
subMenu.Add("120", Clipboard_BreakLines_120)
formatMenu.Add("&BreakLines", subMenu)

formatMenu.Add()

subMenu := Menu()
subMenu.Add("80", Clipboard_Replicate_80)
subMenu.Add("120", Clipboard_Replicate_120)
formatMenu.Add("Char.Replicate", subMenu)

formatMenu.Add()

formatMenu.Add("Path.ToSingleBackslash", Clipboard_ToSingleBackslash)
formatMenu.Add("Path.ToDoubleBackslash", Clipboard_ToDoubleBackslash)
formatMenu.Add("Path.ToBackslash", Clipboard_ToBackslash)

formatMenu.Add()

formatMenu.Add("SQL.AddBraket", Clipboard_AddBraket)
formatMenu.Add("SQL.RemoveBraket", Clipboard_RemoveBraket)
formatMenu.Add("SQL.ToQuotedList", Menu_Format_SQL_ToQuotedList)
formatMenu.Add("SQL.ToValuesTable", Menu_Format_SQL_ToValuesTable)

formatMenu.Add()

formatMenu.Add("&Number.AddThousandsSeparators", Clipboard_AddThousandsSeparators)

formatMenu.Add()

subMenu := Menu()
subMenu.Add("Encrypt", Menu_Format_Encrypt_RC4)
subMenu.Add("Decrypt", Menu_Format_Decrypt_RC4)
formatMenu.Add("&Crypto.RC4", subMenu)

subMenu := Menu()
subMenu.Add("Encrypt", Menu_Format_Encrypt_BASE64)
subMenu.Add("Decrypt", Menu_Format_Decrypt_BASE64)

formatMenu.Add("Crypto.BASE64", subMenu)

; AHK.ToSpecialKeys
formatMenu.Add()
formatMenu.Add("AHK.ToSpecialKeys", Menu_Format_AHK_ToSpecialKeys)

;--------------------------------------------------------------------------------
; Create 'Stringgenerator' menu. 

Menu_UserSignature(itemName, itemPos, menu)
{
    value := UserSignatures[itemName]
    Std_Paste(value)
}

stringGeneratorMenu := Menu()
stringGeneratorMenu.SetColor("cee1f8")
stringGeneratorMenu.Add("&Random.Guid", Menu_StringGenerator_RandomGuid)

subMenu := Menu()
subMenu.Add("16", Menu_StringGenerator_RandomString_16)
subMenu.Add("32", Menu_StringGenerator_RandomString_32)
subMenu.Add("Dummy", Menu_StringGenerator_Dummy)
stringGeneratorMenu.Add("&Random.String", subMenu)

stringGeneratorMenu.Add()

stringGeneratorMenu.Add("&Date.Current", Menu_StringGenerator_CurrentDate)

subMenu := Menu()
subMenu.Add("Local", Menu_StringGenerator_CurrentDateTime)
subMenu.Add("UTC ISO-8601", Menu_StringGenerator_CurrentDateTime_ISO8601)

stringGeneratorMenu.Add("&DateTime.Current", subMenu)
stringGeneratorMenu.Add()

subMenu := Menu()
subMenu.Add("50", Menu_StringGenerator_Separator_50)
subMenu.Add("80", Menu_StringGenerator_Separator_80)
subMenu.Add("120", Menu_StringGenerator_Separator_120)

stringGeneratorMenu.Add("&Separator", subMenu)
stringGeneratorMenu.Add()

signaturesMenu := Menu()
for key, value in UserSignatures
{
    signaturesMenu.Add(key, Menu_UserSignature)
}

stringGeneratorMenu.Add("UserSignatures", signaturesMenu)

;--------------------------------------------------------------------------------
; Create 'TextSnippet' menu. 

SNIPPET_TITLE_PROPERY := "Title"
SNIPPET_CONTENT_PROPERY := "Content"
SNIPPET_CONTENT_SEPARATOR := "--"

Menu_TextSnippetCallback(itemName, itemPos, menu, content := unset)
{
	SendInput(content)
}

textSnippetsMenu := Menu()
textSnippetsMenu.SetColor("b6e0e7")

for snippetName in TextSnippetsJson
{
	subMenu := Menu()

	if (snippetName = SNIPPET_CONTENT_SEPARATOR)
	{
		textSnippetsMenu.Add()
		continue
	}

    snippets := TextSnippetsJson[snippetName]

    if (snippets.Length > 0)
    {
        for snippet in snippets
        {
            content := snippet[SNIPPET_CONTENT_PROPERY]

			if (content = SNIPPET_CONTENT_SEPARATOR)
			{
				subMenu.Add()
				continue
			}

            if (snippet.Has(SNIPPET_TITLE_PROPERY))
            {
                title := snippet[SNIPPET_TITLE_PROPERY]
            }
            else
            {
                title := content
            }
    
            subMenu.Add(title, Menu_TextSnippetCallback.Bind(,,, content))
        }

        textSnippetsMenu.Add(snippetName, subMenu)
    }
}

;--------------------------------------------------------------------------------
; Create 'EmojiMenu' menu. 

emojiMenu := Menu()
emojiMenu.Add("🤑 — Money-Mouth Face", (*) => Send("🤑"))
emojiMenu.Add("👍 — Thumbs Up", (itemName, *) => Send("👍"))
emojiMenu.Add("👎 — Thumbs Down", (itemName, *) => Send("👎"))
emojiMenu.Add("☠️ — Skull and Crossbones", (itemName, *) => Send("☠️"))
emojiMenu.Add("💨 — Dashing Away", (itemName, *) => Send("💨"))
