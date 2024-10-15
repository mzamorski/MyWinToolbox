#Requires AutoHotkey v2.0

class DateTimeUtils
{
    static GetCurrentDate()
    {
        ; Format: 'YYYYMMDDHHmmSS'.
        currentDateTime := A_Now  
            
        ; Extract the year, month, and day.
        year := SubStr(currentDateTime, 1, 4)
        month := SubStr(currentDateTime, 5, 2)
        day := SubStr(currentDateTime, 7, 2)

        ; Format the date as 'YYYY-MM-DD'.
        return year . "-" . month . "-" . day
    }
}