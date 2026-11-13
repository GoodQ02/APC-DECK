Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ApcDeck.psm1') -Force -DisableNameChecking
$references=@([IO.Directory]::GetFiles((Join-Path $PSHOME 'ref'),'*.dll'))+@(
    [NAudio.CoreAudioApi.MMDevice].Assembly.Location,[NAudio.Wave.WaveFormat].Assembly.Location)
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'AppVolume.cs'))+[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'tests\AppVolumeFixture.cs'))
Add-Type -TypeDefinition $source -ReferencedAssemblies $references
[GoodCube.ApcDeck.Tests.AppVolumeFixture]::Run()
