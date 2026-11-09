# Exercise real control event handlers and the bounded timer; all writes use existing fixture sinks.
$script:Drafts.Clear()
$form.Size=[Drawing.Size]::new(1680,970)
Set-ReadableTextScale 1.0; Update-WindowLayout; Select-ApcControl 'Pad_32'
$feedbackGeometry=(@($script:ControlButtons.Keys | Sort-Object | ForEach-Object { "$_=$($script:ControlButtons[$_].Bounds)" }) + @($keybedCanvas.KeyBounds | ForEach-Object ToString)) -join '|'
$feedbackLeds=$script:PadVelocities.Clone()
$feedbackAudio=$script:TestAudio.Count; $feedbackActions=$script:TestActions.Count; $feedbackSaves=$script:TestSaves
function Send-FeedbackMouse($control,[string]$event,[int]$x=10,[int]$y=10,[Windows.Forms.MouseButtons]$button='None') {
    $method=$control.GetType().GetMethod($event,[Reflection.BindingFlags]'Instance,NonPublic')
    $null=$method.Invoke($control,@([Windows.Forms.MouseEventArgs]::new($button,1,$x,$y,0)))
}
function Send-FeedbackEvent($control,[string]$event) {
    $method=$control.GetType().GetMethod($event,[Reflection.BindingFlags]'Instance,NonPublic')
    $null=$method.Invoke($control,@([EventArgs]::Empty))
}
$tile=$script:ControlButtons['Pad_32']
Send-FeedbackMouse $tile OnMouseMove
Assert-Ui (-not $tile.HoverFeedbackBounds.IsEmpty -and $tile.PressedFeedbackBounds.IsEmpty) 'Hover feedback missing.'
Send-FeedbackMouse $tile OnMouseDown 10 10 Left
Assert-Ui (-not $tile.PressedFeedbackBounds.IsEmpty) 'Mouse press feedback missing.'
Save-TestFrame 'feedback-pressed-wide.png'
Send-FeedbackEvent $tile OnMouseCaptureChanged
Assert-Ui $tile.PressedFeedbackBounds.IsEmpty 'Capture loss left a pressed tile.'
Send-FeedbackMouse $tile OnMouseDown 10 10 Left
Send-FeedbackEvent $tile OnMouseLeave
Assert-Ui ($tile.PressedFeedbackBounds.IsEmpty -and $tile.HoverFeedbackBounds.IsEmpty) 'Pointer exit left stale feedback.'
Send-FeedbackMouse $tile OnMouseMove
$tile.Enabled=$false
Assert-Ui $tile.HoverFeedbackBounds.IsEmpty 'Disabled tile retained hover.'
$tile.Enabled=$true
Focus-ApcControl 'Pad_32'; $null=Send-FixtureKey $tile Space
Assert-Ui (-not $tile.PressedFeedbackBounds.IsEmpty) 'Space lacks pressed feedback.'
$up=$tile.GetType().GetMethod('WndProc',[Reflection.BindingFlags]'Instance,NonPublic')
$release=[Windows.Forms.Message]::Create($tile.Handle,0x0101,[IntPtr]::new([int][Windows.Forms.Keys]::Space),[IntPtr]::Zero)
$null=$up.Invoke($tile,@($release))
Assert-Ui $tile.PressedFeedbackBounds.IsEmpty 'Key release left pressed feedback.'
$null=Send-FixtureKey $tile Enter; $null=$txtLabel.Focus()
Assert-Ui $tile.PressedFeedbackBounds.IsEmpty 'Focus loss left pressed feedback.'

foreach ($note in @(48,49,72)) {
    $r=$keybedCanvas.KeyBounds[$note-48]
    $x=$r.Left+[int]($r.Width/2); $y=if ($keybedCanvas.BlackKeys[$note-48]) { $r.Top+8 } else { $r.Bottom-12 }
    Send-FeedbackMouse $keybedCanvas OnMouseMove $x $y
    Assert-Ui ($keybedCanvas.HoverFeedbackBounds -eq $keybedCanvas.KeyFocusBounds[$note-48]) 'Piano hover hit the wrong key.'
    Send-FeedbackMouse $keybedCanvas OnMouseDown $x $y Left
    Assert-Ui ($keybedCanvas.PressedFeedbackBounds -eq $keybedCanvas.KeyFocusBounds[$note-48]) 'Piano press hit the wrong key.'
    Send-FeedbackMouse $keybedCanvas OnMouseUp $x $y Left
    Assert-Ui $keybedCanvas.PressedFeedbackBounds.IsEmpty 'Piano release left pressed feedback.'
}
Assert-Ui ($script:TestAudio.Count -eq $feedbackAudio -and $script:TestActions.Count -eq $feedbackActions -and $script:TestSaves -eq $feedbackSaves) 'Hover/press performed an action or write.'
foreach ($id in $feedbackLeds.Keys) { Assert-Ui ($script:PadVelocities[$id] -eq $feedbackLeds[$id]) 'Hover/press changed physical LED values.' }

$realPreference=$lblDraftState.AnimationPreference
$script:FixtureAnimations=$true
$lblDraftState.AnimationPreference=[Func[bool]]{ return $script:FixtureAnimations }
try {
    Select-ApcControl 'Pad_32'; $txtLabel.Text='Applied feedback fixture'
    $script:FailSave=$true; $btnSave.PerformClick(); $script:FailSave=$false
    Assert-Ui (-not $lblDraftState.FeedbackActive -and $lblDraftState.Text -like 'Save failed*' -and $script:Drafts.ContainsKey('Pad_32')) 'Failed save showed success or lost its draft.'
    $btnSave.PerformClick()
    Assert-Ui ($lblDraftState.Text -eq 'Applied · saved' -and $lblDraftState.FeedbackActive -and $lblDraftState.FeedbackTimerRunning) 'Successful Apply lacked immediate acknowledgement.'
    Save-TestFrame 'feedback-applied-wide.png'
    $until=[Environment]::TickCount64+1700
    while ([Environment]::TickCount64 -lt $until) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 20 }
    Assert-Ui (-not $lblDraftState.FeedbackTimerRunning -and -not $lblDraftState.FeedbackActive -and $lblDraftState.Text -eq 'Applied · saved') 'Confirmation timer did not stop or erased success text.'
    $txtLabel.Text='Interrupt acknowledgement'; $btnSave.PerformClick()
    $txtLabel.Text='New unsaved draft'
    Assert-Ui (-not $lblDraftState.FeedbackActive -and -not $lblDraftState.FeedbackTimerRunning -and $lblDraftState.Text -like 'Unsaved draft*') 'New edit retained stale success.'
    $script:FixtureAnimations=$false; $btnSave.PerformClick()
    Assert-Ui ($lblDraftState.FeedbackActive -and -not $lblDraftState.FeedbackTimerRunning) 'Reduced motion lost acknowledgement or started a timer.'
    $form.Size=[Drawing.Size]::new(640,560); Update-WindowLayout; Show-WorkspacePane $true
    Save-TestFrame 'feedback-reduced-compact.png'
    Select-ApcControl 'Pad_33'
    Assert-Ui (-not $lblDraftState.FeedbackActive) 'Selection retained another mapping acknowledgement.'
    Show-WorkspacePane $true; $script:FixtureAnimations=$true
    $lblDraftState.ShowFeedback(); $script:FixtureAnimations=$false
    $until=[Environment]::TickCount64+100
    while ([Environment]::TickCount64 -lt $until) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 10 }
    Assert-Ui (-not $lblDraftState.FeedbackTimerRunning -and $lblDraftState.FeedbackActive) 'Live reduced-motion change did not stop fading.'
    $script:FixtureAnimations=$true; Set-ApcContrastTheme $true
    $lblDraftState.ShowFeedback()
    Assert-Ui (-not $lblDraftState.FeedbackTimerRunning) 'High contrast started a fade.'
    Save-TestFrame 'feedback-high-contrast.png'
    Set-ApcContrastTheme $false; $lblDraftState.ShowFeedback(); Show-WorkspacePane $false
    $until=[Environment]::TickCount64+100
    while ([Environment]::TickCount64 -lt $until) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 10 }
    Assert-Ui (-not $lblDraftState.FeedbackTimerRunning) "Hidden inspector retained a timer: compact=$script:CompactWindow pane=$($compactTabs.SelectedIndex) visible=$($lblDraftState.Visible)."
} finally {
    $script:FailSave=$false; $lblDraftState.ClearFeedback(); $lblDraftState.AnimationPreference=$realPreference
    Set-ApcContrastTheme $false; $form.Size=[Drawing.Size]::new(1680,970); Update-WindowLayout
    Send-FeedbackEvent $keybedCanvas OnMouseLeave
}
$afterFeedbackGeometry=(@($script:ControlButtons.Keys | Sort-Object | ForEach-Object { "$_=$($script:ControlButtons[$_].Bounds)" }) + @($keybedCanvas.KeyBounds | ForEach-Object ToString)) -join '|'
Assert-Ui ($feedbackGeometry -ceq $afterFeedbackGeometry) 'Interaction feedback changed hardware geometry.'
foreach ($id in $feedbackLeds.Keys) { Assert-Ui ($script:PadVelocities[$id] -eq $feedbackLeds[$id]) 'Label-only Apply changed LED values.' }
Assert-Ui ($script:TestAudio.Count -eq $feedbackAudio -and $script:TestActions.Count -eq $feedbackActions) 'Feedback produced an audio/action write.'
[Console]::WriteLine('INTERACTION_FEEDBACK_TESTS_OK: hover/press/capture/focus/disabled cleanup, natural/sharp piano hit testing, failed/successful/repeated Apply, edit/selection interruption, bounded idle timer, live reduced-motion preference, hidden/high-contrast static fallback, unchanged geometry and LED/audio/action state.')
