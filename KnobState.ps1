# Snapshot-only UI state. No endpoint discovery or audio writes belong here.
function Get-KnobObservation($Mapping, [object[]]$Snapshot) {
    $key = "$($Mapping.ActionType)|$($Mapping.Target)"
    $ep = $null
    $status = 'Unavailable'
    if ($Mapping.ActionType -eq 'None') { $status = 'Unmapped' }
    elseif ($Mapping.ActionType -eq 'VolumeApp') { return Get-AppKnobObservation $Mapping (Get-AppVolumeSnapshot) }
    else {
        $target = switch ($Mapping.ActionType) {
            'VolumeMasterOut' { '@DefaultRender' }
            'VolumeDefaultMic' { '@DefaultCapture' }
            'VolumeDevice' { [string]$Mapping.Target }
            default { '' }
        }
        $matches = @(foreach ($item in $Snapshot) {
            $match = if ($target -eq '@DefaultRender') { $item.IsDefault -and $item.Flow -eq 'Render' }
                elseif ($target -eq '@DefaultCapture') { $item.IsDefault -and $item.Flow -eq 'Capture' }
                else { $target -and ($item.ID -ieq $target -or $item.FriendlyName.IndexOf($target, [StringComparison]::OrdinalIgnoreCase) -ge 0) }
            if ($match) { $item }
        })
        # Match the audio resolver: prefer the first active endpoint.
        $ep = $matches | Where-Object State -eq 'Active' | Select-Object -First 1
        if (-not $ep) { $ep = $matches | Select-Object -First 1 }
        if ($ep) {
            $status = switch ($ep.State) {
                'Unplugged' { 'Disconnected' }
                'Disabled' { 'Disabled' }
                'Active' { if ($null -eq $ep.VolumePct) { 'Unavailable' } elseif ($ep.Muted) { 'Muted' } else { 'Ready' } }
                default { 'Unavailable' }
            }
        }
    }
    [pscustomobject]@{
        Key = $key; EndpointId = $(if ($ep) { $ep.ID } else { '' })
        Known = $status -in @('Ready', 'Muted'); Status = $status
        VolumePct = $(if ($ep) { $ep.VolumePct } else { $null })
        Muted = $(if ($ep) { [bool]$ep.Muted } else { $false }); Pending = $false
    }
}

function Get-AppKnobObservation($Mapping, $Snapshot) {
    $target=([string]$Mapping.Target).Trim()
    $process=$target -replace '\.exe$',''
    $sessions=@($Snapshot.Sessions | Where-Object {
        $target -and ($_.Name -ieq $process -or ($_.Display -and $_.Display.IndexOf($target,[StringComparison]::OrdinalIgnoreCase) -ge 0))
    })
    $available=@($sessions | Where-Object Available)
    $known=$Snapshot.Ready -and $available.Count -gt 0 -and $available.Count -eq $sessions.Count
    $levels=@($available | ForEach-Object Percent | Sort-Object -Unique)
    $muted=@($available | Where-Object Muted).Count
    $gateKey="$($Mapping.ControlId)|$($target.ToLowerInvariant())"
    $caught=@($available | Where-Object { $_.Acquired -contains $gateKey }).Count
    $status=if(-not $Snapshot.Ready){if($Snapshot.Error){'Unavailable'}else{'Loading'}}
        elseif(-not $sessions.Count){'No session'}elseif(-not $known){'Unavailable'}
        elseif($muted -eq $sessions.Count){'Muted'}elseif($muted){'Part muted'}elseif($levels.Count -gt 1){'Mixed levels'}else{'Ready'}
    $range=if($levels.Count -gt 1){"$($levels[0])–$($levels[-1])%"}elseif($levels.Count){"$($levels[0])%"}else{'—'}
    [pscustomobject]@{
        Key="VolumeApp|$target"; EndpointId=(($sessions | ForEach-Object Id) -join '|'); Known=$known; Status=$status
        VolumePct=$(if($known){$levels[-1]}else{$null}); Muted=($known -and $muted -eq $sessions.Count); Pending=$false
        IsApp=$true; ValueText=$range; SessionCount=$sessions.Count; Caught=$caught
        Sessions=$available; GateKey=$gateKey
        Detail="App sessions: $($sessions.Count); levels $range; muted $muted; caught $caught/$($sessions.Count). $($Snapshot.Error)"
        Signature=(($sessions | ForEach-Object { "$($_.Id):$($_.Percent):$($_.Muted):$($_.Available):$($_.Acquired -join ',')" }) -join '|')
    }
}

function Get-KnobValueText([string]$cid) {
    $state=$script:KnobStates[$cid]
    if(-not $state -or -not $state.Known){return '—'}
    if($state.PSObject.Properties['IsApp']){return $state.ValueText}
    return "$($script:KnobValues[$cid])%"
}

function Get-KnobValueFont($Graphics, [int]$Width, [int]$Height, [string]$Text) {
    $font=Get-SurfaceFont $Graphics 'FKnobValue' $Width $Height $Text
    # Ranges have more digits than a single value. Reuse the smaller cached font family.
    if ($Graphics.MeasureString($Text,$font).Width -gt $Width) {
        $font=Get-SurfaceFont $Graphics 'FKnobFeedback' $Width $Height $Text
    }
    return $font
}

function Format-KnobFeedbackForWidth([string]$Feedback,[int]$Width) {
    if ($Width -ge 85) { return $Feedback }
    switch ($Feedback) {
        'Awaiting turn' { return 'Waiting' }
        'Disconnected' { return 'Offline' }
        'No session' { return 'Start audio' }
        'Updating...' { return 'Updating' }
        default { return ($Feedback -replace ' to \d+% · ',' ' -replace ' to ',' ') }
    }
}

function Sync-KnobObservations([switch]$AppsOnly) {
    foreach ($cc in 48..55) {
        $cid = "Knob_$cc"
        if (-not $script:ProfileMap.ContainsKey($cid)) { continue }
        if ($AppsOnly -and $script:ProfileMap[$cid].ActionType -ne 'VolumeApp') { continue }
        $next = Get-KnobObservation $script:ProfileMap[$cid] $script:AudioSnapshot
        $old = $script:KnobStates[$cid]
        $changed = -not $old -or $old.Key -cne $next.Key -or $old.EndpointId -ne $next.EndpointId -or
            $old.Known -ne $next.Known -or $old.Status -ne $next.Status -or $old.Muted -ne $next.Muted -or
            $old.Pending -or ($next.Known -and $script:KnobValues[$cid] -ne $next.VolumePct)
        if ($next.PSObject.Properties['IsApp']) {
            $changed = $changed -or -not $old -or -not $old.PSObject.Properties['Signature'] -or $old.Signature -cne $next.Signature
        }
        # An observed change that does not match our last command re-arms pickup.
        $external = -not $old -or $old.Key -cne $next.Key -or $old.EndpointId -ne $next.EndpointId -or
            $old.Known -ne $next.Known -or $old.Muted -ne $next.Muted -or
            ($next.Known -and $script:KnobValues[$cid] -ne $next.VolumePct)
        if ($external) { $script:KnobPickedUp[$cid] = $false }
        if ($next.Known) { $script:KnobValues[$cid] = [int]$next.VolumePct }
        $script:KnobStates[$cid] = $next
        if ($changed) { $cid }
    }
}

function Set-KnobCommand([string]$cid, [int]$pct) {
    $state = $script:KnobStates[$cid]
    if ($state -and $state.PSObject.Properties['IsApp']) { return }
    $script:KnobValues[$cid] = $pct
    if ($state -and $state.Known) {
        $state.Pending = $true
        $state.Muted = ($pct -eq 0)
        $state.Status = if ($pct -eq 0) { 'Muted' } else { 'Ready' }
    }
}

function Get-KnobFeedback([string]$cid, [bool]$Pickup, [bool]$EditOnly) {
    $state = $script:KnobStates[$cid]
    if (-not $state) { return 'Unavailable' }
    if (-not $state.Known) { return $state.Status }
    if ($state.PSObject.Properties['IsApp']) {
        if ($EditOnly) { return 'Edit mode' }
        if (-not $Pickup) { return $state.Status }
        if ($state.Caught -eq $state.SessionCount) { return "In sync · $($state.SessionCount)" }
        $phys=$script:KnobLastPhys[$cid]
        if ($phys -lt 0) { return 'Awaiting turn' }
        $waiting=@($state.Sessions | Where-Object { $_.Acquired -notcontains $state.GateKey } | Sort-Object { [math]::Abs($_.Percent-$phys) })
        $next=$waiting[0].Percent
        $direction=if($phys -lt $next){'CW'}else{'CCW'}
        return "$direction to $next% · $($state.Caught)/$($state.SessionCount)"
    }
    if ($state.Pending) { return 'Updating...' }
    if ($EditOnly) { return 'Edit mode' }
    if ($Pickup -and -not $script:KnobPickedUp[$cid]) {
        $phys = $script:KnobLastPhys[$cid]
        $pct = $script:KnobValues[$cid]
        if ($phys -lt 0) { return 'Awaiting turn' }
        if ($phys -lt $pct) { return "CW to $pct%" }
        return "CCW to $pct%"
    }
    if ($state.Muted) { return 'Muted' }
    if ($Pickup) { return 'In sync' }
    return 'Direct'
}
