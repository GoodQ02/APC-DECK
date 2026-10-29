# Screen-only presentation. Never derives device state from a customizable LED color.
function Find-PadEndpoint([string]$Target, [object[]]$Snapshot) {
    if (-not $Target) { return $null }
    $matches = @(foreach ($endpoint in $Snapshot) {
        $matched = if ($Target -eq '@DefaultRender') { $endpoint.IsDefault -and $endpoint.Flow -eq 'Render' }
            elseif ($Target -eq '@DefaultCapture') { $endpoint.IsDefault -and $endpoint.Flow -eq 'Capture' }
            else { $endpoint.ID -ieq $Target -or $endpoint.FriendlyName.IndexOf($Target, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
        if ($matched) { $endpoint }
    })
    $active = $matches | Where-Object State -eq 'Active' | Select-Object -First 1
    if ($active) { return $active }
    return $matches | Select-Object -First 1
}

function Get-PadPresentation($Mapping, [object[]]$AudioSnapshot, [object[]]$BtSnapshot) {
    $title = if ($Mapping -and $Mapping.Label) { [string]$Mapping.Label } else { 'Unassigned' }
    $status = 'Unassigned'; $state = 'Unassigned'; $tone = 'Secondary'; $detail = ''
    if ($Mapping) {
        $action = [string]$Mapping.ActionType
        if ($action -in @('SetDefaultDevice','MuteToggle','EndpointEnableToggle','SwapDevices')) {
            $ep = Find-PadEndpoint $Mapping.Target $AudioSnapshot
            if (-not $ep) { $status = 'Missing'; $state = 'Unavailable'; $tone = 'Warning' }
            elseif ($ep.State -ne 'Active') {
                $state = switch ($ep.State) { 'Disabled' { 'Disabled' } 'Unplugged' { 'Disconnected' } default { 'Unavailable' } }
                $status = if ($state -eq 'Disconnected') { 'Offline' } elseif ($state -eq 'Unavailable') { 'Missing' } else { $state }
                $tone = 'Warning'
            } else {
                switch ($action) {
                    'SetDefaultDevice' {
                        $status = if ($ep.IsDefault) { 'Default' } else { 'Ready' }
                        $state = $status; $tone = if ($ep.IsDefault) { 'Positive' } else { 'Secondary' }
                    }
                    'MuteToggle' {
                        if ($null -eq $ep.VolumePct) { $status = 'Unknown'; $state = 'Volume state unavailable'; $tone = 'Warning' }
                        elseif ($ep.Muted) { $status = 'Muted'; $state = 'Muted'; $tone = 'Muted' }
                        else { $status = 'Live'; $state = 'Unmuted'; $tone = 'Positive' }
                    }
                    'EndpointEnableToggle' { $status = 'Enabled'; $state = 'Enabled'; $tone = 'Positive' }
                    'SwapDevices' {
                        $second = Find-PadEndpoint $Mapping.SecondaryTarget $AudioSnapshot
                        if (-not $second -or $second.State -ne 'Active') { $status = 'Partial'; $state = 'Second device unavailable'; $tone = 'Warning' }
                        elseif ($ep.IsDefault) { $status = 'A active'; $state = 'First device is default'; $tone = 'Positive' }
                        elseif ($second.IsDefault) { $status = 'B active'; $state = 'Second device is default'; $tone = 'Positive' }
                        else { $status = 'Ready'; $state = 'Neither device is default' }
                    }
                }
            }
            if ($ep) { $detail = "$($ep.FriendlyName) · $state" }
        } elseif ($action -eq 'BluetoothConnect') {
            $device = $BtSnapshot | Where-Object { $_.Name -like "*$($Mapping.Target)*" -or $_.DeviceId -eq $Mapping.Target } | Select-Object -First 1
            if ($device -and $device.Status -eq 'Connected') { $status = 'Linked'; $state = 'Audio link detected'; $tone = 'Positive' }
            else { $status = 'Offline'; $state = 'No audio link detected'; $tone = 'Warning' }
        } else {
            $status = switch ($action) {
                'Hotkey' { 'Shortcut' } 'MediaKey' { 'Media' } 'SystemCommand' { 'Open' }
                'BalanceAll' { 'Balance' } 'None' { 'Unassigned' } default { 'Action' }
            }
            $state = $status
        }
    }
    [pscustomobject]@{ Title=$title; Status=$status; State=$state; Tone=$tone; Detail=$detail }
}

function New-PadPalette([bool]$HighContrast = $false) {
    if ($HighContrast) {
        return @{
            Background=[Drawing.SystemColors]::Window; SelectedBackground=[Drawing.SystemColors]::Window
            Primary=[Drawing.SystemColors]::WindowText; Secondary=[Drawing.SystemColors]::WindowText
            Positive=[Drawing.SystemColors]::WindowText; Muted=[Drawing.SystemColors]::WindowText
            Warning=[Drawing.SystemColors]::WindowText; Border=[Drawing.SystemColors]::WindowText
            SelectedBorder=[Drawing.SystemColors]::Highlight
        }
    }
    @{
        Background=[Drawing.Color]::FromArgb(30,34,43); SelectedBackground=[Drawing.Color]::FromArgb(32,45,66)
        Primary=[Drawing.Color]::FromArgb(238,242,246); Secondary=[Drawing.Color]::FromArgb(203,213,225)
        Positive=[Drawing.Color]::FromArgb(167,243,208); Muted=[Drawing.Color]::FromArgb(252,165,165)
        Warning=[Drawing.Color]::FromArgb(253,230,138); Border=[Drawing.Color]::FromArgb(71,85,105)
        SelectedBorder=[Drawing.Color]::FromArgb(56,189,248)
    }
}

function Get-ColorLuminance([Drawing.Color]$Color) {
    $components = foreach ($part in @($Color.R,$Color.G,$Color.B)) {
        $channel = $part / 255.0
        if ($channel -le 0.04045) { $channel / 12.92 } else { [math]::Pow(($channel + 0.055) / 1.055, 2.4) }
    }
    $components[0] * 0.2126 + $components[1] * 0.7152 + $components[2] * 0.0722
}
$script:ReadableInkCache = @{}
function Get-ReadableInk([Drawing.Color]$Background) {
    $key = $Background.ToArgb()
    if (-not $script:ReadableInkCache.ContainsKey($key)) {
        $luma = Get-ColorLuminance $Background
        $script:ReadableInkCache[$key] = if ((1.05 / ($luma + 0.05)) -ge (($luma + 0.05) / 0.05)) { [Drawing.Color]::White } else { [Drawing.Color]::Black }
    }
    $script:ReadableInkCache[$key]
}

function Get-PadLedDescription([int]$Velocity) {
    switch ($Velocity) { 1 {'Green'} 2 {'Blink green'} 3 {'Red'} 4 {'Blink red'} 5 {'Amber'} 6 {'Blink amber'} default {'Off'} }
}
