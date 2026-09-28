#Requires AutoHotkey v2.0

#Include WindowApp.ahk

class Browser
{
    static GetURL(allowInteractiveFallback := true)
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

        return allowInteractiveFallback
            ? Browser.GetURLFromAddressBar(hwnd)
            : ""
    }

    static GetURLFromUIAutomation(hwnd)
    {
        static S_OK := 0
        static UIA_EditControlTypeId := 50004
        static UIA_DocumentControlTypeId := 50030

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

            reverseEditSearch := false
            try
            {
                exeName := StrLower(WinGetProcessName("ahk_id " hwnd))
                ; Chrome/Brave expose the browser chrome after page content in
                ; the UIA tree, so searching Edit controls from the end avoids
                ; picking an HTML text box before the omnibox.
                reverseEditSearch := exeName = "chrome.exe" || exeName = "brave.exe"
            }

            url := Browser.GetURLFromUIAControlType(
                automation,
                root,
                UIA_EditControlTypeId,
                reverseEditSearch
            )
            if (url != "")
            {
                return url
            }

            ; Chromium can also expose the current page URL as the Value of its
            ; Document element. This remains non-interactive and is useful when
            ; the address bar is not exposed (for example in some full-screen
            ; or accessibility-tree states).
            return Browser.GetURLFromUIAControlType(
                automation,
                root,
                UIA_DocumentControlTypeId,
                false
            )
        }
        catch Error
        {
            return ""
        }
    }

    static GetURLFromUIAControlType(automation, root, controlTypeId, reverseSearch := false)
    {
        static S_OK := 0
        static TreeScope_Descendants := 4
        static UIA_ControlTypePropertyId := 30003
        static UIA_ValueValuePropertyId := 30045

        condition := Browser.CreateUIAPropertyCondition(
            automation,
            UIA_ControlTypePropertyId,
            controlTypeId
        )
        if (!condition || !condition.Ptr)
        {
            return ""
        }

        elements := ComValue(13, 0)
        hResult := ComCall(
            6,
            root,
            "UInt", TreeScope_Descendants,
            "Ptr", condition,
            "Ptr*", elements
        )

        if (hResult != S_OK || !elements.Ptr)
        {
            return ""
        }

        hResult := ComCall(3, elements, "Int*", &elementCount := 0)
        if (hResult != S_OK || elementCount <= 0)
        {
            return ""
        }

        Loop elementCount
        {
            elementIndex := reverseSearch
                ? elementCount - A_Index
                : A_Index - 1

            element := ComValue(13, 0)
            hResult := ComCall(4, elements, "Int", elementIndex, "Ptr*", element)
            if (hResult != S_OK || !element.Ptr)
            {
                continue
            }

            value := Browser.GetUIAStringProperty(element, UIA_ValueValuePropertyId)
            url := Browser.NormalizeURLCandidate(value)
            if (url != "")
            {
                return url
            }
        }

        return ""
    }

    static CreateUIAPropertyCondition(automation, propertyId, integerValue)
    {
        static S_OK := 0

        ; VARIANT(VT_I4) with the integer payload at offset 8.
        propertyValue := Buffer(8 + 2 * A_PtrSize, 0)
        NumPut("UShort", 3, propertyValue, 0)
        NumPut("Int", integerValue, propertyValue, 8)

        condition := ComValue(13, 0)

        if (A_PtrSize = 8)
        {
            hResult := ComCall(
                23,
                automation,
                "UInt", propertyId,
                "Ptr", propertyValue,
                "Ptr*", condition
            )
        }
        else
        {
            hResult := ComCall(
                23,
                automation,
                "UInt", propertyId,
                "UInt64", NumGet(propertyValue, 0, "UInt64"),
                "UInt64", NumGet(propertyValue, 8, "UInt64"),
                "Ptr*", condition
            )
        }

        return hResult = S_OK ? condition : 0
    }

    static GetUIAStringProperty(element, propertyId)
    {
        static S_OK := 0
        static VT_BSTR := 8

        valueVariant := Buffer(8 + 2 * A_PtrSize, 0)

        try
        {
            hResult := ComCall(
                10,
                element,
                "UInt", propertyId,
                "Ptr", valueVariant
            )

            if (hResult != S_OK || NumGet(valueVariant, 0, "UShort") != VT_BSTR)
            {
                return ""
            }

            valuePtr := NumGet(valueVariant, 8, "Ptr")
            return valuePtr ? StrGet(valuePtr, "UTF-16") : ""
        }
        finally
        {
            DllCall("OleAut32\VariantClear", "Ptr", valueVariant)
        }
    }

    static NormalizeURLCandidate(value)
    {
        value := Trim(value)
        if (value = "" || InStr(value, " ") || InStr(value, "`t"))
        {
            return ""
        }

        if RegExMatch(value, "i)^[a-z][a-z0-9+.-]*://")
        {
            return value
        }

        if RegExMatch(value, "i)^(about|chrome|edge|brave|file|view-source|devtools):")
        {
            return value
        }

        ; Chromium may expose a display-form address without the https://
        ; prefix. Accept a domain/localhost shape and normalize it so existing
        ; URL match rules keep working with full URLs.
        if RegExMatch(
            value,
            "i)^(localhost|\[[0-9a-f:]+\]|(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,})(?::\d+)?(?:[/?#]|$)"
        )
        {
            return "https://" value
        }

        return ""
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
