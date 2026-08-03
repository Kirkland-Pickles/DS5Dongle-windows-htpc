:: this file exists to flush out old dualsense entries, fixing issues
@echo off
setlocal
title DualSense Device Cache Cleaner
set "SELF=%~f0"

fltmc >nul 2>&1
if errorlevel 1 (
    powershell.exe -NoProfile -Command "Start-Process -FilePath $env:SELF -Verb RunAs"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$tmp=Join-Path $env:TEMP ('ds5-clear-'+[guid]::NewGuid().ToString('N')+'.ps1'); $code=[IO.File]::ReadAllText($env:SELF); $marker=':__POWERSHELL__'; [IO.File]::WriteAllText($tmp,$code.Substring($code.LastIndexOf($marker)+$marker.Length),[Text.UTF8Encoding]::new($false)); try { & $tmp } catch { Write-Host ''; Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red; Write-Host ''; Read-Host 'Press Enter to close' } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }"
exit /b

:__POWERSHELL__
$pattern = 'VID_054C&PID_0(CE6|DF2)'

try {
    $devices = @(
        Get-PnpDevice -ErrorAction Stop |
            Where-Object {
                $_.InstanceId -match $pattern -or
                $_.FriendlyName -match 'DualSense'
            } |
            Sort-Object InstanceId -Unique
    )
} catch {
    Write-Host ""
    Write-Host "Could not enumerate Plug and Play devices:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Write-Host ""
    Read-Host "Press Enter to close"
    return
}

if ($devices.Count -eq 0) {
    Write-Host ""
    Write-Host "No DualSense device entries were found."
    Write-Host ""
    Read-Host "Press Enter to close"
    return
}

$removed = 0
$failed = @()

foreach ($device in $devices) {
    pnputil.exe /remove-device "$($device.InstanceId)" | Out-Null

    if ($LASTEXITCODE -eq 0) {
        $removed++
    } else {
        $failed += $device
    }
}

pnputil.exe /scan-devices | Out-Null

Write-Host ""
Write-Host "Removed $removed of $($devices.Count) DualSense device entries."

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Could not remove:" -ForegroundColor Yellow
    $failed | ForEach-Object {
        Write-Host "  $($_.FriendlyName) [$($_.InstanceId)]"
    }
}

Write-Host ""
Read-Host "Press Enter to close"
