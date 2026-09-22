[CmdletBinding()]
param(
    [string]$AutoHotkeyPath
)

$ErrorActionPreference = 'Stop'

function Find-AutoHotkeyV2 {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
            throw "AutoHotkey executable not found: $ExplicitPath"
        }

        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    foreach ($commandName in @('AutoHotkey64.exe', 'AutoHotkey.exe')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey32.exe')
    )

    if (${env:ProgramFiles(x86)}) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\v2\AutoHotkey32.exe'
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw 'AutoHotkey v2 executable was not found. Pass -AutoHotkeyPath explicitly.'
}

$autoHotkey = Find-AutoHotkeyV2 -ExplicitPath $AutoHotkeyPath
$testScripts = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Tests') -Filter '*.Tests.ahk' -File | Sort-Object Name

if ($testScripts.Count -eq 0) {
    throw 'No test scripts were found.'
}

$failures = 0

foreach ($testScript in $testScripts) {
    Write-Host "Running $($testScript.Name)..."

    $stdoutPath = [IO.Path]::GetTempFileName()
    $stderrPath = [IO.Path]::GetTempFileName()

    try {
        $process = Start-Process -FilePath $autoHotkey `
            -ArgumentList ('"{0}"' -f $testScript.FullName) `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -Wait -PassThru

        $stdout = Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue

        if ($stdout) {
            Write-Host $stdout.TrimEnd()
        }

        if ($stderr) {
            Write-Host $stderr.TrimEnd() -ForegroundColor Red
        }

        if ($process.ExitCode -ne 0) {
            Write-Host "Failed: $($testScript.Name)" -ForegroundColor Red
            $failures++
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

if ($failures -gt 0) {
    throw "$failures test suite(s) failed."
}

Write-Host "All $($testScripts.Count) test suite(s) passed." -ForegroundColor Green
