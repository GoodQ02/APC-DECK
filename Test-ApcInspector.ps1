param([string]$PreviewDirectory = $env:APC_DECK_PREVIEW_DIRECTORY)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$profilePath = Join-Path $env:LOCALAPPDATA 'GoodCube\ApcMidiDeck\profile.json'
$before = if (Test-Path $profilePath) { (Get-FileHash $profilePath).Hash } else { '' }
$oldPreviewPath = $env:APC_DECK_PREVIEW_DIRECTORY
try {
    $env:APC_DECK_PREVIEW_DIRECTORY = $PreviewDirectory
    $result = & pwsh.exe -NoLogo -NoProfile -STA -File (Join-Path $PSScriptRoot 'Open-ApcDeck.ps1') -SmokeTestUi -OfflinePreview -UiTestScript (Join-Path $PSScriptRoot 'tests\InspectorCases.ps1')
    $resultText = $result -join "`n"
    if ($LASTEXITCODE -ne 0 -or $resultText -match 'UI_TEST_FAILED' -or $resultText -notmatch 'INSPECTOR_TESTS_OK' -or $resultText -notmatch 'LIVE_STATE_TESTS_OK' -or $resultText -notmatch 'KEYBOARD_TESTS_OK') { throw "Inspector regression failed: $resultText" }
    $result | Write-Output
} finally { $env:APC_DECK_PREVIEW_DIRECTORY = $oldPreviewPath }
$after = if (Test-Path $profilePath) { (Get-FileHash $profilePath).Hash } else { '' }
if ($before -cne $after) { throw 'Inspector test changed the real profile.' }
Write-Output 'PASS: Inspector interaction and layout tests; real profile unchanged; audio/MIDI writes isolated.'
