[CmdletBinding()]
param(
    [ValidateSet('Home', 'Work')]
    [string]$Profile,

    [string]$Destination = (Join-Path $env:ProgramFiles 'MyWinToolbox'),

    [switch]$NoElevation,

    [switch]$Verify,

    [switch]$Restart
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

    Write-Host 'Administrator permission is required to deploy to Program Files.'
    $process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments -Wait -PassThru
    exit $process.ExitCode
}

$scheduledTaskExists = Test-ScheduledTaskExists
Stop-MyWinToolboxScheduledTask -TaskExists $scheduledTaskExists

$entryScript = "MyWin$Profile.ahk"
$files = @(
    $entryScript
    'MyWinShared.ahk'
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
