[CmdletBinding()]
param(
    [ValidateSet('Panel','Headless','Snapshot','ResetDefaults','Stop')][string]$Mode = 'Panel',
    [switch]$Minimized,
    [switch]$SmokeTestUi
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ApcDeck.psm1') -Force -DisableNameChecking

$showEventName = 'Local\GoodCube.ApcMidiDeck.ShowEvent'
$stopEventName = 'Local\GoodCube.ApcMidiDeck.StopEvent'
$mutexName     = 'Local\GoodCube.ApcMidiDeck.Instance'

if ($Mode -eq 'Stop') {
    try {
        $ev = [Threading.EventWaitHandle]::OpenExisting($stopEventName)
        [void]$ev.Set()
        $ev.Dispose()
        Write-Output 'Signaled running APC-DECK instance to stop.'
    } catch {
        Write-Output 'No running APC-DECK instance found.'
    }
    exit 0
}

if ($Mode -eq 'ResetDefaults') {
    $map = @{}
    foreach ($c in (New-DefaultApcProfile)) { $map[$c.ControlId] = $c }
    $path = Save-ApcProfile -ProfileMap $map
    Write-Output "Reset profile to defaults: $path"
    exit 0
}

if ($Mode -eq 'Snapshot') {
    $prof = Load-ApcProfile
    $audio = Get-AudioEndpointsSnapshot
    $bt = Get-PairedBluetoothDevices
    [pscustomobject]@{
        MidiInIndex  = [GoodCube.ApcDeck.NativeBridge]::FindMidiInIndex('APC Key 25')
        MidiOutIndex = [GoodCube.ApcDeck.NativeBridge]::FindMidiOutIndex('APC Key 25')
        ControlCount = $prof.Count
        AudioDevices = $audio
        Bluetooth    = $bt
    } | ConvertTo-Json -Depth 5
    exit 0
}

# Ensure interactive GUI always opens on the user's real desktop (WinSta0\Default),
# never on an isolated background/sandbox desktop (such as exebox-*).
$curDesktop = [GoodCube.ApcDeck.NativeBridge]::GetCurrentDesktopName()
if ($curDesktop -and $curDesktop -ne 'Default' -and -not $SmokeTestUi) {
    $cmdLine = "`"C:\Program Files\PowerShell\7\pwsh.exe`" -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Minimized) { $cmdLine += ' -Minimized' }
    [void][GoodCube.ApcDeck.NativeBridge]::LaunchOnDefaultDesktop($cmdLine, $PSScriptRoot)
    exit 0
}

# Single-instance check: if APC-DECK is already running, signal it to pop its window to the front.
# If the existing instance is unresponsive or windowless, automatically self-heal and replace it.
$windowTitle = 'GOOD-CUBE | Akai APC Key 25 Stream Deck Controller & Mapper'
$instanceMutex = [Threading.Mutex]::new($false, $mutexName)
$ownsMutex = $false
try {
    $ownsMutex = $instanceMutex.WaitOne(0)
} catch [Threading.AbandonedMutexException] {
    $ownsMutex = $true
}
if (-not $ownsMutex) {
    try {
        $existingShow = [Threading.EventWaitHandle]::OpenExisting($showEventName)
        [void]$existingShow.Set()
        $existingShow.Dispose()
    } catch { }

    $restoredExisting = $false
    for ($i = 0; $i -lt 45; $i++) {
        Start-Sleep -Milliseconds 100
        $existingHwnd = [GoodCube.ApcDeck.NativeBridge]::FindWindowByTitle($windowTitle)
        if ($existingHwnd -ne [IntPtr]::Zero) {
            [GoodCube.ApcDeck.NativeBridge]::BringFormToFront($existingHwnd)
            if ([GoodCube.ApcDeck.NativeBridge]::IsWindowVisible($existingHwnd)) {
                $restoredExisting = $true
                break
            }
        }
    }

    if ($restoredExisting) {
        $instanceMutex.Dispose()
        exit 0
    }

    # Stale/windowless instance detected: terminate it and claim the mutex for a fresh window
    Get-CimInstance Win32_Process | Where-Object {
        $_.ProcessId -ne $PID -and $_.CommandLine -match 'Open-ApcDeck\.ps1'
    } | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 150
    try {
        $ownsMutex = $instanceMutex.WaitOne(1000)
    } catch [Threading.AbandonedMutexException] {
        $ownsMutex = $true
    }
}

$showEvent = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::AutoReset, $showEventName)
$stopEvent = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::AutoReset, $stopEventName)

# Hide the PowerShell console window so only the native WinForms GUI is shown
[GoodCube.ApcDeck.NativeBridge]::HideConsoleWindow()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$script:ProfileMap    = Load-ApcProfile
$script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
$script:BtSnapshot    = @(Get-PairedBluetoothDevices -AudioSnapshot $script:AudioSnapshot)
$script:SelectedId    = 'Pad_32'
$script:ControlButtons= @{}
$script:KnobValues    = @{}
$script:KnobPickedUp  = @{}
$script:KnobLastPhys  = @{}

# Initialize knob percentages from current audio device levels
foreach ($cc in 48..55) {
    $cid = "Knob_$cc"
    $script:KnobValues[$cid]   = 75
    $script:KnobPickedUp[$cid] = $false
    $script:KnobLastPhys[$cid] = -1
    if ($script:ProfileMap.ContainsKey($cid)) {
        $curPct = Get-CurrentMappingVolumePct -Mapping $script:ProfileMap[$cid]
        if ($null -ne $curPct) {
            $script:KnobValues[$cid] = [int]$curPct
        }
    }
}

$openMsg = [GoodCube.ApcDeck.NativeBridge]::OpenDevice('APC Key 25')
if ($openMsg -eq 'OK') {
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
}

# Color palette
$cBgDark      = [Drawing.Color]::FromArgb(18, 22, 29)
$cPanelBg     = [Drawing.Color]::FromArgb(26, 32, 42)
$cCardBg      = [Drawing.Color]::FromArgb(35, 43, 56)
$cKnobBg      = [Drawing.Color]::FromArgb(30, 41, 59)
$cKnobZeroBg  = [Drawing.Color]::FromArgb(69, 10, 10)
$cGreenFill   = [Drawing.Color]::FromArgb(22, 101, 52)
$cGreenBlink  = [Drawing.Color]::FromArgb(5, 150, 105)
$cRedFill     = [Drawing.Color]::FromArgb(127, 29, 29)
$cRedBlink    = [Drawing.Color]::FromArgb(185, 28, 28)
$cAmberFill   = [Drawing.Color]::FromArgb(120, 53, 15)
$cAmberBlink  = [Drawing.Color]::FromArgb(180, 83, 9)
$cUnmapped    = [Drawing.Color]::FromArgb(30, 36, 46)
$cKeyWhite    = [Drawing.Color]::FromArgb(226, 232, 240)
$cKeyBlack    = [Drawing.Color]::FromArgb(15, 23, 42)
$cKeyMapped   = [Drawing.Color]::FromArgb(14, 116, 144)
$cCyanBorder  = [Drawing.Color]::FromArgb(0, 240, 255)

$form = [Windows.Forms.Form]::new()
$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
$form.Text = 'GOOD-CUBE | Akai APC Key 25 Stream Deck Controller & Mapper'
$primWa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$initW  = [Math]::Min(1660, [Math]::Max(1240, $primWa.Width - 80))
$initH  = [Math]::Min(960,  [Math]::Max(760,  $primWa.Height - 60))
$initX  = $primWa.X + [int](($primWa.Width - $initW) / 2)
$initY  = $primWa.Y + [int](($primWa.Height - $initH) / 2)
$form.StartPosition = [Windows.Forms.FormStartPosition]::Manual
$form.Bounds = [Drawing.Rectangle]::new($initX, $initY, $initW, $initH)
$form.MinimumSize = [Drawing.Size]::new(1180, 740)
$form.Font = [Drawing.Font]::new('Segoe UI', 9.0)
$form.BackColor = $cBgDark
$form.ForeColor = [Drawing.Color]::Gainsboro

$icoPath = Join-Path $PSScriptRoot 'assets\apc-deck.ico'
if (Test-Path -LiteralPath $icoPath) {
    try { $form.Icon = [Drawing.Icon]::new($icoPath) } catch { }
}

# System Tray Icon for background operation
$trayIcon = [Windows.Forms.NotifyIcon]::new()
$trayIcon.Text = 'GOOD-CUBE APC Key 25 Audio Deck'
$trayIcon.Icon = if ($form.Icon) { $form.Icon } else { [Drawing.SystemIcons]::Application }
$trayIcon.Visible = $true
$trayMenu = [Windows.Forms.ContextMenuStrip]::new()
$miShow = $trayMenu.Items.Add('Open APC-DECK Window')
$miSync = $trayMenu.Items.Add('Refresh Audio & Sync Pad LEDs')
$miBalance = $trayMenu.Items.Add('Balance All Audio (95% Mics)')
[void]$trayMenu.Items.Add('-')
$miExit = $trayMenu.Items.Add('Exit APC-DECK Controller')
$trayIcon.ContextMenuStrip = $trayMenu

# Top Root Layout: Header (58px), Main Body (Fill), Status Bar (54px)
$rootLayout = [Windows.Forms.TableLayoutPanel]::new()
$rootLayout.Dock = 'Fill'
$rootLayout.ColumnCount = 1
$rootLayout.RowCount = 3
[void]$rootLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Absolute, 58))
[void]$rootLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 100))
[void]$rootLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Absolute, 54))
$form.Controls.Add($rootLayout)

# Header Bar
$headerPanel = [Windows.Forms.Panel]::new()
$headerPanel.Dock = 'Fill'
$headerPanel.BackColor = $cPanelBg
$headerPanel.Padding = [Windows.Forms.Padding]::new(14, 8, 14, 6)
$rootLayout.Controls.Add($headerPanel, 0, 0)

$lblTitle = [Windows.Forms.Label]::new()
$lblTitle.Text = 'AKAI APC KEY 25  |  STREAM DECK AUDIO, BLUETOOTH & HOTKEY CONTROLLER'
$lblTitle.Font = [Drawing.Font]::new('Segoe UI Semibold', 12, [Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [Drawing.Color]::White
$lblTitle.AutoSize = $true
$lblTitle.Location = [Drawing.Point]::new(14, 7)
$headerPanel.Controls.Add($lblTitle)

$lblSubTitle = [Windows.Forms.Label]::new()
$lblSubTitle.Text = 'Touch any physical knob, pad, or piano key on the APC Key 25 (or click below) to map it. Knobs snap cleanly to 0% (zeroed/muted) and 100%.'
$lblSubTitle.Font = [Drawing.Font]::new('Segoe UI', 9)
$lblSubTitle.ForeColor = [Drawing.Color]::FromArgb(148, 163, 184)
$lblSubTitle.AutoSize = $true
$lblSubTitle.Location = [Drawing.Point]::new(15, 32)
$headerPanel.Controls.Add($lblSubTitle)

# Main Split: Left = Hardware Surface (72%), Right = Stream Deck Property Inspector (28%)
$mainSplit = [Windows.Forms.TableLayoutPanel]::new()
$mainSplit.Dock = 'Fill'
$mainSplit.ColumnCount = 2
$mainSplit.RowCount = 1
[void]$mainSplit.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 71))
[void]$mainSplit.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 29))
$rootLayout.Controls.Add($mainSplit, 0, 1)

# Left Hardware Surface Container
$hwLayout = [Windows.Forms.TableLayoutPanel]::new()
$hwLayout.Dock = 'Fill'
$hwLayout.Padding = [Windows.Forms.Padding]::new(8, 6, 6, 6)
$hwLayout.ColumnCount = 1
$hwLayout.RowCount = 3
[void]$hwLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Absolute, 114)) # 8 Knobs
[void]$hwLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 100))  # 5x8 Pads + Scene + Track
[void]$hwLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Absolute, 130)) # 25 Piano Keys
$mainSplit.Controls.Add($hwLayout, 0, 0)

# --- 1. 8 ROTARY KNOBS PANEL (CC 48..55) ---
$knobsGroup = [Windows.Forms.GroupBox]::new()
$knobsGroup.Text = '8 Assignable Rotary Knobs (K1 – K8  |  MIDI Ch 1 CC 48–55  |  60Hz Zero-Out & Auto-Unmute)'
$knobsGroup.Dock = 'Fill'
$knobsGroup.ForeColor = [Drawing.Color]::FromArgb(56, 189, 248)
$hwLayout.Controls.Add($knobsGroup, 0, 0)

$knobsGrid = [Windows.Forms.TableLayoutPanel]::new()
$knobsGrid.Dock = 'Fill'
$knobsGrid.ColumnCount = 8
$knobsGrid.RowCount = 1
for ($i = 0; $i -lt 8; $i++) {
    [void]$knobsGrid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 12.5))
}
$knobsGroup.Controls.Add($knobsGrid)

for ($i = 0; $i -lt 8; $i++) {
    $cc = 48 + $i
    $cid = "Knob_$cc"
    $btn = [Windows.Forms.Button]::new()
    $btn.Dock = 'Fill'
    $btn.Margin = [Windows.Forms.Padding]::new(4, 4, 4, 4)
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 2
    $btn.BackColor = $cKnobBg
    $btn.ForeColor = [Drawing.Color]::White
    $btn.Font = [Drawing.Font]::new('Segoe UI Semibold', 8.5, [Drawing.FontStyle]::Bold)
    $btn.Tag = $cid
    $script:ControlButtons[$cid] = $btn
    $knobsGrid.Controls.Add($btn, $i, 0)
}

# --- 2. 5x8 CLIP LAUNCH PADS + 5 SCENE BUTTONS + 8 TRACK BUTTONS ---
$padsGroup = [Windows.Forms.GroupBox]::new()
$padsGroup.Text = '40 RGB Clip Launch Pads (5x8) + 8 Track/Mode Buttons + 6 Scene Buttons (MIDI Ch 1)'
$padsGroup.Dock = 'Fill'
$padsGroup.ForeColor = [Drawing.Color]::FromArgb(74, 222, 128)
$hwLayout.Controls.Add($padsGroup, 0, 1)

$padsGrid = [Windows.Forms.TableLayoutPanel]::new()
$padsGrid.Dock = 'Fill'
$padsGrid.ColumnCount = 9
$padsGrid.RowCount = 6
for ($c = 0; $c -lt 9; $c++) {
    [void]$padsGrid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 11.11))
}
for ($r = 0; $r -lt 6; $r++) {
    [void]$padsGrid.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 16.66))
}
$padsGroup.Controls.Add($padsGrid)

# Rows 0..4 (top to bottom) correspond to APC Key 25 Note rows 32..39 down to 0..7
$sceneNotes = @(82, 83, 84, 85, 86)
for ($r = 0; $r -lt 5; $r++) {
    $baseNote = (4 - $r) * 8
    for ($c = 0; $c -lt 8; $c++) {
        $note = $baseNote + $c
        $cid = "Pad_$note"
        $btn = [Windows.Forms.Button]::new()
        $btn.Dock = 'Fill'
        $btn.Margin = [Windows.Forms.Padding]::new(3)
        $btn.FlatStyle = 'Flat'
        $btn.FlatAppearance.BorderSize = 2
        $btn.Font = [Drawing.Font]::new('Segoe UI Semibold', 8.2, [Drawing.FontStyle]::Bold)
        $btn.Tag = $cid
        $script:ControlButtons[$cid] = $btn
        $padsGrid.Controls.Add($btn, $c, $r)
    }
    # Column 8: Round Scene button (Notes 82..86)
    $sNote = $sceneNotes[$r]
    $sId = "Scene_$sNote"
    $sBtn = [Windows.Forms.Button]::new()
    $sBtn.Dock = 'Fill'
    $sBtn.Margin = [Windows.Forms.Padding]::new(6, 4, 4, 4)
    $sBtn.FlatStyle = 'Flat'
    $sBtn.FlatAppearance.BorderSize = 2
    $sBtn.Font = [Drawing.Font]::new('Segoe UI Semibold', 8.0, [Drawing.FontStyle]::Bold)
    $sBtn.Tag = $sId
    $script:ControlButtons[$sId] = $sBtn
    $padsGrid.Controls.Add($sBtn, 8, $r)
}

# Row 5: 8 Track/Knob-Mode Buttons (Notes 64..71) + Stop All Clips (Note 81)
for ($c = 0; $c -lt 8; $c++) {
    $tNote = 64 + $c
    $tId = "Track_$tNote"
    $tBtn = [Windows.Forms.Button]::new()
    $tBtn.Dock = 'Fill'
    $tBtn.Margin = [Windows.Forms.Padding]::new(3, 6, 3, 3)
    $tBtn.FlatStyle = 'Flat'
    $tBtn.FlatAppearance.BorderSize = 2
    $tBtn.Font = [Drawing.Font]::new('Segoe UI Semibold', 7.8, [Drawing.FontStyle]::Bold)
    $tBtn.Tag = $tId
    $script:ControlButtons[$tId] = $tBtn
    $padsGrid.Controls.Add($tBtn, $c, 5)
}
$stopBtn = [Windows.Forms.Button]::new()
$stopBtn.Dock = 'Fill'
$stopBtn.Margin = [Windows.Forms.Padding]::new(6, 6, 4, 3)
$stopBtn.FlatStyle = 'Flat'
$stopBtn.FlatAppearance.BorderSize = 2
$stopBtn.Font = [Drawing.Font]::new('Segoe UI Semibold', 7.8, [Drawing.FontStyle]::Bold)
$stopBtn.Tag = 'Scene_81'
$script:ControlButtons['Scene_81'] = $stopBtn
$padsGrid.Controls.Add($stopBtn, 8, 5)

# --- 3. 25 MINI PIANO KEYS (Channel 2, Notes 48..72 -> C3..C5) ---
$keysGroup = [Windows.Forms.GroupBox]::new()
$keysGroup.Text = '25 Synth-Action Piano Keys (C3 – C5  |  MIDI Ch 2 Notes 48–72  |  Click or Press Any Key to Map & Color)'
$keysGroup.Dock = 'Fill'
$keysGroup.ForeColor = [Drawing.Color]::FromArgb(251, 191, 36)
$hwLayout.Controls.Add($keysGroup, 0, 2)

$keysGrid = [Windows.Forms.TableLayoutPanel]::new()
$keysGrid.Dock = 'Fill'
$keysGrid.ColumnCount = 25
$keysGrid.RowCount = 1
for ($k = 0; $k -lt 25; $k++) {
    [void]$keysGrid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 4.0))
}
$keysGroup.Controls.Add($keysGrid)

for ($k = 0; $k -lt 25; $k++) {
    $note = 48 + $k
    $kId = "Key_$note"
    $kBtn = [Windows.Forms.Button]::new()
    $kBtn.Dock = 'Fill'
    $isSharp = (($note % 12) -in @(1, 3, 6, 8, 10))
    $kBtn.Margin = if ($isSharp) { [Windows.Forms.Padding]::new(1, 2, 1, 26) } else { [Windows.Forms.Padding]::new(1, 14, 1, 2) }
    $kBtn.FlatStyle = 'Flat'
    $kBtn.FlatAppearance.BorderSize = 2
    $kBtn.Font = [Drawing.Font]::new('Segoe UI', 7.2, [Drawing.FontStyle]::Bold)
    $kBtn.Tag = $kId
    $script:ControlButtons[$kId] = $kBtn
    $keysGrid.Controls.Add($kBtn, $k, 0)
}

# --- RIGHT PANEL: STREAM DECK PROPERTY INSPECTOR ---
$inspectorGroup = [Windows.Forms.GroupBox]::new()
$inspectorGroup.Text = 'Stream Deck Inspector, Color Customizer & Knob Calibration'
$inspectorGroup.Dock = 'Fill'
$inspectorGroup.Padding = [Windows.Forms.Padding]::new(10, 8, 10, 8)
$inspectorGroup.ForeColor = [Drawing.Color]::White
$mainSplit.Controls.Add($inspectorGroup, 1, 0)

$inspFlow = [Windows.Forms.FlowLayoutPanel]::new()
$inspFlow.Dock = 'Fill'
$inspFlow.FlowDirection = 'TopDown'
$inspFlow.WrapContents = $false
$inspFlow.AutoScroll = $true
$inspectorGroup.Controls.Add($inspFlow)

function Add-InspectorLabel([string]$text, [bool]$bold = $false) {
    $l = [Windows.Forms.Label]::new()
    $l.Text = $text
    $l.AutoSize = $true
    $l.Margin = [Windows.Forms.Padding]::new(2, 6, 2, 1)
    $l.Font = if ($bold) { [Drawing.Font]::new('Segoe UI Semibold', 10.2, [Drawing.FontStyle]::Bold) } else { [Drawing.Font]::new('Segoe UI', 8.8) }
    $l.ForeColor = if ($bold) { [Drawing.Color]::FromArgb(56, 189, 248) } else { [Drawing.Color]::Gainsboro }
    [void]$inspFlow.Controls.Add($l)
    return $l
}

$lblSelectedHeader = Add-InspectorLabel 'Selected: Pad_32' $true
$lblSelectedMeta   = Add-InspectorLabel 'Type: Pad  |  MIDI Ch 1  |  Note/CC: 32' $false

$chkMidiLearn = [Windows.Forms.CheckBox]::new()
$chkMidiLearn.Text = 'Auto-Select on Physical Touch (MIDI Learn)'
$chkMidiLearn.Checked = $true
$chkMidiLearn.AutoSize = $true
$chkMidiLearn.ForeColor = [Drawing.Color]::FromArgb(74, 222, 128)
$chkMidiLearn.Margin = [Windows.Forms.Padding]::new(2, 4, 2, 1)
[void]$inspFlow.Controls.Add($chkMidiLearn)

$chkEditOnly = [Windows.Forms.CheckBox]::new()
$chkEditOnly.Text = 'Edit-Only Mode (Mute actions while mapping)'
$chkEditOnly.Checked = $false
$chkEditOnly.AutoSize = $true
$chkEditOnly.ForeColor = [Drawing.Color]::FromArgb(251, 191, 36)
$chkEditOnly.Margin = [Windows.Forms.Padding]::new(2, 1, 2, 2)
[void]$inspFlow.Controls.Add($chkEditOnly)

$chkPickupMode = [Windows.Forms.CheckBox]::new()
$chkPickupMode.Text = 'Knob Soft-Takeover (Pickup mode — prevent volume jumps)'
$chkPickupMode.Checked = $false
$chkPickupMode.AutoSize = $true
$chkPickupMode.ForeColor = [Drawing.Color]::FromArgb(125, 211, 252)
$chkPickupMode.Margin = [Windows.Forms.Padding]::new(2, 1, 2, 4)
[void]$inspFlow.Controls.Add($chkPickupMode)

[void](Add-InspectorLabel 'Button / Knob Label:')
$txtLabel = [Windows.Forms.TextBox]::new()
$txtLabel.Width = 360
$txtLabel.BackColor = $cCardBg
$txtLabel.ForeColor = [Drawing.Color]::White
$txtLabel.BorderStyle = 'FixedSingle'
[void]$inspFlow.Controls.Add($txtLabel)

[void](Add-InspectorLabel 'Action Type:')
$cmbAction = [Windows.Forms.ComboBox]::new()
$cmbAction.Width = 360
$cmbAction.DropDownStyle = 'DropDownList'
$cmbAction.BackColor = $cCardBg
$cmbAction.ForeColor = [Drawing.Color]::White
[void]$cmbAction.Items.AddRange(@(
    'None',
    'VolumeMasterOut',
    'VolumeDefaultMic',
    'VolumeDevice',
    'VolumeApp',
    'SetDefaultDevice',
    'SwapDevices',
    'MuteToggle',
    'EndpointEnableToggle',
    'BalanceAll',
    'BluetoothConnect',
    'Hotkey',
    'MediaKey',
    'SystemCommand'
))
[void]$inspFlow.Controls.Add($cmbAction)

$lblTarget1 = Add-InspectorLabel 'Primary Target (Device / Hotkey / Command):'
$cmbTarget1 = [Windows.Forms.ComboBox]::new()
$cmbTarget1.Width = 360
$cmbTarget1.DropDownStyle = 'DropDown'
$cmbTarget1.BackColor = $cCardBg
$cmbTarget1.ForeColor = [Drawing.Color]::White
[void]$inspFlow.Controls.Add($cmbTarget1)

$lblTarget2 = Add-InspectorLabel 'Secondary Target (Device B for Swap A <-> B):'
$cmbTarget2 = [Windows.Forms.ComboBox]::new()
$cmbTarget2.Width = 360
$cmbTarget2.DropDownStyle = 'DropDown'
$cmbTarget2.BackColor = $cCardBg
$cmbTarget2.ForeColor = [Drawing.Color]::White
[void]$inspFlow.Controls.Add($cmbTarget2)

[void](Add-InspectorLabel 'Active / ON LED & Key Color:')
$cmbLed = [Windows.Forms.ComboBox]::new()
$cmbLed.Width = 360
$cmbLed.DropDownStyle = 'DropDownList'
$cmbLed.BackColor = $cCardBg
$cmbLed.ForeColor = [Drawing.Color]::White
[void]$cmbLed.Items.AddRange(@('Auto', 'Green', 'BlinkGreen', 'Amber', 'BlinkAmber', 'Red', 'BlinkRed', 'Off'))
[void]$inspFlow.Controls.Add($cmbLed)

[void](Add-InspectorLabel 'Standby / Muted / OFF Pad LED Color:')
$cmbOffLed = [Windows.Forms.ComboBox]::new()
$cmbOffLed.Width = 360
$cmbOffLed.DropDownStyle = 'DropDownList'
$cmbOffLed.BackColor = $cCardBg
$cmbOffLed.ForeColor = [Drawing.Color]::White
[void]$cmbOffLed.Items.AddRange(@('Auto', 'Amber', 'Red', 'Green', 'BlinkAmber', 'BlinkRed', 'BlinkGreen', 'Off'))
[void]$inspFlow.Controls.Add($cmbOffLed)

# 1-Click Color Swatch Bar for Instant Pad/Key Coloring
[void](Add-InspectorLabel '1-Click Instant Pad/Key Color Swatches:')
$swatchPanel = [Windows.Forms.FlowLayoutPanel]::new()
$swatchPanel.Width = 365
$swatchPanel.Height = 34
$swatchPanel.Margin = [Windows.Forms.Padding]::new(0, 2, 0, 4)
[void]$inspFlow.Controls.Add($swatchPanel)

$swatchDefs = @(
    @{ Name='Green';      Label='Green';   Bg=$cGreenFill },
    @{ Name='Amber';      Label='Amber';   Bg=$cAmberFill },
    @{ Name='Red';        Label='Red';     Bg=$cRedFill },
    @{ Name='BlinkGreen'; Label='Blink G'; Bg=$cGreenBlink },
    @{ Name='BlinkAmber'; Label='Blink A'; Bg=$cAmberBlink },
    @{ Name='BlinkRed';   Label='Blink R'; Bg=$cRedBlink },
    @{ Name='Off';        Label='LED Off'; Bg=$cUnmapped }
)
foreach ($sw in $swatchDefs) {
    $sb = [Windows.Forms.Button]::new()
    $sb.Text = $sw.Label
    $sb.Tag  = $sw.Name
    $sb.Width = 48
    $sb.Height = 28
    $sb.Margin = [Windows.Forms.Padding]::new(2, 1, 2, 1)
    $sb.FlatStyle = 'Flat'
    $sb.BackColor = $sw.Bg
    $sb.ForeColor = [Drawing.Color]::White
    $sb.Font = [Drawing.Font]::new('Segoe UI', 7.2, [Drawing.FontStyle]::Bold)
    $sb.Add_Click({
        $chosenColor = [string]$this.Tag
        $cmbLed.SelectedItem = $chosenColor
        $cid = $script:SelectedId
        if ($script:ProfileMap.ContainsKey($cid)) {
            $m = $script:ProfileMap[$cid]
            $m.LedColor = $chosenColor
            $null = Save-ApcProfile -ProfileMap $script:ProfileMap
            Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
            Update-SurfaceButtonsVisuals
            Set-StatusBanner "Set $cid LED/Key color to $chosenColor"
        }
    })
    [void]$swatchPanel.Controls.Add($sb)
}

function New-ActionBtn([string]$text, [Drawing.Color]$bg) {
    $b = [Windows.Forms.Button]::new()
    $b.Text = $text
    $b.Width = 360
    $b.Height = 33
    $b.Margin = [Windows.Forms.Padding]::new(2, 4, 2, 1)
    $b.FlatStyle = 'Flat'
    $b.BackColor = $bg
    $b.ForeColor = [Drawing.Color]::White
    $b.Font = [Drawing.Font]::new('Segoe UI Semibold', 9.0, [Drawing.FontStyle]::Bold)
    [void]$inspFlow.Controls.Add($b)
    return $b
}

$btnSave     = New-ActionBtn 'Apply & Save Mapping' ([Drawing.Color]::FromArgb(2, 132, 199))
$btnTest     = New-ActionBtn 'Test Selected Action Now' ([Drawing.Color]::FromArgb(22, 101, 52))
$btnZeroKnob = New-ActionBtn 'Zero Out Selected Knob / Device (0% Mute)' ([Drawing.Color]::FromArgb(153, 27, 27))
$btnClear    = New-ActionBtn 'Clear This Control (Set None)' ([Drawing.Color]::FromArgb(71, 85, 105))
$btnRefresh  = New-ActionBtn 'Refresh Devices & Re-Sync Pad LEDs' ([Drawing.Color]::FromArgb(51, 65, 85))
$btnTray     = New-ActionBtn 'Minimize to System Tray (Keep Active)' ([Drawing.Color]::FromArgb(49, 46, 129))
$btnReset    = New-ActionBtn 'Reset Entire Profile to Defaults' ([Drawing.Color]::FromArgb(127, 29, 29))

$inspFlow.Add_Resize({
    $targetW = [Math]::Max(250, $inspFlow.ClientSize.Width - 26)
    foreach ($ctrl in @($txtLabel, $cmbAction, $cmbTarget1, $cmbTarget2, $cmbLed, $cmbOffLed, $swatchPanel, $btnSave, $btnTest, $btnZeroKnob, $btnClear, $btnRefresh, $btnTray, $btnReset)) {
        if ($null -ne $ctrl) { $ctrl.Width = $targetW }
    }
})

# Bottom Status & Live MIDI Telemetry Bar
$statusBox = [Windows.Forms.TextBox]::new()
$statusBox.Dock = 'Fill'
$statusBox.Multiline = $true
$statusBox.ReadOnly = $true
$statusBox.BackColor = [Drawing.Color]::FromArgb(13, 17, 23)
$statusBox.ForeColor = [Drawing.Color]::FromArgb(125, 211, 252)
$statusBox.BorderStyle = 'None'
$statusBox.Font = [Drawing.Font]::new('Consolas', 9.5)
$rootLayout.Controls.Add($statusBox, 0, 2)

function Set-StatusBanner([string]$eventText) {
    $defOut = @($script:AudioSnapshot | Where-Object { $_.Flow -eq 'Render' -and $_.IsDefault } | Select-Object -First 1)
    $defIn  = @($script:AudioSnapshot | Where-Object { $_.Flow -eq 'Capture' -and $_.IsDefault } | Select-Object -First 1)
    $outStr = if ($defOut.Count) { "$($defOut[0].FriendlyName) ($($defOut[0].VolumePct)%$(if($defOut[0].Muted){' MUTED'}else{''}))" } else { 'None' }
    $inStr  = if ($defIn.Count)  { "$($defIn[0].FriendlyName) ($($defIn[0].VolumePct)%$(if($defIn[0].Muted){' MUTED'}else{''}))" } else { 'None' }
    $midiState = if ([GoodCube.ApcDeck.NativeBridge]::IsOpen) { 'CONNECTED (MIDI IN + LED OUT)' } else { 'DISCONNECTED (Click Refresh when plugged in)' }
    $statusBox.Text = "MIDI: $midiState  |  Default Speaker: $outStr  |  Default Mic: $inStr`r`nLast Event: $eventText"
}

function Populate-TargetDropdowns([string]$actionType) {
    $cur1 = $cmbTarget1.Text
    $cur2 = $cmbTarget2.Text
    $cmbTarget1.Items.Clear()
    $cmbTarget2.Items.Clear()

    $audioNames = @('@DefaultRender', '@DefaultCapture') + @($script:AudioSnapshot | ForEach-Object { $_.FriendlyName } | Select-Object -Unique)
    foreach ($n in $audioNames) { [void]$cmbTarget2.Items.Add($n) }

    switch ($actionType) {
        { $_ -in @('VolumeDevice','SetDefaultDevice','SwapDevices','MuteToggle','EndpointEnableToggle') } {
            foreach ($n in $audioNames) { [void]$cmbTarget1.Items.Add($n) }
        }
        'VolumeMasterOut' { [void]$cmbTarget1.Items.Add('@DefaultRender') }
        'VolumeDefaultMic'{ [void]$cmbTarget1.Items.Add('@DefaultCapture') }
        'VolumeApp' {
            foreach ($app in @('chrome','msedge','Spotify','Speechify','Discord','vlc')) { [void]$cmbTarget1.Items.Add($app) }
        }
        'BluetoothConnect' {
            foreach ($b in $script:BtSnapshot) { [void]$cmbTarget1.Items.Add($b.Name) }
            foreach ($fallback in @('RB Meta 00YS','RB Meta 01JY','Joes iPhone')) {
                if (-not $cmbTarget1.Items.Contains($fallback)) { [void]$cmbTarget1.Items.Add($fallback) }
            }
        }
        'Hotkey' {
            foreach ($hk in @('Alt+Q','Alt+W','Alt+S','Alt+F','Alt+A','Win+H','Ctrl+Shift+M','Ctrl+C','Ctrl+V','Ctrl+Z','F13','F14','F15')) {
                [void]$cmbTarget1.Items.Add($hk)
            }
        }
        'MediaKey' {
            foreach ($mk in @('PlayPause','NextTrack','PrevTrack','Stop','VolumeMute','VolumeUp','VolumeDown')) {
                [void]$cmbTarget1.Items.Add($mk)
            }
        }
        'SystemCommand' {
            foreach ($sc in @('sound-cpl','recording-cpl','app-mixer','sound-settings','bt-settings','notepad.exe','calc.exe')) {
                [void]$cmbTarget1.Items.Add($sc)
            }
        }
    }
    $cmbTarget1.Text = $cur1
    $cmbTarget2.Text = $cur2
    $cmbTarget2.Enabled = ($actionType -eq 'SwapDevices')
}

function Get-UiColorForColorName([string]$colorName, [Drawing.Color]$fallback) {
    switch ($colorName) {
        'Green'      { return $cGreenFill }
        'BlinkGreen' { return $cGreenBlink }
        'Red'        { return $cRedFill }
        'BlinkRed'   { return $cRedBlink }
        'Amber'      { return $cAmberFill }
        'BlinkAmber' { return $cAmberBlink }
        'Off'        { return $cUnmapped }
        default      { return $fallback }
    }
}

function Update-SurfaceButtonsVisuals {
    foreach ($kv in $script:ControlButtons.GetEnumerator()) {
        $cid = [string]$kv.Key
        $btn = $kv.Value
        $m = if ($script:ProfileMap.ContainsKey($cid)) { $script:ProfileMap[$cid] } else { $null }
        $isSelected = ($cid -eq $script:SelectedId)

        if ($cid.StartsWith('Knob_')) {
            $pct = if ($script:KnobValues.ContainsKey($cid)) { [int]$script:KnobValues[$cid] } else { 0 }
            $lbl = if ($m) { $m.Label } else { $cid }
            $stateTag = if ($pct -eq 0) { 'ZEROED (0%)' } else { "$pct%" }
            if ($chkPickupMode.Checked -and -not $script:KnobPickedUp[$cid] -and $script:KnobLastPhys[$cid] -ge 0) {
                $stateTag = "Target $pct% (Phys $($script:KnobLastPhys[$cid])%)"
            }
            $btn.Text = "$lbl`r`n[$stateTag]"
            $btn.BackColor = if (-not $m -or $m.ActionType -eq 'None') { $cUnmapped } elseif ($pct -eq 0) { $cKnobZeroBg } else { $cKnobBg }
            $btn.ForeColor = [Drawing.Color]::White
        } elseif ($cid.StartsWith('Pad_')) {
            $vel = Get-PadLedVelocity -Mapping $m -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
            $btn.BackColor = switch ($vel) {
                1 { $cGreenFill }
                2 { $cGreenBlink }
                3 { $cRedFill }
                4 { $cRedBlink }
                5 { $cAmberFill }
                6 { $cAmberBlink }
                default { $cUnmapped }
            }
            $btn.ForeColor = [Drawing.Color]::White
            $btn.Text = if ($m -and ($m.ActionType -ne 'None' -or $vel -gt 0)) { $m.Label } else { "PAD $($m.Code)`r`n(Empty)" }
        } elseif ($cid.StartsWith('Scene_') -or $cid.StartsWith('Track_')) {
            $active = ($m -and $m.ActionType -ne 'None')
            $defaultBg = if ($cid.StartsWith('Scene_')) { $cGreenFill } else { $cRedFill }
            $btn.BackColor = if (-not $active -and (-not $m -or $m.LedColor -in @('Auto','Off'))) { $cUnmapped } else { Get-UiColorForColorName $m.LedColor $defaultBg }
            $btn.ForeColor = [Drawing.Color]::White
            $btn.Text = if ($m) { $m.Label } else { $cid }
        } elseif ($cid.StartsWith('Key_')) {
            $note = [int]($cid -replace '^Key_','')
            $isSharp = (($note % 12) -in @(1, 3, 6, 8, 10))
            $hasCustomColor = ($m -and $m.LedColor -notin @('Auto','Off',''))
            $active = ($m -and $m.ActionType -ne 'None')
            if ($hasCustomColor) {
                $btn.BackColor = Get-UiColorForColorName $m.LedColor $cKeyMapped
                $btn.ForeColor = [Drawing.Color]::White
                $btn.Text = $m.Label
            } elseif ($active) {
                $btn.BackColor = $cKeyMapped
                $btn.ForeColor = [Drawing.Color]::White
                $btn.Text = $m.Label
            } else {
                $btn.BackColor = if ($isSharp) { $cKeyBlack } else { $cKeyWhite }
                $btn.ForeColor = if ($isSharp) { [Drawing.Color]::White } else { [Drawing.Color]::Black }
                $noteNames = @('C','C#','D','D#','E','F','F#','G','G#','A','A#','B')
                $oct = [int][math]::Floor(($note / 12) - 1)
                $btn.Text = $noteNames[$note % 12] + $oct
            }
        }

        if ($isSelected) {
            $btn.FlatAppearance.BorderColor = $cCyanBorder
            $btn.FlatAppearance.BorderSize = 3
        } else {
            $btn.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(51, 65, 85)
            $btn.FlatAppearance.BorderSize = 1
        }
    }
}

function Select-ApcControl([string]$cid) {
    if (-not $script:ProfileMap.ContainsKey($cid)) { return }
    $script:SelectedId = $cid
    $m = $script:ProfileMap[$cid]
    $lblSelectedHeader.Text = "Selected: $($m.ControlId) — $($m.Label)"
    $lblSelectedMeta.Text   = "Type: $($m.ControlKind)  |  MIDI Ch $($m.Channel + 1)  |  Code: $($m.Code)"
    $txtLabel.Text          = [string]$m.Label
    $cmbAction.SelectedItem = if ($cmbAction.Items.Contains([string]$m.ActionType)) { [string]$m.ActionType } else { 'None' }
    Populate-TargetDropdowns ([string]$m.ActionType)
    $cmbTarget1.Text        = [string]$m.Target
    $cmbTarget2.Text        = [string]$m.SecondaryTarget
    $ledVal = if ($m.PSObject.Properties['LedColor'] -and $cmbLed.Items.Contains([string]$m.LedColor)) { [string]$m.LedColor } else { 'Auto' }
    $offVal = if ($m.PSObject.Properties['OffLedColor'] -and $cmbOffLed.Items.Contains([string]$m.OffLedColor)) { [string]$m.OffLedColor } else { 'Auto' }
    $cmbLed.SelectedItem    = $ledVal
    $cmbOffLed.SelectedItem = $offVal
    Update-SurfaceButtonsVisuals
}

# Wire surface button clicks (Left-Click selects; Right-Click selects AND tests action immediately)
foreach ($btn in $script:ControlButtons.Values) {
    $btn.Add_Click({
        $cid = [string]$this.Tag
        Select-ApcControl $cid
        if ($script:ProfileMap.ContainsKey($cid)) {
            $m = $script:ProfileMap[$cid]
            Set-StatusBanner "Selected $cid [$($m.Label)] -> Action=$($m.ActionType) Target='$($m.Target)' LED=$($m.LedColor) (Right-click pad to test action)"
        }
    })
    $btn.Add_MouseUp({
        param($sender, $e)
        if ($e.Button -eq [Windows.Forms.MouseButtons]::Right) {
            $cid = [string]$sender.Tag
            Select-ApcControl $cid
            $btnTest.PerformClick()
        }
    })
}

$cmbAction.Add_SelectedIndexChanged({
    Populate-TargetDropdowns ([string]$cmbAction.SelectedItem)
})

$btnSave.Add_Click({
    $cid = $script:SelectedId
    if (-not $script:ProfileMap.ContainsKey($cid)) { return }
    $m = $script:ProfileMap[$cid]
    $m.Label           = $txtLabel.Text.Trim()
    $m.ActionType      = [string]$cmbAction.SelectedItem
    $m.Target          = $cmbTarget1.Text.Trim()
    $m.SecondaryTarget = $cmbTarget2.Text.Trim()
    $m.LedColor        = [string]$cmbLed.SelectedItem
    $m.OffLedColor     = [string]$cmbOffLed.SelectedItem
    $path = Save-ApcProfile -ProfileMap $script:ProfileMap
    Clear-AudioEndpointCache
    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
    Select-ApcControl $cid
    Set-StatusBanner "Saved mapping for $cid ($($m.Label) -> $($m.ActionType) $($m.Target), LED=$($m.LedColor)/$($m.OffLedColor))"
})

$btnTest.Add_Click({
    $cid = $script:SelectedId
    if (-not $script:ProfileMap.ContainsKey($cid)) { return }
    $m = $script:ProfileMap[$cid]
    if ($m.ControlKind -eq 'Knob') {
        $msg = Set-AudioVolumeByMapping -Mapping $m -MidiValue 96
        $script:KnobValues[$cid] = [int][math]::Round((Convert-MidiCcToScalar 96) * 100)
    } else {
        $msg = Invoke-ApcAction -Mapping $m
    }
    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
    Update-SurfaceButtonsVisuals
    Set-StatusBanner "[TEST] $cid -> $msg"
})

$btnZeroKnob.Add_Click({
    $cid = $script:SelectedId
    if (-not $script:ProfileMap.ContainsKey($cid)) { return }
    $m = $script:ProfileMap[$cid]
    if ($m.ControlKind -eq 'Knob') {
        $msg = Set-AudioVolumeByMapping -Mapping $m -MidiValue 0 -AutoMuteAtZero
        $script:KnobValues[$cid] = 0
        $script:KnobPickedUp[$cid] = $false
    } else {
        $ep = Resolve-AudioEndpoint -MatchPattern $m.Target
        if ($ep) {
            $ep.AudioEndpointVolume.MasterVolumeLevelScalar = [float]0.0
            $ep.AudioEndpointVolume.Mute = $true
            $msg = "$($ep.FriendlyName): 0% (ZEROED/MUTED)"
        } else {
            $msg = "Select a knob or audio device button to zero out."
        }
    }
    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
    Update-SurfaceButtonsVisuals
    Set-StatusBanner "[ZERO OUT] $cid -> $msg"
})

$btnClear.Add_Click({
    $cid = $script:SelectedId
    if (-not $script:ProfileMap.ContainsKey($cid)) { return }
    $m = $script:ProfileMap[$cid]
    $m.ActionType = 'None'
    $m.Target = ''
    $m.SecondaryTarget = ''
    $m.LedColor = 'Off'
    $m.OffLedColor = 'Off'
    $null = Save-ApcProfile -ProfileMap $script:ProfileMap
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
    Select-ApcControl $cid
    Set-StatusBanner "Cleared mapping for $cid"
})

$btnRefresh.Add_Click({
    Clear-AudioEndpointCache
    if (-not [GoodCube.ApcDeck.NativeBridge]::IsOpen) {
        $null = [GoodCube.ApcDeck.NativeBridge]::OpenDevice('APC Key 25')
    }
    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
    $script:BtSnapshot    = @(Get-PairedBluetoothDevices -AudioSnapshot $script:AudioSnapshot)
    foreach ($cc in 48..55) {
        $kId = "Knob_$cc"
        $cur = Get-CurrentMappingVolumePct -Mapping $script:ProfileMap[$kId]
        if ($null -ne $cur) { $script:KnobValues[$kId] = $cur }
    }
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
    Update-SurfaceButtonsVisuals
    Set-StatusBanner 'Refreshed audio/Bluetooth endpoints and synced physical APC Key 25 LEDs.'
})

$btnTray.Add_Click({
    $form.Hide()
    $trayIcon.ShowBalloonTip(2000, 'APC-DECK Active', 'Your Akai APC Key 25 mappings & LEDs are running in the background. Double-click the desktop shortcut or tray icon to reopen.', [Windows.Forms.ToolTipIcon]::Info)
})

$btnReset.Add_Click({
    if ([Windows.Forms.MessageBox]::Show($form, 'Reset all knobs, pads, and keys back to the default workstation audio/Bluetooth layout?', 'Confirm Reset', 'OKCancel', 'Warning') -ne 'OK') { return }
    $map = @{}
    foreach ($c in (New-DefaultApcProfile)) { $map[$c.ControlId] = $c }
    $script:ProfileMap = $map
    $null = Save-ApcProfile -ProfileMap $script:ProfileMap
    Clear-AudioEndpointCache
    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
    Select-ApcControl $script:SelectedId
    Set-StatusBanner 'Reset entire profile to default workstation audio/Bluetooth layout.'
})

function Restore-MainWindow {
    $form.Show()
    $form.WindowState = 'Normal'
    $wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $w  = [Math]::Min([Math]::Max($form.Width, 1180), $wa.Width - 40)
    $h  = [Math]::Min([Math]::Max($form.Height, 740), $wa.Height - 40)
    if (-not $wa.Contains($form.Bounds)) {
        $x = $wa.X + [int](($wa.Width - $w) / 2)
        $y = $wa.Y + [int](($wa.Height - $h) / 2)
        $form.Bounds = [Drawing.Rectangle]::new($x, $y, $w, $h)
    }
    $form.Activate()
    [GoodCube.ApcDeck.NativeBridge]::BringFormToFront($form.Handle)
}

# Tray Menu Events
$trayIcon.Add_DoubleClick({ Restore-MainWindow })
$miShow.Add_Click({ Restore-MainWindow })
$miSync.Add_Click({ $btnRefresh.PerformClick() })
$miBalance.Add_Click({
    $null = Invoke-ApcAction -Mapping ([pscustomobject]@{ ActionType = 'BalanceAll'; Target = '' })
    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
    Update-SurfaceButtonsVisuals
    Set-StatusBanner 'Balanced all workstation outputs & normalized microphones to 95%.'
})
$miExit.Add_Click({
    $form.Close()
})

$script:InitialShowCompleted = $false

# High-speed 60Hz MIDI Polling Timer (16ms interval for instant, lag-free knobs & pads)
$midiTimer = [Windows.Forms.Timer]::new()
$midiTimer.Interval = 16
$midiTimer.Add_Tick({
    if (-not $script:InitialShowCompleted) {
        $script:InitialShowCompleted = $true
        if ($Minimized) {
            $form.Hide()
        } else {
            Restore-MainWindow
        }
        if ($SmokeTestUi) {
            [Console]::WriteLine("SMOKE_UI_OK: Handle=$($form.Handle) Visible=$([GoodCube.ApcDeck.NativeBridge]::IsWindowVisible($form.Handle)) Title=$($form.Text) MidiOpen=$([GoodCube.ApcDeck.NativeBridge]::IsOpen)")
            $form.Close()
            return
        }
    }

    # Check single-instance wake-up or stop signals
    if ($stopEvent.WaitOne(0)) {
        $form.Close()
        return
    }
    if ($showEvent.WaitOne(0)) {
        Restore-MainWindow
        Set-StatusBanner 'Restored APC-DECK window to foreground.'
    }

    $ev = New-Object GoodCube.ApcDeck.MidiEventRecord
    $needUiRefresh = $false
    $lastBanner = $null

    # Coalesce rapid knob CC changes per 16ms frame
    $latestCc = @{}
    while ([GoodCube.ApcDeck.NativeBridge]::EventQueue.TryDequeue([ref]$ev)) {
        if ($ev.Command -eq 0xB0 -and $ev.Data1 -ge 48 -and $ev.Data1 -le 55) {
            $latestCc[$ev.Data1] = $ev
        } elseif ($ev.Command -eq 0x90 -and $ev.Data2 -gt 0) {
            $cid = if ($ev.Channel -eq 0) {
                if ($ev.Data1 -ge 0 -and $ev.Data1 -le 39) { "Pad_$($ev.Data1)" }
                elseif ($ev.Data1 -ge 64 -and $ev.Data1 -le 71) { "Track_$($ev.Data1)" }
                elseif ($ev.Data1 -ge 81 -and $ev.Data1 -le 86) { "Scene_$($ev.Data1)" }
                else { "Pad_$($ev.Data1)" }
            } else {
                "Key_$($ev.Data1)"
            }

            if ($chkMidiLearn.Checked -and $script:ProfileMap.ContainsKey($cid) -and $form.Visible) {
                Select-ApcControl $cid
            }

            if (-not $chkEditOnly.Checked -and $script:ProfileMap.ContainsKey($cid)) {
                $m = $script:ProfileMap[$cid]
                if ($m.ActionType -ne 'None') {
                    $res = Invoke-ApcAction -Mapping $m
                    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
                    if ($m.ActionType -eq 'BluetoothConnect') {
                        $script:BtSnapshot = @(Get-PairedBluetoothDevices)
                    }
                    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
                    $needUiRefresh = $true
                    $lastBanner = "MIDI Ch$($ev.Channel + 1) Note $($ev.Data1) [$cid : $($m.Label)] -> $res"
                } else {
                    $lastBanner = "MIDI Ch$($ev.Channel + 1) Note $($ev.Data1) [$cid] (Unassigned — pick an Action Type or Color on the right!)"
                }
            } else {
                $lastBanner = "MIDI Learn Selected: $cid (Ch$($ev.Channel + 1) Note $($ev.Data1))"
            }
        }
    }

    foreach ($ccKey in $latestCc.Keys) {
        $ccEv = $latestCc[$ccKey]
        $cid = "Knob_$ccKey"
        $scalar = Convert-MidiCcToScalar -MidiValue $ccEv.Data2
        $physPct = [int][math]::Round($scalar * 100)
        $prevPhys = $script:KnobLastPhys[$cid]
        $script:KnobLastPhys[$cid] = $physPct

        if ($chkMidiLearn.Checked -and $script:ProfileMap.ContainsKey($cid) -and $form.Visible -and $script:SelectedId -ne $cid) {
            Select-ApcControl $cid
        }

        if (-not $chkEditOnly.Checked -and $script:ProfileMap.ContainsKey($cid)) {
            $m = $script:ProfileMap[$cid]
            if ($chkPickupMode.Checked -and -not $script:KnobPickedUp[$cid]) {
                $targetPct = $script:KnobValues[$cid]
                $crossed = ($prevPhys -ge 0) -and (($prevPhys -le $targetPct -and $physPct -ge $targetPct) -or ($prevPhys -ge $targetPct -and $physPct -le $targetPct))
                if ([math]::Abs($physPct - $targetPct) -le 5 -or $crossed -or $physPct -eq 0) {
                    $script:KnobPickedUp[$cid] = $true
                } else {
                    $dir = if ($physPct -lt $targetPct) { 'Turn CW ->' } else { '<- Turn CCW' }
                    $lastBanner = "Pickup [$($m.Label)]: Physical=$physPct%, Target=$targetPct% ($dir to catch)"
                    $needUiRefresh = $true
                    continue
                }
            }
            $script:KnobValues[$cid] = $physPct
            $res = Set-AudioVolumeByMapping -Mapping $m -MidiValue $ccEv.Data2 -AutoMuteAtZero
            $lastBanner = "MIDI Ch1 CC $ccKey = $($ccEv.Data2) [$($m.Label)] -> $res"
            $needUiRefresh = $true
        }
    }

    if ($needUiRefresh) {
        Update-SurfaceButtonsVisuals
    }
    if ($lastBanner) {
        Set-StatusBanner $lastBanner
    }
})

# Periodic 4-second background LED & device state sync
$syncTimer = [Windows.Forms.Timer]::new()
$syncTimer.Interval = 4000
$syncTimer.Add_Tick({
    if (-not [GoodCube.ApcDeck.NativeBridge]::IsOpen) {
        $res = [GoodCube.ApcDeck.NativeBridge]::OpenDevice('APC Key 25')
        if ($res -eq 'OK') {
            Clear-AudioEndpointCache
            $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
            Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
            Update-SurfaceButtonsVisuals
            Set-StatusBanner 'Reconnected Akai APC Key 25 and synced LEDs.'
        }
        return
    }
    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
    if ($form.Visible) {
        Update-SurfaceButtonsVisuals
    }
})

$form.Add_Load({
    Select-ApcControl 'Pad_32'
    Set-StatusBanner "Ready. Turn any knob (K1–K8), press any pad, or press any piano key on your Akai APC Key 25."
    if (-not $Minimized) {
        Restore-MainWindow
    }
    $midiTimer.Start()
    $syncTimer.Start()
})

try {
    [Windows.Forms.Application]::Run($form)
} finally {
    try { $instanceMutex.ReleaseMutex() } catch { }
    try { $instanceMutex.Dispose() } catch { }
    try { $midiTimer.Stop(); $midiTimer.Dispose() } catch { }
    try { $syncTimer.Stop(); $syncTimer.Dispose() } catch { }
    try { $trayIcon.Visible = $false; $trayIcon.Dispose() } catch { }
    try { [GoodCube.ApcDeck.NativeBridge]::ClearAllPadLeds() } catch { }
    try { [GoodCube.ApcDeck.NativeBridge]::CloseDevice() } catch { }
    try { $showEvent.Dispose() } catch { }
    try { $stopEvent.Dispose() } catch { }
    try { $form.Dispose() } catch { }
    [Console]::Out.Flush()
    [Environment]::Exit(0)
}
