#Requires AutoHotkey v2.0

#Include ..\Libs\Externals\_JXON.ahk
#Include ..\Libs\TextSnippetsEditor.ahk

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

valid := Map(
    "Test", [
        Map(
            "Title", "Hello",
            "Description", "Example",
            "Content", "Hello world"
        ),
        Map("Content", "--"),
        Map("Content", "Untitled")
    ]
)

AssertTrue(TextSnippetsEditor.ValidateData(valid), "valid snippet data should pass validation")
AssertEqual(
    "Hello",
    TextSnippetsEditor.GetSnippetLabel(valid["Test"][1], 1),
    "title should be used as list label"
)
AssertTrue(
    InStr(TextSnippetsEditor.GetSnippetLabel(valid["Test"][2], 2), "separator") > 0,
    "separator should have a friendly list label"
)
AssertEqual(
    "Untitled",
    TextSnippetsEditor.GetSnippetLabel(valid["Test"][3], 3),
    "untitled snippet should use content preview"
)

AssertThrows(
    () => TextSnippetsEditor.ValidateData(Map("Broken", [Map("Title", "Missing content")])),
    "snippet without Content should be rejected"
)

AssertThrows(
    () => TextSnippetsEditor.ValidateData(Map("Broken", [Map("Content", "")])),
    "snippet without title or content should be rejected"
)

tempPath := A_Temp "\MyWinToolbox-TextSnippetsEditor-" A_TickCount ".json"

try
{
    TextSnippetsEditor.SaveData(tempPath, valid)
    AssertTrue(FileExist(tempPath), "save should create JSON file")

    json := FileRead(tempPath)
    loaded := jxon_load(&json)

    AssertEqual("Hello world", loaded["Test"][1]["Content"], "saved JSON should round-trip")

    loaded["Test"][1]["Content"] := "Changed"
    TextSnippetsEditor.SaveData(tempPath, loaded)

    AssertTrue(FileExist(tempPath ".bak"), "second save should create backup")
}
catch Error as e
{
    TestFailures.Push("save/round-trip unexpected error: " e.Message)
}
finally
{
    if FileExist(tempPath)
    {
        FileDelete(tempPath)
    }

    if FileExist(tempPath ".bak")
    {
        FileDelete(tempPath ".bak")
    }

    if FileExist(tempPath ".tmp")
    {
        FileDelete(tempPath ".tmp")
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

FileAppend("TextSnippetsEditor tests passed.`n", "*")
ExitApp(0)
