#Requires AutoHotkey v2.0

class DateTimeUtils
{
    static GetCurrentDate(includeTime := false)
    {
        ; Format: 'YYYYMMDDHHmmSS'.
        currentDateTime := A_Now  
      
        ; Format the date as 'YYYY-MM-DD'.
        format := "yyyy-MM-dd"

        if includeTime 
        {
            format .= " HH:mm:ss"
        }
        
        return FormatTime(currentDateTime, format)
    }

    static GetCurrentISO8601Date(useLocalTime := false)
    {
        currentDateTime := useLocalTime ? A_Now : A_NowUTC

        ; Get the current time in ISO 8601 format.
        currentTime := FormatTime(currentDateTime, "yyyy-MM-dd'T'HH:mm:ssZ")
        
        return currentTime
    }
}