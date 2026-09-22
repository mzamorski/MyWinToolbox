#Requires AutoHotkey v2.0

#Include StringUtils.ahk
#Include Collections.ahk
#Include Constants.ahk
#Include Std.ahk

FileEncoding("UTF-8")

Ini_GetUtf8Section(filePath, section)
{
    if !FileExist(filePath)
    {
        throw IOError(filePath)
    }

    entries := Map()
    entries.CaseSense := false
    currentSection := ""

    ; The Windows INI API treats a BOM-less UTF-8 file as an ANSI file.
    ; Parse it directly so localized values retain their Unicode characters.
    fileContent := FileRead(filePath, "UTF-8")
    for line in StrSplit(fileContent, "`n", "`r")
    {
        trimmedLine := Trim(line)
        if RegExMatch(trimmedLine, "^\[(.*)\]$", &sectionMatch)
        {
            currentSection := Trim(sectionMatch[1])
            continue
        }

        if (currentSection != section || trimmedLine = "" || SubStr(trimmedLine, 1, 1) = ";")
        {
            continue
        }

        separatorPos := InStr(line, "=")
        if (separatorPos)
        {
            entryKey := Trim(SubStr(line, 1, separatorPos - 1))
            entries[entryKey] := Trim(SubStr(line, separatorPos + 1))
        }
    }

    return entries
}

Ini_ReadOrDefault(filePath, section, key := "", defaultValue := UNKNOWN)
{
    entries := Ini_GetUtf8Section(filePath, section)
    value := entries.Has(key) ? entries[key] : defaultValue
    value := StringUtils.RemoveComments(value)
    value := StrReplace(value, "\n", "`n")

    ; Cleanup Latin-1 chars.
    value := StrReplace(value, "â€ž", "„")
    value := StrReplace(value, "â€ť", "”")
    value := StrReplace(value, "â€”", "—")
    
    return value
}

Ini_GetSectionEntries(filePath, section)
{
    entries := OrderedMap()
    entries.CaseSense := false

    for key, value in Ini_GetUtf8Section(filePath, section)
    {
        value := StringUtils.RemoveComments(value)
        entries[key] := StrReplace(value, "\n", "`n")
    }

    return entries
}
