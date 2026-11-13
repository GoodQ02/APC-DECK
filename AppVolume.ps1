# Worker lifecycle and plain-data boundary. No session COM objects enter the UI thread.
$script:AppVolumeWorker = $null
function Initialize-AppVolumeRuntime {
    if (-not ('GoodCube.ApcDeck.AppVolumeWorker' -as [type])) {
            $references = @([IO.Directory]::GetFiles((Join-Path $PSHOME 'ref'),'*.dll')) + @(
                [NAudio.CoreAudioApi.MMDevice].Assembly.Location, [NAudio.Wave.WaveFormat].Assembly.Location)
            Add-Type -Path (Join-Path $script:ModuleRoot 'AppVolume.cs') -ReferencedAssemblies $references
    }
}
function Update-AppVolumeSessions {
    if ($script:AppVolumeWorker -and -not $script:AppVolumeWorker.IsRunning) { Stop-AppVolumeSessions }
    if (-not $script:AppVolumeWorker) {
        Initialize-AppVolumeRuntime
        $script:AppVolumeWorker = [GoodCube.ApcDeck.AppVolumeWorker]::new()
    } else { $script:AppVolumeWorker.RequestRefresh() }
}
function Get-AppVolumeSnapshot {
    if ($script:AppVolumeWorker) { return $script:AppVolumeWorker.Read() }
    [pscustomobject]@{Sessions=@(); Ready=$false; Error=''; Revision=0; DiscoveryMs=0; LastCommandMs=0}
}
function Reset-AppVolumePickup { if ($script:AppVolumeWorker) { $script:AppVolumeWorker.ResetPickup() } }
function Stop-AppVolumeSessions {
    if ($script:AppVolumeWorker) { $script:AppVolumeWorker.Dispose(); $script:AppVolumeWorker=$null }
}
function Set-AppSessionVolume {
    param($Mapping, [int]$Percent, [bool]$Pickup=$false, [bool]$Physical=$false, [bool]$AutoMute=$true)
    if (-not $script:AppVolumeWorker) { return "No active audio session for '$($Mapping.Target)'. Refresh devices, then retry." }
    $snapshot=$script:AppVolumeWorker.Read()
    if (-not $snapshot.Ready -or -not @($snapshot.Sessions | Where-Object { $_.Available -and [GoodCube.ApcDeck.AppVolumeWorker]::Matches($_,[string]$Mapping.Target) }).Count) {
        return "No active audio session for '$($Mapping.Target)'. Start audio and refresh, then retry."
    }
    if (-not $script:AppVolumeWorker.Queue([string]$Mapping.ControlId,[string]$Mapping.Target,$Percent,$Pickup,$AutoMute,$Physical)) {
        return 'App volume failed: audio worker is unavailable or busy. Refresh devices, then retry.'
    }
    return "App '$($Mapping.Target)': $(if($Pickup){'pickup turn queued'}else{"$Percent% requested; awaiting readback"})"
}
