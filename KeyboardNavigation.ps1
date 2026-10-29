# Roving tab stops keep 90 mappings reachable without 90 Tab presses.
$script:NavigationGroups = [ordered]@{
    Pads = @(foreach ($row in 4..0) { foreach ($column in 0..7) { "Pad_$($row * 8 + $column)" } })
    Scenes = @('Scene_82','Scene_83','Scene_84','Scene_85','Scene_86','Scene_81')
    Tracks = @(64..71 | ForEach-Object { "Track_$_" })
    Knobs = @(48..55 | ForEach-Object { "Knob_$_" })
    Transport = @('Trans_91','Trans_93','Trans_98')
    Piano = @(48..72 | ForEach-Object { "Key_$_" })
}
$script:NavigationEntry = @{}
$script:NavigationGroupForId = @{}
foreach ($group in $script:NavigationGroups.Keys) {
    $ids = $script:NavigationGroups[$group]
    $script:NavigationEntry[$group] = $ids[0]
    foreach ($cid in $ids) { $script:NavigationGroupForId[$cid] = $group }
}

function Set-NavigationEntry([string]$cid) {
    $group = $script:NavigationGroupForId[$cid]
    if ($group -eq 'Piano') { return }
    $previous = $script:NavigationEntry[$group]
    if ($previous -ne $cid) { $script:ControlButtons[$previous].TabStop = $false }
    $script:NavigationEntry[$group] = $cid
    $script:ControlButtons[$cid].TabStop = $true
}

function Focus-ApcControl([string]$cid) {
    if ($cid.StartsWith('Key_')) {
        $keybedCanvas.FocusNote = [int]$cid.Substring(4)
        $null = $keybedCanvas.Focus()
    } else {
        Set-NavigationEntry $cid
        $null = $script:ControlButtons[$cid].Focus()
    }
    if ($script:SelectedId -ne $cid) { Select-ApcControl $cid }
}

function Move-DeckKeyboardFocus([string]$cid, [Windows.Forms.KeyEventArgs]$e) {
    if ($e.Control -or $e.Alt) { return }
    $key = $e.KeyCode.ToString()
    if ($key -notin @('Tab','Left','Right','Up','Down','Home','End','Enter','Space')) { return }
    $e.Handled = $true
    $e.SuppressKeyPress = $true
    $group = $script:NavigationGroupForId[$cid]
    $ids = $script:NavigationGroups[$group]
    $index = [array]::IndexOf($ids, $cid)
    if ($key -eq 'Tab') {
        $groups = @($script:NavigationGroups.Keys)
        $nextGroup = [array]::IndexOf($groups, $group) + $(if ($e.Shift) { -1 } else { 1 })
        if ($nextGroup -lt 0) { $null = $btnMore.Focus(); return }
        if ($nextGroup -ge $groups.Count) { $null = $chkMidiLearn.Focus(); return }
        $targetGroup = $groups[$nextGroup]
        $target = if ($targetGroup -eq 'Piano') { "Key_$($keybedCanvas.FocusNote)" } else { $script:NavigationEntry[$targetGroup] }
        Focus-ApcControl $target
        return
    }
    $columns = switch ($group) { 'Pads' { 8 } 'Knobs' { 4 } 'Scenes' { 1 } default { $ids.Count } }
    $next = $index
    switch ($key) {
        'Home' { $next = 0 }
        'End' { $next = $ids.Count - 1 }
        'Left' { if ($index % $columns -gt 0) { $next-- } }
        'Right' { if ($index % $columns -lt $columns - 1 -and $index + 1 -lt $ids.Count) { $next++ } }
        'Up' { if ($index -ge $columns) { $next -= $columns } }
        'Down' { if ($index + $columns -lt $ids.Count) { $next += $columns } }
    }
    Focus-ApcControl $ids[$next]
}

foreach ($group in $script:NavigationGroups.Keys) {
    if ($group -eq 'Piano') { continue }
    $ids = $script:NavigationGroups[$group]
    for ($index = 0; $index -lt $ids.Count; $index++) {
        $control = $script:ControlButtons[$ids[$index]]
        $control.TabStop = ($index -eq 0)
        $control.TabIndex = [array]::IndexOf(@($script:NavigationGroups.Keys), $group) * 100 + $index
        $control.AccessibleRole = 'PushButton'
        $control.AccessibleDefaultActionDescription = 'Select mapping'
        $control.Add_GotFocus({
            $cid = [string]$this.Tag
            Set-NavigationEntry $cid
            if ($script:SelectedId -ne $cid) { Select-ApcControl $cid }
        })
        $control.Add_KeyDown({ param($sender, $e) Move-DeckKeyboardFocus ([string]$sender.Tag) $e })
    }
}
$keybedCanvas.TabStop = $true
$keybedCanvas.AccessibleName = 'Piano mappings, C3 to C5'
$keybedCanvas.AccessibleDescription = '25 keys. Left and Right select by semitone; Home and End select C3 and C5. Tab moves to the inspector.'
$keybedCanvas.Add_GotFocus({
    $cid = "Key_$($keybedCanvas.FocusNote)"
    if ($script:SelectedId -ne $cid) { Select-ApcControl $cid }
})
$keybedCanvas.Add_KeySelectionRequested({ Select-ApcControl "Key_$($keybedCanvas.FocusNote)" })
$keybedCanvas.Add_KeyDown({ param($sender, $e) Move-DeckKeyboardFocus "Key_$($keybedCanvas.FocusNote)" $e })
# Explicit boundaries between the roving deck groups and the native inspector tab order.
$chkMidiLearn.Add_PreviewKeyDown({ param($sender,$e) if ($e.KeyCode -eq 'Tab' -and $e.Shift) { $e.IsInputKey = $true } })
$chkMidiLearn.Add_KeyDown({ param($sender,$e) if ($e.KeyCode -eq 'Tab' -and $e.Shift) { $e.SuppressKeyPress=$true; Focus-ApcControl "Key_$($keybedCanvas.FocusNote)" } })
$btnMore.Add_PreviewKeyDown({ param($sender,$e) if ($e.KeyCode -eq 'Tab' -and -not $e.Shift) { $e.IsInputKey = $true } })
$btnMore.Add_KeyDown({ param($sender,$e) if ($e.KeyCode -eq 'Tab' -and -not $e.Shift) { $e.SuppressKeyPress=$true; Focus-ApcControl $script:NavigationEntry['Pads'] } })
$inspHeader.TabIndex = 0
$inspFlow.TabIndex = 1
$inspectorFooter.TabIndex = 2
$btnSave.TabIndex = 0
$btnRevert.TabIndex = 1
$btnTest.TabIndex = 2
$btnMore.TabIndex = 3
$statusBox.TabStop = $false
$form.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq 'F6' -and -not $e.Control -and -not $e.Alt) {
        $e.SuppressKeyPress = $true
        if ($chassisLayout.ContainsFocus) { $null = $txtLabel.Focus() }
        else { Focus-ApcControl $script:SelectedId }
    }
})
