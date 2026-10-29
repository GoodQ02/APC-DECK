# Dot-sourced only by the offline UI smoke process, after the actual form has loaded.
if (-not $OfflinePreview -or -not $SmokeTestUi) { throw 'Inspector cases require offline smoke mode.' }
$script:TestSaves = 0
$script:TestAudio = [Collections.Generic.List[object]]::new()
$script:TestActions = [Collections.Generic.List[object]]::new()
$script:FailSave = $false
function Save-ApcProfile {
    param($ProfileMap)
    if ($script:FailSave) { throw 'Simulated disk failure' }
    $script:TestSaves++
    $script:LastSavedJson = $ProfileMap | ConvertTo-Json -Depth 5
}
function Set-AudioVolumeByMapping {
    param($Mapping, $MidiValue, [switch]$AutoMuteAtZero)
    $script:TestAudio.Add([pscustomobject]@{Mapping=$Mapping.PSObject.Copy(); MidiValue=$MidiValue})
    return 'Recorded volume'
}
function Invoke-ApcAction {
    param($Mapping)
    $script:TestActions.Add($Mapping.PSObject.Copy())
    return 'Recorded action'
}
function Assert-Ui([bool]$condition, [string]$message) { if (-not $condition) { throw $message } }
function Save-TestFrame([string]$name) {
    if (-not $env:APC_DECK_PREVIEW_DIRECTORY) { return }
    $null = New-Item -ItemType Directory -Path $env:APC_DECK_PREVIEW_DIRECTORY -Force
    $form.Refresh()
    $bitmap = [Drawing.Bitmap]::new($form.Width, $form.Height)
    try {
        $form.DrawToBitmap($bitmap, [Drawing.Rectangle]::new(0, 0, $form.Width, $form.Height))
        $bitmap.Save((Join-Path $env:APC_DECK_PREVIEW_DIRECTORY $name), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $bitmap.Dispose() }
}

# Edits belong to a control, independent of selection (including MIDI Learn's selection function).
Select-ApcControl 'Pad_32'
$originalLabel = $txtLabel.Text
$txtLabel.Text = 'Draft A — α'
Assert-Ui ($script:Drafts.ContainsKey('Pad_32')) 'Label edit did not create a draft.'
Assert-Ui ($script:ProfileMap['Pad_32'].Label -eq $originalLabel) 'Editing mutated the committed mapping.'
Select-ApcControl 'Knob_49'
Assert-Ui ($cmbAction.GetItemText($cmbAction.SelectedItem) -eq 'Device volume') 'Friendly action label changed the underlying action contract.'
$knobOriginalTarget = $cmbTarget1.Text
$cmbTarget1.Text = 'VOICE_CUBE'
Select-ApcControl 'Pad_32'
Assert-Ui ($txtLabel.Text -eq 'Draft A — α') 'Selection discarded draft A.'
Assert-Ui ($script:Drafts.Count -eq 2) 'Independent drafts were not retained.'
$btnRevert.PerformClick()
Assert-Ui ($txtLabel.Text -eq $originalLabel -and $script:Drafts.Count -eq 1) 'Revert did not restore only the current mapping.'

# Test uses the displayed draft without saving it or changing a saved knob's displayed target value.
Select-ApcControl 'Knob_49'
$savedKnobPct = $script:KnobValues['Knob_49']
$chkEditOnly.Checked = $true
$btnTest.PerformClick()
Assert-Ui ($script:TestAudio.Count -eq 1 -and $script:TestAudio[0].Mapping.Target -eq 'VOICE_CUBE' -and $script:TestAudio[0].MidiValue -eq 64) 'Test did not execute the displayed draft at the stated 50%.'
Assert-Ui ($script:TestSaves -eq 0 -and $script:ProfileMap['Knob_49'].Target -eq $knobOriginalTarget) 'Test saved or changed the committed mapping.'
Assert-Ui ($script:KnobValues['Knob_49'] -eq $savedKnobPct) 'Draft test overwrote the saved target volume display.'

# Wheel changes are incidental and must respect Edit mode. Invoke the actual registered control event.
$mouseWheel = [Windows.Forms.Control].GetMethod('OnMouseWheel', [Reflection.BindingFlags]'Instance,NonPublic')
$wheelArgs = [Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::None, 0, 0, 0, 120)
$mouseWheel.Invoke($script:ControlButtons['Knob_49'], @($wheelArgs))
Assert-Ui ($script:TestAudio.Count -eq 1) 'Wheel bypassed Edit mode.'
$chkEditOnly.Checked = $false
$mouseWheel.Invoke($script:ControlButtons['Knob_49'], @($wheelArgs))
Assert-Ui ($script:TestAudio.Count -eq 2) 'Live wheel no longer changes volume.'

# Invalid drafts stay available but cannot be applied/tested; disk failure preserves both states.
$cmbAction.SelectedItem = 'Hotkey'
$cmbTarget1.Text = 'Ctrl+Shift+M'
Assert-Ui (-not $btnSave.Enabled -and -not $btnTest.Enabled) 'Knob accepted an unsupported action.'
$cmbAction.SelectedItem = 'VolumeDevice'
$cmbTarget1.Text = ''
Assert-Ui (-not $btnSave.Enabled -and -not $btnTest.Enabled) 'Missing target was accepted.'
$cmbTarget1.Text = 'VOICE_CUBE'
$script:FailSave = $true
$btnSave.PerformClick()
Assert-Ui ($script:Drafts.ContainsKey('Knob_49') -and $script:ProfileMap['Knob_49'].Target -eq $knobOriginalTarget) 'Failed save lost draft or committed it.'
$script:FailSave = $false
$btnSave.PerformClick()
Assert-Ui ($script:TestSaves -eq 1 -and -not $script:Drafts.ContainsKey('Knob_49') -and $script:ProfileMap['Knob_49'].Target -eq 'VOICE_CUBE') 'Apply failed to commit exactly the selected draft.'
Assert-Ui (-not $btnSave.Enabled -and -not $btnRevert.Enabled) 'Saved state still offers Apply/Revert.'

# Colors and Clear obey the same Apply/Revert contract; non-knob Test also uses draft values.
Select-ApcControl 'Pad_0'
$savedColor = $cmbLed.SelectedItem
$swatchPanel.Controls[0].PerformClick()
Assert-Ui ($script:TestSaves -eq 1 -and $script:ProfileMap['Pad_0'].LedColor -eq $savedColor) 'Swatch saved immediately.'
$cmbTarget1.Text = 'Ctrl+Shift+M'
$btnTest.PerformClick()
Assert-Ui ($script:TestActions.Count -eq 1 -and $script:TestActions[0].Target -eq 'Ctrl+Shift+M') 'Pad test did not use draft target.'
$btnClear.PerformClick()
Assert-Ui ($cmbAction.SelectedItem -eq 'None' -and $script:ProfileMap['Pad_0'].ActionType -eq 'Hotkey') 'Clear changed saved mapping.'
$btnRevert.PerformClick()
Assert-Ui ($cmbAction.SelectedItem -eq 'Hotkey' -and $cmbLed.SelectedItem -eq $savedColor) 'Revert failed after swatch/Clear.'

Select-ApcControl 'Pad_39'
Assert-Ui ($cmbTarget2.Visible) 'Swap lacks a secondary target.'
$cmbTarget2.Text = ''
Assert-Ui (-not $btnSave.Enabled -and -not $btnTest.Enabled) 'Swap accepted a missing second target.'
$btnRevert.PerformClick()

# Real rendered layout at three shipping window sizes; the footer never enters the scroll pane.
foreach ($size in @(@(1680,970), @(1366,768), @(1200,740))) {
    $form.Size = [Drawing.Size]::new($size[0], $size[1])
    $form.PerformLayout()
    Resize-InspectorContent
    foreach ($cid in @('Pad_39','Key_48','Knob_49')) {
        Select-ApcControl $cid
        $form.PerformLayout()
        $form.Refresh()
        Assert-Ui (-not $inspFlow.HorizontalScroll.Visible) "Horizontal inspector overflow: $cid at $size."
        foreach ($button in @($btnSave,$btnRevert,$btnTest)) {
            $point = $form.PointToClient($button.PointToScreen([Drawing.Point]::Empty))
            $rect = [Drawing.Rectangle]::new($point, $button.Size)
            Assert-Ui ($button.Visible -and $form.ClientRectangle.Contains($rect)) "Footer action offscreen: $($button.Text) at $size."
        }
        if ($cid.StartsWith('Knob_')) { Assert-Ui (-not $cmbLed.Visible -and -not $cmbTarget2.Visible) 'Knob displays irrelevant color/secondary fields.' }
    }
    Save-TestFrame "inspector-$($size[0])x$($size[1]).png"
}
foreach ($cid in @('Trans_91','Trans_93','Trans_98')) { Assert-Ui (-not [string]::IsNullOrWhiteSpace($script:ControlButtons[$cid].Text)) 'Transport label is blank.' }
Assert-Ui ($script:ProfileMap.Count -eq 90 -and $script:ControlButtons.Count -eq 65 -and $whiteNotes.Count + $blackKeySpecs.Count -eq 25) 'Hardware control inventory changed.'

$txtLabel.Text = 'A long device label with more detail'
Select-ApcControl 'Pad_32'
$txtLabel.Text = 'Draft kept on another control'
$btnSave.PerformClick()
Assert-Ui ($script:Drafts.ContainsKey('Knob_49') -and -not $script:Drafts.ContainsKey('Pad_32')) 'Apply discarded another control draft.'
Select-ApcControl 'Knob_49'
Assert-Ui ($txtLabel.Text -eq 'A long device label with more detail') 'Long draft did not survive selection.'
Save-TestFrame 'inspector-long-draft.png'
[Console]::WriteLine('INSPECTOR_TESTS_OK: retained drafts, Apply/Revert/Test, save failure, swatches/Clear, validation, edit-only wheel, transport labels, 90 controls, and three window sizes.')

. (Join-Path $PSScriptRoot 'LiveStateCases.ps1')
