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
}


