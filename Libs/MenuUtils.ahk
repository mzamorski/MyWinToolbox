#Requires AutoHotkey v2.0

#include Collections.ahk

class MenuUtils
{
    static INI_MENU_SEPARATOR_MARKER := "--"

    static Build(entries, callback)
    {
        ; Check if the argument is of type Dictionary
        if !entries is Map 
        {
            throw TypeError("The argument must be a ``" . Type(Map) . "`` object.")
        }

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

    static IsChecked(menuHandle, itemPos)
    {
        static MF_BYPOSITION := 0x00000400
        static MF_CHECKED    := 0x00000008

        menuState := DllCall("user32\GetMenuState", "Ptr", menuHandle, "UInt", itemPos - 1, "UInt", MF_BYPOSITION, "UInt")
        if (menuState = -1)
        {
            return -1
        }

        return !!(menuState & MF_CHECKED)
    }
}