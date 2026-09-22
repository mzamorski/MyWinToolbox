#Requires AutoHotkey v2.0

#Include ..\Libs\Logger.ahk
#Include ..\Libs\AutoPaste.ahk

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
    AssertTrue(expected = actual, message " | expected: " expected ", actual: " actual)
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
        return
    }
}

Test_ValidSimpleRule()
{
    entries := [
        Map(
            "name", "simple",
            "exe", "notepad.exe",
            "text", "hello"
        )
    ]

    AutoPaste_ValidateEntries(entries)
    AssertTrue(true, "simple rule should validate")
}

Test_ValidActionsRule()
{
    entries := [
        Map(
            "name", "actions",
            "exe", "msedge.exe",
            "url", "https://example.com/login",
            "triggerMode", "oncePerUrl",
            "actions", [
                Map("keys", "{Tab}"),
                Map("delay", 150),
                Map("passwordKey", "ExamplePassword")
            ]
        )
    ]

    AutoPaste_ValidateEntries(entries)
    AssertTrue(true, "actions rule should validate")
}

Test_InvalidMixedAction()
{
    entries := [
        Map(
            "name", "invalid",
            "exe", "msedge.exe",
            "actions", [
                Map("keys", "{Tab}", "delay", 100)
            ]
        )
    ]

    AssertThrows(
        () => AutoPaste_ValidateEntries(entries),
        "action with keys and delay should be rejected"
    )
}

Test_InvalidUnknownField()
{
    entries := [
        Map(
            "name", "invalid",
            "exe", "notepad.exe",
            "texxt", "typo"
        )
    ]

    AssertThrows(
        () => AutoPaste_ValidateEntries(entries),
        "unknown rule field should be rejected"
    )
}

Test_OncePerUrlRequiresUrl()
{
    entries := [
        Map(
            "name", "invalid trigger",
            "exe", "notepad.exe",
            "triggerMode", "oncePerUrl",
            "text", "hello"
        )
    ]

    AssertThrows(
        () => AutoPaste_ValidateEntries(entries),
        "oncePerUrl without url should be rejected"
    )
}

Test_LegacyFocusNormalization()
{
    entry := Map(
        "exe", "msedge.exe",
        "focus", Map(
            "method", "keys",
            "keys", "{Tab 2}"
        ),
        "focusDelay", 150,
        "passwordKey", "ExamplePassword"
    )

    actions := AutoPaste_GetActions(entry)

    AssertEqual(3, actions.Length, "legacy focus should normalize to three actions")
    AssertEqual("{Tab 2}", actions[1]["keys"], "legacy focus keys should be first")
    AssertEqual(150, actions[2]["delay"], "legacy focusDelay should become delay action")
    AssertEqual("ExamplePassword", actions[3]["passwordKey"], "password should remain last")
}

Test_TriggerKeys()
{
    context := Map("url", "https://example.com/login?id=1")

    AssertEqual(
        "__window__",
        AutoPaste_GetTriggerKey(Map("exe", "msedge.exe"), context),
        "default trigger mode should be oncePerWindow"
    )

    AssertEqual(
        context["url"],
        AutoPaste_GetTriggerKey(Map("url", "example.com", "triggerMode", "oncePerUrl"), context),
        "oncePerUrl should use current URL as trigger key"
    )

    AssertEqual(
        "",
        AutoPaste_GetTriggerKey(Map("exe", "msedge.exe", "triggerMode", "always"), context),
        "always should disable processed-state suppression"
    )
}

tests := [
    Test_ValidSimpleRule,
    Test_ValidActionsRule,
    Test_InvalidMixedAction,
    Test_InvalidUnknownField,
    Test_OncePerUrlRequiresUrl,
    Test_LegacyFocusNormalization,
    Test_TriggerKeys
]

for test in tests
{
    try
    {
        test.Call()
    }
    catch Error as e
    {
        TestFailures.Push(test.Name ": unexpected error: " e.Message)
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

FileAppend("AutoPaste tests passed (" tests.Length ").`n", "*")
ExitApp(0)
