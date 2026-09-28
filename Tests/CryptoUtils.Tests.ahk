#Requires AutoHotkey v2.0

#Include ..\Libs\CryptoUtils.ahk

global TestFailures := []

AssertTrue(condition, message)
{
    global TestFailures

    if (!condition)
    {
        TestFailures.Push(message)
    }
}

AssertEqual(expected, actual, message)
{
    AssertTrue(
        expected = actual,
        message " | expected: " expected ", actual: " actual
    )
}

plaintext := "Zażółć gęślą jaźń — DPAPI test 123"
protected := ""

try
{
    protected := CryptoUtils.Protect(plaintext)

    AssertTrue(
        CryptoUtils.IsProtectedValue(protected),
        "Protect should return a versioned DPAPI value"
    )

    AssertTrue(
        SubStr(protected, 1, StrLen(CryptoUtils.DpapiPrefix))
            = CryptoUtils.DpapiPrefix,
        "DPAPI value should use the configured prefix"
    )

    AssertEqual(
        plaintext,
        CryptoUtils.Unprotect(protected),
        "DPAPI value should round-trip for the current Windows user"
    )

    emptyProtected := CryptoUtils.Protect("")
    AssertEqual(
        "",
        CryptoUtils.Unprotect(emptyProtected),
        "DPAPI should round-trip an empty string"
    )
}
catch Error as e
{
    TestFailures.Push("DPAPI round-trip failed: " e.Message)
}

legacyKey := "legacy-test-key"
legacyPlaintext := "legacy password"
legacyValue := CryptoUtils.Encrypt(legacyPlaintext, legacyKey)

AssertTrue(
    !CryptoUtils.IsProtectedValue(legacyValue),
    "legacy RC4 value should not be classified as DPAPI"
)

AssertEqual(
    legacyPlaintext,
    CryptoUtils.Unprotect(legacyValue, legacyKey),
    "compatibility layer should decrypt legacy RC4"
)

try
{
    migratedValue := CryptoUtils.MigrateToDpapi(
        legacyValue,
        legacyKey
    )

    AssertTrue(
        CryptoUtils.IsProtectedValue(migratedValue),
        "legacy migration should create a DPAPI value"
    )

    AssertEqual(
        legacyPlaintext,
        CryptoUtils.Unprotect(migratedValue),
        "migrated DPAPI value should preserve plaintext"
    )

    AssertEqual(
        migratedValue,
        CryptoUtils.MigrateToDpapi(migratedValue, legacyKey),
        "migrating an existing DPAPI value should be idempotent"
    )
}
catch Error as e
{
    TestFailures.Push("RC4 to DPAPI migration failed: " e.Message)
}

try
{
    CryptoUtils.Unprotect(legacyValue)
    TestFailures.Push(
        "legacy RC4 decrypt without Secret should have failed"
    )
}
catch Error
{
}

if (TestFailures.Length > 0)
{
    for failure in TestFailures
    {
        FileAppend("FAIL: " failure "`n", "**")
    }

    ExitApp(1)
}

FileAppend("CryptoUtils DPAPI tests passed.`n", "*")
ExitApp(0)
