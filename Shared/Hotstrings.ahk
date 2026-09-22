;========================================================================================================================
; HOTSTRINGS
; --
; O  - Remove the ending character.
; b0 - Don't delete the typed text.
; *  - Trigger immediately.
; ?  - Search everywhere (trigger even if the start is not separated from the previous text).
; X  - Execute. Instead of replacement text.
;========================================================================================================================

Config_GetEmail() 
{
	return Ini_ReadOrDefault(ConfigFilePath, "Settings", "Email")
}

Terminal_IsActive() {
    winExe := WinGetProcessPath("A")
    return InStr(winExe, "cmd.exe") || InStr(winExe, "WindowsTerminal.exe")
}

TortoiseGit_IsActive() {
    winExe := WinGetProcessPath("A")
    return InStr(winExe, "TortoiseGitProc.exe")
}

;--------------------------------------------------------------------------------

Hotstring(":0*:@=", Config_GetEmail())
Hotstring(":0*:@me", Config_GetEmail())
Hotstring(":0*:--=", Menu_StringGenerator_Separator_120)

; Add three zeros (convert to thousands)
XHotstring(":*:(\d+)k=", (match, *) => Send(match[1] . "000"))

#Hotstring *

; Insert char [—]
::@--::{U+2014}

; Insert char [→]
::@->::{U+2192}

; Insert char [✓]
::@v::{U+2713}

; Insert char [•] (Bullet point)
::@..::{U+2022}

; Insert char [○] (White circle / Second level bullet)
::@.o::{U+25CB}

; Insert char [▪] (Black small square)
::@.k::{U+25AA}

; Insert char [‣] (Bullet arrow)
::@.>::{U+2023}

; Insert char [☐] (Empty checkbox)
::@cb::{U+2610}

; Insert char [✗] (Ballot X / Cancelled)
::@x::{U+2717}

; Insert char [⚠️] (Warning sign)
::@!!::{U+26A0}

; Insert char [§] (Section sign)
::@pp::{U+00A7}

; Insert char [°] (Degree sign)
::@oo::{U+00B0}

; Insert char […] (Horizontal ellipsis)
::@...::{U+2026}

#Hotstring

;--------------------------------------------------------------------------------
; Terminal

#HotIf Terminal_IsActive()

::s30m=::
{
    SendText("shutdown -s -t 1800")
}

::s1h=::
{
    SendText("shutdown -s -t 3600")
}

::s2h=::
{
    SendText("shutdown -s -t 7200")
}

#HotIf 

;--------------------------------------------------------------------------------
; TortoiseGit

#HotIf TortoiseGit_IsActive()

::r=::Refactoring.

#HotIf
