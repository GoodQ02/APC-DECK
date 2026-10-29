$audioBeforePads = $script:TestAudio.Count
$actionsBeforePads = $script:TestActions.Count
$savesBeforePads = $script:TestSaves
function Get-TestContrast([Drawing.Color]$Foreground, [Drawing.Color]$Background) {
    $a = Get-ColorLuminance $Foreground; $b = Get-ColorLuminance $Background
    ([math]::Max($a,$b) + 0.05) / ([math]::Min($a,$b) + 0.05)
}
$palette = New-PadPalette
$minContrast = 100.0
foreach ($background in @('Background','SelectedBackground')) {
    foreach ($ink in @('Primary','Secondary','Positive','Muted','Warning')) {
        $ratio = Get-TestContrast $palette[$ink] $palette[$background]
        $minContrast = [math]::Min($minContrast, $ratio)
        Assert-Ui ($ratio -ge 4.5) "Pad contrast below 4.5:1: $ink on $background = $ratio."
    }
}
foreach ($name in @('Green','BlinkGreen','Red','BlinkRed','Amber','BlinkAmber','Off')) {
    $background = Get-UiColorForColorName $name $cPadUnmapped
    Assert-Ui ((Get-TestContrast (Get-ReadableInk $background) $background) -ge 4.5) "Custom $name key/transport text lacks contrast."
}
$endpoint = [pscustomobject]@{ID='fixture'; FriendlyName='Fixture speaker'; Flow='Render'; State='Active'; IsDefault=$true; VolumePct=42; Muted=$false}
$mapping = [pscustomobject]@{Label='A long mapping label that must remain intact'; ActionType='SetDefaultDevice'; Target='fixture'; SecondaryTarget='second'; LedColor='Red'; OffLedColor='Red'}
$observed = Get-PadPresentation $mapping @($endpoint) @()
Assert-Ui ($observed.Status -eq 'Default' -and $observed.Title -eq $mapping.Label) 'State inferred from red LED or full name discarded.'
foreach ($color in @('Green','BlinkGreen','Red','BlinkRed','Amber','BlinkAmber','Off')) {
    $mapping.LedColor=$color; $mapping.OffLedColor=$color
    Assert-Ui ((Get-PadPresentation $mapping @($endpoint) @()).Status -eq 'Default') 'Custom LED override altered operational state.'
}
$mapping.ActionType='MuteToggle'; $endpoint.Muted=$true
Assert-Ui ((Get-PadPresentation $mapping @($endpoint) @()).Status -eq 'Muted') 'Muted state missing.'
$endpoint.State='Disabled'
Assert-Ui ((Get-PadPresentation $mapping @($endpoint) @()).State -eq 'Disabled') 'Disabled state missing.'
$endpoint.State='Unplugged'
Assert-Ui ((Get-PadPresentation $mapping @($endpoint) @()).State -eq 'Disconnected') 'Disconnected state missing.'
Assert-Ui ((Get-PadPresentation $mapping @() @()).State -eq 'Unavailable') 'Missing endpoint presented as live.'
$endpoint.State='Active'; $endpoint.VolumePct=$null
Assert-Ui ((Get-PadPresentation $mapping @($endpoint) @()).Status -eq 'Unknown') 'Failed level read presented as live mute state.'
$mapping.ActionType='SwapDevices'; $endpoint.VolumePct=42
Assert-Ui ((Get-PadPresentation $mapping @($endpoint) @()).Status -eq 'Partial') 'Missing second swap target ignored.'
$second=$endpoint.PSObject.Copy(); $second.ID='second'; $second.FriendlyName='Second speaker'; $endpoint.IsDefault=$false
Assert-Ui ((Get-PadPresentation $mapping @($endpoint,$second) @()).Status -eq 'B active') 'Second default target not identified.'

# Test the real changed-pad cache with LED colors pinned identical in both states.
$script:ProfileMap=@{}; foreach ($m in New-DefaultApcProfile) { $script:ProfileMap[$m.ControlId]=$m }
$script:FixtureSnapshot = @(foreach ($name in @('COMMAND_CENTER','VOICE_CUBE','PS5_HEADPHONES','M-AUDIO-AUX','META_VR','CMD_MIC','PS5_MIC')) {
    [pscustomobject]@{ID=$name; FriendlyName=$name; Flow=$(if ($name -match 'MIC') {'Capture'} else {'Render'}); State='Active'; IsDefault=($name -in @('COMMAND_CENTER','CMD_MIC')); VolumePct=50; Muted=$false}
})
$script:AudioSnapshot=$script:FixtureSnapshot
$script:BtSnapshot=@()
$script:ProfileMap['Pad_25'].LedColor='Red'; $script:ProfileMap['Pad_25'].OffLedColor='Red'
$null = Update-PadVelocitiesCache
$velocityBefore=$script:PadVelocities['Pad_25']
$script:AudioSnapshot[0].Muted=$true
$changed=@(Update-PadVelocitiesCache)
Assert-Ui ($changed -contains 'Pad_25' -and $script:PadVelocities['Pad_25'] -eq $velocityBefore) 'State-only change did not invalidate a pad with fixed LED color.'
Assert-Ui (@(Update-PadVelocitiesCache).Count -eq 0) 'Unchanged pads requested redundant repaint.'
Focus-ApcControl 'Pad_25'
Assert-Ui ($lblSelectedMeta.Text -match 'Muted' -and $toolTips.GetToolTip($script:ControlButtons['Pad_25']) -match 'LED: Red' -and $script:ControlButtons['Pad_25'].AccessibilityObject.Value -match 'State: Muted') 'Inspector/tooltip/accessibility omit independent status and LED identity.'

$script:FailSnapshot=$true
Invoke-FixtureTick
Assert-Ui ($script:PadPresentations['Pad_25'].State -eq 'Telemetry unavailable') 'Refresh failure left pad state live.'
$script:FailSnapshot=$false
Invoke-FixtureTick
Assert-Ui ($script:PadPresentations['Pad_25'].State -eq 'Muted') 'Pad telemetry did not recover.'

# Real render fixtures: each state, long labels, and all LED colors without changing the profile on disk.
$script:AudioSnapshot[2].State='Disabled'
$script:AudioSnapshot[3].State='Unplugged'
$script:ProfileMap['Pad_36'].Target='Missing fixture endpoint'
$script:ProfileMap['Pad_0'].Label='A long custom mapping label with several words'
foreach ($pair in @(@('Pad_1','BlinkGreen'),@('Pad_2','BlinkAmber'),@('Pad_3','BlinkRed'))) { $script:ProfileMap[$pair[0]].LedColor=$pair[1] }
$script:ProfileMap['Key_48'].LedColor='BlinkGreen'
$script:ProfileMap['Key_49'].LedColor='BlinkAmber'
$script:ProfileMap['Trans_91'].LedColor='BlinkGreen'
$script:ProfileMap['Knob_48'].Label='K1: MASTER OUT'
Update-SurfaceButtonsVisuals
foreach ($size in @(@(1680,970), @(1366,768), @(1200,740))) {
    $form.Size=[Drawing.Size]::new($size[0],$size[1]); $form.PerformLayout()
    Focus-ApcControl 'Pad_25'
    Save-TestFrame "contrast-$($size[0])x$($size[1]).png"
}
$ledsBeforeTheme = $script:PadVelocities.Clone()
$script:PadPalette = New-PadPalette $true
$form.Size=[Drawing.Size]::new(1680,970); $form.PerformLayout(); $form.Refresh()
Save-TestFrame 'contrast-system-colors.png'
foreach ($cid in $ledsBeforeTheme.Keys) { Assert-Ui ($script:PadVelocities[$cid] -eq $ledsBeforeTheme[$cid]) 'Screen contrast palette changed LED velocity.' }
$script:PadPalette = New-PadPalette $script:PadHighContrast
Assert-Ui ($script:TestAudio.Count -eq $audioBeforePads -and $script:TestActions.Count -eq $actionsBeforePads -and $script:TestSaves -eq $savesBeforePads) 'Pad presentation invoked audio/actions/profile writes.'
[Console]::WriteLine("PAD_TESTS_OK: measured pad contrast minimum $([math]::Round($minContrast,2)):1; readable custom colors; independent state/LED identity; change-only refresh; telemetry failure/recovery; full labels; three sizes and system-color palette; no audio/profile writes.")
