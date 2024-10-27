#Requires AutoHotkey v2.0

#Include StringUtils.ahk

global UNKNOWN := "<unknown>"

Ini_ReadOrDefault(filePath, section, key := "", defaultValue := UNKNOWN) 
{
    value := IniRead(filePath, section, key, defaultValue)

    return StringUtils.RemoveComments(value)
}

Ini_GetSectionEntries(filePath, section)
{
    entries := []

    entryLines := IniRead(filePath, section)
    for line in StrSplit(entryLines, "`n")
    {
        key := StrSplit(line, "=")[1]
        value := Ini_ReadOrDefault(filePath, section, key)

        entries.Push({Key: key, Value: value})
    }

    return entries
}