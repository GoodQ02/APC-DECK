<!-- DOC_STATUS: AUTHORITATIVE -->
<!-- HANDOFF_DATE: 2026-10-28 -->

# APC-DECK — Codex Agent Handoff & Current State Reference

This document provides the complete technical handoff for **APC-DECK** (`C:\Tools\apc-midi-deck`, GitHub repository [`GoodQ02/APC-DECK`](https://github.com/GoodQ02/APC-DECK)).

> **IMPORTANT FOR RECEIVING AGENTS (CODEX / ANTIGRAVITY / HERMES)**:
> Every issue listed in **Section 3 (Resolved Engineering Issues)** has already been diagnosed, fixed in code, verified via automated tests and live desktop inspection, and committed to `main`. **Do not re-diagnose, revert, or attempt to re-fix those completed items.**

---

## 1. Executive Summary & Live State

**Latest verified change (2026-10-28):** queued knob volume updates now run before one coalesced inspector selection. Commit `7a56312` was pushed to GitHub with explicit user authorization; local and remote `main` were verified to match at `7a563125b640ccf6f850a7957afb95b6cf9b4839` after that push. See Section 7 for measured results and their limits. The earlier `~105 ms` sweep is a historical observation, not a guaranteed current baseline.

- **Repository Root**: `C:\Tools\apc-midi-deck`
- **GitHub Remote**: `https://github.com/GoodQ02/APC-DECK` (`origin/main`)
- **Hardware Target**: **Akai Professional APC Key 25 (MK1)** (`USB\VID_09E8&PID_0027`, WinMM Input Index `0`, WinMM Output Index `1`)
- **Total Mappable Controls**: **90 physical controls** rendered in a **1:1 physical hardware twin layout**:
  - **40 Clip Launch Pads (`Pad_0`–`Pad_39`)**: `5×8` bi-color RGB matrix (`Ch 1 Notes 0–39`)
  - **6 Circular Scene / Stop Buttons (`Scene_82`–`Scene_86` + `Scene_81`)**: `5` Green-LED Scene Launch buttons + `STOP ALL CLIPS` (`Ch 1 Notes 81–86`)
  - **8 Circular Track / Mode Buttons (`Track_64`–`Track_71`)**: Red-LED buttons (`UP`, `DOWN`, `LEFT`, `RIGHT`, `VOLUME`, `PAN`, `SEND`, `DEVICE`, `Ch 1 Notes 64–71`)
  - **8 Rotary Potentiometers (`Knob_48`–`Knob_55`, `K1`–`K8`)**: `2×4` bank with 270° painted indicator arcs, live Windows `VOL XX%` readout, and `KNOB XX%` physical pickup indicator (`Ch 1 CC 48–55`)
  - **3 Rectangular Transport / Shift Buttons (`Trans_91`, `Trans_93`, `Trans_98`)**: `PLAY/PAUSE`, `REC`, and `SHIFT` below the knob bank (`Ch 1 Notes 91, 93, 98`)
  - **25 Synth-Action Piano Keys (`Key_48`–`Key_72`)**: `C3`–`C5` (15 full-height white keys + 10 recessed black sharp/flat keys) rendered on a single double-buffered geometric canvas (`Ch 2 Notes 48–72`)

### Default 8-Knob Audio Mixer Mapping on GOOD-CUBE

| Knob | ControlId | MIDI CC | Default Action | Target Endpoint on GOOD-CUBE |
| :--- | :--- | :---: | :--- | :--- |
| **`K1`** | `Knob_48` | `CC 48` | `VolumeMasterOut` | `@DefaultRender` (`LOGI_VIBES (Zone Vibe Wireless)`) |
| **`K2`** | `Knob_49` | `CC 49` | `VolumeDevice` | `COMMAND_CENTER (Realtek(R) Audio)` |
| **`K3`** | `Knob_50` | `CC 50` | `VolumeDevice` | `VOICE_CUBE (Realtek(R) Audio)` |
| **`K4`** | `Knob_51` | `CC 51` | `VolumeDevice` | `PS5_HEADPHONES (PlayStation Link Adapter)` |
| **`K5`** | `Knob_52` | `CC 52` | `VolumeDevice` | `M-AUDIO-AUX (5- Producer USB)` |
| **`K6`** | `Knob_53` | `CC 53` | `VolumeDevice` | `META_VR (Oculus Virtual Audio Device)` |
| **`K7`** | `Knob_54` | `CC 54` | `VolumeDevice` | `CMD_MIC (5- Producer USB)` |
| **`K8`** | `Knob_55` | `CC 55` | `VolumeDevice` | `PS5_MIC (PlayStation Link Adapter)` |

---

## 2. File & Component Inventory

| File / Path | Purpose & Ownership |
| :--- | :--- |
| [`ApcDeck.psm1`](../ApcDeck.psm1) | Core module containing `GoodCube.ApcDeck.NativeBridge` (C# P/Invoke for `winmm.dll`, `IPolicyConfig` COM vtable, `user32.dll`, `advapi32.dll`, `kernel32.dll`), CoreAudio endpoint caching (`$script:EndpointCache`, `$script:NegativeEndpointCache`, `$script:FriendlyNameCache`, `$script:SnapshotDevices`), Bluetooth RFCOMM `0x111E` background connector, LED velocity calculator (`Get-PadLedVelocity`), differential USB MIDI LED sync (`Sync-ApcHardwareLeds`), and 90-control JSON profile persistence (`%APPDATA%\GoodCube\ApcMidiDeck\apc-key25-profile.json`). |
| [`Open-ApcDeck.ps1`](../Open-ApcDeck.ps1) | Main WinForms application & CLI entry point. Implements `GoodCube.ApcDeck.SurfaceTile` custom double-buffered control, `GoodCube.ApcDeck.KeybedCanvas` 25-key piano renderer, Stream Deck Property Inspector, System Tray icon, single-instance mutex + named event wake-up, 60 Hz MIDI polling loop, and 4-second device state sync timer. |
| [`Test-ApcDeck.ps1`](../Test-ApcDeck.ps1) | Automated verification script validating the 90-control profile schema, knob `0%`/`100%` deadzone clamping, hotkey chord parser, LED velocity overrides, `-Mode Snapshot`, and `-SmokeTestUi` (including the `< 500 ms` 8-knob sweep latency regression gate). |
| [`AGENTS.md`](../AGENTS.md) | Concise repository-root agent rules and architectural invariants. |
| [`README.md`](../README.md) | Repository overview, quick start, default 90-control table, and CLI reference. |
| [`docs/USER_GUIDE.md`](USER_GUIDE.md) | End-user operational guide covering launching, 1:1 surface navigation, MIDI Learn, Edit-Only Mode, pad/key color swatches, knob zero-out, and soft-takeover pickup mode. |
| [`docs/HARDWARE_MIDI_SPEC.md`](HARDWARE_MIDI_SPEC.md) | Complete Akai APC Key 25 (MK1) MIDI IN/OUT protocol specification, canonical `ControlId` mapping tables, LED velocity codes, and WinMM lifecycle notes. |
| [`docs/REA_STREAMDECK_ANALYSIS.md`](REA_STREAMDECK_ANALYSIS.md) | Reverse-engineering report (`reverse-engineer-anything`) documenting the Elgato Stream Deck plugins inspected, SHA-256 digests, REA Evidence IDs, `IPolicyConfig` COM vtable, WinRT RFCOMM `0x111E` wake-up, and CoreAudio caching architecture. |
| `C:\Tools\bin\apc-deck.vbs` | Windowless VBScript launcher (`sh.Run psCmd, 0, False`) used by the Desktop shortcut and `apc-deck.cmd` so Windows 11 never intercepts GUI launches into a Windows Terminal (`wt.exe`) tab. |
| `C:\Tools\bin\apc-deck.cmd` | Command-line shim on `PATH`. Delegates GUI/Tray launches to `wscript.exe "C:\Tools\bin\apc-deck.vbs"` and passes CLI modes (`-Mode Snapshot`, `-Mode Stop`, `-Mode ResetDefaults`, `-SmokeTestUi`) directly to `pwsh.exe`. |
| `C:\Users\jdben\Desktop\APC-DECK.lnk` | User Desktop shortcut (`TargetPath = C:\Windows\System32\wscript.exe`, `Arguments = "C:\Tools\bin\apc-deck.vbs"`, `IconLocation = C:\Tools\apc-midi-deck\assets\apc-deck.ico,0`). |
| `%LOCALAPPDATA%\GoodCube\ApcMidiDeck\profile.json` | Actual saved user profile path used by `ApcDeck.psm1` (auto-created and auto-migrated to 90 controls by `Load-ApcProfile`). Preserved byte-for-byte during the latest fix. |

---

## 3. All Resolved Engineering Issues (Passes 1–5 — COMPLETE)

Every item below has been **fixed, tested, and verified in the current codebase**:

| Pass | Symptom Reported | Root Cause | Permanent Fix Implemented | Current Verified Metric |
| :---: | :--- | :--- | :--- | :--- |
| **Pass 1** | Need Stream Deck–style control of audio volumes, device switching, endpoint enable/disable, Bluetooth connect, LED colors, and hotkeys on Akai APC Key 25 | Akai APC Key 25 has no standalone Windows mixer/mapper software; Stream Deck plugins lock CoreAudio/Bluetooth logic inside `.sdPlugin` binaries | Reverse-engineered `me.rumkee.bluetooth.monitor.dll` and `com.barraider.audiometer.exe` with REA; built `ApcDeck.psm1` (`IPolicyConfig` COM + `winmm.dll` + WinRT RFCOMM `0x111E`) and `Open-ApcDeck.ps1` | All 14 action types working across audio, Bluetooth, media, hotkeys, and system commands |
| **Pass 2** | Double-clicking Desktop shortcut opened an empty terminal window and nothing appeared | 1. Windows 11 DefTerm (`wt.exe`) intercepts console subsystem (`pwsh.exe`) shortcuts.<br>2. Calling `midiInReset`/`midiInClose` on an `-STA` thread deadlocks `winmm.dll` when closing a previous instance.<br>3. Agent tool calls execute inside sandboxed desktop `WinSta0\exebox-*`, hiding windows from `WinSta0\Default`. | 1. Routed shortcut & `apc-deck.cmd` through `wscript.exe "C:\Tools\bin\apc-deck.vbs"` (`WindowStyle 0`).<br>2. Removed `midiInReset`/`midiInClose` from STA shutdown in `NativeBridge.CloseDevice()`.<br>3. Added `GetCurrentDesktopName()` + `LaunchOnDefaultDesktop()` (`lpDesktop = "WinSta0\\Default"`) and stale-mutex recovery. | Shortcut opens GUI directly with zero terminal window; re-clicking shortcut wakes existing instance |
| **Pass 3** | Window could spawn on secondary monitor (`DISPLAY2` at `X=-1920`) or overflow under 125% DPI font auto-scaling; Windows 11 foreground lock blocked `SetForegroundWindow` | 1. `StartPosition = 'CenterScreen'` can pick non-primary monitor.<br>2. `AutoScaleMode = 'Font'` scaled controls past container bounds.<br>3. `wscript.exe` background spawn lacked foreground lock permission. | 1. Forced `$form.AutoScaleMode = 'None'` and centered explicitly on `[Windows.Forms.Screen]::PrimaryScreen.WorkingArea` (`\\.\DISPLAY1`).<br>2. Implemented `AttachThreadInput` + simulated `ALT` key press + `TOP`/`NOTOPMOST` sequence in `NativeBridge.BringFormToFront()`. | Always centers cleanly on `\\.\DISPLAY1` (`1920×1032`) and pops to front reliably |
| **Pass 4** | Generic grid UI did not match physical APC Key 25 layout; missing 3 physical buttons (`PLAY/PAUSE`, `REC`, `SHIFT`) and piano keys looked like flat grid buttons | Initial layout stacked knobs across the top and rendered 25 piano keys in a `2×13` uniform grid | Rebuilt left chassis as a **1:1 physical hardware twin** (90 controls): Top-Left `5×8` RGB pads + `6` circular scene buttons + `8` circular track buttons; Top-Right `2×4` rotary knobs with 270° arcs + `3` transport/shift buttons (`Trans_91`, `Trans_93`, `Trans_98`); Bottom `KeybedCanvas` with overlapping white/black piano keys (`C3`–`C5`). | 90 controls matching exact physical APC Key 25 geometry; right-click instant test & live target validation |
| **Pass 5** | Twisting multiple knobs caused noticeable delay and crashed the UI when clicked | 1. Touching a different knob with MIDI Learn active called `Select-ApcControl`, which fired `Validate-InspectorInput` **3×**, each calling uncached `Resolve-AudioEndpoint -IncludeDisabled` (`802 ms × 3 = 2,406 ms` COM `IPropertyStore` freeze per knob switch).<br>2. `$syncTimer` re-queried `.FriendlyName` on all 22 endpoints every 4s (`538 ms` freeze) and resent all 54 MIDI LED messages.<br>3. Turning 1 knob called `Update-SurfaceButtonsVisuals`, invalidating all 66 controls and allocating ~200 GDI+ `Font`/`Brush` objects per 16ms frame.<br>4. Timer/Paint callbacks lacked `try/catch` guards under `$ErrorActionPreference = 'Stop'`. | 1. Changed `Validate-InspectorInput` to match against `$script:AudioSnapshot` in memory (`0.01 ms`) and added `$script:SuppressInspectorEvents` in `Select-ApcControl`.<br>2. Added `$script:FriendlyNameCache`, `$script:SnapshotDevices`, and `$script:NegativeEndpointCache` in `ApcDeck.psm1` (`538 ms -> 23.9 ms`).<br>3. Replaced `BufferedButton` with `GoodCube.ApcDeck.SurfaceTile` (`: Control`), pre-allocated all GDI+ fonts, added `$script:PadVelocities` cache, differential MIDI LED updates (`$script:LastSentLedVel`), and single-control `Invalidate-ApcControl $cid` (`< 0.2 ms`).<br>4. Wrapped all timer, paint, and CoreAudio calls in `try/catch`. | 8-knob sweep dropped from **`19,248 ms` to `105 ms`** (`183×` faster); single knob tick **`0.15–1.0 ms`**; settled idle CPU **`0.0 ms/sec`** |

---

## 4. Performance & Latency Architecture (Pass 5 Deep Dive)

### 4.1 Four-Tier CoreAudio Caching in [`ApcDeck.psm1`](../ApcDeck.psm1)
1. **`$script:FriendlyNameCache` (`Get-EndpointFriendlyName`)**:
   - Windows CoreAudio stores `.FriendlyName` in the PnP PropertyStore (`PKEY_Device_FriendlyName`). Reading it over COM for 22 endpoints (`Active`, `Disabled`, `Unplugged`) takes `~538 ms`.
   - `Get-EndpointFriendlyName` caches `Endpoint.ID -> FriendlyName` in memory so subsequent `Get-AudioEndpointsSnapshot` calls complete in **`~24 ms`**.
2. **`$script:SnapshotDevices`, `$script:DefaultRenderDevice`, `$script:DefaultCaptureDevice`**:
   - Populated during `Get-AudioEndpointsSnapshot`. Holds live `MMDevice` references alongside cached `ID`, `FriendlyName`, `Flow`, and `State`.
   - When `Resolve-AudioEndpoint -UseCache` experiences a cold key miss, it resolves directly from `$script:SnapshotDevices` in memory (`0.005 ms`) without calling `$enum.EnumerateAudioEndPoints`.
3. **`$script:EndpointCache` & `$script:NegativeEndpointCache`**:
   - Maps `"$Flow|$IncludeDisabled|$MatchPattern"` directly to the resolved `MMDevice` for `0.15 ms` volume scalar updates during 60 Hz knob turns.
   - Unmatched patterns are recorded in `$script:NegativeEndpointCache` with a `3,000 ms` TTL so disconnected devices never trigger repeated COM enumerations during rapid knob movement.
   - Any COM exception (`AUDCLNT_E_DEVICE_INVALIDATED`) inside `Set-AudioVolumeByMapping` or `Get-CurrentMappingVolumePct` automatically calls `Clear-AudioEndpointCache` and gracefully recovers on the next tick.

### 4.2 Zero-Allocation GDI+ Rendering & Targeted Invalidation in [`Open-ApcDeck.ps1`](../Open-ApcDeck.ps1)
- **`GoodCube.ApcDeck.SurfaceTile` (`: System.Windows.Forms.Control`)**:
  - Inherits directly from `Control` instead of `Button` (`ButtonBase`), eliminating Windows `uxtheme.dll` native hover/fade animation timers across the 62 upper-chassis controls.
  - Enables `AllPaintingInWmPaint | UserPaint | OptimizedDoubleBuffer | ResizeRedraw` and suppresses `Selectable` focus rectangles.
- **Pre-Allocated GDI+ Resources**:
  - All 15 `System.Drawing.Font` instances (`$script:FPadTiny` through `$script:FKeyNote`) and 2 `StringFormat` instances (`$script:SfCenter`, `$script:SfNearCenter`) are allocated once at startup and reused across all `Paint` events.
- **Targeted `Invalidate-ApcControl([string]$cid)`**:
  - Turning a knob (`Knob_48`–`Knob_55`) only invalidates that single `SurfaceTile` (`< 0.2 ms`).
  - Pressing or hovering a piano key only invalidates `$keybedCanvas`.
  - Full-surface `Update-SurfaceButtonsVisuals` is only invoked when audio/Bluetooth device states actually change (`$changed` signature check in `$syncTimer`) or when the user clicks Save/Test/Reset/Refresh.
- **Differential Hardware LED Transmission (`Sync-ApcHardwareLeds`)**:
  - Tracks `$script:LastSentLedVel[$note]` for all 54 LED-capable notes (`0..39`, `64..71`, `82..86`) and only calls `midiOutShortMsg` when a pad's velocity code changes (unless `-Force` is passed on startup or manual refresh).

---

## 5. Launching, Single-Instance IPC & Agent Desktop Persistence

### 5.1 Named IPC Primitives
- **Single-Instance Mutex**: `Local\GoodCube.ApcMidiDeck.Instance` (or `.SmokeTest` when `-SmokeTestUi` is passed)
- **Wake / Restore Event**: `Local\GoodCube.ApcMidiDeck.ShowEvent` — signaled when a second launch detects the mutex is already held; the running instance's 16ms timer catches `$showEvent.WaitOne(0)` and calls `Restore-FromTray`.
- **Clean Stop Event**: `Local\GoodCube.ApcMidiDeck.StopEvent` — signaled by `Open-ApcDeck.ps1 -Mode Stop` or `apc-deck -Mode Stop`; triggers clean LED shutoff, tray icon removal, and form close.

### 5.2 Launching Persistently from an Agent Session (`WinSta0\exebox-*` -> `WinSta0\Default`)
When an AI agent (`Antigravity` / `Codex`) executes a tool command, two Windows isolation mechanisms apply:
1. The command may run on an isolated desktop (`WinSta0\exebox-*`) instead of the user's interactive desktop (`WinSta0\Default`).
2. Direct child processes spawned by the command session's Job Object are terminated when the command tool call finishes.

To launch or restart `APC-DECK` from an agent command so that it opens visibly on `WinSta0\Default` (`\\.\DISPLAY1`) **and** survives after the command exits, delegate the launch to `explorer.exe` on `WinSta0\Default`:

```powershell
Import-Module "C:\Tools\apc-midi-deck\ApcDeck.psm1" -Force
[GoodCube.ApcDeck.NativeBridge]::LaunchOnDefaultDesktop(
    'C:\Windows\explorer.exe "C:\Users\jdben\Desktop\APC-DECK.lnk"',
    'C:\Users\jdben\Desktop'
)
```

Because `explorer.exe` hands activation off to the running interactive shell process on `WinSta0\Default`, the spawned `pwsh.exe` GUI process lives inside the user's desktop process tree rather than the temporary agent tool-call job.

---

## 6. Verification & Regression Commands

### Full Automated Test Suite
```powershell
pwsh -NoLogo -NoProfile -File "C:\Tools\apc-midi-deck\Test-ApcDeck.ps1"
```
Validates:
1. `Load-ApcProfile` returns all **90 controls** including `Trans_91`, `Trans_93`, `Trans_98`.
2. `Convert-MidiCcToScalar` clamps `CC 0..1` to `0.0` (`0%`) and `CC 126..127` to `1.0` (`100%`).
3. `Parse-HotkeyChord` parses modifier chords (`Alt+Q`, `Ctrl+Shift+M`, `F13`).
4. `Get-PadLedVelocity` computes hardware LED velocity codes (`1` Green, `2` BlinkGreen, `3` Red, `4` BlinkRed, `5` Amber, `6` BlinkAmber, `0` Off) across active, standby, muted, disabled, and custom override states.
5. `Open-ApcDeck.ps1 -Mode Snapshot` returns valid JSON with `ControlCount = 90`.
6. `Open-ApcDeck.ps1 -SmokeTestUi` renders the WinForms UI, attempts to open MIDI ports, and times selecting/updating all 8 knobs (`Knob_48`–`Knob_55`) plus returning selection to `Pad_32`. The suite rejects `KnobSweepMs > 500 ms`. This is a startup UI measurement, not a MIDI-to-volume measurement; see Section 7 for current results.
7. `Test-ApcKnobDispatch.ps1` extracts the actual knob dispatch block and uses recording sinks to check that all queued volume calls precede one inspector selection. Eight cases cover ordering, edit-only, pickup waiting/crossing/zero, MIDI Learn disabled, hidden windows, and an already-selected knob. It performs no audio writes.

### Refresh UI Screenshot Asset (`assets/apc-deck-ui.png`)
```powershell
pwsh -NoLogo -NoProfile -STA -File "C:\Tools\apc-midi-deck\Open-ApcDeck.ps1" -SmokeTestUi -SavePreviewPath "C:\Tools\apc-midi-deck\assets\apc-deck-ui.png"
```

## 7. Knob Dispatch Priority Fix — Verified 2026-10-28

### Problem and bounded change

With MIDI Learn enabled, the old CC loop called `Select-ApcControl` before each knob's `Set-AudioVolumeByMapping`. Visible inspector work, especially rebuilding target dropdowns when action types change at K1/K2, delayed audio dispatch. Diagnostic timing attributed most of the sweep cost to inspector updates rather than knob painting. It did not establish why the historical handoff run was faster under its original conditions.

`Open-ApcDeck.ps1` now records the selection candidate while processing the queued CC batch, applies all eligible knob volumes, then selects the final candidate once. This preserves MIDI Learn during edit-only mode and while pickup is waiting; pickup still gates volume writes. Continuing on an already-selected knob still skips inspector selection. The change does not alter profiles, audio targets, MIDI polling interval, endpoint caches, or volume conversion.

### Verification and timing evidence

Before the fix, ten fresh-process runs of the existing startup smoke test measured **212.95 ms median**, **194.59–525.50 ms range**, with **one of ten over the 500 ms gate**. This was 2.03 times the documented 105 ms observation, or 2.18 times the pasted 97.73 ms handoff result.

The targeted comparison used the actual old dispatch block from `4d90375` and the patched block with the real inspector UI in a temporary diagnostic copy. Ten paired batches alternated before/after execution order. Each batch queued K1–K8 in a fixed order and started from `Pad_32`. The audio function was replaced with a recording sink; elapsed time began at dispatch-block entry. No audio levels were changed by this benchmark.

| Metric | Before: median (range), ms | After: median (range), ms |
| :--- | :--- | :--- |
| Time to first volume-handler entry | 25.7635 (18.500–42.573) | 0.1455 (0.108–1.869) |
| Time to eighth volume-handler entry | 88.8770 (70.685–121.343) | 0.4665 (0.373–2.578) |
| Whole dispatch block, including inspector | 88.9125 (70.723–121.393) | 31.7190 (29.813–45.880) |

The eight dispatch regression cases passed, and the ordering case correctly failed against the old implementation. PowerShell parsing and `git diff --check` passed. The full existing suite plus the new regression checks passed after the fix:

```text
PASS: Knob dispatch ordering, edit-only, pickup, and MIDI Learn (8 cases; no audio writes).
PASS: ApcDeck verified (Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=22, BluetoothPaired=4, KnobSweepMs=165.65, UI=Visible)
```

### Limits and resume boundary

- These timings establish reduced delay **before reaching the audio handler**, not USB/MIDI arrival-to-CoreAudio completion or audible response. Real audio writes, driver latency, and playback were not timed by the recording-sink benchmark.
- Inspector work still runs synchronously after the batch and can delay processing of later-arriving events. The fix prioritizes volumes already queued; it does not make the entire UI asynchronous or guarantee sub-millisecond physical response.
- The 165.65 ms startup sweep is one post-fix smoke result, not a controlled improvement in inspector rendering. That benchmark directly selects controls and does not exercise the reordered CC dispatch path. The before/after dispatch harness was temporary and in-memory; only the deterministic regression checks are retained in the repository.
- Earlier read-only checks found cached endpoint-plus-volume-read medians of 0.118–0.143 ms (one 48 ms outlier), and 120 live window-response probes had no timeouts. Neither check proves volume-write or physical input latency.
- The actual profile, `%LOCALAPPDATA%\GoodCube\ApcMidiDeck\profile.json`, retained SHA-256 `D7C5D06D756824D37E882F2C7703BA5376BF002E1AD67EC7B2F79D665128FCC4` across the fix and restart. The patched app was verified visible and responding as PID `73768`; this is a dated observation, not a persistent process identity.
- Leave APC-DECK running. The fix in `7a56312` is published and synchronization was verified; the earlier local-only hold is superseded by the user's explicit push authorization. This documentation-only publication-status correction is also authorized for commit and push. Reuse the completed checks unless new code, a failure, or a changed condition warrants another run.
