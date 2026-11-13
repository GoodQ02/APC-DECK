# Full-screen presentation only; theme changes never synchronize or write hardware LEDs.
$script:UiHighContrast = $false
$script:NormalUiStyles = @{}
$script:NormalUiColors = @{}
foreach ($variable in Get-Variable -Scope Script -Name 'c*') {
    if ($variable.Value -is [Drawing.Color]) { $script:NormalUiColors[$variable.Name] = $variable.Value }
}
function Save-NormalUiStyles($Control) {
    $script:NormalUiStyles[$Control] = @($Control.BackColor,$Control.ForeColor)
    foreach ($child in $Control.Controls) { Save-NormalUiStyles $child }
}
Save-NormalUiStyles $form

function Set-ApcContrastTheme([bool]$Enabled) {
    $script:UiHighContrast = $Enabled
    [GoodCube.ApcDeck.DeckTheme]::HighContrast = $Enabled
    foreach ($name in $script:NormalUiColors.Keys) {
        $color = $script:NormalUiColors[$name]
        if ($Enabled) {
            $color = if ($name -eq 'cCyanSelect') { [Drawing.SystemColors]::Highlight }
                elseif ($name -match 'Glow|KeyBlack') { [Drawing.SystemColors]::WindowText }
                else { [Drawing.SystemColors]::Window }
        }
        Set-Variable $name $color -Scope Script
    }
    foreach ($control in $script:NormalUiStyles.Keys) {
        $control.BackColor = if ($Enabled) { [Drawing.SystemColors]::Window } else { $script:NormalUiStyles[$control][0] }
        $control.ForeColor = if ($Enabled) { [Drawing.SystemColors]::WindowText } else { $script:NormalUiStyles[$control][1] }
        if ($control -is [Windows.Forms.Button]) {
            $control.FlatAppearance.BorderColor = if ($Enabled) { [Drawing.SystemColors]::WindowText } else { [Drawing.Color]::FromArgb(71,85,105) }
        }
    }
    $script:PadHighContrast = $Enabled
    $script:PadPalette = New-PadPalette $Enabled
    foreach ($cid in @('Trans_91','Trans_93','Trans_98')) { Invalidate-ApcControl $cid }
    Validate-InspectorInput
    Update-InspectorDraftState
    Set-RecoveryContrast $Enabled
    $form.Invalidate($true)
}

function Paint-ContrastSurface($Sender, $Event, [string]$Kind) {
    $g = $Event.Graphics
    $w = $Sender.ClientSize.Width; $h = $Sender.ClientSize.Height
    $g.Clear([Drawing.SystemColors]::Window)
    $ink = [Drawing.SystemBrushes]::WindowText
    $paper = [Drawing.SystemBrushes]::Window
    $edge = [Drawing.Pen]::new([Drawing.SystemColors]::WindowText,1)
    $selectedEdge = [Drawing.Pen]::new([Drawing.SystemColors]::Highlight,3)
    try {
        if ($Kind -eq 'Header') {
            if ($script:CompactWindow) {
                $g.DrawString('APC key 25',$script:FHeaderModel,$ink,12,6)
                $g.DrawString('F6  Controller / Inspector',$script:FHeaderSub,$ink,210,13)
                return
            }
            $g.DrawString('AKAI PROFESSIONAL', $script:FHeaderBrand,$ink,21,15)
            $g.DrawString('APC key 25',$script:FHeaderModel,$ink,196,11)
            $g.DrawString('Arrows select · Tab groups · F6 edit · F8 read · Ctrl+T test',$script:FHeaderSub,$ink,322,17)
            $text = if ([GoodCube.ApcDeck.NativeBridge]::IsOpen) { 'MIDI IN / LED OUT ONLINE' } else { 'MIDI OFFLINE' }
            $g.DrawString($text,$script:FHeaderPill,$ink,[Drawing.RectangleF]::new($w-206,12,190,26),$script:SfCenter)
            return
        }
        if ($Kind -eq 'Piano') {
            foreach ($black in @($false,$true)) {
                $rects = if ($black) { $script:BlackKeyRects } else { $script:WhiteKeyRects }
                foreach ($cid in $rects.Keys) {
                    $rc = $rects[$cid]; $note = [int]$cid.Substring(4)
                    $g.FillRectangle($(if($black){$ink}else{$paper}),$rc)
                    $g.DrawRectangle($(if($cid -eq $script:SelectedId){$selectedEdge}else{$edge}),$rc.X,$rc.Y,$rc.Width-1,$rc.Height-1)
                    $name = @('C','C#','D','D#','E','F','F#','G','G#','A','A#','B')[$note%12] + ([int][math]::Floor($note/12)-1)
                    $font = Get-SurfaceFont $g $(if($black){'FKeyNoteB'}else{'FKeyNoteW'}) ($rc.Width-2) ([int]($rc.Height/5)) $name
                    $lineH = [math]::Ceiling($font.GetHeight($g))+2
                    $brush = if($black){$paper}else{$ink}
                    $g.DrawString($name,$font,$brush,[Drawing.RectangleF]::new($rc.X+1,$rc.Bottom-$lineH-6,$rc.Width-2,$lineH),$script:SfBottom)
                    $m = $script:ProfileMap[$cid]
                    if ($m.ActionType -ne 'None' -or $m.Label -notin @($name,"KEY $name")) {
                        $g.DrawString($m.Label,$font,$brush,[Drawing.RectangleF]::new($rc.X+1,$rc.Bottom-2*$lineH-8,$rc.Width-2,$lineH),$script:SfBottom)
                    }
                }
            }
            return
        }
        $cid = [string]$Sender.Tag
        $m = $script:ProfileMap[$cid]
        $border = if($cid -eq $script:SelectedId){$selectedEdge}else{$edge}
        if ($Kind -eq 'Round') {
            $capH=[math]::Max(22,$h-19); $capW=[math]::Min($w-8,[math]::Max(34,$capH+18))
            $g.DrawEllipse($border,[int](($w-$capW)/2),2,$capW,$capH)
            $font=Get-SurfaceFont $g 'FRoundCap' ($w-4) $capH 'SELECT'
            $g.DrawString($m.Label,$font,$ink,[Drawing.RectangleF]::new(2,2,$w-4,$capH),$script:SfCenter)
            $code=[int]($cid -replace '^\w+_','')
            $badge=if($cid.StartsWith('Scene_')){$script:SceneMeta[$code].ShiftBadge}else{$script:TrackMeta[$code].Sub}
            $g.DrawString($badge,$script:FRoundBadge,$ink,[Drawing.RectangleF]::new(3,$h-15,$w-6,13),$script:SfCenter)
            return
        }
        $g.DrawRectangle($border,2,2,$w-5,$h-5)
        $state=$script:KnobStates[$cid]
        $value=if($state.Known){"$($script:KnobValues[$cid])%"}else{'—'}
        $top="K$([int]$cid.Substring(5)-47)$(if($state.Known -and $state.Muted){' muted'})"
        $feedback=Get-KnobFeedback $cid $chkPickupMode.Checked $chkEditOnly.Checked
        $topFont=Get-SurfaceFont $g 'FKnobTop' ($w-6) ([int]($h/7)) 'K1 muted'
        $valueFont=Get-SurfaceFont $g 'FKnobValue' ($w-6) ([int]($h/5)) '100%'
        $feedbackFont=Get-SurfaceFont $g 'FKnobFeedback' ($w-6) ([int]($h/6)) 'Waiting'
        $nameFont=Get-SurfaceFont $g 'FKnobName' ($w-8) ([int]($h/6)) 'MASTER'
        $g.DrawString($top,$topFont,$ink,[Drawing.RectangleF]::new(3,3,$w-6,$h*0.18),$script:SfCenter)
        $g.DrawString($value,$valueFont,$ink,[Drawing.RectangleF]::new(3,$h*0.23,$w-6,$h*0.22),$script:SfCenter)
        $g.DrawString($feedback,$feedbackFont,$ink,[Drawing.RectangleF]::new(3,$h*0.46,$w-6,$h*0.2),$script:SfCenter)
        $label=Get-SurfaceLines $g ($m.Label -replace '^K\d+:\s*','') $nameFont ($w-8) 2
        $g.DrawString($label,$nameFont,$ink,[Drawing.RectangleF]::new(4,$h*0.67,$w-8,$h*0.31),$script:SfPadLabel)
    } finally { $edge.Dispose(); $selectedEdge.Dispose() }
}
$form.Add_SystemColorsChanged({ Set-ApcContrastTheme ([Windows.Forms.SystemInformation]::HighContrast) })
