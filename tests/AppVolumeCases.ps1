# Plain-data UI fixtures; no real session worker/audio writes in offline previews.
$realAppSnapshot=${function:Get-AppVolumeSnapshot}
$script:AppUiSnapshot=[pscustomobject]@{Ready=$true;Error='';Revision=1;Sessions=@()}
function Get-AppVolumeSnapshot { $script:AppUiSnapshot }
$script:ProfileMap['Knob_55'].ActionType='VolumeApp'; $script:ProfileMap['Knob_55'].Target='chrome'; $script:ProfileMap['Knob_55'].Label='Chrome'
$appA=[pscustomobject]@{Id='output-a|instance-1';Name='chrome';Display='';Percent=20;Muted=$false;Available=$true;Acquired=@();Waiting=@()}
$appB=[pscustomobject]@{Id='output-b|instance-2';Name='chrome';Display='';Percent=80;Muted=$false;Available=$true;Acquired=@();Waiting=@()}
$beforeAppAudio=$script:TestAudio.Count; $beforeAppActions=$script:TestActions.Count
try {
    $null=Sync-KnobObservations -AppsOnly
    Assert-Ui (-not $script:KnobStates['Knob_55'].Known -and (Get-KnobFeedback 'Knob_55' $true $false) -eq 'No session') 'No app session appeared as zero.'
    $script:AppUiSnapshot.Sessions=@($appA,$appB); $null=Sync-KnobObservations -AppsOnly
    Assert-Ui ((Get-KnobValueText 'Knob_55') -eq '20–80%' -and $script:KnobStates['Knob_55'].Status -eq 'Mixed levels') 'Different sessions did not display a truthful range.'
    $script:KnobLastPhys['Knob_55']=0
    Assert-Ui ((Get-KnobFeedback 'Knob_55' $true $false) -eq 'CW to 20% · 0/2') 'Multi-session pickup did not point at the nearest waiting level.'
    $appA.Acquired=@('Knob_55|chrome'); $null=Sync-KnobObservations -AppsOnly
    Assert-Ui ((Get-KnobFeedback 'Knob_55' $true $false) -eq 'CW to 80% · 1/2') 'Partial pickup omitted the remaining session.'
    Select-ApcControl 'Knob_55'; Update-ControlDescription 'Knob_55'
    Assert-Ui ($script:ControlButtons['Knob_55'].AccessibleDescription -like '*20–80%*caught 1/2*') 'Accessible readout hides mixed sessions.'
    Set-KnobCommand 'Knob_55' 50
    Assert-Ui ((Get-KnobValueText 'Knob_55') -eq '20–80%') 'Queued command was substituted for actual app readback.'
    $script:KnobLastPhys['Knob_55']=95
    Assert-Ui ((Get-KnobFeedback 'Knob_55' $true $false) -eq 'CCW to 80% · 1/2') 'Downward pickup guidance incorrect.'
    foreach($size in @([Drawing.Size]::new(1680,970),[Drawing.Size]::new(800,600))) {
        $form.Size=$size; Update-WindowLayout; Show-WorkspacePane $false; Invalidate-ApcControl 'Knob_55'
        Save-TestFrame "app-volume-$($size.Width).png"
    }
    Set-ReadableTextScale 2.25; Set-ApcContrastTheme $true
    $appTile=$script:ControlButtons['Knob_55']; $graphics=$appTile.CreateGraphics()
    try {
        $value=Get-KnobValueText 'Knob_55'
        $font=Get-KnobValueFont $graphics ($appTile.Width-6) ([int]($appTile.Height/5)) $value
        Assert-Ui ($graphics.MeasureString($value,$font).Width -le $appTile.Width-6) 'Mixed range clips at the compact large-text size.'
        $feedback=Format-KnobFeedbackForWidth (Get-KnobFeedback 'Knob_55' $true $false) $appTile.Width
        Assert-Ui ($feedback -eq 'CCW 1/2') 'Compact feedback lost pickup count/direction.'
        $font=Get-SurfaceFont $graphics 'FKnobFeedback' ($appTile.Width-6) ([int]($appTile.Height/6)) $feedback
        Assert-Ui ($graphics.MeasureString($feedback,$font).Width -le $appTile.Width-6) 'Compact app pickup feedback clips.'
    } finally { $graphics.Dispose() }
    Save-TestFrame 'app-volume-large-contrast.png'
    $appB.Muted=$true; $null=Sync-KnobObservations -AppsOnly
    Assert-Ui ($script:KnobStates['Knob_55'].Status -eq 'Part muted') 'Mixed mute state was hidden.'
    $appB.Available=$false; $null=Sync-KnobObservations -AppsOnly
    Assert-Ui (-not $script:KnobStates['Knob_55'].Known) 'Partial readback failure appeared fully known.'
    $script:AppUiSnapshot.Sessions=@(); $null=Sync-KnobObservations -AppsOnly
    Assert-Ui ((Get-KnobValueText 'Knob_55') -eq '—') 'App exit retained a percentage.'
    $appA.Id='output-a|restarted-instance'; $appA.Acquired=@(); $appA.Percent=35; $script:AppUiSnapshot.Sessions=@($appA)
    $null=Sync-KnobObservations -AppsOnly
    Assert-Ui ((Get-KnobValueText 'Knob_55') -eq '35%' -and $script:KnobStates['Knob_55'].Caught -eq 0) 'Restart did not reset observed session identity/pickup.'
    $appA.Percent=64; $script:AppUiSnapshot.Revision=98765; $script:LastAppUiPoll=0
    $tick=[Windows.Forms.Timer].GetMethod('OnTick',[Reflection.BindingFlags]'Instance,NonPublic')
    $null=$tick.Invoke($midiTimer,@([EventArgs]::Empty))
    Assert-Ui ((Get-KnobValueText 'Knob_55') -eq '64%') 'MIDI loop did not reconcile worker revision into app readback.'
    Set-StatusBanner 'Test failed: app fixture failure'
    $attention=$script:RecoveryAttention
    Set-StatusBanner "[TEST Knob_55 — not saved] App 'chrome': 50% requested; awaiting readback"
    Assert-Ui ($script:RecoveryAttention -eq $attention) 'An async request falsely resolved a failed Test.'
    Assert-Ui (Test-RecoveryFailureResult 'App volume failed: worker unavailable') 'Worker rejection did not count as a failed action.'
} finally {
    Set-Item Function:Get-AppVolumeSnapshot $realAppSnapshot
    Set-ReadableTextScale 1; Set-ApcContrastTheme $false; $form.Size=[Drawing.Size]::new(1680,970); Update-WindowLayout
}
Assert-Ui ($script:TestAudio.Count -eq $beforeAppAudio -and $script:TestActions.Count -eq $beforeAppActions) 'App readback UI executed an action.'
[Console]::WriteLine('APP_VOLUME_UI_TESTS_OK: mixed range, per-session catch count/direction, no session, mixed mute, failed readback, new session identity, truthful queued writes, accessible details, compact/225%/high-contrast renders; no real writes.')
