# Screen-reader messages use cached UI state only. No speech engine or device actions.
$script:PendingAnnouncement = ''
$script:LastAnnouncement = ''
$script:LastInspectorAnnouncementKey = ''
$script:AccessibilityNotificationDelivered = $false
$announcementTimer = [Windows.Forms.Timer]::new()
$announcementTimer.Interval = 450
function Queue-AccessibilityAnnouncement([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $script:PendingAnnouncement = $Text
    $announcementTimer.Stop()
    $announcementTimer.Start()
}
function Send-PendingAccessibilityAnnouncement {
    $announcementTimer.Stop()
    if (-not $script:PendingAnnouncement) { return }
    $message = $script:PendingAnnouncement
    $script:PendingAnnouncement = ''
    if (-not $form.ContainsFocus -or $message -eq $script:LastAnnouncement) { return }
    $script:LastAnnouncement = $message
    $script:AccessibilityNotificationDelivered = $lblDraftState.AccessibilityObject.RaiseAutomationNotification(
        [Windows.Forms.Automation.AutomationNotificationKind]::Other,
        [Windows.Forms.Automation.AutomationNotificationProcessing]::MostRecent, $message)
}
$announcementTimer.Add_Tick({ Send-PendingAccessibilityAnnouncement })

function Read-SelectedAccessibilityStatus {
    $cid = $script:SelectedId
    $mapping = $script:ProfileMap[$cid]
    $message = "$($mapping.Label). $cid. "
    if ($cid.StartsWith('Pad_')) { $message += "Saved state: $($script:PadPresentations[$cid].State). " }
    elseif ($cid.StartsWith('Knob_')) {
        $state = $script:KnobStates[$cid]
        $message += if ($state.Known) { "Saved device level $($script:KnobValues[$cid]) percent. " } else { "$($state.Status). " }
        if ($state.Known -and $state.Muted) { $message += 'Muted. ' }
        $message += (Get-KnobFeedback $cid $chkPickupMode.Checked $chkEditOnly.Checked) + '. '
    }
    $message += $lblDraftState.Text + '. ' + $lblValidation.Text + '. ' + $btnTest.Text + '.'
    $script:LastAnnouncement = '' # An explicit request may repeat the same current status.
    Queue-AccessibilityAnnouncement $message
}

function Update-AccessibleInspectorState([string]$ErrorText, [bool]$Dirty) {
    $description = if ($ErrorText) { "$ErrorText. Apply and Test unavailable." } else { $lblValidation.Text }
    $cmbTarget1.AccessibleDescription = $description
    $cmbTarget2.AccessibleDescription = if ([string]$cmbAction.SelectedItem -eq 'SwapDevices') { $description } else { '' }
    $txtLabel.AccessibleDescription = $lblDraftState.Text
    $btnSave.AccessibleDescription = if ($ErrorText) { $description } elseif (-not $Dirty) { 'No pending changes to apply.' } else { 'Save only this control. Ctrl+S.' }
    $btnTest.AccessibleDescription = if ($ErrorText) { $description } else { 'Explicit live action. Runs the displayed mapping without saving. Ctrl+T. ' + $btnTest.Text }
    $key = "$($script:SelectedId)|$Dirty|$ErrorText"
    if ($key -ne $script:LastInspectorAnnouncementKey) {
        $script:LastInspectorAnnouncementKey = $key
        if ($ErrorText -or $Dirty) { Queue-AccessibilityAnnouncement "$($lblDraftState.Text). $description" }
    }
}
$lblValidation.IsAccessible = $true
$lblValidation.AccessibleRole = 'StaticText'
$lblDraftState.IsAccessible = $true
$lblDraftState.AccessibleRole = 'StaticText'
$statusBox.AccessibleName = 'MIDI connection, audio summary, and last action'
$statusBox.AccessibleDescription = 'Press F8 to read the selected mapping, current state, draft status, and validation.'
$readStatusItem = $utilityMenu.Items.Add('Read selected status  (F8)')
$readStatusItem.Add_Click({ Read-SelectedAccessibilityStatus })
$form.Add_KeyDown({ param($sender,$e) if ($e.KeyCode -eq 'F8' -and -not $e.Alt -and -not $e.Control) { $e.SuppressKeyPress=$true; Read-SelectedAccessibilityStatus } })
$form.Add_FormClosed({ $announcementTimer.Stop(); $announcementTimer.Dispose() })
