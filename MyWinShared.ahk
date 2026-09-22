#Requires AutoHotkey v2.0
#SingleInstance Force

#Include Libs\Constants.ahk
#Include Libs\StringUtils.ahk
#Include Libs\ClipboardUtils.ahk
#Include Libs\CryptoUtils.ahk
#Include Libs\DateTimeUtils.ahk
#Include Libs\ConfigUtils.ahk
#Include Libs\Logger.ahk
#Include Libs\WinAPI.ahk
#Include Libs\MenuUtils.ahk
#include Libs\Externals\_JXON.ahk
#Include Libs\Externals\XHotstring.ahk
#Include Libs\IOUtils.ahk
#Include Libs\ExplorerUtils.ahk
#Include Libs\MinimizeToTray.ahk
#Include Libs\WindowGrid.ahk
#Include Libs\CopyWindowInfo.ahk
#Include Libs\DynamicHotStrings.ahk
#Include Libs\AutoPaste.ahk
#Include Libs\Sound.ahk

SendMode("Input")
SetTitleMatchMode("2")
DetectHiddenWindows(true)
Persistent

; Shared feature modules are included in execution order.
#Include Shared\Startup.ahk
#Include Shared\Menus.ahk
#Include Shared\Hotkeys.ahk
#Include Shared\Hotstrings.ahk
