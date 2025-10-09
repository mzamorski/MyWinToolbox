#Requires AutoHotkey v2.0

; Based on: https://github.com/mmikeww/AHK-v2-script-converter
class OrderedMap extends Map 
{
    __New(pairs*) 
    {
        super.__New(pairs*)

        this.KeyArray := []

        keyCount := pairs.Length // 2
        this.KeyArray.Length := keyCount

        Loop keyCount
        {
            this.KeyArray[A_Index] := pairs[(A_Index << 1) - 1]     ; Every other element is a key.
        }
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
        
        keyCount := pairs.Length // 2
        this.KeyArray.Capacity += keyCount

        Loop keyCount 
        {
            key := pairs[(A_Index << 1) - 1]

            if !this.Has(key)
            {
                this.KeyArray.Push(key)
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

class ArrayUtils {
    ; Detects "dictionary-like" objects (Map, OrderedMap, SortedMap, custom maps).
    static IsDict(obj) => IsObject(obj) && !(obj is Array)

    ; Detects arrays (plain Array or array-like).
    static IsArr(obj) => IsObject(obj) && (obj is Array)

    ; Safe key check: prefer .Has() for Map/OrderedMap, but fall back to ObjHasOwnProp
    ; in case the object doesn't implement .Has() (e.g., custom/dictionary-like objects).    
    static HasKey(obj, key) {
        try return obj.Has(key)
        catch
            return ObjHasOwnProp(obj, key)
    }

    ; Safe get: returns true and sets &out if any of the provided keys exists (first match wins).
    ; Useful for case-insensitive or multi-alias lookups.
    static TryGet(obj, keys, &out) {
        if !IsObject(obj) || !IsObject(keys)
            return false

        for k in keys {
            if ArrayUtils.HasKey(obj, k) {
                out := obj[k]
                return true
            }
        }
        
        return false
    }

    ; Case-insensitive get: tries name variants like ["Key","key"].
    static TryGetCI(obj, key, &out) {
        return ArrayUtils.TryGet(obj, [key, StrLower("" . key), StrUpper("" . key)], &out)
    }

    ; Get with default if key missing.
    static GetOr(obj, key, defaultVal := "") {
        return ArrayUtils.HasKey(obj, key) ? obj[key] : defaultVal
    }

    ; Ensures array: wraps non-empty scalar into single-element array; copies arrays 1:1.
    static ToArray(val) {
        arr := []

        if !IsSet(val)
            return arr

        if ArrayUtils.IsArr(val) {
            for it in val
                arr.Push(it)
            return arr
        }

        if ("" . val != "")
            arr.Push(val)

        return arr
    }

    ; Iterates values of dict-like object into an array (shallow).
    static Values(dict) {
        out := []

        if ArrayUtils.IsDict(dict) {
            for _, v in dict
                out.Push(v)
        }

        return out
    }

    ; Shallow copy of array/dict into a plain AHK v2 structure (useful if upstream returns exotic types).
    static CloneShallow(obj) {
        if ArrayUtils.IsArr(obj) {
            out := []
            for v in obj
                out.Push(v)
            return out
        }

        if ArrayUtils.IsDict(obj) {
            out := Map()
            for k, v in obj
                out[k] := v
            return out
        }
        
        return obj
    }
}
