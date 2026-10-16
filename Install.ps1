[CmdletBinding()]
param(
    [ValidateSet('Home', 'Work')]
    [string]$Profile,

    [string]$Destination = (Join-Path $env:ProgramFiles 'MyWinToolbox'),

    [switch]$NoElevation,

    [switch]$Verify,

    [switch]$Restart,

    # Internal re-entry flag: avoid checking a different HKCU after UAC.
    [switch]$SkipNotificationCheck
)

$ErrorActionPreference = 'Stop'

$scheduledTaskName = 'MyWinToolbox'
$scheduledTaskPath = Join-Path $env:SystemRoot 'System32\schtasks.exe'

function Test-ScheduledTaskExists {
    & $scheduledTaskPath /Query /TN $scheduledTaskName *> $null
    return $LASTEXITCODE -eq 0
}

function Stop-MyWinToolboxScheduledTask {
    param([bool]$TaskExists)

    if (-not $TaskExists) {
        Write-Warning "Scheduled task '$scheduledTaskName' was not found. Deployment will continue."
        return
    }

    Write-Host "Stopping scheduled task '$scheduledTaskName'..."
    & $scheduledTaskPath /End /TN $scheduledTaskName *> $null

    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Scheduled task stopped.'
        Start-Sleep -Milliseconds 250
    }
    else {
        Write-Host 'Scheduled task was not running or could not be stopped; deployment will continue.' -ForegroundColor Yellow
    }
}

function Start-MyWinToolboxScheduledTask {
    param([bool]$TaskExists)

    if (-not $TaskExists) {
        Write-Warning "Scheduled task '$scheduledTaskName' was not found, so MyWinToolbox was not started."
        return
    }

    Write-Host "Starting scheduled task '$scheduledTaskName'..."
    & $scheduledTaskPath /Run /TN $scheduledTaskName *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "Deployment succeeded, but scheduled task '$scheduledTaskName' could not be started."
    }

    Write-Host 'Scheduled task started.' -ForegroundColor Green
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-CurrentUserTrayNotifications {
    # Keep this diagnostic read-only. Windows stores Explorer notification
    # senders under per-user GUID keys, which cannot be assumed to be stable
    # across user profiles or machines.
    $balloonTipsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $balloonTips = Get-ItemProperty -Path $balloonTipsPath -Name 'EnableBalloonTips' -ErrorAction SilentlyContinue
    if ($null -ne $balloonTips -and $balloonTips.EnableBalloonTips -eq 0) {
        Write-Warning 'Windows has EnableBalloonTips=0. AutoHotkey TrayTip notifications may be suppressed.'
        Write-Host "  Check: $balloonTipsPath -> EnableBalloonTips" -ForegroundColor Yellow
    }

    $senderSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
    $disabledSenders = @(
        Get-ChildItem -Path $senderSettingsPath -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -like 'Microsoft.Explorer.Notification.*' } |
            ForEach-Object {
                $settings = Get-ItemProperty -LiteralPath $_.PSPath -Name 'Enabled' -ErrorAction SilentlyContinue
                if ($null -ne $settings -and $settings.Enabled -eq 0) {
                    $_.PSChildName
                }
            }
    )

    if ($disabledSenders.Count -gt 0) {
        Write-Warning "$($disabledSenders.Count) Windows Explorer notification sender(s) have Enabled=0. TrayTip notifications might be blocked."
        foreach ($sender in $disabledSenders) {
            Write-Host "  Disabled: $sender" -ForegroundColor Yellow
        }
        Write-Host '  These GUIDs do not uniquely identify AutoHotkey. Review the sender before changing its settings.' -ForegroundColor Yellow
    }
}

function Select-Profile {
    Write-Host 'Select the MyWinToolbox profile to deploy:'
    Write-Host '  [H] Home'
    Write-Host '  [W] Work'

    while ($true) {
        $answer = Read-Host 'Profile'
        switch ($answer.Trim().ToUpperInvariant()) {
            'H' { return 'Home' }
            'HOME' { return 'Home' }
            'W' { return 'Work' }
            'WORK' { return 'Work' }
            default { Write-Warning "Enter 'H' for Home or 'W' for Work." }
        }
    }
}

if (-not $Profile) {
    $Profile = Select-Profile
}

# Check the invoking Windows user's HKCU before a possible UAC elevation:
# an alternate administrator account could have a different HKCU hive.
if (-not $SkipNotificationCheck) {
    Test-CurrentUserTrayNotifications
}

$sourceRoot = $PSScriptRoot
$destinationPath = [IO.Path]::GetFullPath($Destination)
$programFilesPath = [IO.Path]::GetFullPath($env:ProgramFiles).TrimEnd('\')
$destinationIsInProgramFiles =
    $destinationPath.Equals($programFilesPath, [StringComparison]::OrdinalIgnoreCase) -or
    $destinationPath.StartsWith($programFilesPath + '\', [StringComparison]::OrdinalIgnoreCase)

if ($destinationIsInProgramFiles -and -not $NoElevation -and -not (Test-IsAdministrator)) {
    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $PSCommandPath)
        '-Profile', $Profile
        '-Destination', ('"{0}"' -f $destinationPath)
    )

    if ($Verify) {
        $arguments += '-Verify'
    }

    if ($Restart) {
        $arguments += '-Restart'
    }

    # We already checked the calling user's HKCU before elevation.
    $arguments += '-SkipNotificationCheck'

    Write-Host 'Administrator permission is required to deploy to Program Files.'
    $process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments -Wait -PassThru
    exit $process.ExitCode
}

$scheduledTaskExists = Test-ScheduledTaskExists
Stop-MyWinToolboxScheduledTask -TaskExists $scheduledTaskExists

$obsoleteDeploymentFiles = @(
    'Libs\TextSnippetsEditor.ahk'
    'Libs\ConfiguratorScheduledTasksTab.ahk'
    'Libs\ConfiguratorAhkScriptsTab.ahk'
)

foreach ($relativePath in $obsoleteDeploymentFiles) {
    $obsoletePath = Join-Path $destinationPath $relativePath
    if (Test-Path -LiteralPath $obsoletePath -PathType Leaf) {
        Remove-Item -LiteralPath $obsoletePath -Force
        Write-Host "Removed obsolete file: $relativePath"
    }
}

$entryScript = "MyWin$Profile.ahk"
$files = @(
    $entryScript
    'MyWinShared.ahk'
    'Test.ps1'
    'Docs\SHORTCUTS.pdf'
)

$libFiles = Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'Libs') -File -Recurse -Filter '*.ahk'
$files += $libFiles | ForEach-Object {
    $_.FullName.Substring($sourceRoot.TrimEnd('\').Length + 1)
}

$sharedFiles = Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'Shared') -File -Recurse -Filter '*.ahk'
$files += $sharedFiles | ForEach-Object {
    $_.FullName.Substring($sourceRoot.TrimEnd('\').Length + 1)
}

$testFiles = Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'Tests') -File -Recurse -Filter '*.ahk'
$files += $testFiles | ForEach-Object {
    $_.FullName.Substring($sourceRoot.TrimEnd('\').Length + 1)
}

$copied = 0
$unchanged = 0

foreach ($relativePath in $files) {
    $sourcePath = Join-Path $sourceRoot $relativePath
    $targetPath = Join-Path $destinationPath $relativePath
    $targetDirectory = Split-Path -Parent $targetPath

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required deployment file is missing: $relativePath"
    }

    $needsCopy = -not (Test-Path -LiteralPath $targetPath -PathType Leaf)
    if (-not $needsCopy) {
        $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
        $needsCopy = $sourceHash -ne $targetHash
    }

    if ($needsCopy) {
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
        Write-Host "Updated: $relativePath"
        $copied++
    }
    else {
        $unchanged++
    }
}

if ($Verify) {
    $verificationErrors = @()

    foreach ($relativePath in $files) {
        $sourcePath = Join-Path $sourceRoot $relativePath
        $targetPath = Join-Path $destinationPath $relativePath

        if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
            $verificationErrors += "Missing target file: $relativePath"
            continue
        }

        $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash

        if ($sourceHash -ne $targetHash) {
            $verificationErrors += "Hash mismatch: $relativePath"
        }
    }

    if ($verificationErrors.Count -gt 0) {
        throw ("Deployment verification failed:`n - " + ($verificationErrors -join "`n - "))
    }

    Write-Host "Verification passed for $($files.Count) deployed files." -ForegroundColor Green
}

Write-Host ''
Write-Host "MyWinToolbox $Profile deployed to: $destinationPath" -ForegroundColor Green
Write-Host "Updated files: $copied; unchanged files: $unchanged"
Write-Host 'Configuration and JSON data files were not changed.'

if ($Restart) {
    Write-Verbose '-Restart is retained for backward compatibility; the scheduled task is restarted after every successful deployment.'
}

Start-MyWinToolboxScheduledTask -TaskExists $scheduledTaskExists
