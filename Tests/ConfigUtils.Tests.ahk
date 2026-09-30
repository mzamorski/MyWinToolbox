#Requires AutoHotkey v2.0

#Include ..\Libs\ConfigUtils.ahk

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

AssertThrows(callback, message)
{
    global TestFailures

    try
    {
        callback.Call()
        TestFailures.Push(message " | expected an exception")
    }
    catch Error
    {
    }
}

AssertTrue(Config_ParseBoolean("true"), "true should parse as enabled")
AssertTrue(Config_ParseBoolean("YES"), "YES should parse as enabled")
AssertTrue(Config_ParseBoolean("on"), "on should parse as enabled")
AssertTrue(Config_ParseBoolean("1"), "1 should parse as enabled")
AssertTrue(!Config_ParseBoolean("false", true), "false should parse as disabled")
AssertTrue(!Config_ParseBoolean("No", true), "No should parse as disabled")
AssertTrue(!Config_ParseBoolean("off", true), "off should parse as disabled")
AssertTrue(!Config_ParseBoolean("0", true), "0 should parse as disabled")
AssertTrue(Config_ParseBoolean("", true), "empty value should use true default")
AssertTrue(!Config_ParseBoolean("", false), "empty value should use false default")

AssertThrows(
    () => Config_ParseBoolean("sometimes"),
    "invalid boolean text should be rejected"
)

tempPath := A_Temp "\MyWinToolbox-ConfigUtils-" A_TickCount ".ini"

try
{
    FileAppend(
        "[Startup]`r`n"
            "NoSleep = true`r`n"
            "AutoPaste = false`r`n",
        tempPath,
        "UTF-8"
    )

    AssertTrue(
        Ini_ReadBoolOrDefault(tempPath, "Startup", "NoSleep", false),
        "INI boolean helper should read true"
    )

    AssertTrue(
        !Ini_ReadBoolOrDefault(tempPath, "Startup", "AutoPaste", true),
        "INI boolean helper should read false"
    )

    AssertTrue(
        Ini_ReadBoolOrDefault(tempPath, "Startup", "Missing", true),
        "INI boolean helper should honor default for missing key"
    )
}
catch Error as e
{
    TestFailures.Push("INI boolean helper unexpected error: " e.Message)
}
finally
{
    if FileExist(tempPath)
    {
        FileDelete(tempPath)
    }
}

if (TestFailures.Length > 0)
{
    for failure in TestFailures
    {
        FileAppend("FAIL: " failure "`n", "**")
    }

    ExitApp(1)
}

FileAppend("ConfigUtils tests passed.`n", "*")
ExitApp(0)
