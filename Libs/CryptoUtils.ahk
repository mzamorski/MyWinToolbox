#Requires AutoHotkey v2.0

#Include Externals\Class_CNG.ahk

class CryptoUtils
{
    static DpapiPrefix := "dpapi:v1:"

    ; Legacy RC4 helpers kept for backward compatibility and the Format menu.
    static Encrypt(input, key)
    {
        return Encrypt.String("RC4", "", input, key)
    }

    static Decrypt(input, key)
    {
        return Decrypt.String("RC4", "", input, key)
    }

    static Protect(input)
    {
        static CRYPTPROTECT_UI_FORBIDDEN := 0x1

        inputSize := StrPut(input, "UTF-8")
        inputBuffer := Buffer(inputSize, 0)
        StrPut(input, inputBuffer, "UTF-8")

        inputBlob := CryptoUtils.CreateDataBlob(
            inputBuffer.Ptr,
            inputSize
        )
        outputBlob := CryptoUtils.CreateDataBlob(0, 0)

        success := DllCall(
            "Crypt32\CryptProtectData",
            "Ptr", inputBlob.Ptr,
            "WStr", "MyWinToolbox password",
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", 0,
            "UInt", CRYPTPROTECT_UI_FORBIDDEN,
            "Ptr", outputBlob.Ptr,
            "Int"
        )

        if (!success)
        {
            throw OSError()
        }

        outputPtr := CryptoUtils.GetDataBlobPointer(outputBlob)
        outputSize := CryptoUtils.GetDataBlobSize(outputBlob)

        try
        {
            return CryptoUtils.DpapiPrefix
                . CryptoUtils.BinaryToBase64(outputPtr, outputSize)
        }
        finally
        {
            if (outputPtr)
            {
                DllCall("LocalFree", "Ptr", outputPtr, "Ptr")
            }
        }
    }

    static Unprotect(input, legacyKey := "")
    {
        if (CryptoUtils.IsProtectedValue(input))
        {
            return CryptoUtils.UnprotectDpapi(
                SubStr(input, StrLen(CryptoUtils.DpapiPrefix) + 1)
            )
        }

        if (legacyKey = "")
        {
            throw Error(
                "Legacy RC4 password requires [Settings] / Secret. "
                "Migrate the value to DPAPI from MyWinToolbox Configurator."
            )
        }

        return CryptoUtils.Decrypt(input, legacyKey)
    }

    static IsProtectedValue(input)
    {
        if (Type(input) != "String")
        {
            return false
        }

        prefixLength := StrLen(CryptoUtils.DpapiPrefix)

        return StrLower(SubStr(input, 1, prefixLength))
            = CryptoUtils.DpapiPrefix
    }

    static MigrateToDpapi(input, legacyKey := "")
    {
        if (CryptoUtils.IsProtectedValue(input))
        {
            return input
        }

        return CryptoUtils.Protect(
            CryptoUtils.Unprotect(input, legacyKey)
        )
    }

    static UnprotectDpapi(base64Value)
    {
        static CRYPTPROTECT_UI_FORBIDDEN := 0x1

        encryptedBuffer := CryptoUtils.Base64ToBinary(
            base64Value,
            &encryptedSize
        )

        inputBlob := CryptoUtils.CreateDataBlob(
            encryptedBuffer.Ptr,
            encryptedSize
        )
        outputBlob := CryptoUtils.CreateDataBlob(0, 0)

        success := DllCall(
            "Crypt32\CryptUnprotectData",
            "Ptr", inputBlob.Ptr,
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", 0,
            "UInt", CRYPTPROTECT_UI_FORBIDDEN,
            "Ptr", outputBlob.Ptr,
            "Int"
        )

        if (!success)
        {
            throw OSError()
        }

        outputPtr := CryptoUtils.GetDataBlobPointer(outputBlob)

        try
        {
            return outputPtr
                ? StrGet(outputPtr, "UTF-8")
                : ""
        }
        finally
        {
            if (outputPtr)
            {
                DllCall("LocalFree", "Ptr", outputPtr, "Ptr")
            }
        }
    }

    static CreateDataBlob(dataPointer, dataSize)
    {
        pointerOffset := A_PtrSize = 8 ? 8 : 4
        blob := Buffer(pointerOffset + A_PtrSize, 0)

        NumPut("UInt", dataSize, blob, 0)
        NumPut("Ptr", dataPointer, blob, pointerOffset)

        return blob
    }

    static GetDataBlobSize(blob)
    {
        return NumGet(blob, 0, "UInt")
    }

    static GetDataBlobPointer(blob)
    {
        pointerOffset := A_PtrSize = 8 ? 8 : 4
        return NumGet(blob, pointerOffset, "Ptr")
    }

    static BinaryToBase64(dataPointer, dataSize)
    {
        static CRYPT_STRING_BASE64 := 0x00000001
        static CRYPT_STRING_NOCRLF := 0x40000000
        flags := CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF

        if !DllCall(
            "Crypt32\CryptBinaryToStringW",
            "Ptr", dataPointer,
            "UInt", dataSize,
            "UInt", flags,
            "Ptr", 0,
            "UInt*", &charCount := 0,
            "Int"
        )
        {
            throw OSError()
        }

        output := Buffer(charCount * 2, 0)

        if !DllCall(
            "Crypt32\CryptBinaryToStringW",
            "Ptr", dataPointer,
            "UInt", dataSize,
            "UInt", flags,
            "Ptr", output.Ptr,
            "UInt*", &charCount,
            "Int"
        )
        {
            throw OSError()
        }

        return StrGet(output.Ptr, "UTF-16")
    }

    static Base64ToBinary(input, &outputSize)
    {
        static CRYPT_STRING_BASE64 := 0x00000001

        outputSize := 0

        if !DllCall(
            "Crypt32\CryptStringToBinaryW",
            "WStr", input,
            "UInt", 0,
            "UInt", CRYPT_STRING_BASE64,
            "Ptr", 0,
            "UInt*", &outputSize,
            "Ptr", 0,
            "Ptr", 0,
            "Int"
        )
        {
            throw OSError()
        }

        output := Buffer(outputSize, 0)

        if !DllCall(
            "Crypt32\CryptStringToBinaryW",
            "WStr", input,
            "UInt", 0,
            "UInt", CRYPT_STRING_BASE64,
            "Ptr", output.Ptr,
            "UInt*", &outputSize,
            "Ptr", 0,
            "Ptr", 0,
            "Int"
        )
        {
            throw OSError()
        }

        return output
    }

    static EncryptBase64(input, encoding := "UTF-8")
    {
        static CRYPT_STRING_BASE64 := 0x00000001
        static CRYPT_STRING_NOCRLF := 0x40000000

        outputBuffer := Buffer(StrPut(input, encoding))
        StrPut(input, outputBuffer, encoding)

        if !(DllCall("crypt32\CryptBinaryToStringW", "Ptr", outputBuffer, "UInt", outputBuffer.Size - 1, "UInt", (CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF), "Ptr", 0, "UInt*", &Size := 0))
            throw OSError()

        output := Buffer(Size << 1, 0)
        if !(DllCall("crypt32\CryptBinaryToStringW", "Ptr", outputBuffer, "UInt", outputBuffer.Size - 1, "UInt", (CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF), "Ptr", output, "UInt*", Size))
            throw OSError()

        return StrGet(output)
    }

    static DecryptBase64(input)
    {
        static CRYPT_STRING_BASE64 := 0x00000001

        if !(DllCall("crypt32\CryptStringToBinaryW", "Str", input, "UInt", 0, "UInt", CRYPT_STRING_BASE64, "Ptr", 0, "UInt*", &Size := 0, "Ptr", 0, "Ptr", 0))
            throw OSError()

        output := Buffer(Size)
        if !(DllCall("crypt32\CryptStringToBinaryW", "Str", input, "UInt", 0, "UInt", CRYPT_STRING_BASE64, "Ptr", output, "UInt*", Size, "Ptr", 0, "Ptr", 0))
            throw OSError()

        return StrGet(output, "UTF-8")
    }
}
