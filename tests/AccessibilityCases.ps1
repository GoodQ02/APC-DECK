# Offline, through the real inspector and custom accessibility providers.
$script:Drafts.Clear()
Select-ApcControl 'Pad_32'
$audioBeforeAccessibility = $script:TestAudio.Count
$actionsBeforeAccessibility = $script:TestActions.Count
$savesBeforeAccessibility = $script:TestSaves
$ledsBeforeAccessibility = $script:PadVelocities.Clone()
$geometryBeforeAccessibility = (@($script:ControlButtons.Keys | Sort-Object | ForEach-Object { "$_=$($script:ControlButtons[$_].Bounds)" }) + @($script:WhiteKeyRects.Values) + @($script:BlackKeyRects.Values)) -join '|'
$normalBack = $form.BackColor
$normalInk = $txtLabel.ForeColor
$txtLabel.Text = 'Accessible retained draft'
Assert-Ui ($txtLabel.AccessibleDescription -match 'Unsaved') 'Draft state missing from editable label description.'
$cmbAction.SelectedItem = 'Hotkey'
$cmbTarget1.Text = ''
Assert-Ui (-not $btnSave.Enabled -and -not $btnTest.Enabled -and $cmbTarget1.AccessibleDescription -match 'unavailable') 'Invalid target lacks accessible error/action availability.'
Assert-Ui ($script:PendingAnnouncement -match 'unavailable') 'Validation error was not queued for the screen reader.'
Assert-Ui ($cmbTarget1.AccessibleName -eq $lblTarget1.Text) 'Contextual target label is not exposed.'
$cmbTarget1.Text = 'Ctrl+Shift+M'
$draftBeforeAccessibility = $script:Drafts['Pad_32'] | ConvertTo-Json -Compress
foreach ($enabled in @($true,$false,$true,$false)) {
    Set-ApcContrastTheme $enabled
    $form.Refresh()
    Assert-Ui ($script:UiHighContrast -eq $enabled -and [GoodCube.ApcDeck.DeckTheme]::HighContrast -eq $enabled) 'Theme state was not propagated to custom focus rendering.'
    if ($enabled) {
        foreach ($control in @($form,$txtLabel,$cmbAction,$cmbTarget1,$btnSave,$lblDraftState,$statusBox,$script:ControlButtons['Trans_91'])) {
            Assert-Ui ($control.BackColor.ToArgb() -eq [Drawing.SystemColors]::Window.ToArgb()) "Non-system high-contrast background: $($control.Name)."
            Assert-Ui ($control.ForeColor.ToArgb() -eq [Drawing.SystemColors]::WindowText.ToArgb()) "Non-system high-contrast ink: $($control.Name)."
        }
        Assert-Ui ($script:ControlButtons['Trans_91'].FlatAppearance.BorderColor.ToArgb() -eq [Drawing.SystemColors]::WindowText.ToArgb()) 'Transport boundary vanished in high contrast.'
        Save-TestFrame 'accessibility-system-colors.png'
    } else {
        Assert-Ui ($form.BackColor -eq $normalBack -and $txtLabel.ForeColor -eq $normalInk) 'Normal colors failed to restore.'
    }
}
$geometryAfterAccessibility = (@($script:ControlButtons.Keys | Sort-Object | ForEach-Object { "$_=$($script:ControlButtons[$_].Bounds)" }) + @($script:WhiteKeyRects.Values) + @($script:BlackKeyRects.Values)) -join '|'
Assert-Ui ($geometryAfterAccessibility -ceq $geometryBeforeAccessibility) 'Contrast theme changed hardware geometry.'
Assert-Ui (($script:Drafts['Pad_32'] | ConvertTo-Json -Compress) -ceq $draftBeforeAccessibility) 'Theme switching changed retained draft.'
foreach ($cid in $ledsBeforeAccessibility.Keys) { Assert-Ui ($script:PadVelocities[$cid] -eq $ledsBeforeAccessibility[$cid]) 'Theme switching changed physical LED velocity.' }
Assert-Ui ($script:TestAudio.Count -eq $audioBeforeAccessibility -and $script:TestActions.Count -eq $actionsBeforeAccessibility -and $script:TestSaves -eq $savesBeforeAccessibility) 'Accessibility/theme inspection performed a live action or save.'

$script:FailSave = $true
$btnSave.PerformClick()
Assert-Ui ($script:PendingAnnouncement -match 'Could not save.*Simulated disk failure' -and $script:Drafts.ContainsKey('Pad_32')) 'Save failure was not announced with draft retained.'
$script:FailSave = $false
$btnSave.PerformClick()
Assert-Ui ($script:PendingAnnouncement -match '^Applied Pad_32' -and -not $script:Drafts.ContainsKey('Pad_32')) 'Successful retry not announced.'
$txtLabel.Text = 'Revert this draft'
$btnRevert.PerformClick()
Assert-Ui ($script:PendingAnnouncement -match '^Reverted draft') 'Revert not announced.'
$btnTest.PerformClick()
Assert-Ui ($script:PendingAnnouncement -match '^\[TEST') 'Explicit Test outcome not announced.'
$script:PendingAnnouncement = ''
Set-StatusBanner 'Fixture hardware refresh'
Assert-Ui (-not $script:PendingAnnouncement) 'Background hardware status caused unsolicited speech.'
Select-ApcControl 'Knob_49'
$f8 = Send-FixtureKey $form F8
Assert-Ui ($f8.SuppressKeyPress -and $script:PendingAnnouncement -match 'Knob_49.*Saved device level.*percent') 'F8 omitted cached knob status.'
Select-ApcControl 'Key_49'
$readStatusItem.PerformClick()
Assert-Ui ($script:PendingAnnouncement -match 'Key_49' -and $script:PendingAnnouncement -match 'Saved') 'Menu readout omitted piano mapping or draft status.'
$form.Activate()
Focus-ApcControl 'Key_49'
Assert-Ui $form.ContainsFocus 'Notification test requires the actual form focus.'
Send-PendingAccessibilityAnnouncement
Assert-Ui ($script:LastAnnouncement -match 'Key_49' -and -not $script:PendingAnnouncement) 'Focused notification was not submitted.'
[Console]::WriteLine("ACCESSIBILITY_TESTS_OK: contextual field names, draft/error/save/revert/test announcements, cached F8/menu readout, quiet hardware refresh, reversible system colors and transport outlines, retained drafts, identical hardware geometry and LED values. Notification API accepted=$($script:AccessibilityNotificationDelivered); this is not proof of Narrator speech.")
