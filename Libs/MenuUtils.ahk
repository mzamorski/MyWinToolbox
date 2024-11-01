#Requires AutoHotkey v2.0

#include Collections.ahk

class MenuUtils
{
    static INI_MENU_SEPARATOR_MARKER := "--"

    static Build(entries, callback)
    {
        ; Check if the argument is of type Dictionary
        ; if !entries is Dictionary 
        ; {
        ;     throw TypeError("The argument must be a ``" . Type(Dictionary) . "`` object.")
        ; }

        contextMenu := Menu()
        for key, value in entries
        {
            if (key == MenuUtils.INI_MENU_SEPARATOR_MARKER)
            {
                contextMenu.Add()    
                continue
            }

            contextMenu.Add(key, callback)
        }

        return contextMenu
    }
}