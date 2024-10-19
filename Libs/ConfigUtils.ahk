#Requires AutoHotkey v2.0

#Include ..\Constants.ahk

IniReadOrDefault(filePath, section, key, defaultValue := UNKNOWN) 
{
    value := IniRead(filePath, section, key, "")

    if (value = "")
    {
        return defaultValue
    }

    return value
}