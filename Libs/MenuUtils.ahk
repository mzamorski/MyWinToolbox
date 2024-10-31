#Requires AutoHotkey v2.0

#include Collections.ahk

class MenuUtils
{
    static Build(entries, callback)
    {
        ; Check if the argument is of type Dictionary
        ; if !entries is Dictionary 
        ; {
        ;     throw TypeError("The argument must be a ``" . Type(Dictionary) . "`` object.")
        ; }

        menux := Menu()
        for key, value in entries
        {
            menux.Add(key, callback)
        }

        return menux
    }
}