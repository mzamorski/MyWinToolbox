#Requires AutoHotkey v2.0

#Include StringUtils.ahk
FileEncoding("UTF-8")

global UNKNOWN := "<unknown>"

Ini_ReadOrDefault(filePath, section, key := "", defaultValue := UNKNOWN) 
{
    value := IniRead(filePath, section, key, defaultValue)
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
    entries := Map()

    entryLines := IniRead(filePath, section)
    for line in StrSplit(entryLines, "`n")
    {
        key := StrSplit(line, "=")[1]
        value := Ini_ReadOrDefault(filePath, section, key)

        entries[key] := value
    }

    return entries
}