#Requires AutoHotkey v2.0

#Include ..\Libs\Collections.ahk
#Include ..\Libs\Externals\_JXON.ahk
#Include ..\Libs\MyWinToolboxConfigurator.ahk

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
    }
}

parsed := ConfiguratorJsonStore.ParseList("one, two`nthree")
AssertEqual(3, parsed.Length, "ParseList should split commas and newlines")
AssertEqual("one, two, three", ConfiguratorJsonStore.JoinList(parsed), "JoinList should join values")

snippets := Map(
    "Test", [
        Map("Title", "Hello", "Content", "Hello world"),
        Map("Content", "--"),
        Map("Content", "Untitled")
    ]
)

AssertTrue(
    MyWinToolboxConfigurator.ValidateSnippets(snippets),
    "valid snippets should pass validation"
)

AssertThrows(
    () => MyWinToolboxConfigurator.ValidateSnippets(
        Map("Broken", [Map("Content", "")])
    ),
    "empty snippet should fail validation"
)

hotStrings := Map(
    "Version", 1,
    "Defaults", Map(
        "Options", "*",
        "ScopeMode", "include"
    ),
    "Scopes", Map(
        "Aliases", Map(
            "Notepad", Map("Process", ["notepad.exe"])
        )
    ),
    "HotStrings", [
        Map(
            "Id", "sig",
            "Trigger", "sig",
            "Text", "Hello",
            "IncludeScopes", ["Notepad"],
            "ExcludeScopes", [],
            "Enabled", true
        )
    ]
)

tempHotStringsPath := A_Temp "\MyWinToolbox-HotStrings-" A_TickCount ".json"
state := ConfiguratorHotStringsState(hotStrings, tempHotStringsPath)

AssertTrue(state.Validate(), "valid HotStrings configuration should pass")
AssertEqual(1, state.GetDefinitions().Length, "HotStrings definition list should be exposed")
AssertTrue(state.GetAliases().Has("Notepad"), "scope aliases should be exposed")

invalidHotStrings := ConfiguratorJsonStore.Clone(hotStrings)
invalidHotStrings["HotStrings"][1]["IncludeScopes"] := ["MissingScope"]
invalidState := ConfiguratorHotStringsState(invalidHotStrings, tempHotStringsPath)

AssertThrows(
    () => invalidState.Validate(),
    "unknown HotString scope should fail validation"
)

duplicateIds := ConfiguratorJsonStore.Clone(hotStrings)
duplicateIds["HotStrings"].Push(
    Map(
        "Id", "SIG",
        "Trigger", "other",
        "Text", "Other",
        "IncludeScopes", ["*"],
        "ExcludeScopes", [],
        "Enabled", true
    )
)
duplicateState := ConfiguratorHotStringsState(duplicateIds, tempHotStringsPath)

AssertThrows(
    () => duplicateState.Validate(),
    "duplicate HotString Id should fail validation case-insensitively"
)

tempSnippetsPath := A_Temp "\MyWinToolbox-Snippets-" A_TickCount ".json"

try
{
    ConfiguratorJsonStore.SaveWithBackup(tempSnippetsPath, snippets)
    AssertTrue(FileExist(tempSnippetsPath), "first save should create JSON file")

    changedSnippets := ConfiguratorJsonStore.Clone(snippets)
    changedSnippets["Test"][1]["Content"] := "Changed"
    ConfiguratorJsonStore.SaveWithBackup(tempSnippetsPath, changedSnippets)

    AssertTrue(
        FileExist(tempSnippetsPath ".bak"),
        "second save should create a backup"
    )

    state.SetDirty()
    state.Save()
    AssertTrue(FileExist(tempHotStringsPath), "HotStrings state should save JSON")
    AssertTrue(!state.Dirty, "HotStrings state should clear dirty flag after save")
}
catch Error as e
{
    TestFailures.Push("save/round-trip unexpected error: " e.Message)
}
finally
{
    for filePath in [
        tempSnippetsPath,
        tempSnippetsPath ".bak",
        tempSnippetsPath ".tmp",
        tempHotStringsPath,
        tempHotStringsPath ".bak",
        tempHotStringsPath ".tmp"
    ]
    {
        if FileExist(filePath)
        {
            FileDelete(filePath)
        }
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

FileAppend("MyWinToolboxConfigurator tests passed.`n", "*")
ExitApp(0)
