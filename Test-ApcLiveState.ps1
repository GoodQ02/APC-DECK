Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Exercise the real snapshot/resolver cache lifecycle using in-memory COM substitutes.
# This fresh process neither discovers endpoints nor writes audio.
$module = Import-Module (Join-Path $PSScriptRoot 'ApcDeck.psm1') -Force -DisableNameChecking -PassThru
& $module {
    $missingMute = [pscustomobject]@{ ActionType='MuteToggle'; Target='@DefaultRender'; LedColor='Auto'; OffLedColor='Auto' }
    if ((Get-PadLedVelocity -Mapping $missingMute -AudioSnapshot @() -BtSnapshot @()) -ne 0) { throw 'Missing mute endpoint did not clear its LED.' }
    $script:FixtureEndpoints = @(
        [pscustomobject]@{ID='a'; FriendlyName='Fixture A'; State='Active'; Flow='Render'; AudioEndpointVolume=[pscustomobject]@{MasterVolumeLevelScalar=0.42; Mute=$false}},
        [pscustomobject]@{ID='b'; FriendlyName='Fixture B'; State='Active'; Flow='Render'; AudioEndpointVolume=[pscustomobject]@{MasterVolumeLevelScalar=0.65; Mute=$false}}
    )
    $script:FixtureDefault = $script:FixtureEndpoints[0]
    $script:FixtureEnumerator = [pscustomobject]@{}
    $script:FixtureEnumerator | Add-Member ScriptMethod GetDefaultAudioEndpoint {
        param($flow, $role)
        if ($flow.ToString() -eq 'Render') { return $script:FixtureDefault }
        throw 'No capture endpoint in fixture'
    }
    $script:FixtureEnumerator | Add-Member ScriptMethod EnumerateAudioEndPoints {
        param($flow, $state)
        @($script:FixtureEndpoints | Where-Object Flow -eq $flow.ToString())
    }
    function script:Get-SharedEnumerator { $script:FixtureEnumerator }
    $null = Get-AudioEndpointsSnapshot
    if ((Resolve-AudioEndpoint '@DefaultRender' -UseCache).ID -ne 'a') { throw 'Initial default incorrect.' }
    $null = Resolve-AudioEndpoint 'Future endpoint' -UseCache
    $script:FixtureDefault = $script:FixtureEndpoints[1]
    $snapshot = @(Get-AudioEndpointsSnapshot)
    if ((Resolve-AudioEndpoint '@DefaultRender' -UseCache).ID -ne 'b') { throw 'Default resolver retained stale cached endpoint.' }
    if ($script:NegativeEndpointCache.Count -ne 0) { throw 'Fresh snapshot retained negative lookup cache.' }
    if (($snapshot | Where-Object IsDefault).VolumePct -ne 65) { throw 'Snapshot did not follow default switch.' }
}
Write-Output 'PASS: Snapshot refresh rebinds cached default endpoints and clears stale negative lookups (no audio writes).'
