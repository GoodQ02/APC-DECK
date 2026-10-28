<!-- DOC_STATUS: AUTHORITATIVE -->
<!-- LAST_VERIFIED: 2026-10-28 -->

# APC-DECK Agent Instructions (`C:\Tools\apc-midi-deck`)

`APC-DECK` is GOOD-CUBE's native Windows Stream Deck–style visual controller, hardware LED synchronizer, CoreAudio mixer/router, Bluetooth RFCOMM wake-up controller, and hotkey mapper for the **Akai Professional APC Key 25** (`USB\VID_09E8&PID_0027`).

Before modifying any file in this repository, read this file and [`docs/AGENT_HANDOFF.md`](docs/AGENT_HANDOFF.md).

---

## 1. Current Verified State (Do Not Re-Diagnose Resolved Issues)

All five engineering passes (initial build, Windows 11 terminal interception fix, multi-monitor/DPI/foreground placement fix, 1:1 physical hardware twin layout, and sub-millisecond CoreAudio knob/UI latency optimization) are **complete, verified, and active in production**:

- **90 Mappable Physical Controls (1:1 Hardware Twin UI)**:
  - `Pad_0`–`Pad_39` (`5×8` RGB Clip Launch Matrix, Ch 1 Notes `0`–`39`)
  - `Scene_82`–`Scene_86` + `Scene_81` (`6` Circular Scene Launch / `STOP ALL CLIPS` buttons, Ch 1 Notes `81`–`86`)
  - `Track_64`–`Track_71` (`8` Circular Track / Knob Mode buttons, Ch 1 Notes `64`–`71`)
  - `Knob_48`–`Knob_55` (`2×4` Rotary Potentiometer Bank `K1`–`K8`, Ch 1 CC `48`–`55`)
  - `Trans_91`, `Trans_93`, `Trans_98` (`3` Transport/Shift buttons: `PLAY/PAUSE`, `REC`, `SHIFT`, Ch 1 Notes `91`, `93`, `98`)
  - `Key_48`–`Key_72` (`25` Synth-Action Piano Keys `C3`–`C5` rendered on a unified geometric `KeybedCanvas`, Ch 2 Notes `48`–`72`)
- **Verified Performance Baselines**:
  - **Knob Sweep (`K1`–`K8` selection + MIDI CC turn + redraw)**: `~105 ms` total across all 8 knobs (`~13 ms/knob`, down from `19,248 ms`).
  - **Single Knob Volume Tick (`Set-AudioVolumeByMapping` + `Invalidate-ApcControl`)**: `0.15 ms – 1.0 ms`.
  - **Inspector Target Validation (`Validate-InspectorInput`)**: `0.01 ms` (in-memory `$script:AudioSnapshot` lookup, down from `802 ms` COM enumeration).
  - **4-Second Background Audio Snapshot (`Get-AudioEndpointsSnapshot`)**: `~24 ms` (via `$script:FriendlyNameCache` and `$script:SnapshotDevices`, down from `538 ms`).
  - **Settled Idle CPU Usage on `WinSta0\Default`**: `0.0 ms/sec`.

---

## 2. Repository & Workstation Ownership

| Path | Role |
| :--- | :--- |
| [`C:\Tools\apc-midi-deck\ApcDeck.psm1`](ApcDeck.psm1) | Core PowerShell/C# engine: `GoodCube.ApcDeck.NativeBridge` (`winmm.dll`, `IPolicyConfig`, `user32.dll`, `advapi32.dll`), CoreAudio `MMDevice` & `FriendlyName` caches, Bluetooth RFCOMM `0x111E` background runner, LED velocity solver (`Get-PadLedVelocity`), differential USB MIDI LED transmitter (`Sync-ApcHardwareLeds`), and 90-control JSON profile manager. |
| [`C:\Tools\apc-midi-deck\Open-ApcDeck.ps1`](Open-ApcDeck.ps1) | Single-instance DPI-aware WinForms 1:1 physical hardware twin GUI (`GoodCube.ApcDeck.SurfaceTile`, `KeybedCanvas`, right-hand Stream Deck Property Inspector, System Tray icon, 60 Hz MIDI drain loop, 4s background sync timer, and CLI modes). |
| [`C:\Tools\apc-midi-deck\Test-ApcDeck.ps1`](Test-ApcDeck.ps1) | Automated verification suite (90-control schema, knob `0%`/`100%` deadzones, hotkey chord parser, LED velocity overrides, live `-Mode Snapshot`, and `-SmokeTestUi` with `< 500 ms` knob sweep latency regression gate). |
| `C:\Tools\bin\apc-deck.vbs` | Pure windowless GUI launcher (`WScript.Shell.Run ..., 0, False`) that spawns `pwsh.exe` without triggering Windows 11 `wt.exe` terminal tab interception. |
| `C:\Tools\bin\apc-deck.cmd` | CLI shim on `PATH`: launches `wscript.exe C:\Tools\bin\apc-deck.vbs` for GUI/Tray modes and runs `pwsh.exe` directly for CLI output modes (`-Mode Snapshot`, `-Mode Stop`, `-Mode ResetDefaults`, `-SmokeTestUi`). |
| `C:\Users\jdben\Desktop\APC-DECK.lnk` | User Desktop shortcut targeting `C:\Windows\System32\wscript.exe "C:\Tools\bin\apc-deck.vbs"` with `assets\apc-deck.ico`. |
| `%APPDATA%\GoodCube\ApcMidiDeck\apc-key25-profile.json` | User-persisted 90-control mapping and custom LED/key color profile (auto-upgraded from legacy 87-control profiles on load). |

---

## 3. Architectural Invariants (DO NOT REGRESS)

1. **Never Call Uncached COM `EnumerateAudioEndPoints` or `.FriendlyName` on the UI Thread**:
   - Querying `MMDevice.FriendlyName` across all 22 `Active`/`Disabled`/`Unplugged` endpoints queries the Windows PnP `IPropertyStore` and blocks for `538–802 ms`.
   - Always use `Get-EndpointFriendlyName` (`$script:FriendlyNameCache`), `Resolve-AudioEndpoint -UseCache` (backed by `$script:SnapshotDevices`, `$script:EndpointCache`, and `$script:NegativeEndpointCache`), and in-memory `$script:AudioSnapshot` inside UI handlers like `Validate-InspectorInput`.
2. **Targeted Control Invalidation Only (`Invalidate-ApcControl`)**:
   - Turning a knob (`Knob_48`–`Knob_55`) or selecting a control must call `Invalidate-ApcControl $cid` to repaint only the affected control (`< 0.2 ms`), **never** `Update-SurfaceButtonsVisuals` on every 16ms MIDI tick.
   - Surface pads, scene/track buttons, and rotary knobs must remain `GoodCube.ApcDeck.SurfaceTile` (`: Control` with `OptimizedDoubleBuffer`), not `System.Windows.Forms.Button` (`ButtonBase` runs expensive `uxtheme.dll` hover animation timers).
   - Keep GDI+ `Font` and `StringFormat` objects pre-allocated at script scope (`$script:FPadTiny`, `$script:FKnobLbl`, etc.); never instantiate `Font` inside `Paint` callbacks.
3. **Safe WinMM Shutdown Order (`CloseDevice`)**:
   - Do **not** call `midiInReset` or `midiInClose` synchronously from the STA UI thread during shutdown—`winmm.dll` waits on its callback thread lock and deadlocks STA exit. `NativeBridge.CloseDevice()` sets `Closing = true`, clears hardware LEDs via `midiOutShortMsg`, and closes `hMidiOut`, allowing the OS to reclaim `hMidiIn` on process exit.
4. **Desktop & Foreground Placement (`WinSta0\Default` on `\\.\DISPLAY1`)**:
   - Keep `AutoScaleMode = 'None'` and explicit primary monitor centering (`[Windows.Forms.Screen]::PrimaryScreen.WorkingArea`) in `$form.Add_Load` so multi-monitor coordinates (`DISPLAY2` at negative `X=-1920`) never push the window off-screen.
   - When launching `APC-DECK` from a sandboxed agent command session (`WinSta0\exebox-*`) and wanting the window to persist after the tool call finishes, spawn it via `explorer.exe` on `WinSta0\Default`:
     ```powershell
     Import-Module "C:\Tools\apc-midi-deck\ApcDeck.psm1" -Force
     [GoodCube.ApcDeck.NativeBridge]::LaunchOnDefaultDesktop('C:\Windows\explorer.exe "C:\Users\jdben\Desktop\APC-DECK.lnk"', 'C:\Users\jdben\Desktop')
     ```
     *(Direct child processes of a tool call's Job Object are killed when the tool call ends; delegating to `explorer.exe` places the GUI in the user's persistent shell process tree.)*

---

## 4. Verification Workflow

Run the automated test suite after any change:

```powershell
pwsh -NoLogo -NoProfile -File "C:\Tools\apc-midi-deck\Test-ApcDeck.ps1"
```

Expected output:
```text
PASS: ApcDeck verified (Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=22, BluetoothPaired=4, KnobSweepMs=..., UI=Visible)
```
