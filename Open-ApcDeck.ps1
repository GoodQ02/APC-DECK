[CmdletBinding()]
param(
    [ValidateSet('Panel','Tray','Headless','Snapshot','ResetDefaults','Stop')][string]$Mode = 'Panel',
    [switch]$Minimized,
    [switch]$SmokeTestUi,
    [string]$SavePreviewPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Mode -eq 'Tray') {
    $Minimized = $true
}

Import-Module (Join-Path $PSScriptRoot 'ApcDeck.psm1') -Force -DisableNameChecking

$instanceSuffix = if ($SmokeTestUi) { '.SmokeTest' } else { '' }
$showEventName  = "Local\GoodCube.ApcMidiDeck.ShowEvent$instanceSuffix"
$stopEventName  = "Local\GoodCube.ApcMidiDeck.StopEvent$instanceSuffix"
$mutexName      = "Local\GoodCube.ApcMidiDeck.Instance$instanceSuffix"

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
    $prof  = Load-ApcProfile
    $audio = Get-AudioEndpointsSnapshot
    $bt    = Get-PairedBluetoothDevices -AudioSnapshot $audio
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

if (-not ('GoodCube.ApcDeck.BufferedButton' -as [type])) {
    Add-Type -ReferencedAssemblies @('System.Windows.Forms', 'System.Drawing', 'System.ComponentModel.Primitives', 'System.Drawing.Primitives') -TypeDefinition @"
using System;
using System.Windows.Forms;
namespace GoodCube.ApcDeck {
    public class BufferedButton : Button {
        public BufferedButton() {
            this.DoubleBuffered = true;
            this.ResizeRedraw = true;
            this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }
    }
    public class SurfaceTile : Control {
        public SurfaceTile() {
            this.DoubleBuffered = true;
            this.ResizeRedraw = true;
            this.Cursor = Cursors.Hand;
            this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.StandardClick | ControlStyles.StandardDoubleClick, true);
        }
        protected override void OnPaintBackground(PaintEventArgs pevent) {
            // Paint handlers clear the full surface directly
        }
    }
    public class BufferedPanel : Panel {
        public BufferedPanel() {
            this.DoubleBuffered = true;
            this.ResizeRedraw = true;
            this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
        }
        protected override void OnPaintBackground(PaintEventArgs pevent) {
            // Paint handlers clear the full surface directly
        }
    }
}
"@
}

$script:ProfileMap              = Load-ApcProfile
$script:AudioSnapshot           = @(Get-AudioEndpointsSnapshot)
$script:BtSnapshot              = @(Get-PairedBluetoothDevices -AudioSnapshot $script:AudioSnapshot)
$script:SelectedId              = 'Pad_32'
$script:ControlButtons          = @{}
$script:KnobValues              = @{}
$script:KnobPickedUp            = @{}
$script:KnobLastPhys            = @{}
$script:PadVelocities           = @{}
$script:SuppressInspectorEvents = $false
$script:LastKnobTurnTick        = [int64]0
$script:LastMidiOpenState       = $false
$script:CachedSpeakerSummary    = 'None'
$script:CachedMicSummary        = 'None'

function Format-CompactText([string]$text, [int]$maxChars = 18) {
    if ([string]::IsNullOrWhiteSpace($text)) { return '' }
    $clean = $text.Trim()
    if ($clean.Length -le $maxChars) { return $clean }
    return ($clean.Substring(0, [Math]::Max(1, $maxChars - 1)).TrimEnd() + '…')
}

function Update-CachedTelemetrySummaries {
    $defOut = $null
    $defIn  = $null
    foreach ($ep in $script:AudioSnapshot) {
        if ($ep.IsDefault) {
            if ($ep.Flow -eq 'Render' -and $null -eq $defOut) { $defOut = $ep }
            elseif ($ep.Flow -eq 'Capture' -and $null -eq $defIn) { $defIn = $ep }
        }
    }
    $script:CachedSpeakerSummary = if ($defOut) { "$(Format-CompactText $defOut.FriendlyName 26) ($($defOut.VolumePct)%$(if($defOut.Muted){' MUTED'}else{''}))" } else { 'None' }
    $script:CachedMicSummary     = if ($defIn)  { "$(Format-CompactText $defIn.FriendlyName 24) ($($defIn.VolumePct)%$(if($defIn.Muted){' MUTED'}else{''}))" } else { 'None' }
}

function Update-PadVelocitiesCache {
    $changedPads = [Collections.Generic.List[string]]::new()
    for ($note = 0; $note -lt 40; $note++) {
        $cid = "Pad_$note"
        $vel = if ($script:ProfileMap.ContainsKey($cid)) {
            Get-PadLedVelocity -Mapping $script:ProfileMap[$cid] -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
        } else { 0 }
        if ((-not $script:PadVelocities.ContainsKey($cid)) -or $script:PadVelocities[$cid] -ne $vel) {
            $script:PadVelocities[$cid] = $vel
            $changedPads.Add($cid)
        }
    }
    return $changedPads.ToArray()
}

Update-CachedTelemetrySummaries
$null = Update-PadVelocitiesCache

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
$script:LastMidiOpenState = [GoodCube.ApcDeck.NativeBridge]::IsOpen
if ($openMsg -eq 'OK') {
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot -Force
}

# Hardware-accurate Akai APC Key 25 palette (Operate Mode — Restrained Dark Studio Hardware)
$cChassisBg   = [Drawing.Color]::FromArgb(16, 18, 23)
$cBezelBg     = [Drawing.Color]::FromArgb(24, 27, 34)
$cDeckSurface = [Drawing.Color]::FromArgb(30, 34, 43)
$cInspectorBg = [Drawing.Color]::FromArgb(22, 26, 34)
$cFieldBg     = [Drawing.Color]::FromArgb(33, 39, 51)
$cAkaiRed     = [Drawing.Color]::FromArgb(225, 29, 46)
$cCyanSelect  = [Drawing.Color]::FromArgb(56, 189, 248)
$cGreenFill   = [Drawing.Color]::FromArgb(21, 128, 61)
$cGreenGlow   = [Drawing.Color]::FromArgb(74, 222, 128)
$cGreenBlink  = [Drawing.Color]::FromArgb(16, 185, 129)
$cRedFill     = [Drawing.Color]::FromArgb(153, 27, 27)
$cRedGlow     = [Drawing.Color]::FromArgb(248, 113, 113)
$cRedBlink    = [Drawing.Color]::FromArgb(220, 38, 38)
$cAmberFill   = [Drawing.Color]::FromArgb(146, 64, 14)
$cAmberGlow   = [Drawing.Color]::FromArgb(251, 191, 36)
$cAmberBlink  = [Drawing.Color]::FromArgb(217, 119, 6)
$cPadUnmapped = [Drawing.Color]::FromArgb(42, 47, 58)
$cKeyWhite    = [Drawing.Color]::FromArgb(238, 242, 246)
$cKeyBlack    = [Drawing.Color]::FromArgb(20, 24, 31)
$cKeyMapped   = [Drawing.Color]::FromArgb(14, 116, 144)

# Pre-allocated GDI+ Fonts and StringFormats (zero font-creation overhead during 60Hz Paint passes)
$script:SfCenter = [Drawing.StringFormat]::new()
$script:SfCenter.Alignment     = [Drawing.StringAlignment]::Center
$script:SfCenter.LineAlignment = [Drawing.StringAlignment]::Center
$script:SfCenter.Trimming      = [Drawing.StringTrimming]::EllipsisCharacter
$script:SfCenter.FormatFlags   = [Drawing.StringFormatFlags]::NoWrap

$script:SfBottom = [Drawing.StringFormat]::new()
$script:SfBottom.Alignment     = [Drawing.StringAlignment]::Center
$script:SfBottom.LineAlignment = [Drawing.StringAlignment]::Near
$script:SfBottom.Trimming      = [Drawing.StringTrimming]::EllipsisCharacter
$script:SfBottom.FormatFlags   = [Drawing.StringFormatFlags]::NoWrap

$script:FHeaderBrand = [Drawing.Font]::new('Segoe UI', 10.5, [Drawing.FontStyle]::Bold)
$script:FHeaderSub   = [Drawing.Font]::new('Segoe UI Semibold', 9.0, [Drawing.FontStyle]::Regular)
$script:FHeaderModel = [Drawing.Font]::new('Segoe UI', 14.0, [Drawing.FontStyle]::Bold)
$script:FHeaderPill  = [Drawing.Font]::new('Segoe UI Semibold', 8.0, [Drawing.FontStyle]::Bold)
$script:FPadTiny     = [Drawing.Font]::new('Segoe UI', 6.8, [Drawing.FontStyle]::Bold)
$script:FPadMain     = [Drawing.Font]::new('Segoe UI Semibold', 8.2, [Drawing.FontStyle]::Bold)
$script:FPadTarget   = [Drawing.Font]::new('Segoe UI', 6.8, [Drawing.FontStyle]::Regular)
$script:FRoundCap    = [Drawing.Font]::new('Segoe UI Semibold', 7.3, [Drawing.FontStyle]::Bold)
$script:FRoundBadge  = [Drawing.Font]::new('Segoe UI', 6.5, [Drawing.FontStyle]::Bold)
$script:FKnobTop     = [Drawing.Font]::new('Segoe UI Semibold', 7.2, [Drawing.FontStyle]::Bold)
$script:FKnobLbl     = [Drawing.Font]::new('Segoe UI Semibold', 7.8, [Drawing.FontStyle]::Bold)
$script:FKnobSub     = [Drawing.Font]::new('Segoe UI', 6.8, [Drawing.FontStyle]::Regular)
$script:FKnobPct     = [Drawing.Font]::new('Consolas', 7.8, [Drawing.FontStyle]::Bold)
$script:FKeyNoteW    = [Drawing.Font]::new('Segoe UI Semibold', 7.8, [Drawing.FontStyle]::Bold)
$script:FKeyLblW     = [Drawing.Font]::new('Segoe UI Semibold', 7.2, [Drawing.FontStyle]::Bold)
$script:FKeyNoteB    = [Drawing.Font]::new('Segoe UI Semibold', 7.0, [Drawing.FontStyle]::Bold)
$script:FKeyLblB     = [Drawing.Font]::new('Segoe UI', 6.5, [Drawing.FontStyle]::Bold)

# Hardware silkscreen metadata for Scene (Notes 82..86, 81) and Track (Notes 64..71) buttons
$script:SceneMeta = @{
    82 = @{ Arrow = '► 1'; ShiftBadge = 'CLIP STOP' }
    83 = @{ Arrow = '► 2'; ShiftBadge = 'SOLO' }
    84 = @{ Arrow = '► 3'; ShiftBadge = 'REC ARM' }
    85 = @{ Arrow = '► 4'; ShiftBadge = 'MUTE' }
    86 = @{ Arrow = '► 5'; ShiftBadge = 'SELECT' }
    81 = @{ Arrow = '■';   ShiftBadge = 'STOP ALL CLIPS' }
}
$script:TrackMeta = @{
    64 = @{ Top = '▲'; Sub = 'UP' }
    65 = @{ Top = '▼'; Sub = 'DOWN' }
    66 = @{ Top = '◀'; Sub = 'LEFT' }
    67 = @{ Top = '▶'; Sub = 'RIGHT' }
    68 = @{ Top = '◉'; Sub = 'VOLUME' }
    69 = @{ Top = '◉'; Sub = 'PAN' }
    70 = @{ Top = '◉'; Sub = 'SEND' }
    71 = @{ Top = '◉'; Sub = 'DEVICE' }
}

$form = [Windows.Forms.Form]::new()
$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
$form.Text = $windowTitle
$form.KeyPreview = $true
$primWa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$initW  = [Math]::Min(1680, [Math]::Max(1260, $primWa.Width - 70))
$initH  = [Math]::Min(970,  [Math]::Max(760,  $primWa.Height - 54))
$initX  = $primWa.X + [int](($primWa.Width - $initW) / 2)
$initY  = $primWa.Y + [int](($primWa.Height - $initH) / 2)
$form.StartPosition = [Windows.Forms.FormStartPosition]::Manual
$form.Bounds = [Drawing.Rectangle]::new($initX, $initY, $initW, $initH)
$form.MinimumSize = [Drawing.Size]::new(1200, 740)
$form.Font = [Drawing.Font]::new('Segoe UI', 9.0)
$form.BackColor = $cChassisBg
$form.ForeColor = [Drawing.Color]::Gainsboro

$icoPath = Join-Path $PSScriptRoot 'assets\apc-deck.ico'
if (Test-Path -LiteralPath $icoPath) {
    try { $form.Icon = [Drawing.Icon]::new($icoPath) } catch { }
}

# System Tray Icon
$trayIcon = [Windows.Forms.NotifyIcon]::new()
$trayIcon.Text = 'GOOD-CUBE APC Key 25 Audio Deck'
$trayIcon.Icon = if ($form.Icon) { $form.Icon } else { [Drawing.SystemIcons]::Application }
$trayIcon.Visible = $true
$trayMenu = [Windows.Forms.ContextMenuStrip]::new()
$miShow    = $trayMenu.Items.Add('Open APC-DECK Window')
$miSync    = $trayMenu.Items.Add('Refresh Audio & Sync Pad LEDs')
$miBalance = $trayMenu.Items.Add('Balance All Audio (95% Mics)')
[void]$trayMenu.Items.Add('-')
$miExit    = $trayMenu.Items.Add('Exit APC-DECK Controller')
$trayIcon.ContextMenuStrip = $trayMenu

# Root Layout: Top Hardware Header Bar (52px), Main Workspace (Fill), Bottom Telemetry Bar (50px)
$rootLayout = [Windows.Forms.TableLayoutPanel]::new()
$rootLayout.Dock = 'Fill'
$rootLayout.ColumnCount = 1
$rootLayout.RowCount = 3
[void]$rootLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Absolute, 52))
[void]$rootLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 100))
[void]$rootLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Absolute, 50))
$form.Controls.Add($rootLayout)

# --- TOP HARDWARE CHASSIS HEADER ---
$headerPanel = [GoodCube.ApcDeck.BufferedPanel]::new()
$headerPanel.Dock = 'Fill'
$headerPanel.BackColor = $cBezelBg
$rootLayout.Controls.Add($headerPanel, 0, 0)

$headerPanel.Add_Paint({
    param($sender, $e)
    try {
        $g = $e.Graphics
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $w = $sender.ClientSize.Width
        $g.Clear($cBezelBg)

        # Top crimson Akai accent line
        $redBrush = [Drawing.SolidBrush]::new($cAkaiRed)
        $g.FillRectangle($redBrush, 0, 0, $w, 3)

        # AKAI PROFESSIONAL badge
        $g.FillRectangle($redBrush, 14, 11, 168, 28)
        $g.DrawString('AKAI PROFESSIONAL', $script:FHeaderBrand, [Drawing.Brushes]::White, 21, 15)

        # APC key 25 silkscreen title
        $g.DrawString('APC key 25', $script:FHeaderModel, [Drawing.Brushes]::White, 196, 11)
        $mutedBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(148, 163, 184))
        $g.DrawString('1:1 Physical Hardware Twin  ·  Click or touch any physical pad, knob, button, or piano key to map  ·  Right-click on screen to test', $script:FHeaderSub, $mutedBrush, 322, 17)

        # Live MIDI connection pill on far right
        $isOpen = [GoodCube.ApcDeck.NativeBridge]::IsOpen
        $pillW = 190
        $pillX = [Math]::Max(340, $w - $pillW - 16)
        $pillBg = if ($isOpen) { [Drawing.Color]::FromArgb(20, 83, 45) } else { [Drawing.Color]::FromArgb(127, 29, 29) }
        $pillDot = if ($isOpen) { $cGreenGlow } else { $cRedGlow }
        $pillTxt = if ($isOpen) { 'MIDI IN / LED OUT ONLINE' } else { 'MIDI OFFLINE (CLICK REFRESH)' }
        $pBrush = [Drawing.SolidBrush]::new($pillBg)
        $dBrush = [Drawing.SolidBrush]::new($pillDot)
        $g.FillRectangle($pBrush, $pillX, 12, $pillW, 26)
        $g.FillEllipse($dBrush, $pillX + 10, 20, 10, 10)
        $g.DrawString($pillTxt, $script:FHeaderPill, [Drawing.Brushes]::White, $pillX + 26, 18)

        $redBrush.Dispose(); $mutedBrush.Dispose(); $pBrush.Dispose(); $dBrush.Dispose()
    } catch { }
})

# --- MAIN WORKSPACE SPLIT: Left = Authentic APC Key 25 Hardware Chassis (73%), Right = Property Inspector (27%) ---
$mainSplit = [Windows.Forms.TableLayoutPanel]::new()
$mainSplit.Dock = 'Fill'
$mainSplit.ColumnCount = 2
$mainSplit.RowCount = 1
[void]$mainSplit.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 73))
[void]$mainSplit.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 27))
$rootLayout.Controls.Add($mainSplit, 0, 1)

# --- LEFT: AKAI APC KEY 25 HARDWARE CHASSIS ---
# Real APC Key 25 layout:
#   Top Deck (67% height):
#     Left (63% width)  = 5x8 RGB Clip Pads + Column 9 Round Scene Buttons (1..5 + STOP ALL) + Row 6 Round Track Buttons (UP/DOWN/LEFT/RIGHT/VOL/PAN/SEND/DEV)
#     Right (37% width) = 2x4 Rotary Encoder Knobs (K1..K4 top row, K5..K8 bottom row) + Transport/Utility Cluster (SUSTAIN, OCT-, OCT+, PLAY, REC, SHIFT)
#   Bottom Deck (33% height):
#     Full-Width 25-Note Overlapping Synth-Action Piano Keyboard (15 White Keys C3..C5 + 10 Recessed Black Sharp/Flat Keys)
$chassisLayout = [Windows.Forms.TableLayoutPanel]::new()
$chassisLayout.Dock = 'Fill'
$chassisLayout.Padding = [Windows.Forms.Padding]::new(8, 6, 6, 6)
$chassisLayout.BackColor = $cChassisBg
$chassisLayout.ColumnCount = 1
$chassisLayout.RowCount = 2
[void]$chassisLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 67))
[void]$chassisLayout.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 33))
$mainSplit.Controls.Add($chassisLayout, 0, 0)

# Upper Hardware Deck Split (Left = Clip Matrix + Scene/Track Buttons, Right = 2x4 Knobs + Transport Cluster)
$upperDeck = [Windows.Forms.TableLayoutPanel]::new()
$upperDeck.Dock = 'Fill'
$upperDeck.ColumnCount = 2
$upperDeck.RowCount = 1
[void]$upperDeck.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 64))
[void]$upperDeck.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 36))
$chassisLayout.Controls.Add($upperDeck, 0, 0)

# ==============================================================================
# 1. UPPER-LEFT DECK: 5x8 CLIP MATRIX + 5 SCENE LAUNCH + 8 TRACK + STOP ALL CLIPS
# ==============================================================================
$matrixBezel = [Windows.Forms.GroupBox]::new()
$matrixBezel.Text = '5×8 RGB CLIP LAUNCH MATRIX  ·  SCENE LAUNCH [CLIP STOP / SOLO / REC ARM / MUTE / SELECT]  ·  TRACK && KNOB CTRL'
$matrixBezel.Dock = 'Fill'
$matrixBezel.ForeColor = [Drawing.Color]::FromArgb(148, 163, 184)
$matrixBezel.BackColor = $cBezelBg
$matrixBezel.Padding = [Windows.Forms.Padding]::new(6, 6, 6, 6)
$upperDeck.Controls.Add($matrixBezel, 0, 0)

$padsGrid = [Windows.Forms.TableLayoutPanel]::new()
$padsGrid.Dock = 'Fill'
$padsGrid.ColumnCount = 9
$padsGrid.RowCount = 6
for ($c = 0; $c -lt 8; $c++) {
    [void]$padsGrid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 10.8))
}
[void]$padsGrid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 13.6))
for ($r = 0; $r -lt 5; $r++) {
    [void]$padsGrid.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 16.5))
}
[void]$padsGrid.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 17.5))
$matrixBezel.Controls.Add($padsGrid)

# Custom painter for rectangular RGB Clip Pads (Pad_0..Pad_39)
$padPaintHandler = {
    param($sender, $e)
    try {
        $g = $e.Graphics
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $cid = [string]$sender.Tag
        $m   = if ($script:ProfileMap.ContainsKey($cid)) { $script:ProfileMap[$cid] } else { $null }
        $sel = ($cid -eq $script:SelectedId)
        $vel = if ($script:PadVelocities.ContainsKey($cid)) { [int]$script:PadVelocities[$cid] } else { 0 }

        $fillCol = switch ($vel) {
            1 { $cGreenFill }
            2 { $cGreenBlink }
            3 { $cRedFill }
            4 { $cRedBlink }
            5 { $cAmberFill }
            6 { $cAmberBlink }
            default { $cPadUnmapped }
        }
        $ledGlow = switch ($vel) {
            1 { $cGreenGlow }
            2 { $cGreenGlow }
            3 { $cRedGlow }
            4 { $cRedGlow }
            5 { $cAmberGlow }
            6 { $cAmberGlow }
            default { [Drawing.Color]::FromArgb(71, 85, 105) }
        }

        $w = $sender.ClientSize.Width
        $h = $sender.ClientSize.Height
        $g.Clear($cBezelBg)

        $padBrush = [Drawing.SolidBrush]::new($fillCol)
        $g.FillRectangle($padBrush, 2, 2, $w - 4, $h - 4)

        # Top inner LED lightbar strip
        $glowBrush = [Drawing.SolidBrush]::new($ledGlow)
        $g.FillRectangle($glowBrush, 4, 3, $w - 8, 3)

        # Border (bright cyan when selected, subtle bezel otherwise)
        $borderPen = if ($sel) {
            [Drawing.Pen]::new($cCyanSelect, 2.5)
        } else {
            [Drawing.Pen]::new([Drawing.Color]::FromArgb(60, 72, 90), 1.0)
        }
        $g.DrawRectangle($borderPen, 2, 2, $w - 5, $h - 5)

        # Pad coordinate badge (top-left) + MIDI note (top-right)
        $noteNum = [int]($cid -replace '^Pad_','')
        $rowNum  = 5 - [int][Math]::Floor($noteNum / 8)
        $colNum  = ($noteNum % 8) + 1
        $dimBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(203, 213, 225))

        $g.DrawString("R${rowNum}·C${colNum}", $script:FPadTiny, $dimBrush, 5, 7)

        $lblText = if ($m -and ($m.ActionType -ne 'None' -or $vel -gt 0)) {
            Format-CompactText $m.Label 14
        } else {
            'UNASSIGNED'
        }
        $subText = if ($m -and $m.ActionType -ne 'None') {
            Format-CompactText $(if ($m.Target) { $m.Target } else { $m.ActionType }) 16
        } else {
            "Note $noteNum"
        }

        $lblBrush = if ($m -and ($m.ActionType -ne 'None' -or $vel -gt 0)) { [Drawing.Brushes]::White } else { $dimBrush }
        $g.DrawString($lblText, $script:FPadMain,   $lblBrush, [Drawing.RectangleF]::new(3, 18, $w - 6, [Math]::Max(16, $h - 32)), $script:SfCenter)
        $g.DrawString($subText, $script:FPadTarget, $dimBrush, [Drawing.RectangleF]::new(3, $h - 16, $w - 6, 13), $script:SfCenter)

        $padBrush.Dispose(); $glowBrush.Dispose(); $borderPen.Dispose(); $dimBrush.Dispose()
    } catch { }
}

# Custom painter for Circular Hardware Scene & Track Buttons (Scene_82..86, Scene_81, Track_64..71)
$roundBtnPaintHandler = {
    param($sender, $e)
    try {
        $g = $e.Graphics
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $cid = [string]$sender.Tag
        $m   = if ($script:ProfileMap.ContainsKey($cid)) { $script:ProfileMap[$cid] } else { $null }
        $sel = ($cid -eq $script:SelectedId)
        $isScene = $cid.StartsWith('Scene_')
        $code = [int]($cid -replace '^(Scene|Track)_','')

        $w = $sender.ClientSize.Width
        $h = $sender.ClientSize.Height
        $g.Clear($cBezelBg)

        $active = ($m -and $m.ActionType -ne 'None')
        $btnFill = if (-not $active -and (-not $m -or $m.LedColor -in @('Auto','Off'))) {
            [Drawing.Color]::FromArgb(38, 43, 54)
        } elseif ($isScene) {
            Get-UiColorForColorName $m.LedColor $cGreenFill
        } else {
            Get-UiColorForColorName $m.LedColor $cRedFill
        }

        # Draw recessed pill/circle button cap in upper portion + authentic Akai silkscreen badge below
        $capH = [Math]::Max(22, $h - 19)
        $capW = [Math]::Min($w - 8, [Math]::Max(34, $capH + 18))
        $capX = [int](($w - $capW) / 2)
        $capY = 2

        $capBrush = [Drawing.SolidBrush]::new($btnFill)
        $g.FillEllipse($capBrush, $capX, $capY, $capW, $capH)

        $ringPen = if ($sel) {
            [Drawing.Pen]::new($cCyanSelect, 2.5)
        } elseif ($active) {
            [Drawing.Pen]::new($(if ($isScene) { $cGreenGlow } else { $cRedGlow }), 1.5)
        } else {
            [Drawing.Pen]::new([Drawing.Color]::FromArgb(80, 92, 112), 1.2)
        }
        $g.DrawEllipse($ringPen, $capX, $capY, $capW, $capH)

        if ($isScene) {
            $meta = $script:SceneMeta[$code]
            $capTitle = if ($m -and $m.Label) { Format-CompactText $m.Label 10 } else { $meta.Arrow }
            $g.DrawString($capTitle, $script:FRoundCap, [Drawing.Brushes]::White, [Drawing.RectangleF]::new(2, $capY, $w - 4, $capH), $script:SfCenter)

            # Red Akai Shift-function silkscreen badge beneath the round Scene button
            $badgeBg = if ($code -eq 81) { [Drawing.Color]::FromArgb(51, 65, 85) } else { $cAkaiRed }
            $bBrush = [Drawing.SolidBrush]::new($badgeBg)
            $g.FillRectangle($bBrush, 3, $h - 15, $w - 6, 13)
            $g.DrawString($meta.ShiftBadge, $script:FRoundBadge, [Drawing.Brushes]::White, [Drawing.RectangleF]::new(3, $h - 15, $w - 6, 13), $script:SfCenter)
            $bBrush.Dispose()
        } else {
            $meta = $script:TrackMeta[$code]
            $customLbl = if ($m -and $m.Label -and $m.Label -ne $meta.Sub) { Format-CompactText $m.Label 9 } else { $meta.Sub }
            $capTitle = "$($meta.Top) $customLbl"
            $g.DrawString($capTitle, $script:FRoundCap, [Drawing.Brushes]::White, [Drawing.RectangleF]::new(2, $capY, $w - 4, $capH), $script:SfCenter)

            $bBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(45, 55, 72))
            $g.FillRectangle($bBrush, 3, $h - 15, $w - 6, 13)
            $g.DrawString($meta.Sub, $script:FRoundBadge, [Drawing.Brushes]::White, [Drawing.RectangleF]::new(3, $h - 15, $w - 6, 13), $script:SfCenter)
            $bBrush.Dispose()
        }

        $capBrush.Dispose(); $ringPen.Dispose()
    } catch { }
}

$sceneNotes = @(82, 83, 84, 85, 86)
for ($r = 0; $r -lt 5; $r++) {
    $baseNote = (4 - $r) * 8
    for ($c = 0; $c -lt 8; $c++) {
        $note = $baseNote + $c
        $cid  = "Pad_$note"
        $btn  = [GoodCube.ApcDeck.SurfaceTile]::new()
        $btn.Dock = 'Fill'
        $btn.Margin = [Windows.Forms.Padding]::new(2)
        $btn.Tag = $cid
        $btn.Add_Paint($padPaintHandler)
        $script:ControlButtons[$cid] = $btn
        $padsGrid.Controls.Add($btn, $c, $r)
    }
    $sNote = $sceneNotes[$r]
    $sId   = "Scene_$sNote"
    $sBtn  = [GoodCube.ApcDeck.SurfaceTile]::new()
    $sBtn.Dock = 'Fill'
    $sBtn.Margin = [Windows.Forms.Padding]::new(4, 2, 2, 2)
    $sBtn.Tag = $sId
    $sBtn.Add_Paint($roundBtnPaintHandler)
    $script:ControlButtons[$sId] = $sBtn
    $padsGrid.Controls.Add($sBtn, 8, $r)
}

for ($c = 0; $c -lt 8; $c++) {
    $tNote = 64 + $c
    $tId   = "Track_$tNote"
    $tBtn  = [GoodCube.ApcDeck.SurfaceTile]::new()
    $tBtn.Dock = 'Fill'
    $tBtn.Margin = [Windows.Forms.Padding]::new(2, 4, 2, 2)
    $tBtn.Tag = $tId
    $tBtn.Add_Paint($roundBtnPaintHandler)
    $script:ControlButtons[$tId] = $tBtn
    $padsGrid.Controls.Add($tBtn, $c, 5)
}

$stopBtn = [GoodCube.ApcDeck.SurfaceTile]::new()
$stopBtn.Dock = 'Fill'
$stopBtn.Margin = [Windows.Forms.Padding]::new(4, 4, 2, 2)
$stopBtn.Tag = 'Scene_81'
$stopBtn.Add_Paint($roundBtnPaintHandler)
$script:ControlButtons['Scene_81'] = $stopBtn
$padsGrid.Controls.Add($stopBtn, 8, 5)

# ==============================================================================
# 2. UPPER-RIGHT DECK: 2x4 ROTARY KNOB BANK (K1..K8) + TRANSPORT / SHIFT CLUSTER
# ==============================================================================
$rightDeckSplit = [Windows.Forms.TableLayoutPanel]::new()
$rightDeckSplit.Dock = 'Fill'
$rightDeckSplit.ColumnCount = 1
$rightDeckSplit.RowCount = 2
[void]$rightDeckSplit.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 74))
[void]$rightDeckSplit.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 26))
$upperDeck.Controls.Add($rightDeckSplit, 1, 0)

$knobsGroup = [Windows.Forms.GroupBox]::new()
$knobsGroup.Text = '2×4 ROTARY KNOB BANK (K1–K8  ·  MIDI CC 48–55  ·  Turn Knob or Scroll)'
$knobsGroup.Dock = 'Fill'
$knobsGroup.ForeColor = $cCyanSelect
$knobsGroup.BackColor = $cBezelBg
$knobsGroup.Padding = [Windows.Forms.Padding]::new(6, 6, 6, 6)
$rightDeckSplit.Controls.Add($knobsGroup, 0, 0)

$knobsGrid = [Windows.Forms.TableLayoutPanel]::new()
$knobsGrid.Dock = 'Fill'
$knobsGrid.ColumnCount = 4
$knobsGrid.RowCount = 2
for ($c = 0; $c -lt 4; $c++) {
    [void]$knobsGrid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 25))
}
for ($r = 0; $r -lt 2; $r++) {
    [void]$knobsGrid.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 50))
}
$knobsGroup.Controls.Add($knobsGrid)

# Custom 360-degree Rotary Potentiometer Dial painter for K1..K8
$knobPaintHandler = {
    param($sender, $e)
    try {
        $g = $e.Graphics
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $cid = [string]$sender.Tag
        $m   = if ($script:ProfileMap.ContainsKey($cid)) { $script:ProfileMap[$cid] } else { $null }
        $sel = ($cid -eq $script:SelectedId)
        $pct = if ($script:KnobValues.ContainsKey($cid)) { [int]$script:KnobValues[$cid] } else { 0 }
        $cc  = [int]($cid -replace '^Knob_','')
        $kIdx = ($cc - 47)

        $w = $sender.ClientSize.Width
        $h = $sender.ClientSize.Height
        $g.Clear($cBezelBg)

        $cardBg = if ($sel) { [Drawing.Color]::FromArgb(32, 45, 66) } elseif ($pct -eq 0) { [Drawing.Color]::FromArgb(52, 18, 24) } else { $cDeckSurface }
        $cardBrush = [Drawing.SolidBrush]::new($cardBg)
        $g.FillRectangle($cardBrush, 2, 2, $w - 4, $h - 4)

        $borderPen = if ($sel) {
            [Drawing.Pen]::new($cCyanSelect, 2.2)
        } else {
            [Drawing.Pen]::new([Drawing.Color]::FromArgb(55, 65, 81), 1.0)
        }
        $g.DrawRectangle($borderPen, 2, 2, $w - 5, $h - 5)

        # Dial geometry — generously proportioned to fill the 2x4 knob cell
        $dialDiam = [Math]::Max(40, [Math]::Min($w - 20, $h - 54))
        $dialX    = [int](($w - $dialDiam) / 2)
        $dialY    = 20
        $cx       = $dialX + ($dialDiam / 2.0)
        $cy       = $dialY + ($dialDiam / 2.0)

        # Track arc (135 deg to +270 deg sweep)
        $trackPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(51, 65, 85), 4.5)
        $trackPen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $trackPen.EndCap   = [Drawing.Drawing2D.LineCap]::Round
        $g.DrawArc($trackPen, $dialX, $dialY, $dialDiam, $dialDiam, 135, 270)

        $arcColor = if ($pct -eq 0) { $cRedGlow } elseif ($pct -ge 95) { $cGreenGlow } else { $cCyanSelect }
        $valPen = [Drawing.Pen]::new($arcColor, 4.5)
        $valPen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $valPen.EndCap   = [Drawing.Drawing2D.LineCap]::Round
        $sweep = [float]([Math]::Max(4.0, ($pct / 100.0) * 270.0))
        $g.DrawArc($valPen, $dialX, $dialY, $dialDiam, $dialDiam, 135, $sweep)

        # Inner dark anodized rotary cap
        $capInset = 6
        $capBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(17, 20, 27))
        $capPen   = [Drawing.Pen]::new([Drawing.Color]::FromArgb(90, 102, 122), 1.2)
        $g.FillEllipse($capBrush, $dialX + $capInset, $dialY + $capInset, $dialDiam - ($capInset * 2), $dialDiam - ($capInset * 2))
        $g.DrawEllipse($capPen,   $dialX + $capInset, $dialY + $capInset, $dialDiam - ($capInset * 2), $dialDiam - ($capInset * 2))

        # Pointer needle
        $angleDeg = 135.0 + (($pct / 100.0) * 270.0)
        $angleRad = $angleDeg * ([Math]::PI / 180.0)
        $rInner   = ($dialDiam / 2.0) * 0.25
        $rOuter   = ($dialDiam / 2.0) - $capInset - 2.0
        $x1 = [float]($cx + [Math]::Cos($angleRad) * $rInner)
        $y1 = [float]($cy + [Math]::Sin($angleRad) * $rInner)
        $x2 = [float]($cx + [Math]::Cos($angleRad) * $rOuter)
        $y2 = [float]($cy + [Math]::Sin($angleRad) * $rOuter)
        $needlePen = [Drawing.Pen]::new([Drawing.Color]::White, 2.3)
        $needlePen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $needlePen.EndCap   = [Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($needlePen, $x1, $y1, $x2, $y2)

        # Center cap pivot dot
        $g.FillEllipse([Drawing.Brushes]::DimGray, [float]($cx - 3), [float]($cy - 3), 6.0, 6.0)

        $pctText = if ($pct -eq 0) { '0% MUTE' } else { "$pct%" }
        $pctBrush = [Drawing.SolidBrush]::new($arcColor)
        $subBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(148, 163, 184))
        $g.DrawString("K${kIdx}·CC${cc}", $script:FKnobTop, [Drawing.Brushes]::Silver, 5, 4)
        $g.DrawString($pctText, $script:FKnobPct, $pctBrush, [Drawing.RectangleF]::new($w - 58, 3, 54, 14), $script:SfCenter)

        $cleanLbl = if ($m -and $m.Label) { Format-CompactText ($m.Label -replace '^K\d+:\s*','') 15 } else { "KNOB $kIdx" }
        $targetSub = if ($m -and $m.Target) { Format-CompactText $m.Target 16 } elseif ($m) { $m.ActionType } else { 'Unassigned' }
        $g.DrawString($cleanLbl,  $script:FKnobLbl, [Drawing.Brushes]::White, [Drawing.RectangleF]::new(3, $h - 32, $w - 6, 15), $script:SfCenter)
        $g.DrawString($targetSub, $script:FKnobSub, $subBrush,                [Drawing.RectangleF]::new(3, $h - 17, $w - 6, 13), $script:SfCenter)

        $cardBrush.Dispose(); $borderPen.Dispose(); $trackPen.Dispose(); $valPen.Dispose()
        $capBrush.Dispose(); $capPen.Dispose(); $needlePen.Dispose(); $pctBrush.Dispose(); $subBrush.Dispose()
    } catch { }
}

for ($i = 0; $i -lt 8; $i++) {
    $cc  = 48 + $i
    $cid = "Knob_$cc"
    $r   = [int][Math]::Floor($i / 4)
    $c   = $i % 4
    $btn = [GoodCube.ApcDeck.SurfaceTile]::new()
    $btn.Dock = 'Fill'
    $btn.Margin = [Windows.Forms.Padding]::new(3)
    $btn.Tag = $cid
    $btn.Add_Paint($knobPaintHandler)
    $btn.Add_MouseWheel({
        param($sender, $e)
        try {
            $kId = [string]$sender.Tag
            if (-not $script:ProfileMap.ContainsKey($kId)) { return }
            $cur = if ($script:KnobValues.ContainsKey($kId)) { [int]$script:KnobValues[$kId] } else { 50 }
            $step = if ($e.Delta -gt 0) { 2 } else { -2 }
            $newPct = [Math]::Max(0, [Math]::Min(100, $cur + $step))
            $midiVal = [int][Math]::Round(($newPct / 100.0) * 127.0)
            $script:KnobValues[$kId] = $newPct
            $script:LastKnobTurnTick = [Environment]::TickCount64
            $res = Set-AudioVolumeByMapping -Mapping $script:ProfileMap[$kId] -MidiValue $midiVal -AutoMuteAtZero
            $sender.Invalidate()
            Set-StatusBanner "MouseWheel [$($script:ProfileMap[$kId].Label)] -> $res"
        } catch { }
    })
    $script:ControlButtons[$cid] = $btn
    $knobsGrid.Controls.Add($btn, $c, $r)
}

# Transport & Utility Cluster directly under the 2x4 Knob Bank (matching real APC Key 25 right deck)
$transGroup = [Windows.Forms.GroupBox]::new()
$transGroup.Text = 'TRANSPORT, OCTAVE && SHIFT CLUSTER (MIDI Ch 1 Notes 91, 93, 98)'
$transGroup.Dock = 'Fill'
$transGroup.ForeColor = [Drawing.Color]::FromArgb(148, 163, 184)
$transGroup.BackColor = $cBezelBg
$transGroup.Padding = [Windows.Forms.Padding]::new(6, 4, 6, 4)
$rightDeckSplit.Controls.Add($transGroup, 0, 1)

$transGrid = [Windows.Forms.TableLayoutPanel]::new()
$transGrid.Dock = 'Fill'
$transGrid.ColumnCount = 3
$transGrid.RowCount = 2
for ($c = 0; $c -lt 3; $c++) {
    [void]$transGrid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 33.33))
}
[void]$transGrid.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 42))
[void]$transGrid.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent, 58))
$transGroup.Controls.Add($transGrid)

# Top row of cluster: Hardware-internal reference badges (SUSTAIN, OCT -, OCT +)
$hwRefBadges = @('SUSTAIN (HW)', 'OCT − (HW KEYBED)', 'OCT + (HW KEYBED)')
for ($c = 0; $c -lt 3; $c++) {
    $lblHw = [Windows.Forms.Label]::new()
    $lblHw.Text = $hwRefBadges[$c]
    $lblHw.Dock = 'Fill'
    $lblHw.Margin = [Windows.Forms.Padding]::new(3, 1, 3, 1)
    $lblHw.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $lblHw.BackColor = [Drawing.Color]::FromArgb(20, 23, 30)
    $lblHw.ForeColor = [Drawing.Color]::FromArgb(100, 116, 139)
    $lblHw.Font = [Drawing.Font]::new('Segoe UI', 7.2, [Drawing.FontStyle]::Bold)
    $transGrid.Controls.Add($lblHw, $c, 0)
}

# Bottom row of cluster: Mappable Physical Transport Buttons (Play_91, Rec_93, Shift_98)
$transDefs = @(
    @{ Id = 'Trans_91'; Hw = '► / ❚❚  PLAY'; Note = 91 },
    @{ Id = 'Trans_93'; Hw = '●  REC';       Note = 93 },
    @{ Id = 'Trans_98'; Hw = 'SHIFT';        Note = 98 }
)
for ($c = 0; $c -lt 3; $c++) {
    $td = $transDefs[$c]
    $tBtn = [GoodCube.ApcDeck.BufferedButton]::new()
    $tBtn.Dock = 'Fill'
    $tBtn.Margin = [Windows.Forms.Padding]::new(3, 2, 3, 2)
    $tBtn.FlatStyle = 'Flat'
    $tBtn.FlatAppearance.BorderSize = 1
    $tBtn.Font = [Drawing.Font]::new('Segoe UI Semibold', 7.8, [Drawing.FontStyle]::Bold)
    $tBtn.Tag = $td.Id
    $script:ControlButtons[$td.Id] = $tBtn
    $transGrid.Controls.Add($tBtn, $c, 1)
}

# ==============================================================================
# 3. BOTTOM DECK: REALISTIC 25-NOTE OVERLAPPING SYNTH-ACTION PIANO KEYBOARD
# ==============================================================================
$keysGroup = [Windows.Forms.GroupBox]::new()
$keysGroup.Text = '25 SYNTH-ACTION PIANO KEYBOARD (C3 – C5  ·  MIDI Ch 2 Notes 48–72  ·  15 White Keys + 10 Recessed Black Sharp/Flat Keys)'
$keysGroup.Dock = 'Fill'
$keysGroup.ForeColor = $cAmberGlow
$keysGroup.BackColor = $cBezelBg
$keysGroup.Padding = [Windows.Forms.Padding]::new(8, 6, 8, 8)
$chassisLayout.Controls.Add($keysGroup, 0, 1)

$keybedCanvas = [GoodCube.ApcDeck.BufferedPanel]::new()
$keybedCanvas.Dock = 'Fill'
$keybedCanvas.BackColor = [Drawing.Color]::FromArgb(12, 14, 18)
$keybedCanvas.Cursor = [Windows.Forms.Cursors]::Hand
$keysGroup.Controls.Add($keybedCanvas)

# Map MIDI Notes 48..72 into 15 White Keys and 10 Black Keys with exact musical offsets
$whiteNotes = @(48, 50, 52, 53, 55, 57, 59, 60, 62, 64, 65, 67, 69, 71, 72)
# Each black key sits between white key index W and W+1:
$blackKeySpecs = @(
    @{ Note = 49; AfterWhiteIdx = 0 },  # C#3
    @{ Note = 51; AfterWhiteIdx = 1 },  # D#3
    @{ Note = 54; AfterWhiteIdx = 3 },  # F#3
    @{ Note = 56; AfterWhiteIdx = 4 },  # G#3
    @{ Note = 58; AfterWhiteIdx = 5 },  # A#3
    @{ Note = 61; AfterWhiteIdx = 7 },  # C#4
    @{ Note = 63; AfterWhiteIdx = 8 },  # D#4
    @{ Note = 66; AfterWhiteIdx = 10 }, # F#4
    @{ Note = 68; AfterWhiteIdx = 11 }, # G#4
    @{ Note = 70; AfterWhiteIdx = 12 }  # A#4
)

$script:WhiteKeyRects = @{}
$script:BlackKeyRects = @{}
$script:HoveredKeyId  = ''

function Update-PianoKeybedGeometry {
    $cw = $keybedCanvas.ClientSize.Width
    $ch = $keybedCanvas.ClientSize.Height
    if ($cw -le 50 -or $ch -le 30) { return }

    $whiteCount = 15
    $whiteW = [double]$cw / $whiteCount
    $whiteH = $ch - 4

    for ($idx = 0; $idx -lt $whiteCount; $idx++) {
        $n   = $whiteNotes[$idx]
        $x   = [int][Math]::Round($idx * $whiteW)
        $nx  = [int][Math]::Round(($idx + 1) * $whiteW)
        $w   = [Math]::Max(20, ($nx - $x - 2))
        $script:WhiteKeyRects["Key_$n"] = [Drawing.Rectangle]::new($x + 1, 2, $w, $whiteH)
    }

    $blackW = [int][Math]::Max(22, [Math]::Round($whiteW * 0.62))
    $blackH = [int][Math]::Max(28, [Math]::Round($whiteH * 0.61))
    foreach ($bk in $blackKeySpecs) {
        $centerX = [int][Math]::Round(($bk.AfterWhiteIdx + 1) * $whiteW)
        $bx = $centerX - [int]($blackW / 2)
        $script:BlackKeyRects["Key_$($bk.Note)"] = [Drawing.Rectangle]::new($bx, 2, $blackW, $blackH)
    }
    $keybedCanvas.Invalidate()
}

function Get-PianoKeyAtPoint([int]$x, [int]$y) {
    # Check recessed Black Keys FIRST since they sit physically on top of White Keys
    foreach ($bk in $blackKeySpecs) {
        $kId = "Key_$($bk.Note)"
        if ($script:BlackKeyRects.ContainsKey($kId) -and $script:BlackKeyRects[$kId].Contains($x, $y)) {
            return $kId
        }
    }
    foreach ($n in $whiteNotes) {
        $kId = "Key_$n"
        if ($script:WhiteKeyRects.ContainsKey($kId) -and $script:WhiteKeyRects[$kId].Contains($x, $y)) {
            return $kId
        }
    }
    return $null
}

$keybedCanvas.Add_Paint({
    param($sender, $e)
    try {
        $g = $e.Graphics
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $g.Clear([Drawing.Color]::FromArgb(10, 12, 16))

        if ($script:WhiteKeyRects.Count -eq 0) { Update-PianoKeybedGeometry }
        $noteNames = @('C','C#','D','D#','E','F','F#','G','G#','A','A#','B')

        # PASS 1: Render 15 Full-Height White Piano Keys (Notes 48, 50, 52..72)
        foreach ($n in $whiteNotes) {
            $kId = "Key_$n"
            if (-not $script:WhiteKeyRects.ContainsKey($kId)) { continue }
            $rc  = $script:WhiteKeyRects[$kId]
            $m   = if ($script:ProfileMap.ContainsKey($kId)) { $script:ProfileMap[$kId] } else { $null }
            $sel = ($kId -eq $script:SelectedId)
            $hov = ($kId -eq $script:HoveredKeyId)
            $oct = [int][Math]::Floor(($n / 12) - 1)
            $noteName = $noteNames[$n % 12] + $oct

            $hasColor = ($m -and $m.LedColor -notin @('Auto','Off',''))
            $active   = ($m -and $m.ActionType -ne 'None')

            $keyFill = if ($hasColor) {
                Get-UiColorForColorName $m.LedColor $cKeyMapped
            } elseif ($active) {
                $cKeyMapped
            } elseif ($hov) {
                [Drawing.Color]::FromArgb(241, 245, 249)
            } else {
                $cKeyWhite
            }

            $kb = [Drawing.SolidBrush]::new($keyFill)
            $g.FillRectangle($kb, $rc)
            $kb.Dispose()

            # Bottom 3D lip bevel on white key
            $lipCol = if ($hasColor -or $active) { [Drawing.Color]::FromArgb(70, 0, 0, 0) } else { [Drawing.Color]::FromArgb(180, 190, 205) }
            $lipBrush = [Drawing.SolidBrush]::new($lipCol)
            $g.FillRectangle($lipBrush, $rc.X, $rc.Bottom - 6, $rc.Width, 6)
            $lipBrush.Dispose()

            $borderPen = if ($sel) {
                [Drawing.Pen]::new($cCyanSelect, 2.8)
            } else {
                [Drawing.Pen]::new([Drawing.Color]::FromArgb(100, 116, 139), 1.0)
            }
            $g.DrawRectangle($borderPen, $rc.X, $rc.Y, $rc.Width - 1, $rc.Height - 1)
            $borderPen.Dispose()

            $txtBrush = if ($hasColor -or $active) { [Drawing.Brushes]::White } else { [Drawing.Brushes]::DarkSlateGray }
            if ($active -or ($m -and $m.Label -and $m.Label -ne $noteName -and $m.Label -ne "KEY $noteName")) {
                $lblTxt = Format-CompactText $m.Label 9
                $g.DrawString($lblTxt, $script:FKeyLblW, $txtBrush, [Drawing.RectangleF]::new($rc.X + 1, $rc.Bottom - 38, $rc.Width - 2, 15), $script:SfBottom)
            }
            $g.DrawString($noteName, $script:FKeyNoteW, $txtBrush, [Drawing.RectangleF]::new($rc.X + 1, $rc.Bottom - 22, $rc.Width - 2, 16), $script:SfBottom)
        }

        # PASS 2: Render 10 Recessed Black Sharp/Flat Keys directly ON TOP of White Keys
        $shadowBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(115, 0, 0, 0))
        foreach ($bk in $blackKeySpecs) {
            $n   = $bk.Note
            $kId = "Key_$n"
            if (-not $script:BlackKeyRects.ContainsKey($kId)) { continue }
            $rc  = $script:BlackKeyRects[$kId]
            $m   = if ($script:ProfileMap.ContainsKey($kId)) { $script:ProfileMap[$kId] } else { $null }
            $sel = ($kId -eq $script:SelectedId)
            $hov = ($kId -eq $script:HoveredKeyId)
            $oct = [int][Math]::Floor(($n / 12) - 1)
            $noteName = $noteNames[$n % 12] + $oct

            # Drop shadow cast by raised black key onto the white keys beneath
            $g.FillRectangle($shadowBrush, $rc.X - 2, $rc.Y, $rc.Width + 5, $rc.Height + 4)

            $hasColor = ($m -and $m.LedColor -notin @('Auto','Off',''))
            $active   = ($m -and $m.ActionType -ne 'None')

            $bFill = if ($hasColor) {
                Get-UiColorForColorName $m.LedColor $cKeyMapped
            } elseif ($active) {
                [Drawing.Color]::FromArgb(14, 116, 144)
            } elseif ($hov) {
                [Drawing.Color]::FromArgb(40, 48, 64)
            } else {
                $cKeyBlack
            }

            $bb = [Drawing.SolidBrush]::new($bFill)
            $g.FillRectangle($bb, $rc)
            $bb.Dispose()

            # Subtle 3D glossy inner bevel highlight on the black key cap
            $inPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(65, 255, 255, 255), 1.0)
            $g.DrawRectangle($inPen, $rc.X + 3, $rc.Y + 2, $rc.Width - 7, $rc.Height - 8)
            $inPen.Dispose()

            $bPen = if ($sel) {
                [Drawing.Pen]::new($cCyanSelect, 2.5)
            } else {
                [Drawing.Pen]::new([Drawing.Color]::FromArgb(71, 85, 105), 1.2)
            }
            $g.DrawRectangle($bPen, $rc.X, $rc.Y, $rc.Width - 1, $rc.Height - 1)
            $bPen.Dispose()

            if ($active -or ($m -and $m.Label -and $m.Label -ne $noteName -and $m.Label -ne "KEY $noteName")) {
                $lblTxt = Format-CompactText $m.Label 7
                $g.DrawString($lblTxt, $script:FKeyLblB, [Drawing.Brushes]::Cyan, [Drawing.RectangleF]::new($rc.X + 1, $rc.Bottom - 34, $rc.Width - 2, 13), $script:SfBottom)
            }
            $g.DrawString($noteName, $script:FKeyNoteB, [Drawing.Brushes]::WhiteSmoke, [Drawing.RectangleF]::new($rc.X + 1, $rc.Bottom - 20, $rc.Width - 2, 15), $script:SfBottom)
        }
        $shadowBrush.Dispose()
    } catch { }
})

$keybedCanvas.Add_MouseMove({
    param($sender, $e)
    $hit = Get-PianoKeyAtPoint $e.X $e.Y
    $newHov = if ($hit) { $hit } else { '' }
    if ($newHov -ne $script:HoveredKeyId) {
        $script:HoveredKeyId = $newHov
        $keybedCanvas.Invalidate()
    }
})

$keybedCanvas.Add_MouseLeave({
    if ($script:HoveredKeyId -ne '') {
        $script:HoveredKeyId = ''
        $keybedCanvas.Invalidate()
    }
})

$keybedCanvas.Add_MouseDown({
    param($sender, $e)
    $cid = Get-PianoKeyAtPoint $e.X $e.Y
    if (-not $cid) { return }
    Select-ApcControl $cid
    if ($e.Button -eq [Windows.Forms.MouseButtons]::Right) {
        $btnTest.PerformClick()
    } elseif ($script:ProfileMap.ContainsKey($cid)) {
        $m = $script:ProfileMap[$cid]
        Set-StatusBanner "Selected Piano Key $cid [$($m.Label)] -> Action=$($m.ActionType) Target='$($m.Target)' Color=$($m.LedColor) (Right-click to test)"
    }
})

$keybedCanvas.Add_Resize({ Update-PianoKeybedGeometry })

# ==============================================================================
# 4. RIGHT PANEL: STREAM DECK PROPERTY INSPECTOR & COLOR CUSTOMIZER
# ==============================================================================
$inspectorGroup = [Windows.Forms.GroupBox]::new()
$inspectorGroup.Text = 'STREAM DECK INSPECTOR  ·  PAD && KEY COLORING  ·  KNOB CALIBRATION'
$inspectorGroup.Dock = 'Fill'
$inspectorGroup.Padding = [Windows.Forms.Padding]::new(8, 6, 8, 6)
$inspectorGroup.BackColor = $cInspectorBg
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
    $l.UseMnemonic = $false
    $l.AutoSize = $true
    $l.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 0)
    $l.Font = if ($bold) { [Drawing.Font]::new('Segoe UI Semibold', 9.5, [Drawing.FontStyle]::Bold) } else { [Drawing.Font]::new('Segoe UI', 8.2) }
    $l.ForeColor = if ($bold) { $cCyanSelect } else { [Drawing.Color]::FromArgb(203, 213, 225) }
    [void]$inspFlow.Controls.Add($l)
    return $l
}

$lblSelectedHeader = Add-InspectorLabel 'Selected: Pad_32' $true
$lblSelectedMeta   = Add-InspectorLabel 'Type: Pad  |  MIDI Ch 1  |  Code: 32' $false

$chkMidiLearn = [Windows.Forms.CheckBox]::new()
$chkMidiLearn.Text = 'Auto-Select on Physical Touch (MIDI Learn)'
$chkMidiLearn.Checked = $true
$chkMidiLearn.AutoSize = $true
$chkMidiLearn.ForeColor = $cGreenGlow
$chkMidiLearn.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 0)
[void]$inspFlow.Controls.Add($chkMidiLearn)

$chkEditOnly = [Windows.Forms.CheckBox]::new()
$chkEditOnly.Text = 'Edit-Only Mode (Mute actions while mapping)'
$chkEditOnly.Checked = $false
$chkEditOnly.AutoSize = $true
$chkEditOnly.ForeColor = $cAmberGlow
$chkEditOnly.Margin = [Windows.Forms.Padding]::new(2, 0, 2, 0)
[void]$inspFlow.Controls.Add($chkEditOnly)

$chkPickupMode = [Windows.Forms.CheckBox]::new()
$chkPickupMode.Text = 'Knob Soft-Takeover (Pickup mode — prevent jumps)'
$chkPickupMode.Checked = $false
$chkPickupMode.AutoSize = $true
$chkPickupMode.ForeColor = [Drawing.Color]::FromArgb(125, 211, 252)
$chkPickupMode.Margin = [Windows.Forms.Padding]::new(2, 0, 2, 2)
[void]$inspFlow.Controls.Add($chkPickupMode)

[void](Add-InspectorLabel 'Custom Button / Knob Label:')
$txtLabel = [Windows.Forms.TextBox]::new()
$txtLabel.Width = 350
$txtLabel.MaxLength = 36
$txtLabel.BackColor = $cFieldBg
$txtLabel.ForeColor = [Drawing.Color]::White
$txtLabel.BorderStyle = 'FixedSingle'
[void]$inspFlow.Controls.Add($txtLabel)

[void](Add-InspectorLabel 'Action Type:')
$cmbAction = [Windows.Forms.ComboBox]::new()
$cmbAction.Width = 350
$cmbAction.DropDownStyle = 'DropDownList'
$cmbAction.BackColor = $cFieldBg
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
$cmbTarget1.Width = 350
$cmbTarget1.DropDownStyle = 'DropDown'
$cmbTarget1.BackColor = $cFieldBg
$cmbTarget1.ForeColor = [Drawing.Color]::White
[void]$inspFlow.Controls.Add($cmbTarget1)

$lblValidation = [Windows.Forms.Label]::new()
$lblValidation.Text = 'Ready.'
$lblValidation.AutoSize = $true
$lblValidation.Font = [Drawing.Font]::new('Segoe UI', 7.6)
$lblValidation.ForeColor = [Drawing.Color]::FromArgb(148, 163, 184)
$lblValidation.Margin = [Windows.Forms.Padding]::new(2, 0, 2, 1)
[void]$inspFlow.Controls.Add($lblValidation)

$lblTarget2 = Add-InspectorLabel 'Secondary Target (Device B for Swap A <-> B):'
$cmbTarget2 = [Windows.Forms.ComboBox]::new()
$cmbTarget2.Width = 350
$cmbTarget2.DropDownStyle = 'DropDown'
$cmbTarget2.BackColor = $cFieldBg
$cmbTarget2.ForeColor = [Drawing.Color]::White
[void]$inspFlow.Controls.Add($cmbTarget2)

[void](Add-InspectorLabel 'Active / ON Hardware LED & Key Color:')
$cmbLed = [Windows.Forms.ComboBox]::new()
$cmbLed.Width = 350
$cmbLed.DropDownStyle = 'DropDownList'
$cmbLed.BackColor = $cFieldBg
$cmbLed.ForeColor = [Drawing.Color]::White
[void]$cmbLed.Items.AddRange(@('Auto', 'Green', 'BlinkGreen', 'Amber', 'BlinkAmber', 'Red', 'BlinkRed', 'Off'))
[void]$inspFlow.Controls.Add($cmbLed)

[void](Add-InspectorLabel 'Standby / Muted / OFF Pad LED Color:')
$cmbOffLed = [Windows.Forms.ComboBox]::new()
$cmbOffLed.Width = 350
$cmbOffLed.DropDownStyle = 'DropDownList'
$cmbOffLed.BackColor = $cFieldBg
$cmbOffLed.ForeColor = [Drawing.Color]::White
[void]$cmbOffLed.Items.AddRange(@('Auto', 'Amber', 'Red', 'Green', 'BlinkAmber', 'BlinkRed', 'BlinkGreen', 'Off'))
[void]$inspFlow.Controls.Add($cmbOffLed)

[void](Add-InspectorLabel '1-Click Instant Hardware Pad / Key Color Swatches:')
$swatchPanel = [Windows.Forms.FlowLayoutPanel]::new()
$swatchPanel.Width = 355
$swatchPanel.Height = 28
$swatchPanel.Margin = [Windows.Forms.Padding]::new(0, 1, 0, 2)
[void]$inspFlow.Controls.Add($swatchPanel)

$swatchDefs = @(
    @{ Name='Green';      Label='Green';   Bg=$cGreenFill },
    @{ Name='Amber';      Label='Amber';   Bg=$cAmberFill },
    @{ Name='Red';        Label='Red';     Bg=$cRedFill },
    @{ Name='BlinkGreen'; Label='Blink G'; Bg=$cGreenBlink },
    @{ Name='BlinkAmber'; Label='Blink A'; Bg=$cAmberBlink },
    @{ Name='BlinkRed';   Label='Blink R'; Bg=$cRedBlink },
    @{ Name='Off';        Label='Off';     Bg=$cPadUnmapped }
)
foreach ($sw in $swatchDefs) {
    $sb = [Windows.Forms.Button]::new()
    $sb.Text = $sw.Label
    $sb.Tag  = $sw.Name
    $sb.Width = 46
    $sb.Height = 24
    $sb.Margin = [Windows.Forms.Padding]::new(2, 1, 2, 1)
    $sb.FlatStyle = 'Flat'
    $sb.BackColor = $sw.Bg
    $sb.ForeColor = [Drawing.Color]::White
    $sb.Font = [Drawing.Font]::new('Segoe UI', 7.0, [Drawing.FontStyle]::Bold)
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
    $b.UseMnemonic = $false
    $b.Width = 350
    $b.Height = 27
    $b.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 0)
    $b.FlatStyle = 'Flat'
    $b.BackColor = $bg
    $b.ForeColor = [Drawing.Color]::White
    $b.Font = [Drawing.Font]::new('Segoe UI Semibold', 8.5, [Drawing.FontStyle]::Bold)
    [void]$inspFlow.Controls.Add($b)
    return $b
}

$btnSave     = New-ActionBtn 'Apply & Save Mapping  (Ctrl+S)' ([Drawing.Color]::FromArgb(2, 132, 199))
$btnTest     = New-ActionBtn 'Test Selected Action Now  (Ctrl+T)' ([Drawing.Color]::FromArgb(22, 101, 52))
$btnZeroKnob = New-ActionBtn 'Zero-Out Selected Knob / Device (0% Mute)' ([Drawing.Color]::FromArgb(153, 27, 27))
$btnClear    = New-ActionBtn 'Clear This Control (Set None)' ([Drawing.Color]::FromArgb(71, 85, 105))
$btnRefresh  = New-ActionBtn 'Refresh Devices & Sync LEDs  (F5)' ([Drawing.Color]::FromArgb(51, 65, 85))
$btnTray     = New-ActionBtn 'Minimize to System Tray (Keep Active)' ([Drawing.Color]::FromArgb(49, 46, 129))
$btnReset    = New-ActionBtn 'Reset Entire Profile to Defaults' ([Drawing.Color]::FromArgb(127, 29, 29))

$inspFlow.Add_Resize({
    $targetW = [Math]::Max(240, $inspFlow.ClientSize.Width - 10)
    foreach ($ctrl in @($txtLabel, $cmbAction, $cmbTarget1, $cmbTarget2, $cmbLed, $cmbOffLed, $swatchPanel, $btnSave, $btnTest, $btnZeroKnob, $btnClear, $btnRefresh, $btnTray, $btnReset)) {
        if ($null -ne $ctrl) { $ctrl.Width = $targetW }
    }
})

# Bottom Status & Live MIDI Telemetry Bar
$statusBox = [Windows.Forms.TextBox]::new()
$statusBox.Dock = 'Fill'
$statusBox.Multiline = $true
$statusBox.ReadOnly = $true
$statusBox.BackColor = [Drawing.Color]::FromArgb(11, 14, 19)
$statusBox.ForeColor = [Drawing.Color]::FromArgb(125, 211, 252)
$statusBox.BorderStyle = 'None'
$statusBox.Font = [Drawing.Font]::new('Consolas', 9.2)
$rootLayout.Controls.Add($statusBox, 0, 2)

function Set-StatusBanner([string]$eventText) {
    $isOpen = [GoodCube.ApcDeck.NativeBridge]::IsOpen
    $midiState = if ($isOpen) { 'ONLINE (IN + LED OUT)' } else { 'OFFLINE' }
    $statusBox.Text = "MIDI: $midiState  |  Speaker: $($script:CachedSpeakerSummary)  |  Mic: $($script:CachedMicSummary)`r`nEvent: $(Format-CompactText $eventText 135)"
    if ($isOpen -ne $script:LastMidiOpenState) {
        $script:LastMidiOpenState = $isOpen
        $headerPanel.Invalidate()
    }
}

function Validate-InspectorInput {
    if ($script:SuppressInspectorEvents) { return }
    $act = [string]$cmbAction.SelectedItem
    $t1  = $cmbTarget1.Text.Trim()
    if ($act -eq 'Hotkey') {
        $parsed = Parse-HotkeyChord -ChordText $t1
        if ($parsed) {
            $lblValidation.Text = "✓ Valid hotkey chord ($t1)"
            $lblValidation.ForeColor = $cGreenGlow
        } else {
            $lblValidation.Text = "⚠ Enter chord like Alt+Q, Win+H, Ctrl+Shift+M, or F13"
            $lblValidation.ForeColor = $cAmberGlow
        }
    } elseif ($act -in @('VolumeDevice','SetDefaultDevice','SwapDevices','MuteToggle','EndpointEnableToggle')) {
        if ($t1 -in @('@DefaultRender', '@DefaultCapture')) {
            $lblValidation.Text = "✓ Dynamic default endpoint ($t1)"
            $lblValidation.ForeColor = $cGreenGlow
            return
        }
        # Fast in-memory snapshot match (0.01ms instead of 800ms COM enumeration)
        $matchedEp = $null
        if (-not [string]::IsNullOrWhiteSpace($t1)) {
            foreach ($ep in $script:AudioSnapshot) {
                if ($ep.ID -ieq $t1 -or $ep.FriendlyName -ieq $t1 -or $ep.FriendlyName.IndexOf($t1, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $matchedEp = $ep
                    if ($ep.State -eq 'Active') { break }
                }
            }
        }
        if ($matchedEp) {
            $stateTag = if ($matchedEp.State -ne 'Active') { " [$($matchedEp.State)]" } else { '' }
            $lblValidation.Text = "✓ Matched: $(Format-CompactText $matchedEp.FriendlyName 28)$stateTag"
            $lblValidation.ForeColor = if ($matchedEp.State -eq 'Active') { $cGreenGlow } else { $cAmberGlow }
        } else {
            $lblValidation.Text = "⚠ No local endpoint matching '$t1'"
            $lblValidation.ForeColor = $cAmberGlow
        }
    } else {
        $lblValidation.Text = "Action: $act"
        $lblValidation.ForeColor = [Drawing.Color]::FromArgb(148, 163, 184)
    }
}

$cmbTarget1.Add_TextChanged({ Validate-InspectorInput })

function Populate-TargetDropdowns([string]$actionType) {
    $wasSuppressed = $script:SuppressInspectorEvents
    $script:SuppressInspectorEvents = $true
    try {
        $cur1 = $cmbTarget1.Text
        $cur2 = $cmbTarget2.Text
        $cmbTarget1.BeginUpdate()
        $cmbTarget2.BeginUpdate()
        $cmbTarget1.Items.Clear()
        $cmbTarget2.Items.Clear()

        $audioNames = @('@DefaultRender', '@DefaultCapture') + @($script:AudioSnapshot | ForEach-Object { $_.FriendlyName } | Select-Object -Unique)
        foreach ($n in $audioNames) { [void]$cmbTarget2.Items.Add($n) }

        switch ($actionType) {
            { $_ -in @('VolumeDevice','SetDefaultDevice','SwapDevices','MuteToggle','EndpointEnableToggle') } {
                foreach ($n in $audioNames) { [void]$cmbTarget1.Items.Add($n) }
            }
            'VolumeMasterOut'  { [void]$cmbTarget1.Items.Add('@DefaultRender') }
            'VolumeDefaultMic' { [void]$cmbTarget1.Items.Add('@DefaultCapture') }
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
        $cmbTarget1.EndUpdate()
        $cmbTarget2.EndUpdate()
    } finally {
        $script:SuppressInspectorEvents = $wasSuppressed
    }
    if (-not $script:SuppressInspectorEvents) {
        Validate-InspectorInput
    }
}

function Get-UiColorForColorName([string]$colorName, [Drawing.Color]$fallback) {
    switch ($colorName) {
        'Green'      { return $cGreenFill }
        'BlinkGreen' { return $cGreenBlink }
        'Red'        { return $cRedFill }
        'BlinkRed'   { return $cRedBlink }
        'Amber'      { return $cAmberFill }
        'BlinkAmber' { return $cAmberBlink }
        'Off'        { return $cPadUnmapped }
        default      { return $fallback }
    }
}

function Invalidate-ApcControl([string]$cid) {
    if ([string]::IsNullOrEmpty($cid)) { return }
    if ($cid.StartsWith('Key_')) {
        $keybedCanvas.Invalidate()
        return
    }
    if ($script:ControlButtons.ContainsKey($cid)) {
        $btn = $script:ControlButtons[$cid]
        if ($cid.StartsWith('Trans_')) {
            $m = if ($script:ProfileMap.ContainsKey($cid)) { $script:ProfileMap[$cid] } else { $null }
            $sel = ($cid -eq $script:SelectedId)
            $active = ($m -and $m.ActionType -ne 'None')
            $btn.BackColor = if ($active) { Get-UiColorForColorName $m.LedColor ([Drawing.Color]::FromArgb(30, 58, 95)) } else { $cPadUnmapped }
            $btn.ForeColor = [Drawing.Color]::White
            $btn.Text = if ($m -and $m.Label) { Format-CompactText $m.Label 16 } else { $cid }
            $btn.FlatAppearance.BorderColor = if ($sel) { $cCyanSelect } else { [Drawing.Color]::FromArgb(71, 85, 105) }
            $btn.FlatAppearance.BorderSize  = if ($sel) { 2 } else { 1 }
        } else {
            $btn.Invalidate()
        }
    }
}

function Update-SurfaceButtonsVisuals {
    $null = Update-PadVelocitiesCache
    foreach ($kv in $script:ControlButtons.GetEnumerator()) {
        Invalidate-ApcControl ([string]$kv.Key)
    }
    $keybedCanvas.Invalidate()
}

function Select-ApcControl([string]$cid) {
    if (-not $script:ProfileMap.ContainsKey($cid)) { return }
    $oldId = $script:SelectedId
    $script:SelectedId = $cid
    $m = $script:ProfileMap[$cid]
    $script:SuppressInspectorEvents = $true
    try {
        $lblSelectedHeader.Text = "Selected: $($m.ControlId) — $($m.Label)"
        $lblSelectedMeta.Text   = "Kind: $($m.ControlKind)  |  MIDI Ch $($m.Channel + 1)  |  Code: $($m.Code)"
        $txtLabel.Text          = [string]$m.Label
        $actStr = if ($cmbAction.Items.Contains([string]$m.ActionType)) { [string]$m.ActionType } else { 'None' }
        if ([string]$cmbAction.SelectedItem -ne $actStr) {
            $cmbAction.SelectedItem = $actStr
            Populate-TargetDropdowns $actStr
        } elseif ($cmbTarget1.Items.Count -eq 0) {
            Populate-TargetDropdowns $actStr
        }
        $cmbTarget1.Text        = [string]$m.Target
        $cmbTarget2.Text        = [string]$m.SecondaryTarget
        $cmbTarget2.Enabled     = ($actStr -eq 'SwapDevices')
        $ledVal = if ($m.PSObject.Properties['LedColor'] -and $cmbLed.Items.Contains([string]$m.LedColor)) { [string]$m.LedColor } else { 'Auto' }
        $offVal = if ($m.PSObject.Properties['OffLedColor'] -and $cmbOffLed.Items.Contains([string]$m.OffLedColor)) { [string]$m.OffLedColor } else { 'Auto' }
        $cmbLed.SelectedItem    = $ledVal
        $cmbOffLed.SelectedItem = $offVal
    } finally {
        $script:SuppressInspectorEvents = $false
    }
    Validate-InspectorInput
    if ($oldId -ne $cid) {
        Invalidate-ApcControl $oldId
    }
    Invalidate-ApcControl $cid
}

# Wire surface button clicks (Left-Click selects; Right-Click selects AND tests action immediately)
foreach ($btn in $script:ControlButtons.Values) {
    $btn.Add_Click({
        $cid = [string]$this.Tag
        Select-ApcControl $cid
        if ($script:ProfileMap.ContainsKey($cid)) {
            $m = $script:ProfileMap[$cid]
            Set-StatusBanner "Selected $cid [$($m.Label)] -> Action=$($m.ActionType) Target='$($m.Target)' LED=$($m.LedColor) (Right-click to test)"
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
    if (-not $script:SuppressInspectorEvents) {
        Populate-TargetDropdowns ([string]$cmbAction.SelectedItem)
    }
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
    $null = Save-ApcProfile -ProfileMap $script:ProfileMap
    Clear-AudioEndpointCache
    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
    Update-CachedTelemetrySummaries
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot -Force
    $null = Update-PadVelocitiesCache
    Select-ApcControl $cid
    Set-StatusBanner "Saved mapping for $cid ($($m.Label) -> $($m.ActionType) $($m.Target), LED=$($m.LedColor)/$($m.OffLedColor))"
})

$btnTest.Add_Click({
    $cid = $script:SelectedId
    if (-not $script:ProfileMap.ContainsKey($cid)) { return }
    $m = $script:ProfileMap[$cid]
    if ($cid.StartsWith('Knob_')) {
        $res = Set-AudioVolumeByMapping -Mapping $m -MidiValue 64
        $script:KnobValues[$cid] = 50
    } else {
        $res = Invoke-ApcAction -Mapping $m
    }
    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
    $script:BtSnapshot    = @(Get-PairedBluetoothDevices -AudioSnapshot $script:AudioSnapshot)
    Update-CachedTelemetrySummaries
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
    Update-SurfaceButtonsVisuals
    Set-StatusBanner "[TEST $cid] $res"
})

$btnZeroKnob.Add_Click({
    $cid = $script:SelectedId
    if (-not $script:ProfileMap.ContainsKey($cid)) { return }
    $m = $script:ProfileMap[$cid]
    if ($cid.StartsWith('Knob_')) {
        $script:KnobValues[$cid]   = 0
        $script:KnobPickedUp[$cid] = $true
        $msg = Set-AudioVolumeByMapping -Mapping $m -MidiValue 0 -AutoMuteAtZero
    } else {
        $ep = Resolve-AudioEndpoint -MatchPattern $m.Target -UseCache
        if ($ep) {
            $ep.AudioEndpointVolume.MasterVolumeLevelScalar = [float]0.0
            $ep.AudioEndpointVolume.Mute = $true
            $msg = "$($ep.FriendlyName): 0% (ZEROED/MUTED)"
        } else {
            $msg = 'Select a knob or audio device button to zero out.'
        }
    }
    $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
    Update-CachedTelemetrySummaries
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
    Update-SurfaceButtonsVisuals
    Set-StatusBanner "[ZERO OUT] $cid -> $msg"
})

$btnClear.Add_Click({
    $cid = $script:SelectedId
    if (-not $script:ProfileMap.ContainsKey($cid)) { return }
    $m = $script:ProfileMap[$cid]
    $m.ActionType      = 'None'
    $m.Target          = ''
    $m.SecondaryTarget = ''
    $m.LedColor        = 'Off'
    $m.OffLedColor     = 'Off'
    $null = Save-ApcProfile -ProfileMap $script:ProfileMap
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot -Force
    $null = Update-PadVelocitiesCache
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
    Update-CachedTelemetrySummaries
    foreach ($cc in 48..55) {
        $kId = "Knob_$cc"
        $cur = Get-CurrentMappingVolumePct -Mapping $script:ProfileMap[$kId]
        if ($null -ne $cur) { $script:KnobValues[$kId] = $cur }
    }
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot -Force
    Update-SurfaceButtonsVisuals
    $headerPanel.Invalidate()
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
    Update-CachedTelemetrySummaries
    Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot -Force
    Update-SurfaceButtonsVisuals
    Select-ApcControl $script:SelectedId
    Set-StatusBanner 'Reset entire profile to default workstation audio/Bluetooth layout.'
})

# Keyboard shortcuts (Ctrl+S Save, Ctrl+T Test, F5 Refresh, Ctrl+0 Zero-Out)
$form.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq [Windows.Forms.Keys]::S) {
        $e.SuppressKeyPress = $true
        $btnSave.PerformClick()
    } elseif ($e.Control -and $e.KeyCode -eq [Windows.Forms.Keys]::T) {
        $e.SuppressKeyPress = $true
        $btnTest.PerformClick()
    } elseif ($e.KeyCode -eq [Windows.Forms.Keys]::F5) {
        $e.SuppressKeyPress = $true
        $btnRefresh.PerformClick()
    } elseif ($e.Control -and $e.KeyCode -eq [Windows.Forms.Keys]::D0) {
        $e.SuppressKeyPress = $true
        $btnZeroKnob.PerformClick()
    }
})

function Restore-MainWindow {
    $form.Show()
    $form.WindowState = 'Normal'
    $wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $w  = [Math]::Min([Math]::Max($form.Width, 1200), $wa.Width - 40)
    $h  = [Math]::Min([Math]::Max($form.Height, 740), $wa.Height - 40)
    if (-not $wa.Contains($form.Bounds)) {
        $x = $wa.X + [int](($wa.Width - $w) / 2)
        $y = $wa.Y + [int](($wa.Height - $h) / 2)
        $form.Bounds = [Drawing.Rectangle]::new($x, $y, $w, $h)
    }
    Update-PianoKeybedGeometry
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
    Update-CachedTelemetrySummaries
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
    try {
        if (-not $script:InitialShowCompleted) {
            $script:InitialShowCompleted = $true
            if ($Minimized) {
                $form.Hide()
            } else {
                Restore-MainWindow
            }
            if ($SmokeTestUi) {
                $swKnob = [Diagnostics.Stopwatch]::StartNew()
                foreach ($cc in 48..55) {
                    $kId = "Knob_$cc"
                    Select-ApcControl $kId
                    $script:ControlButtons[$kId].Update()
                }
                Select-ApcControl 'Pad_32'
                $swKnob.Stop()
                $knobSweepMs = [Math]::Round($swKnob.Elapsed.TotalMilliseconds, 2)
                if ($SavePreviewPath) {
                    try {
                        Update-PianoKeybedGeometry
                        Update-SurfaceButtonsVisuals
                        $form.Refresh()
                        $bmp = [Drawing.Bitmap]::new($form.Width, $form.Height)
                        $form.DrawToBitmap($bmp, [Drawing.Rectangle]::new(0, 0, $form.Width, $form.Height))
                        $bmp.Save($SavePreviewPath, [Drawing.Imaging.ImageFormat]::Png)
                        $bmp.Dispose()
                    } catch { }
                }
                [Console]::WriteLine("SMOKE_UI_OK: Handle=$($form.Handle) Visible=$([GoodCube.ApcDeck.NativeBridge]::IsWindowVisible($form.Handle)) KnobSweepMs=$knobSweepMs Title=$($form.Text) MidiOpen=$([GoodCube.ApcDeck.NativeBridge]::IsOpen)")
                $form.Close()
                return
            }
        }

        if ($stopEvent.WaitOne(0)) {
            $form.Close()
            return
        }
        if ($showEvent.WaitOne(0)) {
            Restore-MainWindow
            Set-StatusBanner 'Restored APC-DECK window to foreground.'
        }

        $ev = New-Object GoodCube.ApcDeck.MidiEventRecord
        $needFullRefresh = $false
        $lastBanner = $null

        $latestCc = @{}
        while ([GoodCube.ApcDeck.NativeBridge]::EventQueue.TryDequeue([ref]$ev)) {
            if ($ev.Command -eq 0xB0 -and $ev.Data1 -ge 48 -and $ev.Data1 -le 55) {
                $latestCc[$ev.Data1] = $ev
            } elseif ($ev.Command -eq 0x90 -and $ev.Data2 -gt 0) {
                $cid = if ($ev.Channel -eq 0) {
                    if ($ev.Data1 -ge 0 -and $ev.Data1 -le 39) { "Pad_$($ev.Data1)" }
                    elseif ($ev.Data1 -ge 64 -and $ev.Data1 -le 71) { "Track_$($ev.Data1)" }
                    elseif ($ev.Data1 -ge 81 -and $ev.Data1 -le 86) { "Scene_$($ev.Data1)" }
                    elseif ($ev.Data1 -in @(91, 93, 98)) { "Trans_$($ev.Data1)" }
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
                        Update-CachedTelemetrySummaries
                        if ($m.ActionType -eq 'BluetoothConnect') {
                            $script:BtSnapshot = @(Get-PairedBluetoothDevices -AudioSnapshot $script:AudioSnapshot)
                        }
                        Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
                        $needFullRefresh = $true
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
            $script:LastKnobTurnTick = [Environment]::TickCount64

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
                        Invalidate-ApcControl $cid
                        continue
                    }
                }
                $oldVal = $script:KnobValues[$cid]
                $script:KnobValues[$cid] = $physPct
                $res = Set-AudioVolumeByMapping -Mapping $m -MidiValue $ccEv.Data2 -AutoMuteAtZero
                $lastBanner = "MIDI Ch1 CC $ccKey = $($ccEv.Data2) [$($m.Label)] -> $res"
                if ($oldVal -ne $physPct) {
                    Invalidate-ApcControl $cid
                }
            }
        }

        if ($needFullRefresh) {
            Update-SurfaceButtonsVisuals
        }
        if ($lastBanner) {
            Set-StatusBanner $lastBanner
        }
    } catch {
        try { Set-StatusBanner "Recovered from runtime event: $($_.Exception.Message)" } catch { }
    }
})

# Periodic 5-second background LED & device state sync (skips while user is actively turning knobs)
$syncTimer = [Windows.Forms.Timer]::new()
$syncTimer.Interval = 5000
$syncTimer.Add_Tick({
    try {
        if (([Environment]::TickCount64 - $script:LastKnobTurnTick) -lt 800) {
            return
        }
        if (-not [GoodCube.ApcDeck.NativeBridge]::IsOpen) {
            $res = [GoodCube.ApcDeck.NativeBridge]::OpenDevice('APC Key 25')
            if ($res -eq 'OK') {
                Clear-AudioEndpointCache
                $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
                Update-CachedTelemetrySummaries
                Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot -Force
                Update-SurfaceButtonsVisuals
                $headerPanel.Invalidate()
                Set-StatusBanner 'Reconnected Akai APC Key 25 and synced LEDs.'
            }
            return
        }
        $script:AudioSnapshot = @(Get-AudioEndpointsSnapshot)
        Update-CachedTelemetrySummaries
        Sync-ApcHardwareLeds -ProfileMap $script:ProfileMap -AudioSnapshot $script:AudioSnapshot -BtSnapshot $script:BtSnapshot
        if ($form.Visible) {
            $changedPads = @(Update-PadVelocitiesCache)
            foreach ($pId in $changedPads) {
                Invalidate-ApcControl $pId
            }
        }
    } catch { }
})

$form.Add_Load({
    Update-PianoKeybedGeometry
    Select-ApcControl 'Pad_32'
    Set-StatusBanner 'Ready. Turn any knob (K1–K8), press any pad, button, or piano key on your Akai APC Key 25.'
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
    if (-not $SmokeTestUi) {
        try { [GoodCube.ApcDeck.NativeBridge]::ClearAllPadLeds() } catch { }
    }
    try { [GoodCube.ApcDeck.NativeBridge]::CloseDevice() } catch { }
    try { $showEvent.Dispose() } catch { }
    try { $stopEvent.Dispose() } catch { }
    try { $form.Dispose() } catch { }
    [Console]::Out.Flush()
    [Environment]::Exit(0)
}
