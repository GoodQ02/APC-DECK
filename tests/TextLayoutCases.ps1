# Exercise larger fonts without changing Windows display/text preferences or real mappings.
$audioBeforeText = $script:TestAudio.Count
$actionsBeforeText = $script:TestActions.Count
$savesBeforeText = $script:TestSaves
$script:TextSizeChoice = 100
$script:Drafts.Clear()
Select-ApcControl 'Pad_39'
$txtLabel.Text = 'A long retained label for two devices'
$draftBeforeText = $script:Drafts['Pad_39'] | ConvertTo-Json -Compress
$ledsBeforeText = $script:PadVelocities.Clone()
$geometryBySize = @{}
foreach ($scale in @(1.0,1.25,1.5,2.0,2.25)) {
    Set-ReadableTextScale $scale
    foreach ($size in @(@(1680,970),@(1200,740))) {
        $form.Size = [Drawing.Size]::new($size[0],$size[1]); $form.PerformLayout()
        Resize-InspectorContent
        $geometry = (@($script:ControlButtons.Keys | Sort-Object | ForEach-Object { "$_=$($script:ControlButtons[$_].Bounds)" }) + @($script:WhiteKeyRects.Keys | Sort-Object | ForEach-Object { "$_=$($script:WhiteKeyRects[$_])" }) + @($script:BlackKeyRects.Keys | Sort-Object | ForEach-Object { "$_=$($script:BlackKeyRects[$_])" })) -join '|'
        $sizeKey = "$($size[0])x$($size[1])"
        if ($scale -eq 1.0) { $geometryBySize[$sizeKey] = $geometry }
        else { Assert-Ui ($geometry -ceq $geometryBySize[$sizeKey]) "Text scaling moved hardware geometry at $sizeKey." }
        foreach ($cid in @('Pad_39','Knob_49','Key_49')) {
            Select-ApcControl $cid
            $form.PerformLayout(); $form.Refresh()
            Assert-Ui (-not $inspFlow.HorizontalScroll.Visible) "Horizontal inspector scroll at $scale / $size."
            Assert-Ui ($inspFlow.Height -ge 100) "Larger text left no useful scrollable editor at $scale / $size."
            foreach ($button in @($btnSave,$btnRevert,$btnTest,$btnMore)) {
                $rect = [Drawing.Rectangle]::new($form.PointToClient($button.PointToScreen([Drawing.Point]::Empty)), $button.Size)
                Assert-Ui ($form.ClientRectangle.Contains($rect)) "Persistent $($button.Text) offscreen at $scale / $size."
                $needed = Get-InspectorTextHeight $button ($button.Width - 10)
                Assert-Ui ($button.Height -ge $needed) "Persistent $($button.Text) text clipped at $scale / $size."
            }
            foreach ($toggle in @($chkMidiLearn,$chkEditOnly,$chkPickupMode)) {
                Assert-Ui ($toggle.Height -ge (Get-InspectorTextHeight $toggle ($toggle.Width - 24))) 'Mode toggle text clipped.'
            }
            $inspFlow.ScrollControlIntoView($cmbAction)
            $null = $cmbAction.Focus()
            Assert-Ui ($cmbAction.Focused -and $inspFlow.ClientRectangle.IntersectsWith($cmbAction.Bounds)) 'Keyboard field scroll failed.'
        }
        Select-ApcControl 'Pad_39'
        $inspFlow.AutoScrollPosition = [Drawing.Point]::Empty
        Save-TestFrame "text-$([int]($scale*100))-$($size[0])x$($size[1]).png"
        # Device arrangement and piano geometry remain in hardware order at every font size.
        Assert-Ui ($script:ControlButtons['Pad_32'].Top -lt $script:ControlButtons['Pad_0'].Top) 'Pad row order changed.'
        Assert-Ui ($script:ControlButtons['Knob_48'].Left -lt $script:ControlButtons['Knob_51'].Left) 'Knob bank order changed.'
        Assert-Ui ($keybedCanvas.AccessibilityObject.GetChildCount() -eq 25) 'Piano mappings lost during text scaling.'
    }
}
Assert-Ui (($script:Drafts['Pad_39'] | ConvertTo-Json -Compress) -ceq $draftBeforeText) 'Text scaling changed a retained draft.'
foreach ($cid in $ledsBeforeText.Keys) { Assert-Ui ($script:PadVelocities[$cid] -eq $ledsBeforeText[$cid]) 'Text scaling changed physical LED values.' }
Assert-Ui ($script:TestAudio.Count -eq $audioBeforeText -and $script:TestActions.Count -eq $actionsBeforeText -and $script:TestSaves -eq $savesBeforeText) 'Text layout wrote audio/actions/profile.'
Set-ReadableTextScale 1.0
Assert-Ui ([math]::Abs($script:FPadLabel.Size - $script:BaseSurfaceFonts['FPadLabel'].Size) -lt 0.01) 'Text size compounded after repeated changes.'
$graphics = $form.CreateGraphics()
try {
    $wrapped = Get-SurfaceLines $graphics 'HEADPHONES SPEAKER' $script:FPadLabel 20 3
    Assert-Ui ($wrapped -eq "HEADPHONES`nSPEAKER") 'Long words fragmented vertically.'
} finally { $graphics.Dispose() }
# Actual GDI+ font metrics at 96/120/144/192 DPI, with proportional device-pixel cells.
Set-ReadableTextScale 2.25
foreach ($dpi in @(96,120,144,192)) {
    $factor = $dpi / 96.0
    $bitmap = [Drawing.Bitmap]::new([int](180*$factor),[int](100*$factor))
    $bitmap.SetResolution($dpi,$dpi)
    $g = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $g.Clear([Drawing.Color]::FromArgb(30,34,43))
        $valueFont = Get-SurfaceFont $g 'FKnobValue' ([int](65*$factor)) ([int](28*$factor)) '100%'
        $noteFont = Get-SurfaceFont $g 'FKeyNoteB' ([int](26*$factor)) ([int](20*$factor)) 'C#3'
        Assert-Ui ($g.MeasureString('100%',$valueFont).Width -le 65*$factor) "Volume percentage cropped at $dpi DPI."
        Assert-Ui ($g.MeasureString('C#3',$noteFont).Width -le 26*$factor) "Piano identity cropped at $dpi DPI."
        $g.DrawString('100%',$valueFont,[Drawing.Brushes]::White,0,0)
        $g.DrawString('C#3',$noteFont,[Drawing.Brushes]::White,0,[single](40*$factor))
        if ($env:APC_DECK_PREVIEW_DIRECTORY) { $bitmap.Save((Join-Path $env:APC_DECK_PREVIEW_DIRECTORY "metrics-$dpi-dpi.png"),[Drawing.Imaging.ImageFormat]::Png) }
    } finally { $g.Dispose(); $bitmap.Dispose() }
}
$textSizeMenu.DropDownItems[2].PerformClick()
Assert-Ui ($script:TextSizeChoice -eq 125 -and $textSizeMenu.DropDownItems[2].Checked -and [math]::Abs($script:TextScale - 1.25) -lt 0.001) 'Text-size menu did not apply/check its choice.'
$textSizeMenu.DropDownItems[0].PerformClick()
Assert-Ui ($script:TextSizeChoice -eq 0 -and $textSizeMenu.DropDownItems[0].Checked) 'Text-size menu did not restore Windows preference.'
$script:TextSizeChoice = 0
Set-ReadableTextScale (Get-WindowsTextScale)
[Console]::WriteLine('TEXT_LAYOUT_TESTS_OK: 100/125/150/200/225% fonts at two window sizes; 96/120/144/192 DPI font metrics; fixed actions, scrollable fields, wrapped toggles, retained drafts, identical hardware geometry, no LED/audio/profile writes, reversible font sizing and menu choices.')
