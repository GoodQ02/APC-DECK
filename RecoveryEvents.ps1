# Session-only, bounded recovery history. Never record routine selection/CC telemetry.
$script:RecentEvents = [Collections.Generic.List[object]]::new()
$script:RecoverySequence = 0
$script:EventsWindow = $null

function Test-RecoveryFailureResult([string]$Text) {
    return $Text -match "^(Audio device state changed|Device '.+' is not active\.|No active audio session for |Audio endpoint '.+' not found\.|Paired Bluetooth device '.+' not found\.|Stream Deck Bluetooth plugin not found\.|Unrecognized hotkey format )"
}

function Add-RecoveryEvent([string]$Text, [string]$Kind = '', [string]$ControlId = '', [bool]$Failed = $false) {
    $last = if ($script:RecentEvents.Count) { $script:RecentEvents[0] } else { $null }
    if ($last -and -not $last.Acknowledged -and -not $last.Resolved -and $last.Text -ceq $Text -and $last.Kind -eq $Kind -and $last.ControlId -eq $ControlId -and $last.Failed -eq $Failed) {
        $last.Count++; $last.Time = Get-Date
    } else {
        $script:RecoverySequence++
        $script:RecentEvents.Insert(0, [pscustomobject]@{
            Id=$script:RecoverySequence; Time=Get-Date; Text=$Text; Kind=$Kind; ControlId=$ControlId
            Failed=$Failed; Acknowledged=$false; Resolved=$false; Count=1
        })
        if ($script:RecentEvents.Count -gt 50) {
            # Keep unresolved failures through ordinary successful activity, within the cap.
            $remove=50
            for ($i=50; $i -ge 0; $i--) {
                $candidate=$script:RecentEvents[$i]
                if (-not $candidate.Failed -or $candidate.Resolved -or $candidate.Acknowledged) { $remove=$i; break }
            }
            $script:RecentEvents.RemoveAt($remove)
        }
    }
    Update-RecoveryAttention
    if ($script:EventsWindow -and -not $script:EventsWindow.IsDisposed -and $script:EventsWindow.Visible) { Update-RecentEventsView }
}

function Resolve-RecoveryEvent([string]$Kind, [string]$ControlId = '') {
    foreach ($item in $script:RecentEvents) {
        if ($item.Kind -eq $Kind -and $item.ControlId -eq $ControlId -and $item.Failed) { $item.Resolved=$true }
    }
    Update-RecoveryAttention
}

function Update-RecoveryAttention {
    $script:RecoveryAttention = @($script:RecentEvents | Where-Object { $_.Failed -and -not $_.Resolved -and -not $_.Acknowledged }).Count
    $btnEvents.Text = if ($script:RecoveryAttention) { "Recent events: $script:RecoveryAttention to review  (F9)" } else { 'Recent events  (F9)' }
}

function Record-StatusEvent([string]$Text) {
    # These are operation results, not the high-frequency MIDI/selection messages.
    if ($Text -like 'Could not save mapping:*') { Add-RecoveryEvent $Text 'Apply' $script:SelectedId $true }
    elseif ($Text -like 'Test failed:*') { Add-RecoveryEvent $Text 'Test' $script:SelectedId $true }
    elseif ($Text -match '^(Device refresh failed:|Observation failed:)') { Add-RecoveryEvent $Text 'Refresh' '' $true }
    elseif ($Text -like 'Recovered from runtime event:*') { Add-RecoveryEvent $Text 'Refresh' '' $true }
    elseif ($Text -like 'Applied *') { Resolve-RecoveryEvent 'Apply' $script:SelectedId; Add-RecoveryEvent $Text }
    elseif ($Text -like '[[]TEST *') { Resolve-RecoveryEvent 'Test' $script:SelectedId; Add-RecoveryEvent $Text }
    elseif ($Text -like 'Refreshed audio/*') { Resolve-RecoveryEvent 'Refresh'; Add-RecoveryEvent $Text }
    elseif ($Text -match '^(Reverted |Reconnected |Reset entire |Balanced |\[ZERO OUT\])') { Add-RecoveryEvent $Text }
}

function Update-RecentEventDetails {
    $item = $eventsList.SelectedItem
    if (-not $item) {
        $eventsDetails.Text = 'No recent events. Apply, Test, Refresh and failures will appear here. Routine knob turns and selections are omitted. History is kept for this session only (up to 50 events).'
        $eventsRecover.Enabled=$false; $eventsAcknowledge.Enabled=$false
        return
    }
    $entry=$item.Entry
    $next = switch ($entry.Kind) {
        'Apply' { 'Your draft is retained. Review the current mapping, then press Apply to retry saving. If you have since changed or reverted it, the inspector shows that current state.' }
        'Test' { 'The action may already have run before feedback failed. Review the current mapping and device state before pressing Test again. A knob test sets its target to 50%; shortcuts and other actions can run again.' }
        'Refresh' { 'Check the device connection, then retry Refresh. This rereads devices, reconnects MIDI if needed and synchronizes LEDs. It does not replay the failed audio or shortcut action.' }
        default { 'No recovery action is needed.' }
    }
    $state=if($entry.Resolved){'Succeeded later'}elseif($entry.Acknowledged){'Reviewed'}elseif($entry.Failed){'Needs review'}else{'Completed'}
    $eventsDetails.Text = "$($entry.Time.ToString('g')) · $state · occurrences: $($entry.Count)`r`n$($entry.ControlId)`r`n`r`n$($entry.Text)`r`n`r`n$next"
    $eventsRecover.Text = switch ($entry.Kind) { 'Apply' {'Review / retry Apply'} 'Test' {'Review / retry Test'} default {'Retry Refresh'} }
    $eventsRecover.Enabled = $entry.Failed -and -not $entry.Resolved -and $entry.Kind -in @('Apply','Test','Refresh') -and ($entry.Kind -ne 'Refresh' -or -not $script:DeviceRefreshJob)
    $eventsAcknowledge.Enabled = $entry.Failed -and -not $entry.Acknowledged -and -not $entry.Resolved
}

function Update-RecentEventsView {
    $selectedId = if ($eventsList.SelectedItem) { $eventsList.SelectedItem.Entry.Id } else { -1 }
    $eventsList.BeginUpdate()
    try {
        $eventsList.Items.Clear()
        foreach ($entry in $script:RecentEvents) {
            $state=if($entry.Resolved){'Recovered'}elseif($entry.Acknowledged){'Reviewed'}elseif($entry.Failed){'Needs review'}else{'Done'}
            $label="$($entry.Time.ToString('HH:mm:ss'))  $state · $(Format-CompactText $entry.Text 95)"
            [void]$eventsList.Items.Add([pscustomobject]@{Label=$label; Entry=$entry})
            if ($entry.Id -eq $selectedId) { $eventsList.SelectedIndex=$eventsList.Items.Count-1 }
        }
        if ($eventsList.SelectedIndex -lt 0 -and $eventsList.Items.Count) { $eventsList.SelectedIndex=0 }
    } finally { $eventsList.EndUpdate() }
    Update-RecentEventDetails
}

function Invoke-SelectedRecovery {
    if (-not $eventsList.SelectedItem -or -not $eventsRecover.Enabled) { return }
    $entry=$eventsList.SelectedItem.Entry
    if ($entry.Kind -eq 'Refresh') { Start-DeviceRefresh; Update-RecentEventDetails; return }
    # Never replay a historical mapping. Review the live draft through the existing actions.
    if (-not $script:ProfileMap.ContainsKey($entry.ControlId)) { return }
    Select-ApcControl $entry.ControlId
    Show-WorkspacePane $true
    $script:EventsWindow.Close()
    $form.Activate()
    if ($entry.Kind -eq 'Apply') { $null=$btnSave.Focus() } else { $null=$btnTest.Focus() }
    Set-StatusBanner "Review $($entry.ControlId), then press $($entry.Kind) to retry. The current mapping is shown; no action was replayed."
}

function Set-RecoveryContrast([bool]$Enabled) {
    if (-not $script:EventsWindow -or $script:EventsWindow.IsDisposed) { return }
    $pending=[Collections.Generic.Queue[Windows.Forms.Control]]::new()
    $pending.Enqueue($script:EventsWindow)
    while ($pending.Count) {
        $control=$pending.Dequeue()
        $control.BackColor=if($Enabled){[Drawing.SystemColors]::Window}else{[Drawing.Color]::FromArgb(20,26,35)}
        $control.ForeColor=if($Enabled){[Drawing.SystemColors]::WindowText}else{[Drawing.Color]::FromArgb(226,232,240)}
        foreach ($child in $control.Controls) { $pending.Enqueue($child) }
    }
}

function Show-RecentEvents {
    if ($script:EventsWindow -and -not $script:EventsWindow.IsDisposed) { $script:EventsWindow.Activate(); return }
    $script:EventsWindow=[Windows.Forms.Form]::new()
    $w=$script:EventsWindow
    $w.Text='Recent events — APC-DECK'; $w.ShowInTaskbar=$false; $w.StartPosition='CenterParent'; $w.AutoScaleMode='None'
    $w.Size=[Drawing.Size]::new(760,620); $w.MinimumSize=[Drawing.Size]::new(640,560)
    $w.Font=[Drawing.Font]::new('Segoe UI',[single](10*$script:TextScale))
    $eventsFont=$w.Font
    $w.Add_FormClosed(({ $eventsFont.Dispose() }).GetNewClosure())
    $layout=[Windows.Forms.TableLayoutPanel]::new(); $layout.Dock='Fill'; $layout.Padding=[Windows.Forms.Padding]::new(12); $layout.ColumnCount=1; $layout.RowCount=4
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('AutoSize'))
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',40))
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',60))
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('AutoSize'))
    $intro=[Windows.Forms.Label]::new(); $intro.Text='Recent events · this session · latest 50'; $intro.AutoSize=$true; $intro.Dock='Fill'
    $script:eventsList=[Windows.Forms.ListBox]::new(); $eventsList.Dock='Fill'; $eventsList.IntegralHeight=$false; $eventsList.DisplayMember='Label'; $eventsList.HorizontalScrollbar=$true; $eventsList.AccessibleName='Recent events'; $eventsList.TabIndex=0
    $script:eventsDetails=[Windows.Forms.TextBox]::new(); $eventsDetails.Dock='Fill'; $eventsDetails.Multiline=$true; $eventsDetails.ReadOnly=$true; $eventsDetails.ScrollBars='Vertical'; $eventsDetails.AccessibleName='Event details and recovery'; $eventsDetails.TabIndex=1
    $actions=[Windows.Forms.FlowLayoutPanel]::new(); $actions.Dock='Fill'; $actions.AutoSize=$true; $actions.WrapContents=$true; $actions.TabIndex=2
    $script:eventsRecover=[Windows.Forms.Button]::new(); $eventsRecover.Text='Retry Refresh'; $eventsRecover.AutoSize=$true; $eventsRecover.TabIndex=0
    $script:eventsAcknowledge=[Windows.Forms.Button]::new(); $eventsAcknowledge.Text='Mark reviewed'; $eventsAcknowledge.AutoSize=$true; $eventsAcknowledge.TabIndex=1
    $close=[Windows.Forms.Button]::new(); $close.Text='Close'; $close.AutoSize=$true; $close.TabIndex=2; $close.DialogResult='Cancel'; $w.CancelButton=$close
    $actions.Controls.AddRange(@($eventsRecover,$eventsAcknowledge,$close))
    $layout.Controls.Add($intro,0,0); $layout.Controls.Add($eventsList,0,1); $layout.Controls.Add($eventsDetails,0,2); $layout.Controls.Add($actions,0,3); $w.Controls.Add($layout)
    # Native system colors supply high contrast; normal mode uses the existing console palette.
    Set-RecoveryContrast $script:UiHighContrast
    $w.Add_SystemColorsChanged({ Set-RecoveryContrast ([Windows.Forms.SystemInformation]::HighContrast) })
    $eventsList.Add_SelectedIndexChanged({ Update-RecentEventDetails })
    $eventsRecover.Add_Click({ Invoke-SelectedRecovery })
    $eventsAcknowledge.Add_Click({
        if ($eventsList.SelectedItem) { $eventsList.SelectedItem.Entry.Acknowledged=$true; Update-RecoveryAttention; Update-RecentEventsView; Set-StatusBanner }
    })
    $close.Add_Click({ $script:EventsWindow.Close() })
    Update-RecentEventsView
    $area=[Windows.Forms.Screen]::FromControl($form).WorkingArea
    $w.Size=[Drawing.Size]::new([math]::Min($w.Width,$area.Width),[math]::Min($w.Height,$area.Height))
    $w.Show($form); $null=$eventsList.Focus()
}

$script:RecoveryAttention=0
$btnEvents=$utilityMenu.Items.Add('Recent events  (F9)')
$btnEvents.Add_Click({ Show-RecentEvents })
$form.Add_KeyDown({ param($sender,$e) if($e.KeyCode -eq [Windows.Forms.Keys]::F9){$e.SuppressKeyPress=$true; Show-RecentEvents} })
$statusBox.AccessibleDescription='Live status. Press F9 for recent events and recovery options.'
