#Requires AutoHotkey v2.0

#Include StringUtils.ahk

class DirectoryUtils
{
    static Create(path)
    {
        if (DirExist(path))
        {
            return true
        }

        try 
        {
            DirCreate(path)
            return true
        } 
        catch
        {
            return false
        }
    }

}

class PathUtils
{
    static Separator := "\"

    static Combine(path, fileName) 
    {
        if !(StringUtils.EndsWith(path, PathUtils.Separator))
        {
            path .= PathUtils.Separator
        }

        return path . fileName
    }

    static CreateUniqueName()
    {
        guid := ComObject("Scriptlet.TypeLib").GUID

        return guid
    }
}