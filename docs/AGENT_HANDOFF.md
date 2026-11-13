<!-- DOC_STATUS: AUTHORITATIVE -->
<!-- HANDOFF_DATE: 2026-11-13 -->

# APC-DECK — Codex Agent Handoff & Current State Reference

This document provides the complete technical handoff for **APC-DECK** (`C:\Tools\apc-midi-deck`, GitHub repository [`GoodQ02/APC-DECK`](https://github.com/GoodQ02/APC-DECK)).

> **IMPORTANT FOR RECEIVING AGENTS (CODEX / ANTIGRAVITY / HERMES)**:
> Every issue listed in **Section 3 (Resolved Engineering Issues)** has already been diagnosed, fixed in code, verified via automated tests and live desktop inspection, and committed to `main`. **Do not re-diagnose, revert, or attempt to re-fix those completed items.**

---

## 1. Executive Summary & Live State

**Recovery clarity and pickup defaults (2026-11-13):** implemented locally on published `38d7bb6`, fully tested before restart. F9 opens bounded session history with persistent failure attention, full details, direct Refresh retry and review-before-retry Apply/Test. Pickup now starts enabled, catches within one percentage point or across the target in either direction, and no longer bypasses at zero. Hardware geometry, physical LED engine, audio writer and dispatch ordering are preserved. Production PID 56668 is responding with MIDI online and the user's current profile unchanged. See Section 17. The user has authorized committing and pushing this tested pass to origin/main; implementation, tests, and documentation belong to this release.

**Restrained interaction feedback release (2026-11-09):** implemented and tested on published `284b668` on November 8. Painted controls and individual piano keys now have neutral hover/pressed cues; successful Apply has a bounded underline acknowledgement with static reduced-motion/high-contrast alternatives. Selection, volume rendering, hardware layout, and physical LED outputs are preserved. Full regression testing passed before restart. See Section 16. The user authorized committing and pushing this tested pass to origin/main; implementation, tests, and documentation belong to this release.

**Mixed-DPI and small-window release (2026-11-08):** implemented on published `f6d2085`. Compact Controller/Inspector tabs, a scrollable hardware viewport, fixed inspector actions, and current-monitor work-area fitting are covered by the full suite and actual 125% ↔ 150% display transitions. Physical layout, LED outputs, and MIDI dispatch are preserved. See Section 15 for evidence and limits. The user authorized committing and pushing this tested pass to origin/main; implementation, tests, and documentation belong to this release.

**Measured fluidity release (2026-11-04):** implemented on published `3d23782`, with baseline/after measurements and full regression verification before launch. Unchanged target choices no longer rebuild native dropdowns. Explicit F5 discovery runs in an owned read-only process and returns only name strings; the UI retains its own CoreAudio objects and reads current levels at completion. Apply persistence and MIDI dispatch ordering are preserved. See Section 14. After verification, the user authorized documentation updates, commit, and push to origin/main; implementation, tests, and documentation belong to this release.

**Accessibility release (2026-11-04):** the user authorized committing and pushing the tested accessibility pass to origin/main. Contextual accessible fields, debounced action/error announcements, cached F8 status, and full Windows system-color presentation are implemented. Actual dark and Desert light contrast transitions passed; Speechify selected-text ingestion was verified and is the user's preferred reading workflow. Full Narrator spoken qualification remains partial. See Section 13. Runtime IDs and settings below are dated test evidence, not a current process inventory.

**DPI and larger-text usability pass (2026-10-29):** implemented locally on published contrast commit `fe972d1`, tested before restart, and verified visible/online as PID `18328`. Inspector typography follows Windows text size with a session override, fields/toggles scroll, actions remain fixed, and hardware text adapts to available space using measured font metrics. Hardware geometry, physical LED engine, and MIDI dispatch remain intact. See Section 12. The user has authorized committing and pushing this tested pass to origin/main.

**Contrast and pad readability pass (2026-10-29):** implemented locally on published keyboard commit `3bd2b56`, fully tested before restart, and verified visible/online as PID `73548`. Neutral pad fills, wrapped labels, independent status text, and readable custom-color text are active. Hardware geometry, physical LED engine, and MIDI dispatch remain intact. See Section 11. The user has authorized committing and pushing this tested pass to origin/main.

**Keyboard and visible-focus pass (2026-10-29):** implemented locally on published `c1a6d80`, tested before restart, and verified online/responding as PID `81792`. All 90 mappings now have keyboard selection and accessible identities, including 25 virtual piano keys; the dispatch block remains unchanged. See Section 10. The user has authorized committing and pushing this tested pass to `origin/main`.

**Live-state and pickup pass (2026-10-28):** implemented locally on top of published `5e80bb5`, tested before restart, and verified visible/online as PID `84116`. Knob observations, pickup feedback, footer telemetry, and default-endpoint cache rebinding now follow refreshed Windows state. Hardware positions and queued-volume-before-inspector ordering are preserved. See Section 9. The user has authorized committing and pushing this tested pass to `origin/main`.

**Inspector first pass (2026-10-28):** the redesigned inspector, per-control session drafts, fixed Apply/Revert/Test footer, contextual fields, and readable knob labels are implemented and tested. The app was restarted only after checks passed and verified online as PID `85456`. The underlying knob-dispatch block is unchanged. See Section 8 for current behavior, evidence, and remaining scope. The user authorized committing and pushing this tested first pass to `main`; `caddf01` is the pre-first-pass baseline.

**Previously verified dispatch change (2026-10-28):** queued knob volume updates now run before one coalesced inspector selection. Commit `7a56312` was pushed to GitHub with explicit user authorization; local and remote `main` were verified to match at `7a563125b640ccf6f850a7957afb95b6cf9b4839` after that push. See Section 7 for measured results and their limits. The earlier `~105 ms` sweep is a historical observation, not a guaranteed current baseline.

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

## 8. Inspector First Pass — Implemented and Verified 2026-10-28

The user authorized the first Impeccable implementation pass and a restart after testing. Scope: inspector workflow, retained drafts, persistent Apply/Revert/Test, and readable knob labels, preserving the hardware layout and completed latency fixes.

### Delivered behavior

- The inspector has a stable header, scrollable contextual fields, and a fixed action footer. Maintenance commands moved into **More actions…**. Action display names are friendly; stored enum values are unchanged.
- Each control retains its own unsaved draft across mouse or MIDI Learn selection. **Apply** saves only that control; **Revert** restores only that control. Drafts are session-local and do not survive quitting/restarting. They never modify the runtime mappings until Apply.
- **Test** runs the displayed draft without saving it. With no pending changes it tests the saved mapping. Knob tests explicitly announce **50% volume**. Tests are deliberate live actions, including in Edit mode; hardware and wheel actions are paused in Edit mode.
- Swatches and Clear now modify the draft. Missing required targets, invalid hotkeys, missing swap targets, and unsupported knob action types block Apply/Test. Save failure preserves the draft and restores the committed in-memory mapping.
- Knob K-number, percentage, and device name occupy separate rows. Names wrap only between words; very narrow tiles use ellipses, with the full saved label/target in a tooltip and the selected mapping in the inspector. Hardware control order is unchanged.
- Transport buttons now initialize their labels on startup. Painted controls expose descriptive accessible names; this is not a complete keyboard/screen-reader accessibility implementation.
- Apply no longer forces endpoint cache clearing/rediscovery for mapping edits. The existing queued-volume-before-inspector dispatch code, MIDI polling interval, SurfaceTile controls, cached endpoint machinery, shutdown path, and launcher are preserved.

### Verification completed before restart

- PowerShell parsing and `git diff --check` passed. Compared the dispatch block against `caddf01`: identical after newline normalization.
- `Test-ApcDeck.ps1` now includes `Test-ApcInspector.ps1`, which exercises actual WinForms controls via `tests/InspectorCases.ps1` in a fresh **offline** smoke process. The offline mode uses fixture mappings/state and recording sinks; it does not acquire MIDI devices, persist the user profile, or change real audio.
- Inspector cases passed: multiple retained drafts, selected-only Apply/Revert, draft Test for knobs and buttons, failure-to-save recovery, swatch/Clear semantics, required/unsupported action validation, Edit-mode wheel protection, friendly labels, initial transport labels, 90-control inventory, and visible footer/no horizontal inspector scroll at 1680×970, 1366×768, and 1200×740.
- Long-label drafts were rendered and checked. Pre-restart captures are in `C:\Users\jdben\Documents\APC-DECK UI Audit 2026-10-28\implemented`.
- All eight existing dispatch regression cases passed. Final full-suite receipt:

```text
PASS: Inspector interaction and layout tests; real profile unchanged; audio/MIDI writes isolated.
PASS: ApcDeck verified (Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=21, BluetoothPaired=4, KnobSweepMs=107.53, UI=Visible)
```

The 107.53 ms measurement is the existing startup eight-knob selection/redraw smoke test, not physical MIDI arrival-to-audio latency. The offline inspector smoke in that suite measured 91.64 ms; fixture timing is not live hardware timing.

### Restart and preservation

- Verified the existing process identity, signaled PID 73768 through the normal Stop mode, waited for exit, and launched the existing desktop shortcut through the established Explorer/default-desktop path.
- Replacement PID `85456` was visible/responding; the live UI showed **MIDI IN / LED OUT ONLINE** and the new inspector/footer. The window was left open. The readback after restoring approximately the previous geometry was 1665×962 at x=888/y=265 (one-pixel width rounding by the desktop tooling).
- The profile SHA-256 remained `D7C5D06D756824D37E882F2C7703BA5376BF002E1AD67EC7B2F79D665128FCC4` before tests, before restart, and after restart. A pre-restart profile copy is in the same external evidence folder.
- After implementation and verification, the user explicitly authorized committing and pushing this first pass to `origin/main`. The implementation, regression tests, user guide, and this handoff belong to the same release.

### Remaining audit scope

This completes the requested first pass, not the entire audit backlog. General telemetry reconciliation, complete accessible keyboard/piano control semantics, comprehensive state/contrast treatment, physical touch testing, Narrator, and broader DPI/high-contrast qualification remain future work. Live rendered inspection followed restart; no deliberate physical MIDI/audio-write latency experiment was added.

## 9. Live-State Accuracy and Pickup Feedback — Implemented 2026-10-28

The user authorized implementation and restart after testing, keeping hardware layout and latency fixes intact. Base: published inspector commit `5e80bb5`. After verification, the user explicitly authorized committing and pushing this pass to `origin/main`; implementation, tests, user guide, and this handoff belong to the same release.

### Behavior and implementation

- `KnobState.ps1` derives per-knob observations entirely from the existing audio snapshot. It matches the writer's active-endpoint preference, distinguishes observed levels from pending commands, and re-arms pickup on external level/mute changes, endpoint switches, mapping changes, and reconnects.
- Every knob has local feedback: Awaiting turn, CW/CCW target percentage, In sync, Direct, Updating, or explicit unavailable/disabled/disconnected status. Muted is labeled separately. Unknown levels render a dash. Compact tiles shorten text and omit dial artwork; all control positions and the 90-control inventory are unchanged. Full feedback is available in tooltips.
- The existing 5-second refresh now updates knobs, footer, Bluetooth audio-derived evidence, and changed pads. It preserves the last event message, runs even when MIDI is disconnected, and retains the 800 ms active-turn deferral. Refresh failures mark knob/footer telemetry unavailable until recovery. This is periodic reconciliation, not continuous CoreAudio event notification.
- Snapshot completion clears stale endpoint aliases/negative lookups while preserving friendly-name and device snapshots. Default output writes therefore follow the refreshed default instead of a previous cached endpoint.
- Fixed the existing changed-pad loop's `$pId` collision with PowerShell's read-only `$PID`, plus empty-match handling for mute-pad LEDs. Both could prevent accurate unavailable/mute refreshes.
- All coalesced volume writes complete before knob redraw/tooltip work and the single inspector selection. The 16 ms MIDI timer, cached write path, targeted invalidation, SurfaceTile controls, safe WinMM shutdown, DPI/launcher behavior, and retained drafts remain in place. No new COM lookup occurs in knob painting or state reconciliation.
- `VolumeApp` has no session readback observer. It explicitly displays No readback (compact: Unverified), retaining direct writes without pretending endpoint pickup can validate application session levels. Bluetooth connected/disconnected remains an inference from known audio endpoints, not general radio status.

### Tests completed before restart

- `Test-ApcDeck.ps1` passed, including ten dispatch cases, the real snapshot/resolver cache path with fake endpoints, existing inspector/draft tests, and the actual WinForms sync timer driven with offline fixtures.
- Live-state cases covered external volume/mute, same-level default switch, shared endpoint mappings, disconnected/disabled/reconnected devices, confirmed own writes, both pickup directions, unchanged-snapshot redraw suppression, active-turn grace, snapshot failure/recovery, empty observations, app readback limitations, and retained footer events. Fixtures made no real audio/profile writes.
- Final full-suite receipt: **Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=21, BluetoothPaired=4, KnobSweepMs=123.67, UI=Visible**. The offline UI sweep was 99.28 ms. These are startup selection/redraw tests, not physical MIDI-to-audio timing.
- PowerShell parsing and `git diff --check` passed. Rendered checks covered 1680×970, 1366×768, and 1200×740. Captures are in `C:\Users\jdben\Documents\APC-DECK UI Audit 2026-10-28\live-state`.

### Restart and live evidence

- Confirmed PID 85456's command line and that the inspector showed no pending changes, then used normal Stop mode. It exited before Wait-Process attached; verified absent before launching the existing desktop shortcut through Explorer on the default desktop.
- Replacement PID **84116**, HWND **4067126**, was visible/responding and displayed MIDI IN / LED OUT ONLINE. Restored the prior window frame: 1665×962 at x=888/y=265 (desktop tooling rounds the requested width by one pixel).
- Post-restart rendered levels matched a fresh read-only Windows snapshot: master 42%, COMMAND_CENTER 31%, VOICE_CUBE 38%, M-AUDIO 34%, CMD_MIC 100%, PS5_MIC 10%; PS5_HEADPHONES and META_VR output both 0% and muted.
- Profile SHA-256 stayed **D7C5D06D756824D37E882F2C7703BA5376BF002E1AD67EC7B2F79D665128FCC4**. The app is left open. No deliberate live volume-change or physical-knob latency experiment was performed.

Remaining audit priorities: keyboard/focus and piano accessibility, broader contrast/state consistency and DPI qualification, and optional app-session readback. Reuse this pass's completed evidence unless code or conditions change.

## 10. Keyboard Navigation and Visible Focus — Implemented 2026-10-29

The user authorized keyboard navigation, visible focus, piano-key coverage, testing, and restart. Base is published live-state commit `c1a6d80`. After verification, the user explicitly authorized committing and pushing this pass to `origin/main`; implementation, tests, user guide, and this handoff belong to the same release.

### Delivered behavior

- `KeyboardNavigation.ps1` supplies one remembered tab stop per hardware group: pads, scenes, tracks, knobs, transport, and piano. Tab/Shift+Tab move between groups and the native inspector. Arrows follow the pad/knob rows and columns; piano Left/Right traverse all 25 notes chromatically. Home/End select each group's endpoints. Movement stops at group edges.
- F6 moves from the deck to the label editor and back to the selected mapping. Enter/Space on the deck select only. Ctrl+T and Test remain explicit actions; Ctrl+S and right-click Test retain their behavior. Native text boxes and combo boxes retain ordinary editing keys.
- A white ring with a black outline marks focus, distinct from cyan selection. White piano-key focus is drawn below the overlapping black keys, so it stays visible. Mouse selection sets the corresponding keyboard target. MIDI Learn changes selection without calling Focus or changing the remembered piano focus note.
- `KeyboardSurface.cs` extends the existing double-buffered SurfaceTile/BufferedButton classes and adds a single KeybedCanvas with 25 cached virtual accessibility children. Names, roles, values, selection/focus, default selection actions, and piano hit testing are exposed. Piano mapping names/values notify accessibility clients when updated; knob values use cached observed state.
- Hardware dimensions/order, mapping persistence, endpoint caches, WinMM lifecycle, launcher/placement, and the MIDI dispatch block are preserved. The piano remains one painted control; no per-key native controls or audio lookups were added to painting. Focus repaints only the affected control/canvas.

### Verification before restart

- Extended the existing offline WinForms harness with `tests/KeyboardCases.ps1`; its success marker is required by `Test-ApcInspector.ps1`. All 90 accessible default actions selected their mapping without executing audio/actions or saving. Cases also cover spatial arrows, six roving tab groups, native key acceptance, inspector boundaries, F6, 25 chromatic notes, boundary stops, piano focus/selection/hit testing, retained drafts, and MIDI selection preserving editor focus.
- Rendered focus on a pad, black key, and white key at **1680×970, 1366×768, and 1200×740**. Evidence: `C:\Users\jdben\Documents\APC-DECK UI Audit 2026-10-29\keyboard`.
- A separate temporary offline window verified actual Windows input delivery and accessibility traversal before production restart. Windows accessibility inspection returned all **90 mappings, including 25 piano keys**. Native arrows, group Tab, inspector Shift+Tab, F6, and More-actions-to-deck Tab were confirmed by state readback. Background modifier delivery did not reproduce Shift+Tab, so that one key was repeated using foreground delivery and confirmed. The probe was closed normally and never acquired MIDI or wrote the real profile/audio.
- PowerShell parsing and `git diff --check` passed. Compared the queued-CC dispatch block against `c1a6d80`: identical after newline normalization.
- Full `Test-ApcDeck.ps1` passed: **Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=19, BluetoothPaired=4, KnobSweepMs=149.45, UI=Visible**. The offline UI sweep was 114.77 ms. These are existing startup selection/redraw tests, not physical MIDI-to-audio timing. Endpoint count reflects current Windows state, not a test mutation.

### Restart and preservation

- Verified PID 84116's command line and no pending drafts, signaled normal Stop, waited for exit, and launched the existing desktop shortcut through Explorer/default desktop only after all tests passed.
- Replacement PID **81792**, HWND **4132662**, is visible/responding with **MIDI IN / LED OUT ONLINE**. Restored prior geometry: 1665×962 at x=888/y=265 (one-pixel tooling rounding).
- Live accessibility readback again exposed all 90 mappings. A safe live selection check focused C-sharp 3 and sent Right; inspector readback showed **KEY D3 / Key_50**, with the white-key focus ring visible. No mapping was executed. The app is left open with D3 selected.
- Profile SHA-256 remained **D7C5D06D756824D37E882F2C7703BA5376BF002E1AD67EC7B2F79D665128FCC4** before tests and after restart/live selection.

### Remaining scope

Keyboard behavior and accessibility-object/provider coverage were verified; a full Narrator user journey, high-contrast theme qualification, and broader increased-text/DPI coverage were not performed. Next audit work is contrast and pad readability, separating operational status from customizable physical LED colors without changing hardware LED outputs. App-session volume readback remains a separate optional improvement.

## 11. Contrast and Pad Readability — Implemented 2026-10-29

The user authorized this implementation and a restart after testing, explicitly preserving hardware layout, physical LED outputs, and latency fixes. Base is published keyboard commit `3bd2b56`. After verification, the user explicitly authorized committing and pushing this pass to origin/main; implementation, tests, user guide, and this handoff belong to the same release.

### Delivered behavior

- `PadPresentation.ps1` derives screen labels and operational states from existing snapshots, separately from customizable LED colors. Neutral pad fills and bright wrapped names replace saturated fills and the arbitrary 14-character label cutoff. The thin LED strip retains the existing velocity/color mapping. Row/column, target, decoded LED color, and full status remain in tooltips and accessible values.
- Larger pads show Default, Ready, Live, Muted, Disabled, Offline, Missing, or Unknown beneath the name. Compact pads reserve their height for the label; the selected inspector always shows full saved status. Unapplied drafts do not alter that status. Bluetooth feedback describes audio-link evidence only. Refresh failure marks audio-related pad telemetry unavailable until recovery.
- State-only changes invalidate the affected pad even when custom active/standby LED colors are identical. Unchanged snapshots request no pad repaint. Presentation work runs on existing refreshes, not the MIDI CC dispatch path.
- Scene/track caps use neutral fills with colored rings. Piano and transport colors are retained while their foreground automatically chooses black or white for readable contrast. Pad palettes use system window/text colors when Windows high contrast is active.
- The core `ApcDeck.psm1` LED/audio engine is unchanged. The queued-knob dispatch block is identical to `3bd2b56` after newline normalization. Hardware dimensions/order, polling, endpoint caches, SurfaceTile controls, shutdown, and launcher behavior remain intact.

### Verification before restart

- Added `tests/PadCases.ps1` to the existing offline UI harness and required its success marker. Tests cover independent state/LED identity, identical custom colors across state changes, disabled/missing/disconnected/unknown states, partial swaps, telemetry failure/recovery, unchanged-snapshot repaint suppression, full saved labels, inspector/tooltips/accessibility, and zero fixture audio/action/profile writes.
- Measured all pad text tones against normal and selected backgrounds: minimum **7.3:1**. Custom piano/transport foreground combinations meet at least 4.5:1. Rendered review covered **1680×970, 1366×768, 1200×740**, and a forced system-color palette. Evidence: `C:\Users\jdben\Documents\APC-DECK UI Audit 2026-10-29\contrast`.
- PowerShell parsing and `git diff --check` passed. Full `Test-ApcDeck.ps1` passed, including ten dispatch cases, snapshot cache tests, inspector/draft tests, live-state/pickup tests, and keyboard/piano cases. Final receipt: **Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=19, BluetoothPaired=4, KnobSweepMs=122.9, UI=Visible**. Offline UI sweep: 86.14 ms. These are startup selection/redraw measurements, not physical MIDI-to-audio latency.

### Restart and preservation

- Verified PID 81792's command line and no pending drafts, stopped it normally, waited for exit, then launched the existing desktop shortcut through Explorer/default desktop after all tests passed.
- Replacement PID **73548**, HWND **4198198**, is responding and visible with **MIDI IN / LED OUT ONLINE**. Restored prior geometry: 1665×962 at x=888/y=265. Live screen and accessibility readback show independent Default/Unmuted/Muted/audio-link states and LED identities; the app is left open with Pad_32 selected.
- Profile SHA-256 remained **D7C5D06D756824D37E882F2C7703BA5376BF002E1AD67EC7B2F79D665128FCC4** before and after restart. Physical LED code/settings were preserved and tested; no deliberate physical input/output timing experiment was performed.

Remaining audit scope: broader DPI/increased-text usability and a full Narrator journey; complete OS high-contrast theme qualification (the system-color fixture is not that qualification); optional app-session volume readback. Compact labels can still ellipsize at the fixed hardware layout's minimum dimensions, with full text available in the inspector and tooltip.

## 12. DPI and Larger-Text Usability — Implemented 2026-10-29

The user authorized implementation and restart after testing, preserving hardware layout, physical LED outputs, and latency fixes. Base: published contrast commit `fe972d1`. After verification, the user explicitly authorized committing and pushing this pass to origin/main; implementation, tests, user guide, and this handoff belong to the same release.

### Delivered behavior

- `TextLayout.ps1` reads Windows Accessibility `TextScaleFactor` on startup/activation, bounded to 100–225%. **More actions → Text size** offers session overrides and **Use Windows text size**. These actions do not change Windows preferences or mapping persistence.
- Inspector fields, labels, toggles, menus, and persistent actions use the requested font size. Selected context remains above the scrollable area; the three mode toggles now begin that area. Wrapped text determines field/toggle heights. Apply/Revert/Test remain fixed; the full 50% volume warning stays on knob Test. Wide dropdown lists improve device-name readability.
- Hardware geometry remains fixed. Preallocated font choices let pad/knob/scene/track/piano text enlarge only while meaningful words, percentages, and note identities still fit. Label wrapping keeps words intact, ellipsizing overlong words instead of fragmenting them vertically. Knob and piano text rows use actual GDI+ font heights; dial artwork yields to text. Full labels and state remain available in the inspector/tooltips/accessibility values.
- Fonts are created only when text size changes, previous generated fonts are disposed, and wrapped surface strings use a bounded cache. Header row heights remain stable during hardware selection to avoid repeated inspector layout. No registry or endpoint query was added to the MIDI tick or painting.
- `ApcDeck.psm1` is unchanged, and the queued-CC dispatch block matches `fe972d1` after newline normalization. Physical LED mappings/transmission, audio caches, polling, shutdown, AutoScaleMode=None, and desktop launcher/placement behavior are preserved. The implementation uses measured text layout while retaining the established [WinForms scaling mode](https://learn.microsoft.com/en-us/dotnet/desktop/winforms/automatic-scaling-in-windows-forms).

### Verification before restart

- Added `tests/TextLayoutCases.ps1` to the existing offline harness, with a required success marker. Tested **100%, 125%, 150%, 200%, and 225%** fonts at **1680×970 and 1200×740**. Checks cover fixed action bounds and text fit, scrollable fields, wrapped toggles, retained drafts, menu selection/reset, non-compounding font changes, and zero audio/action/profile writes.
- Compared all 65 native hardware-control bounds and 25 piano-key rectangles across text sizes: identical for each window size. LED values remain identical. GDI+ bitmap contexts at **96/120/144/192 DPI** verified that full volume percentages and sharp-note identities fit proportional device-pixel cells. These are font-metric checks, not actual OS display-mode changes.
- Rendered review caught excessive hardware-text enlargement at 225%; the final fitting policy preserves meaningful compact labels and piano note identities. Reviewed minimum/large layouts and the live 150% override. Captures: `C:\Users\jdben\Documents\APC-DECK UI Audit 2026-10-29\text-size`.
- PowerShell parsing and `git diff --check` passed. Full `Test-ApcDeck.ps1` passed, including ten dispatch cases, snapshot cache tests, inspector/drafts, live state/pickup, keyboard/piano, contrast, and text sizing. Final receipt: **Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=19, BluetoothPaired=4, KnobSweepMs=167.57, UI=Visible**. Offline sweep: 124.32 ms. These are startup selection/redraw measurements, not physical MIDI-to-audio latency.

### Restart and live verification

- Verified PID 73548's identity and no pending drafts; stopped it normally, waited for exit, and launched the existing desktop shortcut through Explorer/default desktop only after the full suite passed.
- Replacement PID **18328**, HWND **6621922**, is visible/responding with **MIDI IN / LED OUT ONLINE**. Restored prior geometry: 1665×962 at x=888/y=265. Safe native UI interaction selected **150%**, confirmed larger editor/action controls, then restored **Use Windows text size** (105%). No mapping action was executed.
- Windows TextScaleFactor remains **105**, and profile SHA-256 remains **D7C5D06D756824D37E882F2C7703BA5376BF002E1AD67EC7B2F79D665128FCC4**. The app is left open with Pad_32 selected and no pending drafts.

Remaining qualification: actual mixed-DPI monitor transitions and Windows display-mode changes, sub-minimum work areas, a full Narrator journey, and full OS high-contrast behavior. Existing desktop/DPI awareness was deliberately preserved. Compact hardware labels can still ellipsize; the inspector honors the full requested text size while hardware text is bounded by available space. App-session volume readback remains optional separate work.

## 13. Accessibility Pass — Implemented, Partial Interactive Qualification (2026-10-29)

User authorized the accessibility pass including Narrator/Windows high contrast and restart after testing, preserving layout, physical LEDs, and latency. Base: published `f4dd187`. On 2026-11-04, the user authorized committing and pushing this pass to origin/main, including implementation, tests, user guide, and handoff.

### Delivered and tested

- `Accessibility.ps1` exposes contextual target/color names, draft/validation descriptions, action availability, and debounced Windows automation notifications for edits, errors, Apply/Revert/Test outcomes. Background hardware events remain quiet. F8 and More actions → Read selected status report cached mapping/state, mute/pickup feedback, drafts, and validation; no speech engine, endpoint enumeration, or device action is introduced.
- `ContrastTheme.ps1` uses system colors across the entire surface, native inspector, transport outlines, and custom focus indicators. Piano natural/sharp geometry and identities remain intact. Startup and `SystemColorsChanged` apply/restore the presentation. The implementation follows [Windows high-contrast guidance](https://learn.microsoft.com/en-us/windows/win32/winauto/high-contrast-parameter).
- Added `tests/AccessibilityCases.ps1` and a required harness marker. Verified contextual labels, invalid target descriptions, retained drafts through repeated theme changes, save failure/retry, Revert/Test notifications, F8/menu status, quiet background refresh, unchanged geometry/LED velocities, and no incidental audio/profile/action writes. The notification API returned **True**, which establishes submission to Windows, **not actual Narrator speech**.
- Full `Test-ApcDeck.ps1` passed before restart: **Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=19, BluetoothPaired=4, KnobSweepMs=228.03, UI=Visible**. Offline sweep 184.28 ms. Existing keyboard tests include all 90 mappings and 25 individual piano keys. Parsing and `git diff --check` passed. `ApcDeck.psm1` and the MIDI/queued-dispatch section are unchanged from HEAD.
- Inspected the rendered light system-color fixture at minimum size and an actual Windows dark high-contrast transition in an isolated, offline UI probe. Live `SystemColorsChanged` updated the open form; this exposed and led to fixing the transport border color. The initial light OS theme attempt was inconclusive; the later Desert test below qualified the actual light-theme transition. Captures and disposable probe scripts: `C:\Users\jdben\Documents\APC-DECK UI Audit 2026-10-29\accessibility`.

### Runtime and restoration

- After the full suite passed, verified production PID 18328's identity and saved state, stopped it normally, and relaunched through the existing desktop shortcut/Explorer. Replacement **PID 69408, HWND 9373322**, responds and reports **MIDI: ONLINE (IN + LED OUT)**. Restored 1665×962 at x=888/y=265; Pad_32 selected with no pending edits.
- Profile SHA-256 remains **D7C5D06D756824D37E882F2C7703BA5376BF002E1AD67EC7B2F79D665128FCC4**. Windows text scale remains **105**. Actual high contrast is **False**, system Window/WindowText are white/black, and Windows restored `Custom.theme`. Original HighContrast registry values restored: Flags `4152`, empty `High Contrast Scheme`.
- Test Narrator PID 30808 was started, but the UI driver reported the desktop locked. Neither shortcut attempts nor speech recap produced verifiable speech evidence. Direct process termination was denied by Windows; opening the installed Narrator Home app and invoking **Exit Narrator** succeeded. Verified no Narrator process and `NoRoam\RunningState=0`. Offline probe exited normally; production remained intact throughout its tests.

### Remaining acceptance work

The full Narrator journey is **not complete**. Existing automation-provider tests must not be relabeled as spoken acceptance. Avoid rerunning unrelated passing regression work unless code changes. This pass does not claim physical MIDI-to-audio latency measurement or app-session volume readback.

### Interactive follow-up after the user unlocked Windows

- Used the isolated offline probe again (PID 74760), preserving production PID 69408 and the real profile. Narrator speech recap visibly confirmed **Pad_32 — OUT: CMD CTR**, SetDefaultDevice, Default, Green LED, row/column; **C sharp 3 — KEY C#3 — Key_49**, button/None; and F8 output **KEY D3. Key_50. Saved · no pending changes. Action: None. Test saved action (Ctrl+T)**. This is actual Narrator speech-history evidence, beyond provider/API acceptance.
- Exercised native inspector focus, label draft, empty target, Revert, simulated save failure with retained draft, successful retry, recorded Test, and cached knob F8 status. The empty target disabled Apply/Test and queued the explanatory error; failure retained the draft; retry saved only the offline copy. Do not classify these later announcements as spoken acceptance: the restarted Narrator's recap could not be reopened reliably through the lower-integrity helper. A manual shortcut request was sent; no reply was received before cleanup.
- The `desktop_unlocked=false` driver field was still returned after unlock, while a read-only Win32 input-desktop query returned **Default**. That field alone is insufficient evidence that Windows is locked. Later foreground/input errors explicitly described Windows integrity/UIAccess restrictions. Do not repeat the earlier lock diagnosis from that field alone.
- Applied **Desert** through Windows Settings → Accessibility → Contrast themes. Verified actual OS `hcwhite.theme`, probe HighContrast=True, Window=-1297 / WindowText=-12763843, and inspected `accessibility\actual-desert.png`: inspector, selected knob, transport boundaries, pad labels, and natural/sharp piano identities remained readable. Restored **None** through Settings and verified `Custom.theme`, HighContrast=False, white/black system colors, text scale 105, original Flags 4152/empty scheme, and the prior remembered dark contrast theme. Both actual dark and light theme transitions are now qualified.
- No application code changed in this follow-up, so the preceding full-suite receipt remains applicable. Remaining acceptance is the actual Narrator spoken inspector error/save/retry/Revert/Test sequence and a fuller spoken navigation sample; it requires an interactive recap or listening check. The broader functionality already has passing automated tests.
- Follow-up cleanup verified: Narrator exited (RunningState=0), offline probe exited, Settings closed, production PID 69408 remains responding at 1665×962 / x888 / y265, and profile SHA-256 is unchanged. No additional restart was needed.
- The assisted recap attempt replayed empty-target error, Revert, draft edit, simulated save failure, retry, and Test in offline probe PID 93824 / HWND 1508372 with Narrator PID 51164. Notifications submitted with focus; the real profile remained unchanged. The user then clarified that the crosshair/dim overlay belonged to Speechify and chose Speechify as the preferred reader. Further Narrator spoken acceptance is deferred in favor of this on-demand workflow; the partial Narrator qualification above remains accurate.
- Verified the installed Speechify shortcuts: Alt+A reads selected text, Alt+X captures a screen region to listen, and Alt+Q pauses/resumes. With the offline probe in front, selected its native status text and invoked Alt+A. Speechify's Today listening history contained the exact status and result: `MIDI: OFFLINE | Speaker: COMMAND_CENTER (50%) | Mic: CMD_MIC (50%)` and `[TEST Pad_32 — not saved] Offline action test recorded; no action executed.` This proves selected-text ingestion/listening-history evidence, not independent auditory verification or screenshot-OCR qualification. F8's Windows notifications do not automatically invoke Speechify.
- Final cleanup on 2026-10-29: exited Narrator through Narrator Home (RunningState=0), closed probe PID 93824 using its stop marker, and left Speechify running on its Shortcuts page. Production PID 69408 remained responding. Real profile SHA-256 remained D7C5D06D756824D37E882F2C7703BA5376BF002E1AD67EC7B2F79D665128FCC4; Windows text scale was 105, contrast Flags were 4152, and Custom.theme was restored. No application code changed or additional restart was needed during that follow-up.

### Release verification (2026-11-04)

- Refreshed origin/main; local and remote base were both `f4dd187`. Reviewed the pending accessibility implementation and tests; `ApcDeck.psm1` remains unchanged. No application implementation changes were needed for release.
- Full `Test-ApcDeck.ps1` passed again: **Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=18, BluetoothPaired=4, KnobSweepMs=309.95, UI=Visible**. Offline UI sweep was 117.03 ms. All inspector, live-state, keyboard/piano, contrast, text-layout, and accessibility markers passed. `git diff --check` passed. These sweep figures measure startup selection/redraw, not physical MIDI-to-audio latency.
- The current real profile differs from the October test baseline and was preserved: SHA-256 **02805CD35F251798CCD8FC37A45E264A4D6AA73DC6D16F70015DFCE66C3B8781** before and after testing. No production restart was performed for this commit/push request.
- Recommended next audit work: measured fluidity (P2-10). Profile selection, Apply, and Refresh separately; optimize only demonstrated delays while preserving cached audio access, MIDI dispatch ordering, hardware layout, and physical LED behavior. Actual mixed-DPI monitor transitions/small work areas remain a separate qualification gap; app-session volume readback remains optional. Full Narrator spoken qualification is deferred per the user's Speechify preference, and Speechify screenshot OCR still needs its own witness.

## 14. Measured Fluidity — Implemented 2026-11-04

### Measurements and scope

Profiled real WinForms selection/Apply handlers in an isolated offline window, with real read-only audio discovery, the actual profile serializer redirected to a disposable file, and no-op MIDI/LED/audio-action sinks. Compared five samples per operation; separate async discovery used three cold-name-cache runs. Evidence/scripts: `C:\Users\jdben\Documents\APC-DECK UI Audit 2026-11-04\fluidity`. These are handler/paint timings, not physical input-to-audio latency.

| Operation | Baseline median | Final median |
|---|---:|---:|
| Repeated target dropdown population | 19.27 ms | 0.69 ms |
| Select device-volume knob K2, including repaint | 41.87 ms | 21.47 ms |
| Select master-volume knob K1, including repaint | 28.46 ms | 17.34 ms |
| Select Pad_26, including repaint | 27.72 ms | 17.35 ms |
| Apply label through temporary real profile save | 39.91 ms | 45.47 ms |

Apply showed no demonstrated pause requiring a persistence change; its original atomic temporary-file/backup behavior remains. The small timing variation is not claimed as an improvement. Other selection measurements and maxima are retained in the JSON evidence.

Cold name/device discovery originally occupied the calling thread for **566.33 ms**; warm discovery was about 30 ms. The new explicit Refresh start returns in **8.57 ms median / 17.68 ms max**. Real cold discovery takes **1366.57 ms median wall time**, during which the UI message pump continues running. Completion plus repaint is **31.73 ms median / 142.35 ms first-run max**; its fresh owner-thread audio read is **16.48 ms median / 46.08 ms max**. This trades additional elapsed discovery time for responsiveness; it does not make discovery itself faster.

### Implementation and preservation

- `Set-TargetChoices` compares choice sequences before changing native ComboBox items, uses one AddRange when needed, and preserves typed targets/caret under suppressed edit events. Selection checks current snapshot choices even when the action type is unchanged. Empty/changed snapshots remain supported.
- `Read-DeviceNames.ps1` imports the existing engine in a disposable hidden process and reads endpoint names without opening MIDI, loading mappings, saving profiles, or executing actions. `DeviceRefresh.ps1` owns one process/result file, polls completion on a 50 ms UI timer, exposes progress/error/retry, times out discovery after 15 seconds, and cleans up on completion/failure/shutdown. Periodic sync yields while explicit discovery is pending; completion honors the existing 800 ms knob-turn grace.
- Only a JSON dictionary of endpoint ID/name strings crosses the process boundary. `Get-AudioEndpointsSnapshot -FriendlyNames` seeds its existing name cache, then performs the existing fresh observation/cache-rebinding logic on the UI thread. Worker volume/default observations are never adopted over newer user commands. MIDI reconnection and forced physical LED synchronization remain on the original owner thread; only changed pad/knob presentations repaint.
- No hardware layout, physical LED solver/transmitter, volume-write path, polling interval, launcher, or WinMM shutdown changes. The entire MIDI dispatch block matches `3d23782` after newline normalization. `ApcDeck.psm1` changes only by the optional name-cache seed parameter and loop.
- This pass targets explicit Refresh. Startup and ordinary periodic observations retain their existing design; an endpoint arriving after the worker snapshot can still require a fresh property lookup. No blanket claim of zero UI-thread work or full discovery isolation is made.

### Verification and launch

- `tests/FluidityCases.ps1` exercises unchanged choice/caret preservation, empty/changed snapshots, drafts and UI heartbeat during a slow worker, single-flight requests, periodic exclusion, owner-thread snapshot input, forced LED sync, active-knob grace, failure/invalid-result/timeout/retry, and worker/file cleanup. All side effects use recording/no-op sinks. Existing full accessibility/keyboard/piano/contrast/text-size/draft tests passed.
- Full `Test-ApcDeck.ps1` passed before launch: **Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=18, BluetoothPaired=4, KnobSweepMs=283.45, UI=Visible**. Offline sweep: 110.8 ms. PowerShell parsing and `git diff --check` passed. No real profile/audio-action writes occurred during the isolated profiling and interaction tests.
- APC-DECK was closed when this work began. After tests passed, launched the existing desktop shortcut. **PID 69272 / HWND 135962** is visible and reports **MIDI: ONLINE (IN + LED OUT)**, with Saved/no pending changes. A live F5 completed successfully and reported synchronized endpoints/LEDs; rendered inspection retained the hardware layout and fixed inspector actions. The current launch geometry is 2082×1204 at x679/y144; old October process IDs/geometry were not treated as live state.
- Real profile SHA-256 remained **02805CD35F251798CCD8FC37A45E264A4D6AA73DC6D16F70015DFCE66C3B8781** after testing and launch. The user subsequently authorized publishing this pass to origin/main. Release preparation updated documentation only and retained the passing implementation/test evidence above; no additional app restart was needed. Remaining audit opportunities: actual mixed-DPI/small-work-area qualification, restrained interaction feedback, and optional app-session readback.

## 15. Mixed-DPI and small-window usability (2026-11-08)

### Changes and preservation

- The previous 1200-pixel minimum could not fit the portrait monitor's 864-pixel logical work area at 125%. The window now allows 640 × 560 logical pixels; below 1180 pixels of client width it offers native Controller/Inspector tabs with F6 switching. The same inspector controls retain their drafts, focus navigation, accessibility metadata, and actions across pane changes.
- The controller sits in a scrollable viewport with a 780 × 580 minimum canvas. Its 5×8 pads, scenes/tracks, 2×4 knobs, transport cluster, and 25-key piano retain their topology. Selecting a control reveals it in the viewport. Wide geometry restores exactly after compact/text-size roundtrips; the 1680 × 970 window retains its original 1272 × 817 chassis.
- In compact mode, selected metadata scrolls with the fields and More actions shares the draft-status row. Apply/Revert/Test remain fixed. Tests caught and corrected both insufficient editor height at 225% text and stale scrollbar dimensions after returning to a wide window. Shift+Tab from the first deck group reveals the inspector before focusing More actions.
- Restore, activation, and completed moves/resizes fit to the current monitor's work area, using the form's coordinate space. Startup remains centered on the primary display. No global display-setting subscription or DPI-awareness change was introduced.
- `ApcDeck.psm1`, physical LED mapping/transmission, audio writes, timers, and device discovery remain unchanged. The MIDI dispatch block matches `f6d2085` exactly after newline normalization. The normal selection path skips viewport work when no scrollbars are present.

### Verification

- Full `Test-ApcDeck.ps1` passed before production launch: **Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=21, BluetoothPaired=4, KnobSweepMs=419.3, UI=Visible**. Offline sweep was **135.84 ms**. These are smoke observations under the existing 500 ms gate, not physical MIDI-to-audio latency measurements.
- New `tests/WindowLayoutCases.ps1` covers 1024×700, 800×600, and 640×560 at 100%, 150%, and 225% text; visible actions and usable editor space; F6 and Shift+Tab; pad/scene/knob/transport/natural/sharp-key visibility; retained drafts; exact wide geometry restoration; portrait/negative-origin work areas; and no LED/audio/action/profile writes. Existing inspector, live-state, pickup, keyboard, contrast, text-size, accessibility, and fluidity checks all passed. PowerShell parsing and `git diff --check` passed.
- With explicit user permission, temporarily changed only Settings Display 2 (portrait/flipped) from 125% to 150%. Offline probe PID 24176 moved from primary 125% to portrait 150%, back to primary 125%, again to portrait 150%, and to the upper 125% monitor with a negative origin. A native label draft survived; Apply/Revert/Test/More remained inside the compact inspector. Invoking C5 brought its full UIA rectangle inside the viewport. Both Settings readback and `GetScaleFactorForMonitor` confirmed restoration to 125% before cleanup.
- At 150%, the portrait work area was 720 × 1232 in the app's logical coordinates; the tested compact window was 659 × 606 and fit inside it. The upper monitor's work area was (-321,-1680,3072,1642). Frame setters can report a one-pixel mismatch from nonclient/DPI rounding; independent UIA and in-process readbacks supplied the actual geometry.
- DPI awareness remains **0 / unaware**, and `GetDpiForWindow` remains **96**. Windows continues bitmap scaling; this is mixed-DPI fit/interaction qualification, not per-monitor crisp-rendering qualification. Cua window screenshots can include black padding for the scaled unaware window; fixture DrawToBitmap images and live UIA bounds supplement them.
- Evidence, rendered fixtures, full-suite output, and live monitor-state receipts: `C:\Users\jdben\Documents\APC-DECK UI Audit 2026-11-08\window`. The Settings instance initially hung; it was restarted for the test and closed afterward. The offline probe exited through its stop marker. No Narrator or Speechify session was needed.

### Production launch and current boundary

- APC-DECK was closed at the start of this task. After the full suite and live mixed-DPI checks passed, launched the existing desktop shortcut. **PID 99720 / HWND 993318** is visible and responding, at 2082 × 1204 / x679 / y144, and reports **MIDI: ONLINE (IN + LED OUT)**. The normal hardware/inspector view is restored.
- The real profile SHA-256 remains **02805CD35F251798CCD8FC37A45E264A4D6AA73DC6D16F70015DFCE66C3B8781**. Portrait scaling is restored to 125%; the offline probe and Settings test window are closed. The user subsequently authorized committing and pushing this pass to origin/main. Release preparation refreshed origin/main (matching base `f6d2085`), reviewed the diff and passing test receipt, and updated documentation only; no additional app restart was needed. PID 99720 remained responding.

## 16. Restrained interaction feedback (2026-11-08)

### Behavior and boundaries

- `InteractionFeedback.cs` adds local hover and pressed outlines to the existing SurfaceTile controls and to individual natural/sharp piano keys. Pressed feedback clears on mouse release, pointer exit, capture loss, disabling, focus loss, and native key release. Keyboard focus remains a separate inner outline. Native transport/inspector buttons retain their standard states. No geometry, control positions, MIDI handlers, or physical LED values change.
- Successful Apply displays `Applied · saved` or the count of retained drafts. Its underline holds for 1200 ms and fades for 160 ms on one 30 ms WinForms timer, then stops; the text remains. New editing/selection clears stale acknowledgement. Failed saves keep their error/draft and never start success feedback. The timer is disposed with the label and stops on hidden/minimized UI.
- Windows animation preference is read through [SystemParametersInfo / SPI_GETCLIENTAREAANIMATION](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow). Failed reads choose static feedback. Disabled animations and high contrast use a static underline without a timer. An animation-preference change during the brief effect stops fading at the next tick. No Windows setting was changed for this pass; isolated tests inject the preference reader for both values and a live transition.
- Selection and volume indicators remain immediate. There are no selection animations, per-control animation timers, idle decorative loops, new dependencies, or global preference subscriptions. `ApcDeck.psm1` is unchanged, and the MIDI dispatch block matches `284b668` exactly after newline normalization.

### Verification

- Full `Test-ApcDeck.ps1` passed before restart: **Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=21, BluetoothPaired=4, KnobSweepMs=405.55, UI=Visible**. Offline sweep: **169.16 ms**. This passes the existing 500 ms smoke gate; it is not a physical MIDI-to-audio latency measurement.
- `tests/InteractionFeedbackCases.ps1` exercises native mouse/key handlers, black-key-first hit testing, cancellation, disabled/focus cleanup, successful/failed/repeated Apply, edit/selection interruption, finite timer completion, reduced-motion preference changes, high contrast, hidden panes, unchanged geometry, and no audio/action/LED side effects. Saves use the existing recording sink and never touch the real profile.
- Initial suite runs encountered focus/visibility assertions during text/layout transitions. The fixture now pumps native pending events after layout/focus requests and reports actual bounds/focus in failures; the final complete suite passed. The hidden-pane timer assertion similarly waits for its bounded next tick. Existing keyboard/piano, live-state/pickup, contrast, larger-text, accessibility, fluidity, and compact-window checks all passed.
- Rendered wide pressed/Apply, compact static reduced-motion, and high-contrast fixtures were inspected. They retain the existing dark console layout and readable text. Evidence and full output: `C:\Users\jdben\Documents\APC-DECK UI Audit 2026-11-08\feedback`. PowerShell parsing and `git diff --check` passed.

### Restart and current state

- Before restart, verified production PID 99720's identity, restored its minimized window through the app's show event, and confirmed Saved/no pending changes. Stopped it normally with `-Mode Stop` and verified exit, then launched the existing desktop shortcut only after the full suite passed.
- Replacement **PID 57840 / HWND 1779612** is visible and responding at 2082 × 1204 / x679 / y144, reports **MIDI: ONLINE (IN + LED OUT)**, and shows Saved/no pending changes. Rendered inspection retains the hardware layout and persistent inspector controls.
- Real profile SHA-256 remains **02805CD35F251798CCD8FC37A45E264A4D6AA73DC6D16F70015DFCE66C3B8781**. No Windows animation, text, display-scaling, or contrast setting was changed. On November 9 the user authorized committing and pushing this pass to origin/main. Release preparation refreshed origin/main (matching base `284b668`), reviewed the diff and passing full-suite receipt, and updated documentation only. PID 57840 remained responding and the profile hash was unchanged; no additional restart was needed.
- Recommended next audit work: finish recovery clarity from P2-11 with a compact recent-events view and persistent, actionable failure details. Validation and draft retention already have passing coverage; the remaining gap is that the footer retains only one event, so a later action replaces an earlier failure. Keep history bounded and avoid automatic retries of actions that affect audio or launch shortcuts. Afterward, reconcile the original audit against the completed passes before adding further polish.

## 17. Recovery clarity and pickup defaults (2026-11-13)

### Behavior and preservation

- `RecoveryEvents.ps1` adds More actions → Recent events / F9 as a modeless native window. It stores at most 50 session events in memory, coalesces consecutive identical failures, prioritizes unresolved failures over successful activity within the cap, and excludes ordinary selections/knob telemetry. A footer/menu count remains until a failure is reviewed or the matching operation succeeds. Mark reviewed preserves details and does not claim success; a recurrence becomes a new issue. No history disk writes, idle timers, or automatic action retries were added.
- Retry Refresh uses existing asynchronous discovery and single-flight protection. Apply/Test recovery returns to the corresponding current draft and focuses its existing action button; it never executes an old mapping or saves/replays automatically. Test warns that an action may already have run before feedback failed, including a knob's 50% Test. Known engine-returned failure messages are now recorded as failed Tests, rather than successful Tests. Periodic observation exceptions also enter history. Explicit Refresh distinguishes updated audio/Bluetooth from a still-offline MIDI controller.
- Native list/details/buttons offer full selectable error text, F9/Escape, current text scale at opening, 640×560 minimum, and system-color high contrast including live theme changes. Failures are session-only and bounded, not a durable diagnostic log. Generic failures cannot prove whether an external action completed; recovery copy deliberately requires review before repeating it.
- The user clarified that the desired volume behavior is pickup: a physical knob below or above Windows volume must first reach that volume. Pickup now starts enabled; its existing crossing condition remains, tolerance tightens from 5 to 1 percentage point, and the zero bypass is removed. Once acquired, the original zero/mute/full-scale behavior remains. Disabling pickup opts into direct control for that session; startup restores protection. Physical position is not persisted or assumed at startup.
- Windows endpoint levels remain the readback source, on the existing 5-second observation/800 ms active-turn grace. No Windows volume popup was added. Application-volume mappings still lack session readback and use direct writes, including the user's current K8 Chrome mapping; this limitation was explained. App-session observation/pickup is a useful follow-up if desired.
- `ApcDeck.psm1` is unchanged. The MIDI dispatch block matches `38d7bb6` after newline normalization except the single pickup condition described above. Cached audio writes, coalescing/order, targeted invalidation, polling intervals, hardware topology and physical LED calculation/transmission remain intact.

### Verification and restart

- Full `Test-ApcDeck.ps1` passed before production restart: **Controls=90, MidiIn=0, MidiOut=1, AudioEndpoints=42, BluetoothPaired=4, KnobSweepMs=374.11, UI=Visible**. Offline sweep: **176.3 ms**. This passes the existing 500 ms smoke gate; it is not a physical input-to-audio latency measurement.
- Fifteen recording-sink dispatch cases cover upward/downward catch, low/zero/high starting positions, 1% tolerance, rejection at 5% distance, zero after crossing, unavailable endpoints, app no-readback behavior, and unchanged ordering. Recovery tests cover retained save failure/draft, bounded history and pinned errors, quiet telemetry, duplicate coalescing, recurrence after review, full details, returned engine failure, review without replay, single-flight Refresh retry, F9, 225% text, and high-contrast transitions while open. All previous keyboard/piano, live-state, contrast, text-size, accessibility, fluidity and window-layout tests passed.
- The first full run exposed a pre-existing test assumption: LED tests read customized real mappings while expecting factory colors. Those assertions now use deterministic default-profile fixtures, while the real profile schema check and separate custom-color cases remain. No user mappings were changed to make tests pass. Rendered recovery fixtures were inspected, and PowerShell parsing / `git diff --check` passed.
- Evidence: `C:\Users\jdben\Documents\APC-DECK UI Audit 2026-11-13\recovery`, including `full-suite.txt` and normal/225%-high-contrast renders. Tests use isolated audio/action/profile sinks; no Windows contrast, text, animation, or display setting was changed.
- Current user profile differed from the old handoff at entry and was preserved: SHA-256 **5D50AD80EA18CE42342C7872F421727C072C21B75AB16991CE86E1E4E9DD95D7**. Verified old PID 7352's identity and Saved/no pending changes, stopped normally, verified exit, then launched the desktop shortcut after tests passed.
- Replacement **PID 56668 / HWND 136362** is visible/responding at 2082×1204 / x679 / y144, with **MIDI: ONLINE (IN + LED OUT)**, Saved/no pending changes, and Pickup checked. Endpoint controls show Awaiting turn with observed levels; K8 correctly shows No readback. Live F9 opened the new empty-session history, Escape closed it, and the main hardware view remained visible. The user subsequently authorized committing and pushing this pass to origin/main. Release preparation refreshed origin/main (matching base 38d7bb6), reviewed the scoped diff and passing full-suite receipt, and updated documentation only. PID 56668 remained responding and the current profile hash was unchanged; no additional restart was needed.
- Next audit work: reconcile P2-11 and the original audit against completed passes. Session-volume readback/pickup for Chrome is the concrete remaining volume-feedback gap; avoid assuming one app has a single session or inserting discovery into the MIDI hot path.
