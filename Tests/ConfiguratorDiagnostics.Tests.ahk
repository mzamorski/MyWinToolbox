#Requires AutoHotkey v2.0

#Include ..\Libs\ConfiguratorDiagnosticsTab.ahk

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

snippets := Map(
    "General", [
        Map("Title", "A", "Content", "One"),
        Map("Content", "--"),
        Map("Title", "B", "Content", "Two")
    ],
    "SQL", [
        Map("Title", "C", "Content", "Three")
    ]
)

AssertEqual(
    3,
    ConfiguratorDiagnosticsTab.CountSnippets(snippets),
    "Diagnostics should count snippets without separators"
)

hotStrings := [
    Map("Trigger", "a", "Text", "A"),
    Map("Trigger", "b", "Text", "B", "Enabled", true),
    Map("Trigger", "c", "Text", "C", "Enabled", false)
]

AssertEqual(
    2,
    ConfiguratorDiagnosticsTab.CountEnabledHotStrings(hotStrings),
    "Diagnostics should count enabled HotStrings"
)

logText := "2026-09-30 10:00:00 [INFO] [Startup] Started" . Chr(10)
    . "2026-09-30 10:01:00 [ERROR] [AutoPaste] First error" . Chr(10)
    . "2026-09-30 10:02:00 [WARN] [Config] Warning" . Chr(10)
    . "2026-09-30 10:03:00 [ERROR] [Config] Second error" . Chr(10)
    . "2026-09-30 10:04:00 [ERROR] [Config] Third error" . Chr(10)

recentErrors := ConfiguratorDiagnosticsTab.GetRecentErrorsFromText(
    logText,
    2
)

AssertTrue(
    InStr(recentErrors, "Third error") > 0,
    "Diagnostics should include the latest error"
)
AssertTrue(
    InStr(recentErrors, "Second error") > 0,
    "Diagnostics should include the second-latest error"
)
AssertTrue(
    InStr(recentErrors, "First error") = 0,
    "Diagnostics should honor the maximum error count"
)
AssertTrue(
    InStr(recentErrors, "Third error") < InStr(recentErrors, "Second error"),
    "Diagnostics errors should be listed latest first"
)

AssertEqual(
    "Disabled",
    ConfiguratorDiagnosticsTab.DescribeTaskState(1),
    "Scheduled Task state 1 should be Disabled"
)
AssertEqual(
    "Ready",
    ConfiguratorDiagnosticsTab.DescribeTaskState(3),
    "Scheduled Task state 3 should be Ready"
)
AssertEqual(
    "Running",
    ConfiguratorDiagnosticsTab.DescribeTaskState(4),
    "Scheduled Task state 4 should be Running"
)

AssertEqual(
    "512 B",
    ConfiguratorDiagnosticsTab.FormatBytes(512),
    "byte formatting should preserve bytes"
)
AssertEqual(
    "1 KB",
    ConfiguratorDiagnosticsTab.FormatBytes(1024),
    "byte formatting should convert KB"
)

tail := ConfiguratorDiagnosticsTab.TailText("abcdefghij", 4)
AssertTrue(
    InStr(tail, "ghij") > 0,
    "TailText should keep the end of long output"
)

AssertEqual(
    "'a''b'",
    ConfiguratorDiagnosticsTab.PsQuote("a'b"),
    "Diagnostics PowerShell quoting should escape single quotes"
)

if (TestFailures.Length > 0)
{
    for failure in TestFailures
    {
        FileAppend("FAIL: " failure Chr(10), "**")
    }

    ExitApp(1)
}

FileAppend("Configurator diagnostics tests passed." Chr(10), "*")
ExitApp(0)
