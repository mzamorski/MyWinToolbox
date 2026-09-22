#Requires AutoHotkey v2.0

class Logger
{
    static DebugEnabled := false
    static LogDirectory := ""
    static LogPath := ""
    static MaxFileSizeInBytes := 2 * 1024 * 1024

    static Configure(debugEnabled := false)
    {
        Logger.DebugEnabled := !!debugEnabled
        localAppData := EnvGet("LOCALAPPDATA")
        if (localAppData = "")
        {
            localAppData := A_AppData
        }

        Logger.LogDirectory := localAppData "\MyWinToolbox"
        Logger.LogPath := Logger.LogDirectory "\MyWinToolbox.log"

        try
        {
            if (!DirExist(Logger.LogDirectory))
            {
                DirCreate(Logger.LogDirectory)
            }
        }
        catch Error
        {
            ; Logging must never break the toolbox.
        }
    }

    static Debug(message, source := "")
    {
        if (Logger.DebugEnabled)
        {
            Logger.Write("DEBUG", message, source)
        }
    }

    static Info(message, source := "")
    {
        Logger.Write("INFO", message, source)
    }

    static Warning(message, source := "")
    {
        Logger.Write("WARN", message, source)
    }

    static Error(message, source := "")
    {
        Logger.Write("ERROR", message, source)
    }

    static Write(level, message, source := "")
    {
        try
        {
            if (Logger.LogPath = "")
            {
                Logger.Configure(false)
            }

            Logger.RotateIfNeeded()

            timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            sourcePart := source != "" ? " [" source "]" : ""
            normalizedMessage := StrReplace("" message, "`r", "")
            normalizedMessage := StrReplace(normalizedMessage, "`n", "\n")

            FileAppend(
                timestamp " [" level "]" sourcePart " " normalizedMessage "`n",
                Logger.LogPath,
                "UTF-8"
            )
        }
        catch Error
        {
            ; Logging must never break the toolbox.
        }
    }

    static RotateIfNeeded()
    {
        if (!FileExist(Logger.LogPath))
        {
            return
        }

        if (FileGetSize(Logger.LogPath) <= Logger.MaxFileSizeInBytes)
        {
            return
        }

        archivePath := Logger.LogPath ".1"
        if (FileExist(archivePath))
        {
            FileDelete(archivePath)
        }

        FileMove(Logger.LogPath, archivePath, 1)
    }
}
