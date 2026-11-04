param([Parameter(Mandatory)][string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Disposable read-only process owns all its COM objects. Never open MIDI or load/save mappings.
Import-Module (Join-Path $PSScriptRoot 'ApcDeck.psm1') -DisableNameChecking
$names = @{}
foreach ($endpoint in @(Get-AudioEndpointsSnapshot)) { $names[$endpoint.ID] = $endpoint.FriendlyName }
[IO.File]::WriteAllText($OutputPath, (ConvertTo-Json -InputObject $names -Compress))
