#Requires AutoHotkey v2.0

#Include ..\Libs\BluetoothBattery.ahk

BB_Assert(condition, message)
{
    if (!condition)
    {
        FileAppend("FAIL: " message Chr(10), "**")
        ExitApp(1)
    }
}

; Battery and display name are on separate PnP nodes of one container.
nodes := [
    {Id:"BTHENUM\SERVICE_A", Container:"A1", Address:"", Name:"Redmi Buds 3 Lite Hands-Free AG", Class:"System", Battery:70, Connected:""},
    {Id:"BTHENUM\DEV_1", Container:"A1", Address:"", Name:"Redmi Buds 3 Lite", Class:"Bluetooth", Battery:"", Connected:0},
    {Id:"BTHENUM\DEV_2", Container:"B1", Address:"", Name:"HD 4.40BT", Class:"Bluetooth", Battery:100, Connected:1},
    {Id:"BTHENUM\AG_2", Container:"B1", Address:"", Name:"HD 4.40BT Hands-Free AG", Class:"System", Battery:100, Connected:""},
    {Id:"BTHENUM\AG_3", Container:"C1", Address:"", Name:"HD 4.40BT Hands-Free AG", Class:"System", Battery:15, Connected:""},
    {Id:"BTHENUM\DEV_3", Container:"C1", Address:"", Name:"HD 4.40BT", Class:"Bluetooth", Battery:"", Connected:1},
    {Id:"BTHENUM\EMPTY", Container:"D1", Address:"", Name:"Unrelated", Class:"Bluetooth", Battery:"", Connected:""}
]

devices := BluetoothBatteryTracker.Collapse(nodes)
BB_Assert(devices.Length = 3, "One entry per physical battery device")
BB_Assert(devices[1].Name = "Redmi Buds 3 Lite", "Use DEV_ friendly name")
BB_Assert(devices[1].Level = 70 && devices[1].Connected = 0,
    "Keep battery and connection status across child nodes")
BB_Assert(devices[2].Name = devices[3].Name
    && devices[2].Key != devices[3].Key,
    "Do not merge distinct devices with the same name")

alerted := Map()
alarms := BluetoothBatteryTracker.CollectLowAlerts(devices, alerted, 20)
BB_Assert(alarms.Length = 1 && alarms[1].Level = 15,
    "Alert only low and actively connected batteries")
BB_Assert(BluetoothBatteryTracker.CollectLowAlerts(devices, alerted, 20).Length = 0,
    "Do not repeat notifications at every refresh")
devices[3].Level := 80
BluetoothBatteryTracker.CollectLowAlerts(devices, alerted, 20)
devices[3].Level := 10
BB_Assert(BluetoothBatteryTracker.CollectLowAlerts(devices, alerted, 20).Length = 1,
    "Re-arm alerts after charging above the threshold")

; Regression: enumerate present device IDs even if no Bluetooth devices are paired.
; Previously a local variable named "buffer" shadowed the built-in Buffer class.
ids := BluetoothBatteryTracker.GetPresentIds()
BB_Assert(Type(ids) = "Array", "PnP device ID enumeration returns an array")

FileAppend("BluetoothBattery grouping and alert tests passed." Chr(10), "*")
ExitApp(0)
