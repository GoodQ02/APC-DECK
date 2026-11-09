$script:Drafts.Clear()
Select-ApcControl 'Pad_39'; $txtLabel.Text='Draft across monitors and window modes'
$draft=$script:Drafts['Pad_39'] | ConvertTo-Json -Compress
$audio=$script:TestAudio.Count; $actions=$script:TestActions.Count; $saves=$script:TestSaves
$leds=$script:PadVelocities.Clone()
$normalSize=[Drawing.Size]::new(1680,970)
$form.Size=$normalSize; Update-WindowLayout; $form.PerformLayout()
$wideGeometry=(@($script:ControlButtons.Keys | Sort-Object | ForEach-Object { "$_=$($script:ControlButtons[$_].Bounds)" }) + @($script:WhiteKeyRects.Keys | Sort-Object | ForEach-Object { "$_=$($script:WhiteKeyRects[$_])" })) -join '|'
foreach ($scale in @(1.0,1.5,2.25)) {
    Set-ReadableTextScale $scale
    foreach ($size in @(@(1024,700),@(800,600),@(640,560))) {
        $form.Size=[Drawing.Size]::new($size[0],$size[1]); Update-WindowLayout; $form.PerformLayout()
        Assert-Ui ($script:CompactWindow -and $compactTabs.Visible) 'Narrow window did not expose workspace tabs.'
        Show-WorkspacePane $true; Resize-ReadableInspector; $form.PerformLayout()
        [Windows.Forms.Application]::DoEvents()
        Assert-Ui ($inspFlow.Height -ge 70) "No usable editor space at $scale / $size ($($inspFlow.Height))."
        foreach ($button in @($btnSave,$btnRevert,$btnTest,$btnMore)) {
            $rect=[Drawing.Rectangle]::new($form.PointToClient($button.PointToScreen([Drawing.Point]::Empty)),$button.Size)
            Assert-Ui ($button.Visible -and $form.ClientRectangle.Contains($rect)) "Action outside compact inspector: $($button.Text); scale=$scale size=$size visible=$($button.Visible) rect=$rect client=$($form.ClientRectangle) pane=$($compactTabs.SelectedIndex)."
            Assert-Ui ($button.Height -ge (Get-InspectorTextHeight $button ($button.Width-10))) 'Compact action text clipped.'
        }
        Assert-Ui (-not $inspFlow.HorizontalScroll.Visible) 'Compact inspector has horizontal overflow.'
        $null=$txtLabel.Focus(); $null=Send-FixtureKey $form F6
        Assert-Ui ($compactTabs.SelectedIndex -eq 0 -and $chassisLayout.ContainsFocus) 'F6 did not return to the controller.'
        foreach ($cid in @('Pad_32','Pad_7','Scene_81','Knob_55','Trans_98','Key_72','Key_49','Key_48')) {
            Focus-ApcControl $cid; Show-DeckSelection $cid
            $control=if ($cid.StartsWith('Key_')) { $keybedCanvas } else { $script:ControlButtons[$cid] }
            $r=if ($cid.StartsWith('Key_')) { if ($script:WhiteKeyRects.ContainsKey($cid)) { $script:WhiteKeyRects[$cid] } else { $script:BlackKeyRects[$cid] } } else { $control.ClientRectangle }
            $point=$deckViewport.PointToClient($control.PointToScreen([Drawing.Point]::new([int]$r.X,[int]$r.Y)))
            Assert-Ui ($point.X -ge -1 -and $point.Y -ge -1 -and $point.X+$r.Width -le $deckViewport.ClientSize.Width+1 -and $point.Y+$r.Height -le $deckViewport.ClientSize.Height+1) "Focused $cid is outside the controller viewport at $size."
        }
        $null=Send-FixtureKey $form F6
        Assert-Ui ($compactTabs.SelectedIndex -eq 1 -and $txtLabel.Focused) 'F6 did not open the inspector.'
        Focus-ApcControl 'Pad_32'
        $null=Send-FixtureKey $script:ControlButtons['Pad_32'] 'Shift, Tab'
        Assert-Ui ($compactTabs.SelectedIndex -eq 1 -and $btnMore.Focused) 'Shift+Tab did not reveal inspector actions.'
        # Hardware-driven selection must preserve the current editing pane.
        Select-ApcControl 'Pad_39'
        Assert-Ui ($compactTabs.SelectedIndex -eq 1 -and $txtLabel.Text -eq 'Draft across monitors and window modes') 'Selection changed pane or lost draft.'
        Save-TestFrame "window-inspector-$([int]($scale*100))-$($size[0])x$($size[1]).png"
        Show-WorkspacePane $false; Focus-ApcControl 'Key_72'
        Save-TestFrame "window-controller-$([int]($scale*100))-$($size[0])x$($size[1]).png"
    }
}
Set-ReadableTextScale 1.0
$form.Size=$normalSize; Update-WindowLayout; $form.PerformLayout()
$restoredGeometry=(@($script:ControlButtons.Keys | Sort-Object | ForEach-Object { "$_=$($script:ControlButtons[$_].Bounds)" }) + @($script:WhiteKeyRects.Keys | Sort-Object | ForEach-Object { "$_=$($script:WhiteKeyRects[$_])" })) -join '|'
Assert-Ui (-not $script:CompactWindow -and $deckViewport.Parent -eq $mainSplit -and $inspectorGroup.Parent -eq $mainSplit) 'Wide workspace did not restore both panes.'
Assert-Ui ($restoredGeometry -ceq $wideGeometry) "Wide hardware geometry changed after compact roundtrips: $(Compare-Object ($wideGeometry -split '\|') ($restoredGeometry -split '\|') | Select-Object -First 6 | Out-String)"
foreach ($area in @([Drawing.Rectangle]::new(2752,-388,864,1488),[Drawing.Rectangle]::new(-1920,0,1024,700),[Drawing.Rectangle]::new(-321,-1680,3072,1642))) {
    $form.Bounds=[Drawing.Rectangle]::new($area.X-100,$area.Y-100,1680,970)
    Fit-WindowToWorkArea $area
    Assert-Ui ($area.Contains($form.Bounds)) 'Window escaped target work area.'
}
$form.Size=$normalSize; Update-WindowLayout
Assert-Ui (($script:Drafts['Pad_39'] | ConvertTo-Json -Compress) -ceq $draft) 'Window adaptation altered draft.'
foreach ($id in $leds.Keys) { Assert-Ui ($leds[$id] -eq $script:PadVelocities[$id]) 'Window adaptation altered LED values.' }
Assert-Ui ($script:TestAudio.Count -eq $audio -and $script:TestActions.Count -eq $actions -and $script:TestSaves -eq $saves) 'Window adaptation performed a device/action/profile write.'
[Console]::WriteLine('WINDOW_LAYOUT_TESTS_OK: 1024/800/640 widths, 100/150/225% text, visible actions, F6 pane switching, selected pad/knob/piano scroll, retained drafts, reversible hardware geometry, work-area bounds and no LED/audio/profile writes.')
