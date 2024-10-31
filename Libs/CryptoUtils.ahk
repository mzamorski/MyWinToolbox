#Requires AutoHotkey v2.0

#Include Externals\Class_CNG.ahk

class CryptoUtils
{
	static Encrypt(input, key)
	{
        return Encrypt.String("RC4", "", input, key)
	}

    static Decrypt(input, key)
	{
		return Decrypt.String("RC4", "", input, key)
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


