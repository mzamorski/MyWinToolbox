#Requires AutoHotkey v2.0

class Dictionary 
{
    __New() 
    {
        this.data := {} 
    }
    
    ; Add a key-value pair.
    Add(key, value) 
    {
        this.data[key] := value
    }
    
    ; Get a value by key.
    Get(key, defaultValue := "") 
    {
        return this.data.HasKey(key) ? this.data[key] : defaultValue
    }
    
    ; Check if the dictionary has a specific key.
    HasKey(key) 
    {
        return this.data.HasKey(key)
    }
    
    ; Return the entire dictionary as a key-value object for iteration.
    GetAll() 
    {
        return this.data
    }
}