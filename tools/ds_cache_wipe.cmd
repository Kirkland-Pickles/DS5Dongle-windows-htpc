:: this cmd removes stale dualSense device entries. run as admin or double click to run and grant access
setlocal
title ds cache cleaner
set "SELF=%~f0"

fltmc >nul 2>&1
if errorlevel 1 (
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%SELF%' -Verb RunAs"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$tmp=Join-Path $env:TEMP ('ds5-clear-'+[guid]::NewGuid().ToString('N')+'.ps1'); $code=[IO.File]::ReadAllText($env:SELF); $marker=':__POWERSHELL__'; [IO.File]::WriteAllText($tmp,$code.Substring($code.LastIndexOf($marker)+$marker.Length),[Text.UTF8Encoding]::new($false)); try { & $tmp } catch { Write-Host ''; Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red; Write-Host ''; Read-Host 'Press Enter to close' } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }"
exit /b

:__POWERSHELL__
$pattern = 'VID_054C&PID_0(CE6|DF2)'
$pnputil = "$env:SystemRoot\System32\pnputil.exe"

try {
    $controllers = Get-PnpDevice -PresentOnly -ErrorAction Stop |
        Where-Object { $_.InstanceId -match $pattern -or $_.FriendlyName -match 'DualSense' }

    $audio = Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction Stop |
        Where-Object { $_.FriendlyName -match 'DualSense|Wireless Controller' }

    $devices = @($controllers) + @($audio) | Sort-Object InstanceId -Unique
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

Write-Host ""
Write-Host "Found $($devices.Count) device entr$(if ($devices.Count -eq 1) {'y'} else {'ies'}):"
$devices | ForEach-Object { Write-Host "  $($_.FriendlyName) [$($_.InstanceId)]" }
Write-Host ""

$removed = 0
$failed = @()

foreach ($device in $devices) {
    try {
        Remove-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
        $removed++
    } catch {
        $output = & $pnputil /remove-device "$($device.InstanceId)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $removed++
        } else {
            $failed += [PSCustomObject]@{ Device = $device; Output = ($output -join ' ') }
        }
    }
}

& $pnputil /scan-devices | Out-Null

Write-Host "Removed $removed of $($devices.Count) DualSense device entries."

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Could not remove:" -ForegroundColor Yellow
    foreach ($f in $failed) {
        Write-Host "  $($f.Device.FriendlyName) [$($f.Device.InstanceId)]"
        Write-Host "    pnputil: $($f.Output)" -ForegroundColor DarkYellow
    }
}

Write-Host ""
Read-Host "Press Enter to close"
