# Exercise single-flight async refresh through real WinForms controls, with no hardware writes.
$midiTimer.Stop(); $syncTimer.Stop()
$script:Drafts.Clear()
Select-ApcControl 'Pad_32'
$cmbTarget1.Text='Retained target outside choices'
$cmbTarget1.Select(3,5)
$draftBeforeRefresh=$script:Drafts['Pad_32'] | ConvertTo-Json -Compress
Populate-TargetDropdowns ([string]$cmbAction.SelectedItem)
Assert-Ui ($cmbTarget1.Text -eq 'Retained target outside choices' -and $cmbTarget1.SelectionStart -eq 3 -and $cmbTarget1.SelectionLength -eq 5) 'Unchanged choices disturbed editing/caret.'
$oldAudio=$script:AudioSnapshot
$script:AudioSnapshot=@()
Populate-TargetDropdowns 'VolumeDevice'
Assert-Ui ($cmbTarget1.Items.Count -eq 2) 'Empty snapshot lost default choices.'
$script:AudioSnapshot=$oldAudio
Populate-TargetDropdowns 'VolumeDevice'
Assert-Ui ($cmbTarget1.Items.Count -gt 2 -and $cmbTarget1.Text -eq 'Retained target outside choices') 'New choices lost the typed target.'

$realStart=(Get-Command Start-DeviceNameRead).ScriptBlock
$script:DiscoveryMode='Success'
$script:DiscoveryStarts=0
function Start-DeviceNameRead {
    $script:DiscoveryStarts++
    $path=Join-Path ([IO.Path]::GetTempPath()) ('apc-refresh-test-'+[guid]::NewGuid().ToString('N')+'.json')
    $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh.exe'))
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    foreach ($arg in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'DeviceNamesFixture.ps1'),'-OutputPath',$path,'-Mode',$script:DiscoveryMode)) { $info.ArgumentList.Add($arg) }
    [pscustomobject]@{ Process=[Diagnostics.Process]::Start($info); Path=$path; Started=[Environment]::TickCount64 }
}
$script:LastKnobTurnTick=0
$script:RefreshNames=$null; $script:ForcedSyncs=0
function Get-AudioEndpointsSnapshot {
    param([hashtable]$FriendlyNames=@{})
    $script:RefreshNames=$FriendlyNames
    $script:SnapshotReads++
    $script:FixtureSnapshot
}
function Sync-ApcHardwareLeds {
    param($ProfileMap,$AudioSnapshot,$BtSnapshot,[switch]$Force)
    if ($Force) { $script:ForcedSyncs++ }
}
$script:HeartbeatCount=0
$heartbeat=[Windows.Forms.Timer]::new(); $heartbeat.Interval=15
$heartbeat.Add_Tick({ $script:HeartbeatCount++ }); $heartbeat.Start()
function Wait-FixtureRefresh {
    $deadline=[Environment]::TickCount64+8000
    while ($script:DeviceRefreshJob -and [Environment]::TickCount64 -lt $deadline) {
        [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 5
    }
    Assert-Ui (-not $script:DeviceRefreshJob) 'Refresh failed to finish within test deadline.'
}
try {
    $saves=$script:TestSaves; $audio=$script:TestAudio.Count; $actions=$script:TestActions.Count
    $beforeReads=$script:SnapshotReads
    $btnRefresh.PerformClick()
    $worker=$script:DeviceRefreshJob.Process; $workerId=$worker.Id; $workerPath=$script:DeviceRefreshJob.Path
    Start-DeviceRefresh
    Assert-Ui ($script:DiscoveryStarts -eq 1 -and -not $btnRefresh.Enabled) 'Refresh did not coalesce repeated requests.'
    Invoke-FixtureTick
    Assert-Ui ($script:SnapshotReads -eq $beforeReads) 'Periodic refresh competed with discovery.'
    Select-ApcControl 'Key_49'; $txtLabel.Text='Editing while discovery runs'
    Select-ApcControl 'Pad_32'
    Assert-Ui ($cmbTarget1.Text -eq 'Retained target outside choices') 'Selection during discovery lost the draft.'
    Wait-FixtureRefresh
    Assert-Ui ($script:HeartbeatCount -ge 5) 'Message pump was blocked during discovery.'
    Assert-Ui ($script:RefreshNames['fixture-endpoint'] -eq 'Fixture renamed device') 'Discovery names were not passed to the owning audio thread.'
    Assert-Ui ($script:ForcedSyncs -eq 1 -and $btnRefresh.Enabled) 'Successful refresh did not force LED sync/re-enable retry.'
    Assert-Ui (-not (Test-Path $workerPath) -and -not (Get-Process -Id $workerId -ErrorAction SilentlyContinue)) 'Completed refresh leaked a process or result file.'
    Assert-Ui (($script:Drafts['Pad_32'] | ConvertTo-Json -Compress) -ceq $draftBeforeRefresh) 'Refresh completion mutated retained draft.'
    Assert-Ui ($script:TestSaves -eq $saves -and $script:TestAudio.Count -eq $audio -and $script:TestActions.Count -eq $actions) 'Refresh executed a mapping, audio write, or save.'
    foreach ($mode in @('Failure','Invalid','Slow')) {
        $script:DiscoveryMode=$mode; $prior=$script:AudioSnapshot | ConvertTo-Json -Compress
        Start-DeviceRefresh
        if ($mode -eq 'Slow') { $script:DeviceRefreshJob.Started=[Environment]::TickCount64-16000 }
        Wait-FixtureRefresh
        Assert-Ui ($script:LastStatusEvent -match 'Device refresh failed:.*retry' -and $btnRefresh.Enabled) 'Failure/timeout did not allow retry.'
        Assert-Ui (($script:AudioSnapshot | ConvertTo-Json -Compress) -ceq $prior -and $script:ForcedSyncs -eq 1) 'Failed refresh replaced observations or forced LEDs.'
    }
    $script:DiscoveryMode='Success'; Start-DeviceRefresh
    $deviceRefreshTimer.Stop()
    $deadline=[Environment]::TickCount64+8000
    while (-not $script:DeviceRefreshJob.Process.HasExited -and [Environment]::TickCount64 -lt $deadline) { Start-Sleep -Milliseconds 10 }
    Assert-Ui $script:DeviceRefreshJob.Process.HasExited 'Retry fixture failed to exit.'
    $script:LastKnobTurnTick=[Environment]::TickCount64
    Complete-DeviceRefresh
    Assert-Ui ($null -ne $script:DeviceRefreshJob -and $script:ForcedSyncs -eq 1) 'Refresh completion interrupted the active-knob grace period.'
    $script:LastKnobTurnTick=0
    Complete-DeviceRefresh
    Assert-Ui ($script:ForcedSyncs -eq 2) 'Retry after failure did not recover.'
    $script:DiscoveryMode='Slow'; Start-DeviceRefresh
    $cancelId=$script:DeviceRefreshJob.Process.Id; $cancelPath=$script:DeviceRefreshJob.Path
    Stop-DeviceRefresh
    Assert-Ui (-not $script:DeviceRefreshJob -and -not (Test-Path $cancelPath) -and -not (Get-Process -Id $cancelId -ErrorAction SilentlyContinue)) 'Shutdown cleanup left discovery running.'
} finally {
    $heartbeat.Stop(); $heartbeat.Dispose(); Stop-DeviceRefresh
    Set-Item Function:Start-DeviceNameRead $realStart
}
[Console]::WriteLine('FLUIDITY_TESTS_OK: unchanged choices/caret, changed/empty snapshots, editable drafts and heartbeat during discovery, single-flight, periodic exclusion, fresh owner-thread read, forced LED sync, failure/invalid/timeout/retry and shutdown cleanup; no real writes.')
