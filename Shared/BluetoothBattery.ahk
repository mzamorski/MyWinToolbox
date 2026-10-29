#Requires AutoHotkey v2.0

; Bluetooth Battery is a Shared feature for both Home and Work profiles.
; A PnP failure must not prevent the rest of the toolbox from starting.
try
{
    enabled := Ini_ReadBoolOrDefault(
        SharedConfigFilePath, "BluetoothBattery", "Enabled", true)
    refreshText := Trim("" Ini_ReadOrDefault(
        SharedConfigFilePath, "BluetoothBattery", "RefreshMinutes", "5"))
    thresholdText := Trim("" Ini_ReadOrDefault(
        SharedConfigFilePath, "BluetoothBattery", "LowBatteryThreshold", "20"))

    if (!RegExMatch(refreshText, "^\d+$")
        || (refreshText + 0) < 1 || (refreshText + 0) > 60)
        throw Error("BluetoothBattery.RefreshMinutes must be 1..60.")
    if (!RegExMatch(thresholdText, "^\d+$")
        || (thresholdText + 0) < 0 || (thresholdText + 0) > 100)
        throw Error("BluetoothBattery.LowBatteryThreshold must be 0..100.")

    notify := Ini_ReadBoolOrDefault(
        SharedConfigFilePath, "BluetoothBattery", "NotifyLowBattery", true)

    global gBluetoothBattery := BluetoothBatteryTracker(
        enabled, refreshText + 0, thresholdText + 0, notify)
    A_TrayMenu.Add("Bluetooth Battery", gBluetoothBattery.Menu)
    gBluetoothBattery.Start()
    OnExit(ObjBindMethod(gBluetoothBattery, "Stop"))
}
catch Error as e
{
    Logger.Error(e.Message, "BluetoothBattery")
    unavailable := "Bluetooth Battery (unavailable)"
    A_TrayMenu.Add(unavailable, (*) => 0)
    A_TrayMenu.Disable(unavailable)
}
