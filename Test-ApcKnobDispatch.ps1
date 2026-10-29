Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Exercise the real MIDI dispatch block with recording sinks; never write audio.
Import-Module (Join-Path $PSScriptRoot 'ApcDeck.psm1') -Force -DisableNameChecking
$source = Get-Content -Raw (Join-Path $PSScriptRoot 'Open-ApcDeck.ps1')
$start = $source.IndexOf('        $knobToSelect = $null')
if ($start -lt 0) { throw 'Cannot locate knob dispatch block.' }
$end = $source.IndexOf('        if ($needFullRefresh)', $start)
if ($end -le $start) { throw 'Cannot locate knob dispatch block.' }
$dispatch = [scriptblock]::Create($source.Substring($start, $end - $start))

function Set-AudioVolumeByMapping {
    param($Mapping, [int]$MidiValue, [switch]$AutoMuteAtZero)
    $script:Calls.Add("Volume:$($Mapping.ControlId):$MidiValue")
    return 'Recorded'
}
function Select-ApcControl([string]$cid) {
    $script:Calls.Add("Select:$cid")
    $script:SelectedId = $cid
}
function Invalidate-ApcControl([string]$cid) { }

function Test-DispatchCase {
    param(
        [string]$Name, [string[]]$Expected, [bool]$EditOnly = $false,
        [bool]$Pickup = $false, [bool]$Learn = $true, [bool]$Visible = $true,
        [int]$MidiValue = 64, [int]$Previous = -1, [string]$Selected = 'Pad_32',
        [int[]]$Codes = @(48, 49)
    )
    $script:Calls = [Collections.Generic.List[string]]::new()
    $script:ProfileMap = @{}
    $script:KnobValues = @{}
    $script:KnobPickedUp = @{}
    $script:KnobLastPhys = @{}
    $script:SelectedId = $Selected
    $script:LastKnobTurnTick = [int64]0
    $latestCc = [ordered]@{}
    foreach ($cc in $Codes) {
        $cid = "Knob_$cc"
        $script:ProfileMap[$cid] = [pscustomobject]@{ControlId=$cid; Label=$cid}
        $script:KnobValues[$cid] = 75
        $script:KnobPickedUp[$cid] = $false
        $script:KnobLastPhys[$cid] = $Previous
        $latestCc.Add([string]$cc, [pscustomobject]@{Data2=$MidiValue})
    }
    $chkMidiLearn = [pscustomobject]@{Checked=$Learn}
    $chkEditOnly = [pscustomobject]@{Checked=$EditOnly}
    $chkPickupMode = [pscustomobject]@{Checked=$Pickup}
    $form = [pscustomobject]@{Visible=$Visible}
    $lastBanner = $null
    . $dispatch
    if (($script:Calls -join '|') -cne ($Expected -join '|')) {
        throw "${Name}: expected [$($Expected -join ', ')], got [$($script:Calls -join ', ')]"
    }
}

Test-DispatchCase 'All audio precedes one selection' @('Volume:Knob_48:64','Volume:Knob_49:64','Select:Knob_49')
Test-DispatchCase 'Edit-only still learns' @('Select:Knob_49') -EditOnly $true
Test-DispatchCase 'Pickup waits but still learns' @('Select:Knob_49') -Pickup $true
Test-DispatchCase 'Pickup crossing applies volume' @('Volume:Knob_48:100','Volume:Knob_49:100','Select:Knob_49') -Pickup $true -Previous 70 -MidiValue 100
Test-DispatchCase 'Zero bypasses pickup' @('Volume:Knob_48:0','Volume:Knob_49:0','Select:Knob_49') -Pickup $true -MidiValue 0
Test-DispatchCase 'Learn off skips inspector' @('Volume:Knob_48:64','Volume:Knob_49:64') -Learn $false
Test-DispatchCase 'Hidden window skips inspector' @('Volume:Knob_48:64','Volume:Knob_49:64') -Visible $false
Test-DispatchCase 'Selected knob skips inspector' @('Volume:Knob_48:64') -Selected 'Knob_48' -Codes @(48)
Write-Output 'PASS: Knob dispatch ordering, edit-only, pickup, and MIDI Learn (8 cases; no audio writes).'
