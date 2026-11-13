# Explicit refresh is single-flight. Keep cold property-store reads out of the UI thread.
$script:DeviceRefreshJob = $null
$deviceRefreshTimer = [Windows.Forms.Timer]::new()
$deviceRefreshTimer.Interval = 50

function Start-DeviceNameRead {
    $path = Join-Path ([IO.Path]::GetTempPath()) ('apc-device-names-' + [guid]::NewGuid().ToString('N') + '.json')
    $info = [Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh.exe'))
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    foreach ($arg in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $PSScriptRoot 'Read-DeviceNames.ps1'),'-OutputPath',$path)) {
        $info.ArgumentList.Add($arg)
    }
    $process = [Diagnostics.Process]::Start($info)
    [pscustomobject]@{ Process=$process; Path=$path; Started=[Environment]::TickCount64 }
}

function Stop-DeviceRefresh {
    $deviceRefreshTimer.Stop()
    $job = $script:DeviceRefreshJob
    $script:DeviceRefreshJob = $null
    try {
        if ($job) {
            try {
                if (-not $job.Process.HasExited) { $job.Process.Kill(); $null=$job.Process.WaitForExit(100) }
            } finally {
                $job.Process.Dispose()
                Remove-Item -LiteralPath $job.Path -Force -ErrorAction SilentlyContinue
            }
        }
    } finally {
        $btnRefresh.Enabled = $true
        if ($script:EventsWindow -and -not $script:EventsWindow.IsDisposed -and $script:EventsWindow.Visible) { Update-RecentEventDetails }
    }
}

function Start-DeviceRefresh {
    if ($script:DeviceRefreshJob) { return }
    try {
        $script:DeviceRefreshJob = Start-DeviceNameRead
        $btnRefresh.Enabled = $false
        Set-StatusBanner 'Refreshing devices… You can keep editing and using the controller.'
        $deviceRefreshTimer.Start()
    } catch {
        Stop-DeviceRefresh
        Set-StatusBanner "Device refresh failed: $($_.Exception.Message). Press F5 to retry."
    }
}

function Complete-DeviceRefresh {
    $job = $script:DeviceRefreshJob
    if (-not $job) { return }
    try {
        if (-not $job.Process.HasExited) {
            if (([Environment]::TickCount64 - $job.Started) -gt 15000) { throw 'Device discovery timed out' }
            return
        }
        if ($job.Process.ExitCode -ne 0) { throw 'Device discovery did not complete' }
        # Use the existing quiet period before reconciling live observations/pickup.
        if (([Environment]::TickCount64 - $script:LastKnobTurnTick) -lt 800) { return }
        $names = [IO.File]::ReadAllText($job.Path) | ConvertFrom-Json -AsHashtable
        if ($names -isnot [hashtable]) { throw 'Invalid device discovery result' }
        # Bind fresh COM endpoints on the UI thread, with names already discovered.
        # Do not adopt the worker's older volume/default observations over current commands.
        $nextAudio = @(Get-AudioEndpointsSnapshot -FriendlyNames $names)
        $nextBt = @(Get-PairedBluetoothDevices -AudioSnapshot $nextAudio)
        if (-not $OfflinePreview -and -not [GoodCube.ApcDeck.NativeBridge]::IsOpen) {
            $null = [GoodCube.ApcDeck.NativeBridge]::OpenDevice('APC Key 25')
        }
        $script:AudioSnapshot = $nextAudio
        $script:BtSnapshot = $nextBt
        Update-CachedTelemetrySummaries
        Update-ObservedControls
        Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot -Force
        foreach ($cid in @(Update-PadVelocitiesCache)) { Invalidate-ApcControl $cid }
        Populate-TargetDropdowns ([string]$cmbAction.SelectedItem)
        Update-InspectorDraftState
        $headerPanel.Invalidate()
        if (-not $OfflinePreview -and -not [GoodCube.ApcDeck.NativeBridge]::IsOpen) {
            Set-StatusBanner 'Device refresh failed: Audio/Bluetooth updated, but the APC Key 25 is still offline. Check its USB connection and other MIDI apps, then press F5 to retry.'
        } else {
            Set-StatusBanner 'Refreshed audio/Bluetooth endpoints and synced physical APC Key 25 LEDs.'
        }
    } catch {
        Set-StatusBanner "Device refresh failed: $($_.Exception.Message). Press F5 to retry."
    }
    Stop-DeviceRefresh
}
$deviceRefreshTimer.Add_Tick({ Complete-DeviceRefresh })
