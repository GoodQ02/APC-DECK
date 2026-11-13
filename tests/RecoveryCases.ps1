# Real WinForms handlers, isolated save/action sinks inherited from InspectorCases.
$syncTimer.Stop(); $midiTimer.Stop()
$script:RecentEvents.Clear(); Update-RecoveryAttention
$saves=$script:TestSaves; $audio=$script:TestAudio.Count; $actions=$script:TestActions.Count
Show-RecentEvents
Assert-Ui ($eventsDetails.Text -like 'No recent events*' -and -not $eventsRecover.Enabled) 'Empty history lacks guidance.'
$script:EventsWindow.Close()
Select-ApcControl 'Pad_32'; Show-WorkspacePane $true
$txtLabel.Text='Recovery draft'; $script:FailSave=$true
$btnSave.PerformClick(); $script:FailSave=$false
Assert-Ui ($script:RecentEvents.Count -eq 1 -and $script:RecentEvents[0].Kind -eq 'Apply' -and $script:RecoveryAttention -eq 1) 'Save failure was not retained.'
Set-StatusBanner 'Selected Knob_48'; Set-StatusBanner 'Pickup [Speaker]: Physical=20%, Target=60%'
Assert-Ui ($script:RecentEvents.Count -eq 1 -and $statusBox.Text -like '*1 to review · F9*') 'Routine telemetry erased failure or entered history.'
for($i=0;$i -lt 70;$i++){ Add-RecoveryEvent "Completed fixture $i" }
Assert-Ui ($script:RecentEvents.Count -eq 50 -and $script:RecoveryAttention -eq 1) 'Bounded history evicted the pending failure.'
Select-ApcControl 'Pad_33'
Show-RecentEvents
$eventsList.SelectedIndex=49
Assert-Ui ($eventsList.SelectedItem.Entry.Kind -eq 'Apply' -and $eventsRecover.Text -eq 'Review / retry Apply') 'Failure has no relevant recovery option.'
$eventsRecover.PerformClick(); [Windows.Forms.Application]::DoEvents()
Assert-Ui ($script:SelectedId -eq 'Pad_32' -and $txtLabel.Text -eq 'Recovery draft' -and $script:TestSaves -eq $saves) 'Review replayed save or lost the original draft.'
$btnSave.PerformClick()
Assert-Ui ($script:TestSaves -eq $saves+1 -and $script:RecoveryAttention -eq 0) 'Explicit Apply did not recover and resolve the failure.'

# Duplicate failures coalesce; full text is selectable and later status cannot hide attention.
$script:RecentEvents.Clear()
$longError='Device refresh failed: '+('Unreachable device with a long descriptive name. '*18)
Set-StatusBanner $longError; Set-StatusBanner $longError
Assert-Ui ($script:RecentEvents.Count -eq 1 -and $script:RecentEvents[0].Count -eq 2) 'Repeated failure was not coalesced.'
Show-RecentEvents
Assert-Ui ($eventsDetails.Text.Contains($longError) -and $eventsRecover.Text -eq 'Retry Refresh') 'Full error/retry is missing.'
$realRefresh=${function:Start-DeviceRefresh}
$script:RecoveryRefreshCalls=0
try {
    function Start-DeviceRefresh { $script:RecoveryRefreshCalls++; $script:DeviceRefreshJob=[pscustomobject]@{Fixture=$true} }
    $eventsRecover.PerformClick(); $eventsRecover.PerformClick()
    Assert-Ui ($script:RecoveryRefreshCalls -eq 1 -and -not $eventsRecover.Enabled) 'Retry permits duplicate in-flight requests.'
} finally { $script:DeviceRefreshJob=$null; Set-Item Function:Start-DeviceRefresh $realRefresh }
$eventsAcknowledge.PerformClick()
Assert-Ui ($script:RecoveryAttention -eq 0 -and $script:RecentEvents.Count -eq 1 -and $eventsDetails.Text -like '*Reviewed*') 'Review deleted the error or retained attention.'
Set-StatusBanner $longError
Assert-Ui ($script:RecoveryAttention -eq 1 -and $script:RecentEvents.Count -eq 2) 'A recurring failure after review was silently suppressed.'
$script:EventsWindow.Close()

# Failed Test only offers review; it never repeats an action on its own.
Select-ApcControl 'Knob_49'; Show-WorkspacePane $true
$realVolume=${function:Set-AudioVolumeByMapping}
try {
    function Set-AudioVolumeByMapping { param($Mapping,$MidiValue) return "Device 'Fixture endpoint' is not active." }
    $btnTest.PerformClick()
    Assert-Ui ($script:RecentEvents[0].Failed -and $script:RecentEvents[0].Kind -eq 'Test') 'A returned engine failure was reported as a successful Test.'
} finally { Set-Item Function:Set-AudioVolumeByMapping $realVolume }
Set-StatusBanner 'Test failed: Feedback read failed after the action'
Show-RecentEvents
Assert-Ui ($eventsDetails.Text -like '*may already have run*' -and $eventsDetails.Text -like '*50%*') 'Retry Test omits side-effect guidance.'
$eventsRecover.PerformClick()
Assert-Ui ($script:SelectedId -eq 'Knob_49' -and $script:TestAudio.Count -eq $audio -and $script:TestActions.Count -eq $actions) 'Test recovery replayed audio/action.'

# Exercise F9 and readable native layout at small size with 225% text and high contrast.
Set-ReadableTextScale 2.25; Set-ApcContrastTheme $true
$keyArgs=[Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::F9)
$onKey=[Windows.Forms.Control].GetMethod('OnKeyDown',[Reflection.BindingFlags]'Instance,NonPublic')
$null=$onKey.Invoke($form,@($keyArgs))
$script:EventsWindow.Size=[Drawing.Size]::new(640,560)
[Windows.Forms.Application]::DoEvents()
Assert-Ui ($keyArgs.SuppressKeyPress -and $script:EventsWindow.Visible) 'F9 did not open recent events.'
Assert-Ui ($eventsDetails.Height -gt 90 -and $eventsList.Height -gt 70 -and $eventsRecover.Parent.Bottom -le $eventsRecover.Parent.Parent.ClientSize.Height) 'Large text makes event details or recovery actions unusable.'
Assert-Ui ($eventsDetails.ForeColor -eq [Drawing.SystemColors]::WindowText) 'Recovery ignores high contrast.'
function Save-RecoveryFrame([string]$name) {
    if (-not $env:APC_DECK_PREVIEW_DIRECTORY){return}
    $w=$script:EventsWindow; $w.Refresh(); $bitmap=[Drawing.Bitmap]::new($w.Width,$w.Height)
    try { $w.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$w.Width,$w.Height)); $bitmap.Save((Join-Path $env:APC_DECK_PREVIEW_DIRECTORY $name)) } finally {$bitmap.Dispose()}
}
Save-RecoveryFrame 'recovery-large-high-contrast.png'
$script:EventsWindow.Close(); Set-ReadableTextScale 1; Set-ApcContrastTheme $false
Show-RecentEvents; Save-RecoveryFrame 'recovery-events.png'; $script:EventsWindow.Close()
Show-RecentEvents; Set-ApcContrastTheme $true
Assert-Ui ($eventsDetails.ForeColor -eq [Drawing.SystemColors]::WindowText) 'Open recovery window did not adopt high contrast.'
Set-ApcContrastTheme $false
Assert-Ui ($eventsDetails.ForeColor -eq [Drawing.Color]::FromArgb(226,232,240)) 'Open recovery window did not restore its theme.'
$script:EventsWindow.Close()
Assert-Ui ($script:TestAudio.Count -eq $audio -and $script:TestActions.Count -eq $actions) 'History changed audio/actions.'
[Console]::WriteLine('RECOVERY_TESTS_OK: bounded history, pinned failure, quiet telemetry, duplicate coalescing, complete details, reviewed vs resolved, retained draft retry, no Test replay, single-flight Refresh retry, F9, 225% text and high contrast.')
