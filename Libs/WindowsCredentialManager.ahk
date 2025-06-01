class WindowsCredentialManager
{
    ; Static class fields for structure offsets
    static Offset_Type               := 4
    static Offset_TargetName         := 8
    static Offset_CredentialBlobSize := 16 + A_PtrSize * 2
    static Offset_CredentialBlob     := 16 + A_PtrSize * 3
    static Offset_Persist            := 16 + A_PtrSize * 4
    static Offset_UserName           := 24 + A_PtrSize * 6

    static Write(targetName, userName, password, persistType := 3)
    {
        local cred := Buffer(A_PtrSize == 8 ? 80 : 60, 0)
        local cbPassword := StrLen(password) * 2

        ; Accessing static class fields using ClassName.FieldName
        NumPut("UInt", 1, cred, WindowsCredentialManager.Offset_Type)
        NumPut("Ptr", StrPtr(targetName), cred, WindowsCredentialManager.Offset_TargetName)
        NumPut("UInt", cbPassword, cred, WindowsCredentialManager.Offset_CredentialBlobSize)
        NumPut("Ptr", StrPtr(password), cred, WindowsCredentialManager.Offset_CredentialBlob)
        NumPut("UInt", persistType, cred, WindowsCredentialManager.Offset_Persist)
        NumPut("Ptr", StrPtr(userName), cred, WindowsCredentialManager.Offset_UserName)
        
        return DllCall("Advapi32.dll\CredWriteW",
            "Ptr", cred,
            "UInt", 0,
            "UInt")
    }

    static Read(targetName)
    {
        local pCred := 0

        if (!DllCall("Advapi32.dll\CredReadW",
            "WStr", targetName, "UInt", 1, "UInt", 0, "Ptr*", &pCred, "UInt"))
        {
            return
        }

        if (!pCred)
        {
            return
        }

        local credData := Map()

        credData.Name := StrGet(NumGet(pCred, WindowsCredentialManager.Offset_TargetName, "UPtr"), "UTF-16")
        credData.UserName := StrGet(NumGet(pCred, WindowsCredentialManager.Offset_UserName, "UPtr"), "UTF-16")
        
        local len := NumGet(pCred, WindowsCredentialManager.Offset_CredentialBlobSize, "UInt")
        if (len > 0)
        {
            credData.Password := StrGet(NumGet(pCred, WindowsCredentialManager.Offset_CredentialBlob, "UPtr"), len // 2, "UTF-16")
        }
        else
        {
            credData.Password := ""
        }
        
        DllCall("Advapi32.dll\CredFree", "Ptr", pCred)
        return credData
    }

    static Delete(targetName)
    {
        return DllCall("Advapi32.dll\CredDeleteW",
            "WStr", targetName, "UInt", 1, "UInt", 0, "UInt")
    }
}