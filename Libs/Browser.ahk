#Requires AutoHotkey v2.0

#Include WindowApp.ahk

class Browser
{
    static GetURL()
    {
        if (!WindowApp.IsBrowserActive())
        {
            return ""
        }

        hwnd := WinExist("A")
        if (!hwnd)
        {
            return ""
        }

        url := Browser.GetURLFromUIAutomation(hwnd)
        if (url != "")
        {
            return url
        }

        return Browser.GetURLFromAddressBar(hwnd)
    }

    static GetURLFromUIAutomation(hwnd)
    {
        static S_OK := 0
        static TreeScope_Descendants := 4
        static UIA_ControlTypePropertyId := 30003
        static UIA_DocumentControlTypeId := 50030
        static UIA_EditControlTypeId := 50004
        static UIA_ValueValuePropertyId := 30045

        try
        {
            automation := ComObject(
                "{FF48DBA4-60EF-4201-AA87-54103EEF594E}",
                "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}"
            )

            root := ComValue(13, 0)
            hResult := ComCall(6, automation, "Ptr", hwnd, "Ptr*", root)
            if (hResult != S_OK || !root.Ptr)
            {
                return ""
            }

            winClass := WinGetClass("ahk_id " hwnd)
            controlTypeId := RegExMatch(winClass, "i)Chrome")
                ? UIA_DocumentControlTypeId
                : UIA_EditControlTypeId

            propertyValue := Buffer(8 + 2 * A_PtrSize, 0)
            NumPut("UShort", 3, propertyValue, 0)
            NumPut("Ptr", controlTypeId, propertyValue, 8)

            condition := ComValue(13, 0)
            if (A_PtrSize = 8)
            {
                hResult := ComCall(
                    23,
                    automation,
                    "UInt", UIA_ControlTypePropertyId,
                    "Ptr", propertyValue,
                    "Ptr*", condition
                )
            }
            else
            {
                hResult := ComCall(
                    23,
                    automation,
                    "UInt", UIA_ControlTypePropertyId,
                    "UInt64", NumGet(propertyValue, 0, "UInt64"),
                    "UInt64", NumGet(propertyValue, 8, "UInt64"),
                    "Ptr*", condition
                )
            }

            if (hResult != S_OK || !condition.Ptr)
            {
                return ""
            }

            element := ComValue(13, 0)
            hResult := ComCall(
                5,
                root,
                "UInt", TreeScope_Descendants,
                "Ptr", condition,
                "Ptr*", element
            )

            if (hResult != S_OK || !element.Ptr)
            {
                return ""
            }

            valueVariant := Buffer(8 + 2 * A_PtrSize, 0)
            hResult := ComCall(
                10,
                element,
                "UInt", UIA_ValueValuePropertyId,
                "Ptr", valueVariant
            )

            if (hResult != S_OK)
            {
                return ""
            }

            valuePtr := NumGet(valueVariant, 8, "Ptr")
            url := valuePtr ? StrGet(valuePtr, "UTF-16") : ""
            DllCall("OleAut32\VariantClear", "Ptr", valueVariant)

            return url
        }
        catch Error
        {
            return ""
        }
    }

    static GetURLFromAddressBar(hwnd)
    {
        if (!WinActive("ahk_id " hwnd))
        {
            return ""
        }

        clipboardBackup := ClipboardAll()

        try
        {
            A_Clipboard := ""
            Send("^l")
            Sleep(50)
            Send("^c")

            if (!ClipWait(0.5))
            {
                return ""
            }

            return A_Clipboard
        }
        catch Error
        {
            return ""
        }
        finally
        {
            if (WinActive("ahk_id " hwnd))
            {
                Send("{Esc}")
            }

            A_Clipboard := clipboardBackup
        }
    }

    static IsActive()
    {
        return WindowApp.IsBrowserActive()
    }
}
