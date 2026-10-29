# Screen-only text sizing. Keep the established DPI/desktop mode and hardware geometry.
function Get-WindowsTextScale {
    try {
        $percent = Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Accessibility' -Name TextScaleFactor -ErrorAction Stop
        return [math]::Clamp([double]$percent / 100.0, 1.0, 2.25)
    } catch { return 1.0 }
}

$script:TextScale = 1.0
$script:TextSizeChoice = 0
$script:TextLayoutBusy = $false
$script:TextFonts = [Collections.Generic.List[Drawing.Font]]::new()
$script:SurfaceTextCache = @{}
$script:BaseSurfaceFonts = @{}
$script:SurfaceFontChoices = @{}
foreach ($name in @('FPadMain','FPadLabel','FPadStatus','FRoundCap','FKnobTop','FKnobName','FKnobFeedback','FKnobValue','FKeyNoteW','FKeyLblW','FKeyNoteB','FKeyLblB')) {
    $script:BaseSurfaceFonts[$name] = Get-Variable $name -Scope Script -ValueOnly
    $script:SurfaceFontChoices[$name] = @($script:BaseSurfaceFonts[$name])
}

function Get-SurfaceFont($Graphics, [string]$Name, [int]$Width, [int]$Height, [string]$Sample) {
    # Fixed hardware cells cannot grow with the inspector. Enlarge only while useful text still fits.
    $choices = $script:SurfaceFontChoices[$Name]
    for ($i=$choices.Count - 1; $i -ge 0; $i--) {
        $font = $choices[$i]
        if ($font.GetHeight($Graphics) -le $Height -and $Graphics.MeasureString($Sample,$font).Width -le $Width) { return $font }
    }
    return $choices[0]
}

function Get-SurfaceLines($Graphics, [string]$Text, [Drawing.Font]$Font, [int]$Width, [int]$Lines) {
    # Keep words intact; the renderer ellipsizes an overlong word instead of splitting it vertically.
    $Lines = [math]::Max(1, $Lines)
    $key = "$Text|$($Font.Size)|$($Font.FontFamily.Name)|$($Font.Style)|$Width|$Lines|$($Graphics.DpiY)"
    if ($script:SurfaceTextCache.ContainsKey($key)) { return $script:SurfaceTextCache[$key] }
    $rows = [Collections.Generic.List[string]]::new()
    $line = ''
    foreach ($word in ($Text -split '\s+')) {
        $candidate = if ($line) { "$line $word" } else { $word }
        if ($line -and $rows.Count -lt $Lines - 1 -and $Graphics.MeasureString($candidate, $Font).Width -gt $Width) {
            $rows.Add($line); $line = $word
        } else { $line = $candidate }
    }
    $rows.Add($line)
    $result = $rows -join "`n"
    if ($script:SurfaceTextCache.Count -ge 512) { $script:SurfaceTextCache.Clear() }
    $script:SurfaceTextCache[$key] = $result
    return $result
}

function Get-InspectorTextHeight($Control, [int]$Width, [int]$MaxLines = 0) {
    $flags = [Windows.Forms.TextFormatFlags]'WordBreak, NoPrefix, TextBoxControl'
    $size = [Windows.Forms.TextRenderer]::MeasureText($Control.Text, $Control.Font, [Drawing.Size]::new([math]::Max(40,$Width), 10000), $flags)
    $height = [math]::Max($Control.Font.Height, $size.Height) + 4
    if ($MaxLines -gt 0) { $height = [math]::Min($height, $Control.Font.Height * $MaxLines + 4) }
    return $height
}

function Resize-ReadableInspector {
    if ($script:TextLayoutBusy) { return }
    $script:TextLayoutBusy = $true
    try {
        $inspFlow.SuspendLayout(); $inspHeader.SuspendLayout()
        $width = [math]::Max(100, $inspFlow.ClientSize.Width - [Windows.Forms.SystemInformation]::VerticalScrollBarWidth - 6)
        foreach ($ctrl in $inspFlow.Controls) {
            $ctrl.Width = $width
            if ($ctrl -is [Windows.Forms.CheckBox]) { $ctrl.Height = Get-InspectorTextHeight $ctrl ($width - 24) }
            elseif ($ctrl -is [Windows.Forms.Label]) { $ctrl.Height = Get-InspectorTextHeight $ctrl $width }
        }
        $headerHeight = 8
        foreach ($ctrl in $inspHeader.Controls) {
            $ctrl.Width = [math]::Max(100, $inspHeader.ClientSize.Width - 4)
            # Stable two-line context avoids relayout on every hardware selection.
            $ctrl.Height = $ctrl.Font.Height * 2 + 4
            $headerHeight += $ctrl.Height + $ctrl.Margin.Vertical
        }
        $inspectorLayout.RowStyles[0].Height = $headerHeight
        $swatchWidth = [math]::Max(24, [int][math]::Floor(($width - 24) / 4))
        $swatchPanel.Height = $form.Font.Height + 16
        foreach ($swatch in $swatchPanel.Controls) { $swatch.Width = $swatchWidth; $swatch.Height = $swatchPanel.Height - 4 }
        $rowHeights = @([math]::Max(26, $lblDraftState.Font.Height * 2 + 6), [math]::Max(36, $btnSave.Font.Height + 14), [math]::Max(36, $btnTest.Font.Height * 2 + 12), [math]::Max(28, $btnMore.Font.Height + 12))
        for ($i=0; $i -lt 4; $i++) { $inspectorFooter.RowStyles[$i].Height = $rowHeights[$i] }
        $inspectorLayout.RowStyles[2].Height = ($rowHeights | Measure-Object -Sum).Sum + 12
        foreach ($combo in @($cmbAction,$cmbTarget1,$cmbTarget2,$cmbLed,$cmbOffLed)) {
            $combo.DropDownWidth = [math]::Max($combo.Width, [math]::Min(700, [int](440 * $script:TextScale)))
        }
    } finally {
        $inspHeader.ResumeLayout($true); $inspFlow.ResumeLayout($true)
        $script:TextLayoutBusy = $false
    }
}

function Set-ReadableTextScale([double]$Scale) {
    $Scale = [math]::Clamp($Scale, 1.0, 2.25)
    if ($script:TextFonts.Count -gt 0 -and [math]::Abs($script:TextScale - $Scale) -lt 0.001) { return }
    $script:TextScale = $Scale
    $oldFonts = @($script:TextFonts.ToArray())
    $script:TextFonts.Clear()
    $form.SuspendLayout()
    try {
        foreach ($name in $script:BaseSurfaceFonts.Keys) {
            $base = $script:BaseSurfaceFonts[$name]
            $choices = [Collections.Generic.List[Drawing.Font]]::new()
            $choices.Add($base)
            foreach ($step in @(@(1.25,1.5,2.0) | Where-Object { $_ -lt $Scale }) + @($Scale)) {
                if ($step -le 1.0) { continue }
                $font = [Drawing.Font]::new($base.FontFamily, [single]($base.Size * $step), $base.Style, $base.Unit)
                $script:TextFonts.Add($font); $choices.Add($font)
            }
            $script:SurfaceFontChoices[$name] = $choices.ToArray()
            Set-Variable $name $choices[$choices.Count - 1] -Scope Script
        }
        $normal = [Drawing.Font]::new('Segoe UI', [single](9 * $Scale))
        $fieldFont = [Drawing.Font]::new('Segoe UI', [single](9.5 * $Scale))
        $titleFont = [Drawing.Font]::new('Segoe UI Semibold', [single](12 * $Scale))
        foreach ($font in @($normal,$fieldFont,$titleFont)) { $script:TextFonts.Add($font) }
        $form.Font = $normal
        foreach ($ctrl in @($inspFlow.Controls) + @($inspHeader.Controls)) {
            if ($ctrl -is [Windows.Forms.TextBox] -or $ctrl -is [Windows.Forms.ComboBox]) { $ctrl.Font = $fieldFont }
            else { $ctrl.Font = $normal }
        }
        $lblSelectedHeader.Font = $titleFont
        foreach ($button in @($btnSave,$btnRevert,$btnTest,$btnMore)) { $button.Font = $normal }
        $lblDraftState.Font = $normal
        $btnSave.Text = if ($Scale -ge 1.5) { 'Apply' } else { 'Apply  (Ctrl+S)' }
        $toolTips.SetToolTip($btnSave, 'Apply this draft (Ctrl+S)')
        $utilityMenu.Font = $normal
        $script:SurfaceTextCache.Clear()
        Update-InspectorDraftState
        Resize-ReadableInspector
    } finally { $form.ResumeLayout($true) }
    $form.Invalidate($true)
    foreach ($font in $oldFonts) { $font.Dispose() }
}

# A session override is useful without changing Windows settings or the mapping profile.
$textSizeMenu = [Windows.Forms.ToolStripMenuItem]::new('Text size')
[void]$utilityMenu.Items.Add($textSizeMenu)
foreach ($percent in @(0,100,125,150,200,225)) {
    $item = $textSizeMenu.DropDownItems.Add($(if ($percent -eq 0) { 'Use Windows text size' } else { "$percent%" }))
    $item.Tag = $percent
    $item.Add_Click({
        $script:TextSizeChoice = [int]$this.Tag
        Set-ReadableTextScale $(if ($script:TextSizeChoice -eq 0) { Get-WindowsTextScale } else { $script:TextSizeChoice / 100.0 })
        foreach ($entry in $textSizeMenu.DropDownItems) { $entry.Checked = [int]$entry.Tag -eq $script:TextSizeChoice }
    })
}
$textSizeMenu.DropDownItems[0].Checked = $true
$lblValidation.Add_TextChanged({
    if (-not $script:TextLayoutBusy) { $this.Height = Get-InspectorTextHeight $this $this.Width }
})
$form.Add_Activated({ if ($script:TextSizeChoice -eq 0) { Set-ReadableTextScale (Get-WindowsTextScale) } })
