#Requires AutoHotkey v2.0

class Uri
{
    static ExtractHostName(url)
    {
        if RegExMatch(url, "i)://(?:www\.)?([^./]+)\.", &m)
        {
            return m[1]
        }

        return ""
    }

    static Contains(url, pattern, caseInsensitive := true)
    {
        flag := caseInsensitive ? "i" : ""

        return RegExMatch(url, flag . ")" . pattern)
    }
}