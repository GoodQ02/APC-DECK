# Keep the existing DPI mode and hardware topology. Adapt the surrounding workspace.
$script:WindowLayoutBusy = $false
$compactTabs = [Windows.Forms.TabControl]::new()
$compactTabs.Dock = 'Fill'
$compactTabs.AccessibleName = 'Workspace: Controller or Inspector; F6 switches'
$controllerPage = [Windows.Forms.TabPage]::new('Controller')
$inspectorPage = [Windows.Forms.TabPage]::new('Inspector')
$compactTabs.TabPages.AddRange(@($controllerPage,$inspectorPage))
$compactTabs.Visible = $false
$mainSplit.Controls.Add($compactTabs,0,0)
$mainSplit.SetColumnSpan($compactTabs,2)

function Resize-ControllerViewport {
    if (-not $deckViewport.Visible) { return }
    # Start from the full panel, not ClientSize (which includes yesterday's scrollbars).
    $availableW=$deckViewport.Width; $availableH=$deckViewport.Height
    $horizontal=$availableW -lt 780; $vertical=$availableH -lt 580
    if ($horizontal) { $availableH -= [Windows.Forms.SystemInformation]::HorizontalScrollBarHeight }
    if ($vertical -or $availableH -lt 580) { $availableW -= [Windows.Forms.SystemInformation]::VerticalScrollBarWidth }
    if (-not $horizontal -and $availableW -lt 780) { $availableH -= [Windows.Forms.SystemInformation]::HorizontalScrollBarHeight }
    $width=[math]::Max(780,$availableW); $height=[math]::Max(580,$availableH)
    $chassisLayout.Size = [Drawing.Size]::new($width,$height)
    $deckViewport.AutoScrollMinSize = $chassisLayout.Size
}

function Show-DeckSelection([string]$cid) {
    if (-not $deckViewport.Visible) { return }
    if (-not $deckViewport.HorizontalScroll.Visible -and -not $deckViewport.VerticalScroll.Visible) { return }
    if ($cid.StartsWith('Key_')) {
        $control=$keybedCanvas
        $rect=if ($script:WhiteKeyRects.ContainsKey($cid)) { $script:WhiteKeyRects[$cid] } else { $script:BlackKeyRects[$cid] }
    } else {
        $control=$script:ControlButtons[$cid]
        if (-not $control) { return }
        $rect=$control.ClientRectangle
    }
    $point=$deckViewport.PointToClient($control.PointToScreen([Drawing.Point]::new([int]$rect.X,[int]$rect.Y)))
    $x=-$deckViewport.AutoScrollPosition.X; $y=-$deckViewport.AutoScrollPosition.Y
    if ($point.X -lt 0) { $x += $point.X }
    elseif ($point.X+$rect.Width -gt $deckViewport.ClientSize.Width) { $x += $point.X+$rect.Width-$deckViewport.ClientSize.Width }
    if ($point.Y -lt 0) { $y += $point.Y }
    elseif ($point.Y+$rect.Height -gt $deckViewport.ClientSize.Height) { $y += $point.Y+$rect.Height-$deckViewport.ClientSize.Height }
    $deckViewport.AutoScrollPosition=[Drawing.Point]::new([math]::Max(0,$x),[math]::Max(0,$y))
}

function Show-WorkspacePane([bool]$Inspector) {
    if ($script:CompactWindow) { $compactTabs.SelectedIndex = if ($Inspector) { 1 } else { 0 } }
}

function Update-WindowLayout {
    if ($script:WindowLayoutBusy) { return }
    $script:WindowLayoutBusy=$true
    try {
        $compact=$form.ClientSize.Width -lt 1180
        if ($compact -ne $script:CompactWindow) {
            $editing=$inspectorGroup.ContainsFocus
            $script:CompactWindow=$compact
            $mainSplit.SuspendLayout()
            try {
                if ($compact) {
                    $inspFlow.Controls.Add($lblSelectedMeta)
                    $inspFlow.Controls.SetChildIndex($lblSelectedMeta,0)
                    $inspectorFooter.SetColumnSpan($lblDraftState,1)
                    $inspectorFooter.SetColumnSpan($btnMore,1)
                    $inspectorFooter.SetCellPosition($btnMore,[Windows.Forms.TableLayoutPanelCellPosition]::new(1,0))
                    $controllerPage.Controls.Add($deckViewport)
                    $inspectorPage.Controls.Add($inspectorGroup)
                    $compactTabs.Visible=$true
                    $compactTabs.SelectedIndex=if ($editing) { 1 } else { 0 }
                } else {
                    $inspHeader.Controls.Add($lblSelectedMeta)
                    $inspectorFooter.SetCellPosition($btnMore,[Windows.Forms.TableLayoutPanelCellPosition]::new(0,3))
                    $inspectorFooter.SetColumnSpan($btnMore,2)
                    $inspectorFooter.SetColumnSpan($lblDraftState,2)
                    $mainSplit.Controls.Add($deckViewport,0,0)
                    $mainSplit.Controls.Add($inspectorGroup,1,0)
                    $compactTabs.Visible=$false
                }
                $rootLayout.RowStyles[0].Height=if ($compact) { 40 } else { 52 }
                $rootLayout.RowStyles[2].Height=if ($compact) { 40 } else { 50 }
            } finally { $mainSplit.ResumeLayout($true) }
            Resize-ReadableInspector
            $headerPanel.Invalidate()
        }
        Resize-ControllerViewport
    } finally { $script:WindowLayoutBusy=$false }
}

function Fit-WindowToWorkArea([Drawing.Rectangle]$WorkArea) {
    # Work in the form's own (possibly DPI-virtualized) coordinate space.
    $margin=12
    $availableW=[math]::Max(1,$WorkArea.Width-2*$margin)
    $availableH=[math]::Max(1,$WorkArea.Height-2*$margin)
    $form.MinimumSize=[Drawing.Size]::new([math]::Min(640,$availableW),[math]::Min(560,$availableH))
    $width=[math]::Min($form.Width,$availableW); $height=[math]::Min($form.Height,$availableH)
    $x=[math]::Clamp($form.Left,$WorkArea.Left+$margin,$WorkArea.Right-$margin-$width)
    $y=[math]::Clamp($form.Top,$WorkArea.Top+$margin,$WorkArea.Bottom-$margin-$height)
    $form.Bounds=[Drawing.Rectangle]::new($x,$y,$width,$height)
    Update-WindowLayout
}
$deckViewport.Add_SizeChanged({ Resize-ControllerViewport })
$compactTabs.Add_SelectedIndexChanged({ Resize-ControllerViewport; Show-DeckSelection $script:SelectedId })
$form.Add_SizeChanged({ Update-WindowLayout })
$form.Add_ResizeEnd({ Fit-WindowToWorkArea ([Windows.Forms.Screen]::FromControl($form).WorkingArea) })
$form.Add_Activated({ if ($form.WindowState -eq 'Normal') { Fit-WindowToWorkArea ([Windows.Forms.Screen]::FromControl($form).WorkingArea) } })
$form.Add_Load({ Update-WindowLayout })
