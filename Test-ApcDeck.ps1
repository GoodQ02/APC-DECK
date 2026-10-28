Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ApcDeck.psm1') -Force -DisableNameChecking

$profileMap = Load-ApcProfile
if ($profileMap.Count -ne 90) {
    throw "Expected 90 controls in default APC Key 25 profile, got $($profileMap.Count)."
}
foreach ($tid in @('Trans_91', 'Trans_93', 'Trans_98')) {
    if (-not $profileMap.ContainsKey($tid)) {
        throw "Expected physical transport/shift control $tid in default profile."
    }
}

# 1. Verify knob zero-out & full-scale deadzone clamping
if ((Convert-MidiCcToScalar 0) -ne 0.0 -or (Convert-MidiCcToScalar 1) -ne 0.0) {
    throw 'Expected CC 0 and CC 1 to clamp cleanly to 0.0 (0% zeroed out).'
}
if ((Convert-MidiCcToScalar 126) -ne 1.0 -or (Convert-MidiCcToScalar 127) -ne 1.0) {
    throw 'Expected CC 126 and CC 127 to clamp cleanly to 1.0 (100%).'
}
$mid = Convert-MidiCcToScalar 64
if ($mid -lt 0.49 -or $mid -gt 0.52) {
    throw "Unexpected midpoint scalar for CC 64: $mid"
}

# 2. Verify hotkey chord parser
$chord1 = Parse-HotkeyChord 'Alt+Q'
if (-not $chord1 -or $chord1.Modifiers.Count -ne 1 -or $chord1.Modifiers[0] -ne 0x12 -or $chord1.MainKey -ne 81) {
    throw 'Alt+Q hotkey parse failed.'
}
$chord2 = Parse-HotkeyChord 'Ctrl+Shift+M'
if (-not $chord2 -or $chord2.Modifiers.Count -ne 2 -or $chord2.MainKey -ne 77) {
    throw 'Ctrl+Shift+M hotkey parse failed.'
}
$chord3 = Parse-HotkeyChord 'F13'
if (-not $chord3 -or $chord3.Modifiers.Count -ne 0 -or $chord3.MainKey -ne 0x7C) {
    throw 'F13 hotkey parse failed.'
}

# 3. Verify LED velocity state calculation & custom color overrides
$fakeAudio = @(
    [pscustomobject]@{ ID='dev1'; FriendlyName='COMMAND_CENTER (Realtek)'; Flow='Render'; State='Active'; IsDefault=$true; VolumePct=75; Muted=$false },
    [pscustomobject]@{ ID='dev2'; FriendlyName='VOICE_CUBE (Realtek)'; Flow='Render'; State='Active'; IsDefault=$false; VolumePct=65; Muted=$true },
    [pscustomobject]@{ ID='dev3'; FriendlyName='META_VR (Oculus)'; Flow='Render'; State='Disabled'; IsDefault=$false; VolumePct=$null; Muted=$false }
)
$fakeBt = @(
    [pscustomobject]@{ Name='RB Meta 00YS'; DeviceId='bt1'; Status='Connected' },
    [pscustomobject]@{ Name='RB Meta 01JY'; DeviceId='bt2'; Status='Disconnected' }
)

if ((Get-PadLedVelocity -Mapping $profileMap['Pad_32'] -AudioSnapshot $fakeAudio -BtSnapshot $fakeBt) -ne 1) {
    throw 'Expected active default device pad (Pad_32) LED velocity to be 1 (Solid Green).'
}
if ((Get-PadLedVelocity -Mapping $profileMap['Pad_33'] -AudioSnapshot $fakeAudio -BtSnapshot $fakeBt) -ne 5) {
    throw 'Expected standby device pad (Pad_33) LED velocity to be 5 (Solid Amber).'
}
if ((Get-PadLedVelocity -Mapping $profileMap['Pad_26'] -AudioSnapshot $fakeAudio -BtSnapshot $fakeBt) -ne 3) {
    throw 'Expected muted device pad (Pad_26) LED velocity to be 3 (Solid Red).'
}
if ((Get-PadLedVelocity -Mapping $profileMap['Pad_20'] -AudioSnapshot $fakeAudio -BtSnapshot $fakeBt) -ne 3) {
    throw 'Expected disabled endpoint pad (Pad_20) LED velocity to be 3 (Solid Red).'
}
if ((Get-PadLedVelocity -Mapping $profileMap['Pad_8'] -AudioSnapshot $fakeAudio -BtSnapshot $fakeBt) -ne 1) {
    throw 'Expected connected Bluetooth pad (Pad_8) LED velocity to be 1 (Solid Green).'
}
if ((Get-PadLedVelocity -Mapping $profileMap['Pad_9'] -AudioSnapshot $fakeAudio -BtSnapshot $fakeBt) -ne 3) {
    throw 'Expected disconnected Bluetooth pad (Pad_9) LED velocity to be 3 (Solid Red).'
}

# Custom LED override check (BlinkGreen = 2, BlinkRed = 4, BlinkAmber = 6)
$customPad = [pscustomobject]@{
    ControlId='Pad_32'; ControlKind='Pad'; Channel=0; Code=32; Label='TEST'
    ActionType='SetDefaultDevice'; Target='COMMAND_CENTER'; SecondaryTarget=''
    LedColor='BlinkGreen'; OffLedColor='BlinkAmber'
}
if ((Get-PadLedVelocity -Mapping $customPad -AudioSnapshot $fakeAudio -BtSnapshot $fakeBt) -ne 2) {
    throw 'Expected custom BlinkGreen active override to return velocity 2.'
}
$customStandby = [pscustomobject]@{
    ControlId='Pad_33'; ControlKind='Pad'; Channel=0; Code=33; Label='TEST2'
    ActionType='SetDefaultDevice'; Target='VOICE_CUBE'; SecondaryTarget=''
    LedColor='BlinkGreen'; OffLedColor='BlinkAmber'
}
if ((Get-PadLedVelocity -Mapping $customStandby -AudioSnapshot $fakeAudio -BtSnapshot $fakeBt) -ne 6) {
    throw 'Expected custom BlinkAmber standby override to return velocity 6.'
}

# 4. Verify live snapshot mode
$snapJson = & pwsh.exe -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'Open-ApcDeck.ps1') -Mode Snapshot
$snap = $snapJson | ConvertFrom-Json
if ($snap.ControlCount -ne 90) {
    throw "Snapshot reported unexpected ControlCount: $($snap.ControlCount)"
}

# 5. Verify native WinForms UI window rendering & MIDI connection smoke test
$smokeOut = & pwsh.exe -NoLogo -NoProfile -STA -File (Join-Path $PSScriptRoot 'Open-ApcDeck.ps1') -SmokeTestUi
if ($smokeOut -notmatch 'SMOKE_UI_OK:\s+Handle=\d+\s+Visible=True') {
    throw "Native WinForms UI smoke test failed: $smokeOut"
}

Write-Output "PASS: ApcDeck verified (Controls=$($snap.ControlCount), MidiIn=$($snap.MidiInIndex), MidiOut=$($snap.MidiOutIndex), AudioEndpoints=$($snap.AudioDevices.Count), BluetoothPaired=$($snap.Bluetooth.Count), UI=Visible)"
