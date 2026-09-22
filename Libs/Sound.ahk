#Requires AutoHotkey v2.0

#Include Constants.ahk
#Include StringUtils.ahk

class Sound
{
    static ResolveActiveDevice(deviceCategory)
    {
        static audioRenderKey := "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
        static deviceNameProperty := "{a45c254e-df1c-4efd-8020-67d146a850e0},2"
        static deviceDescriptionProperty := "{b3f8fa53-0004-438e-9003-51a46e139bfc},6"
        static DEVICE_STATE_ACTIVE := 1

        try
        {
            Loop Reg, audioRenderKey, "K"
            {
                endpointKey := audioRenderKey "\" A_LoopRegName
                if (RegRead(endpointKey, "DeviceState", 0) != DEVICE_STATE_ACTIVE)
                {
                    continue
                }

                propertiesKey := endpointKey "\Properties"
                deviceName := RegRead(propertiesKey, deviceNameProperty, STRING_EMPTY)
                deviceDescription := RegRead(propertiesKey, deviceDescriptionProperty, STRING_EMPTY)
                fullDeviceName := StringUtils.IsNullOrWhiteSpace(deviceDescription)
                    ? deviceName
                    : deviceName " (" deviceDescription ")"

                if (deviceName = deviceCategory || fullDeviceName = deviceCategory)
                {
                    endpointId := "{0.0.0.00000000}." A_LoopRegName
                    return { Id: endpointId, Name: fullDeviceName }
                }
            }
        }
        catch Error
        {
            return 0
        }

        return 0
    }

    static SetDefaultEndpoint(endpointId)
    {
        static CLSID_PolicyConfigClient := "{870af99c-171d-4f9e-af0d-e63df40c2bc9}"
        static IID_IPolicyConfig := "{f8679f50-850a-41cf-9c72-430f290290c8}"
        static CLSCTX_ALL := 23
        policyConfig := 0

        clsid := Sound.StringToGuid(CLSID_PolicyConfigClient)
        iid := Sound.StringToGuid(IID_IPolicyConfig)
        DllCall("ole32\CoCreateInstance",
            "Ptr", clsid, "Ptr", 0, "UInt", CLSCTX_ALL, "Ptr", iid,
            "Ptr*", &policyConfig, "HRESULT")

        try
        {
            ; 0 = Console, 1 = Multimedia, 2 = Communications
            for role in [0, 1, 2]
            {
                ComCall(13, policyConfig, "WStr", endpointId, "UInt", role, "HRESULT")
            }
        }
        finally
        {
            Sound.Release(policyConfig)
        }
    }

    static SetDefaultDevice(deviceCategory, displayName)
    {
        if (StringUtils.IsNullOrWhiteSpace(deviceCategory))
        {
            Sound.ShowToolTip("Audio device is not configured: " displayName)
            return
        }

        device := Sound.ResolveActiveDevice(deviceCategory)
        if (!device)
        {
            Sound.ShowToolTip("Audio device is not active or was not found: " deviceCategory, 2500)
            return
        }

        try
        {
            Sound.SetDefaultEndpoint(device.Id)
            Sound.ShowToolTip("Audio output: " device.Name)
        }
        catch Error as e
        {
            Sound.ShowToolTip("Unable to switch audio output to: " displayName "`n" e.Message)
        }
    }

    static ToggleProcessMute(processId)
    {
        static CLSID_MMDeviceEnumerator := "{bcde0395-e52f-467c-8e3d-c4579291692e}"
        static IID_IMMDeviceEnumerator := "{a95664d2-9614-4f35-a746-de8db63617e6}"
        static IID_IAudioSessionManager2 := "{77aa99a0-1bd6-484f-8bc7-2c654c9a9b6f}"
        static IID_IAudioSessionControl2 := "{bfb7ff88-7239-4fc9-8fa2-07c950be9c6d}"
        static IID_ISimpleAudioVolume := "{87ce5498-68d6-44e5-9215-6da47ef883d8}"
        static CLSCTX_ALL := 23
        enumerator := device := sessionManager := sessionEnumerator := 0
        volumes := []
        targetProcessName := ProcessGetName(processId)

        try
        {
            clsid := Sound.StringToGuid(CLSID_MMDeviceEnumerator)
            iid := Sound.StringToGuid(IID_IMMDeviceEnumerator)
            DllCall("ole32\CoCreateInstance",
                "Ptr", clsid, "Ptr", 0, "UInt", CLSCTX_ALL, "Ptr", iid,
                "Ptr*", &enumerator, "HRESULT")

            ; eRender = 0, eMultimedia = 1
            ComCall(4, enumerator, "Int", 0, "Int", 1, "Ptr*", &device, "HRESULT")
            sessionManagerIid := Sound.StringToGuid(IID_IAudioSessionManager2)
            ComCall(3, device, "Ptr", sessionManagerIid, "UInt", CLSCTX_ALL,
                "Ptr", 0, "Ptr*", &sessionManager, "HRESULT")
            ComCall(5, sessionManager, "Ptr*", &sessionEnumerator, "HRESULT")
            ComCall(3, sessionEnumerator, "Int*", &sessionCount := 0, "HRESULT")

            sessionControl2Iid := Sound.StringToGuid(IID_IAudioSessionControl2)
            simpleVolumeIid := Sound.StringToGuid(IID_ISimpleAudioVolume)
            Loop sessionCount
            {
                sessionControl := sessionControl2 := simpleVolume := 0
                try
                {
                    ComCall(4, sessionEnumerator, "Int", A_Index - 1,
                        "Ptr*", &sessionControl, "HRESULT")
                    ComCall(0, sessionControl, "Ptr", sessionControl2Iid,
                        "Ptr*", &sessionControl2, "HRESULT")
                    ComCall(14, sessionControl2, "UInt*", &sessionProcessId := 0, "HRESULT")
                    if (sessionProcessId != processId
                        && !Sound.IsSameProcessName(sessionProcessId, targetProcessName))
                    {
                        continue
                    }

                    ComCall(0, sessionControl, "Ptr", simpleVolumeIid,
                        "Ptr*", &simpleVolume, "HRESULT")
                    volumes.Push(simpleVolume)
                    simpleVolume := 0
                }
                finally
                {
                    Sound.Release(simpleVolume)
                    Sound.Release(sessionControl2)
                    Sound.Release(sessionControl)
                }
            }

            if (volumes.Length = 0)
            {
                throw Error("The process has no audio session on the default output device.")
            }

            shouldMute := false
            for volume in volumes
            {
                ComCall(6, volume, "Int*", &isMuted := 0, "HRESULT")
                if (!isMuted)
                {
                    shouldMute := true
                    break
                }
            }

            for volume in volumes
            {
                ComCall(5, volume, "Int", shouldMute, "Ptr", 0, "HRESULT")
            }

            return shouldMute
        }
        finally
        {
            for volume in volumes
            {
                Sound.Release(volume)
            }
            Sound.Release(sessionEnumerator)
            Sound.Release(sessionManager)
            Sound.Release(device)
            Sound.Release(enumerator)
        }
    }

    static IsSameProcessName(processId, targetProcessName)
    {
        try
        {
            return ProcessGetName(processId) = targetProcessName
        }
        catch Error
        {
            ; The process may have exited between audio-session enumeration
            ; and querying its executable name.
            return false
        }
    }

    static StringToGuid(value)
    {
        guid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", value, "Ptr", guid, "HRESULT")
        return guid
    }

    static Release(pointer)
    {
        if (pointer)
        {
            ObjRelease(pointer)
        }
    }

    static ShowToolTip(message, duration := 2000)
    {
        ToolTip(message)
        SetTimer(() => ToolTip(), -duration)
    }
}
