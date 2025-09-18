#Requires AutoHotkey v2.0

#Include StringUtils.ahk
#Include Collections.ahk
#Include Constants.ahk
#Include Std.ahk

FileEncoding("UTF-8")

Ini_ReadOrDefault(filePath, section, key := "", defaultValue := UNKNOWN) 
{
    if !FileExist(filePath) 
    {
        throw IOError(filePath)
    } 

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
    entries := OrderedMap()
    entries.CaseSense := false

    entryLines := IniRead(filePath, section)
    if (StringUtils.IsNullOrWhiteSpace(entryLines))
    {
        return entries
    }

    for line in StrSplit(entryLines, "`n")
    {
        trimmedLine := Trim(line)

        if (StringUtils.IsNullOrWhiteSpace(trimmedLine))
        {
            continue
        }

        firstChar := SubStr(trimmedLine, 1, 1)
        if (firstChar = ";" || firstChar = "#")
        {
            continue
        }

        key := Trim(StrSplit(trimmedLine, "=", , 2)[1])
        if (StringUtils.IsNullOrWhiteSpace(key))
        {
            continue
        }

        value := Ini_ReadOrDefault(filePath, section, key)

        entries[key] := value
    }

    return entries
}