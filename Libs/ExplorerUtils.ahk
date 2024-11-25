#Requires AutoHotkey v2.0

global WINDOWS_EXPLORER_CLASS_NAME := "CabinetWClass"

Explorer_IsExplorerActiveWindow() 
{
    windowClassName := WinGetClass("A")

    return windowClassName = WINDOWS_EXPLORER_CLASS_NAME
}

Explorer_GetSelectedFiles(fileNameFilter := "") 
{
    paths := []
    
    if !Explorer_IsExplorerActiveWindow() 
    {
        throw Error("Action cannot be performed because you are not in Windows Explorer.")
    }

    savedClipboard := A_Clipboard
    A_Clipboard := STRING_EMPTY
    Clipboard_Copy()

    inputData := A_Clipboard
    for line in StrSplit(inputData, "`n", "`r") 
    {
        if (!FileExist(line))
        {
            continue
        }

        if (fileNameFilter)
        {
            if (RegExMatch(line, fileNameFilter))
            {
                paths.Push(line)
            }
        } 
        else 
        {
            paths.Push(line)
        }
    }

    A_Clipboard := savedClipboard

    return paths
}


Explorer_GetWindow(handle := 0) 
{
    handle := (handle ? handle : WinExist("A"))
    className := WinGetClass("ahk_id " handle)

    if (className = "CabinetWClass" || className = "ExploreWClass" || className = "Progman" || className = "WorkerW") 
    {
        for window in ComObject("Shell.Application").Windows 
        {
            if (window.hwnd == handle)
            {
                return window
            }
        }
    }

    return STRING_EMPTY
}

Explorer_GetShellFolderView(handle := 0)
{
	return Explorer_GetWindow(handle).Document
}

Explorer_GetItems(handle := 0)
{
	return Explorer_GetShellFolderView(handle).Folder.Items
}

Explorer_GetActivePath()
{
	explorerWindow := Explorer_GetWindow()
    explorerHandle := explorerWindow.hwnd

	if (explorerHandle)
    {
		for window in ComObject("Shell.Application").Windows
        {
			try
            {
				if (window && window.hwnd && window.hwnd == explorerHandle)
                {
					return window.Document.Folder.Self.Path
                }
			}
		}
	}

	return false
}