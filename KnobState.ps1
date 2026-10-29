# Snapshot-only UI state. No endpoint discovery or audio writes belong here.
function Get-KnobObservation($Mapping, [object[]]$Snapshot) {
    $key = "$($Mapping.ActionType)|$($Mapping.Target)"
    $ep = $null
    $status = 'Unavailable'
    if ($Mapping.ActionType -eq 'None') { $status = 'Unmapped' }
    elseif ($Mapping.ActionType -eq 'VolumeApp') { $status = 'No readback' }
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

function Sync-KnobObservations {
    foreach ($cc in 48..55) {
        $cid = "Knob_$cc"
        if (-not $script:ProfileMap.ContainsKey($cid)) { continue }
        $next = Get-KnobObservation $script:ProfileMap[$cid] $script:AudioSnapshot
        $old = $script:KnobStates[$cid]
        $changed = -not $old -or $old.Key -cne $next.Key -or $old.EndpointId -ne $next.EndpointId -or
            $old.Known -ne $next.Known -or $old.Status -ne $next.Status -or $old.Muted -ne $next.Muted -or
            $old.Pending -or ($next.Known -and $script:KnobValues[$cid] -ne $next.VolumePct)
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
    $script:KnobValues[$cid] = $pct
    $state = $script:KnobStates[$cid]
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
