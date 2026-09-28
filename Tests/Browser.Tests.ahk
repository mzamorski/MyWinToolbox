#Requires AutoHotkey v2.0

#Include ..\Libs\Browser.ahk

global TestFailures := []

AssertEqual(expected, actual, message)
{
    global TestFailures

    if (expected != actual)
    {
        TestFailures.Push(message " | expected: " expected ", actual: " actual)
    }
}

AssertEqual(
    "https://example.com/path?q=1",
    Browser.NormalizeURLCandidate("https://example.com/path?q=1"),
    "full HTTPS URL should be preserved"
)

AssertEqual(
    "https://example.com/path",
    Browser.NormalizeURLCandidate("example.com/path"),
    "display-form domain should gain an HTTPS scheme"
)

AssertEqual(
    "chrome://settings",
    Browser.NormalizeURLCandidate("chrome://settings"),
    "browser-internal URL should be preserved"
)

AssertEqual(
    "",
    Browser.NormalizeURLCandidate("ordinary page text"),
    "ordinary text must not be mistaken for a URL"
)

if (TestFailures.Length > 0)
{
    for failure in TestFailures
    {
        FileAppend("FAIL: " failure "`n", "**")
    }

    ExitApp(1)
}

FileAppend("Browser tests passed.`n", "*")
ExitApp(0)
