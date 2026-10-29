#Requires AutoHotkey v2.0

; Read the battery percentage published by Windows PnP.
; No PowerShell process or Bluetooth GATT polling is needed.
class BluetoothBatteryTracker
{
    static PresentFlag := 0x100
    static BufferSmall := 0x1A

    __New(enabled := true, refreshMinutes := 5, threshold := 20, notify := true)
    {
        this.Enabled := !!enabled
        this.IntervalMs := refreshMinutes * 60000
        this.Threshold := threshold
        this.Notify := !!notify
        this.Alerted := Map()
        this.Devices := []
        this.Menu := Menu()
        this.Timer := ObjBindMethod(this, "Refresh")
        this.ShowMenuMessage(this.Enabled ? "(waiting for first scan)" : "(disabled in config)")
    }

    Start()
    {
        if (!this.Enabled)
            return

        this.Refresh()
        SetTimer(this.Timer, this.IntervalMs)
    }

    Stop(*)
    {
        SetTimer(this.Timer, 0)
    }

    Refresh(*)
    {
        if (!this.Enabled)
            return

        try
        {
            devices := BluetoothBatteryTracker.Collapse(BluetoothBatteryTracker.Scan())
            this.Devices := devices
            this.BuildMenu()

            if (this.Notify)
            {
                for device in BluetoothBatteryTracker.CollectLowAlerts(
                    devices, this.Alerted, this.Threshold)
                {
                    TrayTip(device.Name " - " device.Level "% remaining",
                        "MyWinToolbox - Bluetooth Battery", 2)
                }
            }
            Logger.Debug("Battery scan: " devices.Length " devices.", "BluetoothBattery")
        }
        catch Error as e
        {
            Logger.Warning("Cannot read Bluetooth batteries: " e.Message
                " (" e.File ":" e.Line ")", "BluetoothBattery")
            ; Keep the last valid values if Windows temporarily rejects a scan.
            this.BuildMenu("Battery read failed (see log)")
        }
    }

    BuildMenu(errorMessage := "")
    {
        this.Menu.Delete()

        if (errorMessage != "")
        {
            this.AddDisabled("(" errorMessage ")")
            this.Menu.Add()
        }

        if (this.Devices.Length = 0)
            this.AddDisabled("(no battery data)")
        else
        {
            labels := Map()
            for device in this.Devices
            {
                name := device.Name
                if (labels.Has(name))
                {
                    labels[name] += 1
                    name .= " (#" labels[name] ")"
                }
                else
                    labels[name] := 1

                status := Type(device.Connected) = "Integer"
                    ? (device.Connected ? " [Connected]" : " [Paired]") : ""
                label := StrReplace(name, "&", "&&") " - " device.Level "%" status
                this.AddDisabled(label)
            }
        }

        this.Menu.Add()
        this.Menu.Add("Refresh now", this.Timer)
    }

    ShowMenuMessage(message)
    {
        this.Menu.Delete()
        this.AddDisabled(message)
    }

    AddDisabled(label)
    {
        this.Menu.Add(label, BluetoothBatteryTracker.Noop)
        this.Menu.Disable(label)
    }

    static Noop(*)
    {
    }

    static Scan()
    {
        keys := {
            Battery: BluetoothBatteryTracker.Key(
                "{104EA319-6EE2-4701-BD47-8DDBF425BBE5}", 2),
            Container: BluetoothBatteryTracker.Key(
                "{8C7ED206-3F8A-4827-B3AB-AE9E1FAEFC6C}", 2),
            Address: BluetoothBatteryTracker.Key(
                "{2BD67D8B-8BEB-48D5-87E0-6CDA3428040A}", 1),
            Name: BluetoothBatteryTracker.Key(
                "{B725F130-47EF-101A-A5F1-02608C9EEBAC}", 10),
            FriendlyName: BluetoothBatteryTracker.Key(
                "{A45C254E-DF1C-4EFD-8020-67D146A850E0}", 14),
            Class: BluetoothBatteryTracker.Key(
                "{A45C254E-DF1C-4EFD-8020-67D146A850E0}", 9),
            Connected: BluetoothBatteryTracker.Key(
                "{83DA6326-97A6-4088-9453-A1923F573B29}", 15)
        }

        nodes := []
        for id in BluetoothBatteryTracker.GetPresentIds()
        {
            ; Battery is commonly on a Hands-Free node, the display name and
            ; connection state on the separate Bluetooth DEV_ node.
            if (!RegExMatch(id, "i)^BTH"))
                continue

            devInst := 0
            if (DllCall("CfgMgr32\CM_Locate_DevNodeW", "UIntP", &devInst,
                "WStr", id, "UInt", 0, "UInt") != 0)
                continue

            battery := BluetoothBatteryTracker.Read(devInst, keys.Battery, "byte")
            container := BluetoothBatteryTracker.Read(devInst, keys.Container, "guid")
            address := BluetoothBatteryTracker.Read(devInst, keys.Address, "string")
            name := BluetoothBatteryTracker.Read(devInst, keys.Name, "string")
            if (name = "")
                name := BluetoothBatteryTracker.Read(devInst, keys.FriendlyName, "string")

            nodes.Push({
                Id: id,
                Container: container,
                Address: address,
                Name: name,
                Class: BluetoothBatteryTracker.Read(devInst, keys.Class, "string"),
                Battery: battery,
                Connected: BluetoothBatteryTracker.Read(devInst, keys.Connected, "bool")
            })
        }
        return nodes
    }

    static GetPresentIds()
    {
        ids := []
        Loop 3
        {
            chars := 0
            result := DllCall("CfgMgr32\CM_Get_Device_ID_List_SizeW",
                "UIntP", &chars, "Ptr", 0,
                "UInt", BluetoothBatteryTracker.PresentFlag, "UInt")
            if (result != 0)
                throw Error("CM_Get_Device_ID_List_SizeW failed: " result)

            if (chars <= 1)
                return ids

            idListBuffer := Buffer(chars * 2, 0)
            result := DllCall("CfgMgr32\CM_Get_Device_ID_ListW",
                "Ptr", 0, "Ptr", idListBuffer.Ptr, "UInt", chars,
                "UInt", BluetoothBatteryTracker.PresentFlag, "UInt")
            if (result = BluetoothBatteryTracker.BufferSmall)
                continue
            if (result != 0)
                throw Error("CM_Get_Device_ID_ListW failed: " result)

            offset := 0
            while (offset < chars)
            {
                id := StrGet(idListBuffer.Ptr + offset * 2, "UTF-16")
                if (id = "")
                    break

                ids.Push(id)
                offset += StrLen(id) + 1
            }
            return ids
        }
        throw Error("Device list changed repeatedly during enumeration.")
    }

    static Key(guid, pid)
    {
        key := Buffer(20, 0) ; DEVPROPKEY = GUID(16) + ULONG(4).
        if (DllCall("Ole32\CLSIDFromString", "WStr", guid,
            "Ptr", key.Ptr, "Int") != 0)
            throw Error("Invalid property GUID: " guid)

        NumPut("UInt", pid, key, 16)
        return key
    }

    static Read(devInst, key, expected)
    {
        data := Buffer(256, 0)
        propertyType := 0
        Loop 2
        {
            required := data.Size
            result := DllCall("CfgMgr32\CM_Get_DevNode_PropertyW",
                "UInt", devInst, "Ptr", key.Ptr, "UIntP", &propertyType,
                "Ptr", data.Ptr, "UIntP", &required, "UInt", 0, "UInt")
            if (result = BluetoothBatteryTracker.BufferSmall
                && required > data.Size && required <= 65536)
            {
                data := Buffer(required, 0)
                continue
            }
            if (result != 0)
                return ""

            if (expected = "byte" && propertyType = 3 && required >= 1)
                return NumGet(data, 0, "UChar")
            if (expected = "bool" && propertyType = 17 && required >= 1)
                return NumGet(data, 0, "UChar") ? 1 : 0
            if (expected = "string" && propertyType = 18 && required >= 2)
                return StrGet(data.Ptr, "UTF-16")
            if (expected = "guid" && propertyType = 13 && required = 16)
            {
                ; The 16 raw GUID bytes form a stable deduplication key.
                hex := ""
                Loop 16
                    hex .= Format("{:02X}", NumGet(data, A_Index - 1, "UChar"))
                return hex
            }
            return ""
        }
        return ""
    }

    static GroupKey(node)
    {
        if (node.Container != "")
            return "container:" StrUpper(node.Container)
        if (node.Address != "")
            return "address:" StrUpper(node.Address)
        ; Never group by name: two identical devices can coexist.
        return "instance:" node.Id
    }

    static NameScore(node)
    {
        score := 0
        if (RegExMatch(node.Id, "i)^BTH(?:ENUM|LE|LEDEVICE)\\DEV_"))
            score += 100
        if (StrLower(node.Class) = "bluetooth")
            score += 20
        if (RegExMatch(node.Name,
            "i) (Hands-Free(?: AG(?: Audio)?)?|Avrcp Transport|Stereo)$"))
            score -= 40
        return score
    }

    static Collapse(nodes)
    {
        groups := Map()
        ordered := []

        for node in nodes
        {
            if (Type(node.Battery) != "Integer"
                || node.Battery < 0 || node.Battery > 100)
                continue

            key := BluetoothBatteryTracker.GroupKey(node)
            if (!groups.Has(key))
            {
                device := {
                    Key: key, Name: node.Name, Level: node.Battery,
                    Connected: "", NameScore: -1000, ConnectionScore: -1
                }
                groups[key] := device
                ordered.Push(device)
            }
        }

        ; Consider non-battery sibling nodes of the same physical container.
        for node in nodes
        {
            key := BluetoothBatteryTracker.GroupKey(node)
            if (!groups.Has(key))
                continue

            device := groups[key]
            score := BluetoothBatteryTracker.NameScore(node)
            if (node.Name != "" && score > device.NameScore)
            {
                device.Name := node.Name
                device.NameScore := score
            }
            if (Type(node.Connected) = "Integer"
                && score > device.ConnectionScore)
            {
                device.Connected := node.Connected
                device.ConnectionScore := score
            }
        }

        for device in ordered
        {
            if (device.Name = "")
                device.Name := "(unnamed Bluetooth device)"
            else if (device.NameScore < 100)
            {
                ; Fallback only when a primary DEV_ name cannot be found.
                device.Name := RegExReplace(device.Name,
                    "i) (Hands-Free(?: AG(?: Audio)?)?|Avrcp Transport|Stereo)$")
            }
        }
        return ordered
    }

    static CollectLowAlerts(devices, alerted, threshold)
    {
        result := []
        for device in devices
        {
            if (device.Level > threshold)
            {
                if (alerted.Has(device.Key))
                    alerted.Delete(device.Key)
                continue
            }

            ; Windows can retain a stale percentage for paired devices.
            if (device.Connected != 1 || alerted.Has(device.Key))
                continue

            alerted[device.Key] := true
            result.Push(device)
        }
        return result
    }
}
