# Runs inside the offline WinForms process, with audio/MIDI/profile sinks from InspectorCases.
$script:FixtureSnapshot = @(Get-AudioEndpointsSnapshot)
$script:SnapshotReads = 0
$script:FailSnapshot = $false
function Get-AudioEndpointsSnapshot {
    if ($script:FailSnapshot) { throw 'Fixture snapshot failure' }
    $script:SnapshotReads++
    return $script:FixtureSnapshot
}
$script:ProfileMap['Knob_48'].ActionType = 'VolumeMasterOut'
$script:ProfileMap['Knob_48'].Target = '@DefaultRender'
$script:ProfileMap['Knob_49'].ActionType = 'VolumeDevice'
$script:ProfileMap['Knob_49'].Target = 'COMMAND_CENTER'
$script:AudioSnapshot = $script:FixtureSnapshot
Update-ObservedControls
$chkEditOnly.Checked = $false
$chkPickupMode.Checked = $true
$tickMethod = [Windows.Forms.Timer].GetMethod('OnTick', [Reflection.BindingFlags]'Instance,NonPublic')
function Invoke-FixtureTick {
    $script:LastKnobTurnTick = 0
    $tickMethod.Invoke($syncTimer, @([EventArgs]::Empty))
}
$audioCallsBefore = $script:TestAudio.Count
Set-StatusBanner 'Keep this event through telemetry refresh'
$script:KnobPickedUp['Knob_48'] = $true
$script:KnobLastPhys['Knob_48'] = 20
$script:FixtureSnapshot[0].VolumePct = 42
Invoke-FixtureTick
Assert-Ui ($script:KnobValues['Knob_48'] -eq 42 -and -not $script:KnobPickedUp['Knob_48']) 'External volume failed to reconcile/re-arm pickup.'
Assert-Ui ($script:KnobValues['Knob_49'] -eq 42) 'Shared endpoint knob remained stale.'
Assert-Ui ((Get-KnobFeedback 'Knob_48' $true $false) -eq 'CW to 42%') 'Clockwise pickup guidance incorrect.'
Assert-Ui ($statusBox.Text -match '42%' -and $statusBox.Text -match 'Keep this event') 'Footer refresh lost event or retained old volume.'
Assert-Ui (@(Sync-KnobObservations).Count -eq 0) 'Unchanged snapshot requested knob redraws.'
$script:KnobLastPhys['Knob_48'] = 80
Assert-Ui ((Get-KnobFeedback 'Knob_48' $true $false) -eq 'CCW to 42%') 'Counterclockwise pickup guidance incorrect.'
$script:KnobPickedUp['Knob_48'] = $true
Set-KnobCommand 'Knob_48' 65
Assert-Ui ((Get-KnobFeedback 'Knob_48' $true $false) -eq 'Updating...') 'Unconfirmed command presented as observed state.'
$script:FixtureSnapshot[0].VolumePct = 65
Invoke-FixtureTick
Assert-Ui ($script:KnobPickedUp['Knob_48'] -and -not $script:KnobStates['Knob_48'].Pending) 'Our confirmed write incorrectly re-armed pickup.'
$script:FixtureSnapshot[0].Muted = $true
Invoke-FixtureTick
Assert-Ui ($script:KnobStates['Knob_48'].Muted -and -not $script:KnobPickedUp['Knob_48'] -and $statusBox.Text -match 'MUTED') "External mute was missed: muted=$($script:KnobStates['Knob_48'].Muted), pickup=$($script:KnobPickedUp['Knob_48']), footer=$($statusBox.Text)"
# The default changes even when its percentage is identical.
$script:FixtureSnapshot[0].IsDefault = $false
$script:FixtureSnapshot[1].IsDefault = $true
$script:FixtureSnapshot[1].VolumePct = 65
$script:KnobPickedUp['Knob_48'] = $true
Invoke-FixtureTick
Assert-Ui ($script:KnobStates['Knob_48'].EndpointId -eq 'VOICE_CUBE' -and -not $script:KnobPickedUp['Knob_48']) 'Default endpoint switch retained old pickup ownership.'
$script:FixtureSnapshot[0].State = 'Unplugged'
$script:FixtureSnapshot[0].VolumePct = $null
Invoke-FixtureTick
Assert-Ui (-not $script:KnobStates['Knob_49'].Known -and $script:KnobStates['Knob_49'].Status -eq 'Disconnected') 'Disconnected endpoint displayed a volume.'
$script:FixtureSnapshot[0].State = 'Disabled'
Invoke-FixtureTick
Assert-Ui ($script:KnobStates['Knob_49'].Status -eq 'Disabled') 'Disabled endpoint collapsed into zero volume.'
$script:FixtureSnapshot[0].State = 'Active'
$script:FixtureSnapshot[0].VolumePct = 33
$script:FixtureSnapshot[0].Muted = $false
Invoke-FixtureTick
Assert-Ui ($script:KnobStates['Knob_49'].Known -and $script:KnobValues['Knob_49'] -eq 33 -and -not $script:KnobPickedUp['Knob_49']) 'Reconnect failed to acquire current target.'
$script:LastKnobTurnTick = [Environment]::TickCount64
$readsBefore = $script:SnapshotReads
$tickMethod.Invoke($syncTimer, @([EventArgs]::Empty))
Assert-Ui ($script:SnapshotReads -eq $readsBefore) 'Sync interrupted the active-turn grace period.'
Assert-Ui ($script:TestAudio.Count -eq $audioCallsBefore) 'Observation performed an audio write.'
$script:FailSnapshot = $true
Invoke-FixtureTick
Assert-Ui (-not $script:KnobStates['Knob_48'].Known -and $statusBox.Text -match 'refresh failed') 'Snapshot failure retained stale live state.'
$script:FailSnapshot = $false
Invoke-FixtureTick
Assert-Ui ($script:KnobStates['Knob_48'].Known) 'Snapshot recovery failed.'
# Missing and unsupported readback are explicit, including an empty endpoint list.
$script:AudioSnapshot = @()
$null = Sync-KnobObservations
Assert-Ui (-not $script:KnobStates['Knob_48'].Known) 'Empty snapshot retained a live default.'
$script:ProfileMap['Knob_55'].ActionType = 'VolumeApp'
$script:ProfileMap['Knob_55'].Target = 'fixture-app'
$null = Sync-KnobObservations
Assert-Ui ((Get-KnobFeedback 'Knob_55' $true $false) -eq 'No readback') 'App session level falsely represented as endpoint volume.'
# Show all operational states together at each supported size.
$script:AudioSnapshot = $script:FixtureSnapshot
Update-ObservedControls
$script:KnobLastPhys['Knob_48'] = 15
$script:KnobLastPhys['Knob_49'] = 90
$script:KnobStates['Knob_50'].Known = $false
$script:KnobStates['Knob_50'].Status = 'Disconnected'
$script:KnobStates['Knob_51'].Muted = $true
$script:KnobStates['Knob_52'].Known = $false
$script:KnobStates['Knob_52'].Status = 'Disabled'
$script:KnobLastPhys['Knob_53'] = -1
$script:KnobPickedUp['Knob_54'] = $true
foreach ($size in @(@(1680,970), @(1366,768), @(1200,740))) {
    $form.Size = [Drawing.Size]::new($size[0], $size[1])
    $form.PerformLayout()
    $form.Refresh()
    Save-TestFrame "live-state-$($size[0])x$($size[1]).png"
}
[Console]::WriteLine('LIVE_STATE_TESTS_OK: actual sync timer, external volume/mute/default change, shared targets, unavailable/reconnect, own writes, pickup guidance, no-change redraw suppression, active-turn grace, footer event preservation, and three rendered sizes; no real audio writes.')
