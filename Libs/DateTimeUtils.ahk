#Requires AutoHotkey v2.0

class DateTimeUtils
{
    static GetCurrentDate(includeTime := false)
    {
        ; Format: 'YYYYMMDDHHmmSS'.
        currentDateTime := A_Now  
            
        ; Extract the year, month, and day.
        year := SubStr(currentDateTime, 1, 4)
        month := SubStr(currentDateTime, 5, 2)
        day := SubStr(currentDateTime, 7, 2)

        ; Format the date as 'YYYY-MM-DD'.
        formattedDate := year . "-" . month . "-" . day

        if includeTime 
        {
            hour := SubStr(currentDateTime, 9, 2)
            minute := SubStr(currentDateTime, 11, 2)
            second := SubStr(currentDateTime, 13, 2)

            ; If `includeTime` is true, append the time in format 'HH:mm:SS'.
            formattedDate .= " " . hour . ":" . minute . ":" . second
        }
        
        return formattedDate
    }
}