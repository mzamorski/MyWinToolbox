#Requires AutoHotkey v2.0

#Include ..\Libs\Collections.ahk
#Include ..\Libs\StringUtils.ahk
#Include ..\Libs\Externals\_JXON.ahk
#Include ..\Libs\ConfiguratorAutoPasteTab.ahk
#Include ..\Libs\ConfiguratorSettingsTab.ahk
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

autoPasteRule := Map(
    "name", "Browser login",
    "exe", "msedge.exe",
    "url", "example.com/login",
    "actions", [
        Map("keys", "{Tab}"),
        Map("passwordKey", "ExamplePassword")
    ]
)

autoPasteSummary := ConfiguratorAutoPasteTab.GetRuleMatchSummary(autoPasteRule)
AssertTrue(
    InStr(autoPasteSummary, "exe=msedge.exe") > 0,
    "AutoPaste rule summary should include executable matcher"
)

actionInfo := ConfiguratorAutoPasteTab.GetActionOperation(
    Map("passwordKey", "ExamplePassword")
)
AssertEqual(
    "passwordKey",
    actionInfo["Type"],
    "AutoPaste action operation should detect passwordKey"
)

matcherRule := Map(
    "exe", "msedge.exe",
    "class", "Chrome_WidgetWin_1",
    "title", "Example",
    "titleMatchMode", "contains",
    "url", "https://example.com/login",
    "urlMatchMode", "equals"
)

matchingTarget := Map(
    "exe", "msedge.exe",
    "class", "Chrome_WidgetWin_1",
    "title", "Example - Microsoft Edge",
    "url", "https://example.com/login",
    "isBrowser", true
)

matchResult := ConfiguratorAutoPasteTab.EvaluateRuleMatchers(
    matcherRule,
    matchingTarget
)

AssertTrue(
    matchResult["Matched"],
    "AutoPaste matcher diagnostics should pass matching target"
)
AssertTrue(
    InStr(matchResult["Details"], "✓ EXE") > 0,
    "AutoPaste matcher diagnostics should include successful EXE check"
)

nonMatchingTarget := ConfiguratorJsonStore.Clone(matchingTarget)
nonMatchingTarget["class"] := "OtherClass"
nonMatchingTarget["url"] := ""

noMatchResult := ConfiguratorAutoPasteTab.EvaluateRuleMatchers(
    matcherRule,
    nonMatchingTarget
)

AssertTrue(
    !noMatchResult["Matched"],
    "AutoPaste matcher diagnostics should fail mismatching target"
)
AssertTrue(
    InStr(noMatchResult["Details"], "✗ Class") > 0,
    "AutoPaste matcher diagnostics should identify class mismatch"
)
AssertTrue(
    InStr(noMatchResult["Details"], "✗ URL") > 0,
    "AutoPaste matcher diagnostics should identify unavailable URL"
)

emptyMatcherResult := ConfiguratorAutoPasteTab.EvaluateRuleMatchers(
    Map(),
    matchingTarget
)
AssertTrue(
    !emptyMatcherResult["Matched"],
    "AutoPaste matcher diagnostics should reject rules without matchers"
)

AssertThrows(
    () => ConfiguratorSettingsTab.ValidateNamedEntries(
        [
            Map("Name", "EN", "Value", "one"),
            Map("Name", "en", "Value", "two")
        ],
        "User signature"
    ),
    "Settings should reject duplicate entry names case-insensitively"
)

tempIniPath := A_Temp "\MyWinToolbox-Configurator-" A_TickCount ".ini"

if FileExist(tempIniPath)
{
    FileDelete(tempIniPath)
}

FileAppend(
    "[Settings]`r`n"
        "Secret = old-secret ; keep-readable-comment`r`n"
        "Email = old@example.com`r`n"
        "`r`n"
        "[Unknown]`r`n"
        "KeepMe = yes`r`n",
    tempIniPath,
    "UTF-8"
)

try
{
    iniDoc := ConfiguratorIniDocument(tempIniPath)
    AssertEqual(
        "old-secret",
        iniDoc.Get("Settings", "Secret"),
        "INI reader should strip inline comments"
    )
    AssertTrue(
        iniDoc.HasKey("Settings", "Email"),
        "INI document should find existing key"
    )

    iniDoc.Set("Settings", "Email", "new@example.com")
    iniDoc.Set("Settings", "ShippingAddress", "Line 1`nLine 2")
    iniDoc.ReplaceSectionEntries(
        "UserSignatures",
        [
            Map("Name", "EN", "Value", "Best regards,`nJohn")
        ]
    )
    iniDoc.SaveWithBackup()

    reloadedIni := ConfiguratorIniDocument(tempIniPath)

    AssertEqual(
        "new@example.com",
        reloadedIni.Get("Settings", "Email"),
        "INI document should persist changed values"
    )
    AssertEqual(
        "Line 1`nLine 2",
        reloadedIni.Get("Settings", "ShippingAddress"),
        "INI document should round-trip escaped newlines"
    )
    AssertEqual(
        "yes",
        reloadedIni.Get("Unknown", "KeepMe"),
        "INI document should preserve unknown sections"
    )
    AssertTrue(
        FileExist(tempIniPath ".bak"),
        "INI save should create a backup"
    )

    signatures := reloadedIni.GetSectionEntries("UserSignatures")
    AssertEqual(1, signatures.Length, "INI section replacement should persist entries")
    AssertEqual("EN", signatures[1]["Name"], "INI section entry name should round-trip")
}
catch Error as e
{
    TestFailures.Push("INI configurator unexpected error: " e.Message)
}
finally
{
    for filePath in [
        tempIniPath,
        tempIniPath ".bak",
        tempIniPath ".tmp"
    ]
    {
        if FileExist(filePath)
        {
            FileDelete(filePath)
        }
    }
}

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
