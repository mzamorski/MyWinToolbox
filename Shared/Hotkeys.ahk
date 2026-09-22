;========================================================================================================================
; HOTKEYS
;========================================================================================================================

;--------------------------------------------------------------------------------
; Open shortcut sheet PDF.

^#F1::		; Ctrl + Win + F1
{
    shortcutSheetPath := A_ScriptDir "\Docs\SHORTCUTS.pdf"

    if !FileExist(shortcutSheetPath)
    {
        MsgBox("Shortcut sheet PDF was not found:`n" shortcutSheetPath, "MyWinToolbox", "Iconx")
        return
    }

    try
    {
        Run(shortcutSheetPath)
    }
    catch Error as e
    {
        MsgBox("Unable to open shortcut sheet:`n" e.Message, "MyWinToolbox", "Iconx")
    }
}

;--------------------------------------------------------------------------------
; Show 'FormatMenu'

#^f::
{
    formatMenu.Show()
}

;--------------------------------------------------------------------------------
; Show 'StringGeneratorMenu'

#^i::		; Win + Ctrl + i
{
	stringGeneratorMenu.Show()
}

;--------------------------------------------------------------------------------
; Show 'TextSnippetsMenu'

#^s::		; Win + Ctrl + s
{
	textSnippetsMenu.Show()
}

;--------------------------------------------------------------------------------
; Show 'EmocjiMenu'

#^e::		; Win + Ctrl + e
{
	emojiMenu.Show()
}

;--------------------------------------------------------------------------------
; Paste current local date-time.

#^d::		; Win + Ctrl + d
{
	Menu_StringGenerator_CurrentDate()
}

;--------------------------------------------------------------------------------
; Always On Top — toggle for the active window

#^PgUp:: {
    hwnd := WinExist("A")
    if !hwnd
        return

    ex := WinGetExStyle("ahk_id " hwnd)
    isTop := (ex & 0x00000008) ; WS_EX_TOPMOST

    WinSetAlwaysOnTop !isTop, "ahk_id " hwnd
    ToolTip (isTop ? "Always-on-top: OFF" : "Always-on-top: ON")
    SetTimer () => ToolTip(), -700
}

;--------------------------------------------------------------------------------
; Close all windows of the same type (class)

HotKey_CloseAllWindows(withSameTitle := false)
{
	prevTitleMode := A_TitleMatchMode 
	SetTitleMatchMode(3)

	windowClass := WinGetClass("A")
	windowTitle := WinGetTitle("A")
	
	windowGroup := StrReplace(windowClass, A_Space, "_")
	
	if (withSameTitle)
	{
		GroupAdd(windowGroup, windowTitle . " ahk_class " . windowClass)
	}
	else
	{
		GroupAdd(windowGroup, "ahk_class " . windowClass)
	}
	
	WinClose("ahk_group " . windowGroup)

  
	message := windowTitle . " (" . windowClass . ")"
	SetTitleMatchMode(prevTitleMode)

	TrayTip("Close windows", message)
}

#!F4::		; Win + Alt + F4
{
	HotKey_CloseAllWindows(true)
}

^#F4::		; Ctrl + Win + F4
{
	HotKey_CloseAllWindows()
}

#Space::	; Win + Space
{
    MouseGetPos(&x, &y)
    
	color := PixelGetColor(x, y)
	color := StrLower(color)

	A_Clipboard := color
    
	color := "c" SubStr(color, 3)
    
    colorWindow := Gui()
    colorWindow.BackColor := color
    colorWindow.Opt("-Caption +ToolWindow +Disabled +Border")
    colorWindow.Show("w50 h50 x" . x . " y" . y)
    Sleep (1000)
	
    colorWindow.Destroy()
}

^#Home::		; Ctrl + Win + Home
{
	TrayTip("The script will be reloaded.", MainScriptName)
	Sleep(2000)
	Reload
}

^#End::		; Ctrl + Win + End
{
	TrayTip("The script will be closed.", MainScriptName)
	Sleep(2000)
	ExitApp
}

; --------------------------------------------------------------------------------
; Insert a 4-space indent.

^Tab::		; Ctrl + tab
{
	Send(Format("{Space {1:i}}", SpacesPerIndent))
}

; --------------------------------------------------------------------------------
; Move all selected files/folders to a specified destination directory.

^#m::
{
	paths := Explorer_GetSelectedFiles()
    if (!paths)
    {
        MsgBox("Failed to retrieve file names from Explorer!")
    }
    
    currentDirectory := Explorer_GetActivePath()
    defaultDirName := DateTimeUtils.GetTimestamp()
 
    dialogResult := InputBox("Please enter directory name", "MoveTo", "w100 h70", defaultDirName)
    if (dialogResult.Result = "Cancel")
    {
        return
    }

    newDirectoryName := StringUtils.IsNullOrWhiteSpace(dialogResult.Value) 
        ? defaultDirName 
        : dialogResult.Value

    destDirectoryPath := PathUtils.Combine(currentDirectory, newDirectoryName)
    if (!DirectoryUtils.Create(destDirectoryPath))
    {
        MsgBox("Failed to create the directory!")
    }

	for path in paths 
    {
        if InStr(FileExist(path), "D") 
        {
            DirMove(path, destDirectoryPath, 1)
        } 
        else
        {
            FileMove(path, destDirectoryPath)    
        }
	}
}

; Fn is handled by the keyboard firmware and usually emits the corresponding
; Numpad key. Register both NumLock states so the shortcuts work in either mode.
^Numpad4::
^NumpadLeft::
{
    Sound.SetDefaultDevice(AudioDeviceHeadphones, "Headphones")
}

^Numpad8::
^NumpadUp::
{
    Sound.SetDefaultDevice(AudioDeviceMonitor, "Monitor")
}

^Numpad6::
^NumpadRight::
{
    Sound.SetDefaultDevice(AudioDeviceLaptop, "Laptop")
}

; --------------------------------------------------------------------------------
; Sound - Toggle mute of the active window
#^Volume_Mute:: {
    procName := WinGetProcessName("A")
    procId := WinGetPID("A")
    try
    {
        isMuted := Sound.ToggleProcessMute(procId)
        Sound.ShowToolTip((isMuted ? "Muted: " : "Unmuted: ") procName)
    }
    catch Error as e
    {
        Sound.ShowToolTip("Unable to toggle mute: " procName "`n" e.Message, 6000)
    }
}
