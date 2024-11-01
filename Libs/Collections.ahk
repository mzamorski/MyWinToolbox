#Requires AutoHotkey v2.0

; Based on: https://github.com/mmikeww/AHK-v2-script-converter
class OrderedMap extends Map 
{
    __New(pairs*) 
    {
        super.__New(pairs*)

        KeyArray := []
        keyCount := pairs.Length // 2
        KeyArray.Length := keyCount

        Loop keyCount
        {
            KeyArray[A_Index] := pairs[(A_Index << 1) - 1]
        }

        this.KeyArray := KeyArray
    }

    __Item[key] 
    {
        set 
        {
            if !this.Has(key)
            {
                this.KeyArray.Push(key)
            }

            return super[key] := value
        }
    }

    Clear() 
    {
        super.Clear()
        this.KeyArray := []
    }

    Clone() 
    {
        Other := super.Clone()
        Other.KeyArray := this.KeyArray.Clone()
        return Other
    }

    Delete(key) 
    {
        try 
        {
            RemovedValue := super.Delete(key)

            CaseSense := this.CaseSense
            for i, Element in this.KeyArray 
            {
                areSame := (Element is String)
                    ? !StrCompare(Element, key, CaseSense)
                    : (Element = key)

                if areSame 
                {
                    this.KeyArray.RemoveAt(i)
                    break
                }
            }

            return RemovedValue
        }
        catch Error as e
        {
            throw Error(e.Message, -1, e.Extra)
        }
    }

    Set(pairs*) 
    {
        if (pairs.Length & 1)
        {
            throw ValueError('Invalid number of parameters.', -1)
        }

        KeyArray := this.KeyArray
        keyCount := pairs.Length // 2
        KeyArray.Capacity += keyCount

        Loop keyCount 
        {
            key := pairs[(A_Index << 1) - 1]

            if !this.Has(key)
            {
                KeyArray.Push(key)
            }
        }

        super.Set(pairs*)

        return this
    }

    __Enum(*) 
    {
        keyEnum := this.KeyArray.__Enum(1)

        keyValEnum(&key := unset, &val := unset) 
        {
            if keyEnum(&key) 
            {
                val := this[key]
                return true
            }
            else 
            {
                return false
            }
        }

        return keyValEnum
    }
}