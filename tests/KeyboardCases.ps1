# Exercise the registered native handlers and accessibility objects, with recording sinks only.
$audioBeforeKeyboard = $script:TestAudio.Count
$actionsBeforeKeyboard = $script:TestActions.Count
$savesBeforeKeyboard = $script:TestSaves
$keyDownMethod = [Windows.Forms.Control].GetMethod('OnKeyDown', [Reflection.BindingFlags]'Instance,NonPublic')
$previewMethod = [Windows.Forms.Control].GetMethod('OnPreviewKeyDown', [Reflection.BindingFlags]'Instance,NonPublic')
function Send-FixtureKey($control, [Windows.Forms.Keys]$key) {
    $fixtureKeyArgs = [Windows.Forms.KeyEventArgs]::new($key)
    $null = $keyDownMethod.Invoke($control, @($fixtureKeyArgs))
    return $fixtureKeyArgs
}
function Assert-KeyboardSelection([string]$cid) {
    Assert-Ui ($script:SelectedId -eq $cid) "Keyboard selected $($script:SelectedId), expected $cid."
    $focused = if ($cid.StartsWith('Key_')) { $keybedCanvas.Focused -and $keybedCanvas.FocusNote -eq [int]$cid.Substring(4) } else { $script:ControlButtons[$cid].Focused }
    Assert-Ui $focused "Selection $cid does not own keyboard focus."
}

Focus-ApcControl 'Pad_32'
$script:Drafts.Remove('Pad_32')
$txtLabel.Text = 'Keyboard retained draft'
$null = Send-FixtureKey $script:ControlButtons['Pad_32'] Right
Assert-KeyboardSelection 'Pad_33'
$null = Send-FixtureKey $script:ControlButtons['Pad_33'] Down
Assert-KeyboardSelection 'Pad_25'
$null = Send-FixtureKey $script:ControlButtons['Pad_25'] Home
Assert-KeyboardSelection 'Pad_32'
Assert-Ui ($txtLabel.Text -eq 'Keyboard retained draft') 'Arrow selection discarded the draft.'
$null = Send-FixtureKey $script:ControlButtons['Pad_32'] Left
Assert-KeyboardSelection 'Pad_32'
$null = Send-FixtureKey $script:ControlButtons['Pad_32'] End
Assert-KeyboardSelection 'Pad_7'

Focus-ApcControl 'Knob_48'
$null = Send-FixtureKey $script:ControlButtons['Knob_48'] Down
Assert-KeyboardSelection 'Knob_52'
$null = Send-FixtureKey $script:ControlButtons['Knob_52'] Right
Assert-KeyboardSelection 'Knob_53'
$null = Send-FixtureKey $script:ControlButtons['Knob_53'] Up
Assert-KeyboardSelection 'Knob_49'

# Every group has one tab stop. Tab preserves the last focused member of each group.
Focus-ApcControl 'Pad_32'
foreach ($expected in @('Scene_82','Track_64','Knob_49','Trans_91','Key_48')) {
    $current = if ($script:SelectedId.StartsWith('Key_')) { $keybedCanvas } else { $script:ControlButtons[$script:SelectedId] }
    $inputMethod = $current.GetType().GetMethod('IsInputKey', [Reflection.BindingFlags]'Instance,NonPublic')
    Assert-Ui ($inputMethod.Invoke($current, @([Windows.Forms.Keys]::Tab))) 'Native preprocessing does not accept Tab.'
    $keyResult = Send-FixtureKey $current Tab
    Assert-Ui $keyResult.SuppressKeyPress 'Tab escaped the group handler.'
    Assert-KeyboardSelection $expected
}
$null = Send-FixtureKey $keybedCanvas Tab
Assert-Ui $chkMidiLearn.Focused 'Tab failed to enter the native inspector.'
$preview = [Windows.Forms.PreviewKeyDownEventArgs]::new([Windows.Forms.Keys]'Shift, Tab')
$previewMethod.Invoke($chkMidiLearn, @($preview))
Assert-Ui $preview.IsInputKey 'Inspector Shift+Tab was not routed to the deck.'
$null = Send-FixtureKey $chkMidiLearn ([Windows.Forms.Keys]'Shift, Tab')
Assert-KeyboardSelection 'Key_48'
$null = Send-FixtureKey $keybedCanvas ([Windows.Forms.Keys]'Shift, Tab')
Assert-KeyboardSelection 'Trans_91'
foreach ($group in @('Pads','Scenes','Tracks','Knobs','Transport')) {
    $tabStops = @($script:NavigationGroups[$group] | Where-Object { $script:ControlButtons[$_].TabStop })
    Assert-Ui ($tabStops.Count -eq 1) "Group $group has $($tabStops.Count) tab stops."
}

# Every chromatic piano key is reachable, bounded, named, and selectable through accessibility.
Focus-ApcControl 'Key_48'
foreach ($note in 49..72) {
    $null = Send-FixtureKey $keybedCanvas Right
    Assert-KeyboardSelection "Key_$note"
}
$null = Send-FixtureKey $keybedCanvas Right
Assert-KeyboardSelection 'Key_72'
$null = Send-FixtureKey $keybedCanvas Home
Assert-KeyboardSelection 'Key_48'
$pianoAccess = $keybedCanvas.AccessibilityObject
Assert-Ui ($pianoAccess.GetChildCount() -eq 25) 'Piano accessibility children missing.'
foreach ($note in 48..72) {
    $child = $pianoAccess.GetChild($note - 48)
    Assert-Ui ($child.Name -match "Key_$note" -and $child.Role -eq 'PushButton' -and $child.Bounds.Width -gt 0 -and $child.Bounds.Height -gt 0) "Incomplete piano accessibility for $note."
    $child.DoDefaultAction()
    Assert-KeyboardSelection "Key_$note"
    Assert-Ui (($child.State -band [Windows.Forms.AccessibleStates]::Selected) -ne 0) 'Piano accessible selection state missing.'
    Assert-Ui ($pianoAccess.GetFocused() -eq $child -and $pianoAccess.GetSelected() -eq $child) 'Piano accessibility focus/selection incorrect.'
}
foreach ($cid in $script:ControlButtons.Keys) {
    $access = $script:ControlButtons[$cid].AccessibilityObject
    Assert-Ui ($access.Name -match $cid -and $access.Role -eq 'PushButton' -and $access.DefaultAction -eq 'Select mapping') "Incomplete accessible tile: $cid."
    $access.DoDefaultAction()
    Assert-KeyboardSelection $cid
    Assert-Ui (($access.State -band [Windows.Forms.AccessibleStates]::Selected) -ne 0) "Accessible selection missing: $cid."
    $null = Send-FixtureKey $script:ControlButtons[$cid] Enter
    $null = Send-FixtureKey $script:ControlButtons[$cid] Space
}
Focus-ApcControl 'Key_49'
$blackRect = $keybedCanvas.RectangleToScreen($script:BlackKeyRects['Key_49'])
Assert-Ui ($pianoAccess.HitTest($blackRect.X + 3, $blackRect.Y + 3) -eq $pianoAccess.GetChild(1)) 'Piano hit testing preferred covered white key.'

# F6 enters the editor; MIDI selection does not steal focus or move the remembered piano note.
$null = Send-FixtureKey $form F6
Assert-Ui $txtLabel.Focused 'F6 failed to focus the label editor.'
$txtLabel.Text = 'Piano keyboard draft'
Select-ApcControl 'Knob_48'
Assert-Ui ($txtLabel.Focused -and $keybedCanvas.FocusNote -eq 49) 'MIDI-style selection stole focus or moved the focused piano note.'
Select-ApcControl 'Key_49'
Assert-Ui ($txtLabel.Text -eq 'Piano keyboard draft') 'Piano draft was lost during MIDI selection.'
$null = Send-FixtureKey $form F6
Assert-KeyboardSelection 'Key_49'
$null = Send-FixtureKey $keybedCanvas Enter
$null = Send-FixtureKey $keybedCanvas Space
Assert-Ui ($script:TestAudio.Count -eq $audioBeforeKeyboard -and $script:TestActions.Count -eq $actionsBeforeKeyboard -and $script:TestSaves -eq $savesBeforeKeyboard) 'Navigation/accessibility activation executed or saved a mapping.'

# Focus rings on a pad, black key, and white key at supported shipping sizes.
foreach ($size in @(@(1680,970), @(1366,768), @(1200,740))) {
    $form.Size = [Drawing.Size]::new($size[0], $size[1])
    $form.PerformLayout()
    foreach ($cid in @('Pad_32','Key_49','Key_50')) {
        Focus-ApcControl $cid
        $form.Refresh()
        Save-TestFrame "keyboard-$cid-$($size[0])x$($size[1]).png"
    }
}
[Console]::WriteLine('KEYBOARD_TESTS_OK: spatial arrows, six roving groups, native Tab preprocessing, inspector boundaries, F6, all 90 accessible selections, 25 chromatic notes, focus/selection state, black-key hit testing, retained drafts, no navigation side effects, and three rendered sizes.')
