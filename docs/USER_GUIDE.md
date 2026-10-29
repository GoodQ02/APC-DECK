# APC-DECK User Guide

Complete operational guide for **APC-DECK** ([`Open-ApcDeck.ps1`](../Open-ApcDeck.ps1) / [`ApcDeck.psm1`](../ApcDeck.psm1)), the Stream Deck–style visual audio, Bluetooth, LED, and hotkey mapper for the **Akai Professional APC Key 25**.

---

## 1. Opening & Managing APC-DECK

### Desktop Shortcut (Recommended)
Double-click **`APC-DECK`** on your Windows Desktop (`C:\Users\jdben\Desktop\APC-DECK.lnk`).
- If APC-DECK is not running yet, it opens the interactive visual controller window centered on your primary monitor (`\\.\DISPLAY1`) and lights up your APC Key 25 pads.
- If APC-DECK is already running in the background or minimized to the System Tray, double-clicking the Desktop shortcut immediately restores the existing window to the foreground.

### Command Line (`C:\Tools\bin`)
From any PowerShell or Command Prompt window:

```powershell
# Open the visual mapper window (or bring existing instance to front)
apc-deck

# Start silently in the Windows System Tray (both flags supported)
apc-deck -Minimized
apc-deck -Mode Tray

# Inspect live MIDI indices, 90-control count, audio endpoints, and Bluetooth status as JSON
apc-deck -Mode Snapshot

# Reset all 90 controls to the default workstation layout
apc-deck -Mode ResetDefaults

# Stop the running APC-DECK instance cleanly (turns off hardware LEDs)
apc-deck -Mode Stop
```

### System Tray Behavior & Keyboard Shortcuts
- Clicking the window **`X`** button (or clicking **`Minimize to System Tray (Keep Active)`** in the Inspector) minimizes APC-DECK to the **Windows System Tray** so your knobs, pads, and piano keys continue working in the background without cluttering the taskbar.
- **Double-click** the `APC-DECK` tray icon (or right-click -> **Open APC-DECK Window**) to restore the window.
- Right-click the tray icon -> **Quit APC-DECK** (or run `apc-deck -Mode Stop`) to exit completely and turn off all APC Key 25 LEDs.
- **Built-in Keyboard Shortcuts inside APC-DECK**:
  - `Ctrl+S` — **Apply the selected draft**
  - `Ctrl+T` — **Test the displayed draft without saving**
  - `F5` — **Refresh Devices & Sync LEDs**
  - `Right-Click` on any pad, button, knob, or piano key — **Select & Test Action Immediately**

---

## 2. Navigating the 1:1 Physical Hardware Twin Surface

The left chassis renders all **90 mappable physical controls** of the Akai APC Key 25 in a true-to-life **1:1 hardware layout**:

1. **Top-Left Zone — `5×8` RGB Clip Launch Matrix (`Pad_0`–`Pad_39`) + Circular Scene & Track Buttons**:
   - **40 Rectangular Clip Pads (`R1P1`–`R5P8`, `Pad_32`–`Pad_39` down to `Pad_0`–`Pad_7`)**:
     - Each pad renders a recessed hardware bezel, top-left coordinate badge + LED indicator dot, bold primary label, and bottom action/target badge.
     - Active default audio devices and connected Bluetooth devices glow **Solid Green (`Green`)**; standby devices glow **Warm Amber (`Amber`)**; muted or disabled endpoints glow **Solid Red (`Red`)**.
   - **Right Column — 6 Circular Scene / Stop Buttons (`Scene_82`–`Scene_86` + `Scene_81`)**:
     - 5 Green-LED Scene Launch buttons (`► 1` to `► 5`) plus `STOP ALL CLIPS` (`Scene_81`) aligned with Row 6.
   - **Bottom Row — 8 Circular Track / Knob Control Buttons (`Track_64`–`Track_71`)**:
     - Red-LED circular buttons matching the physical silkscreen labels (`▲ UP`, `▼ DOWN`, `◄ LEFT`, `► RIGHT`, `VOL`, `PAN`, `SEND`, `DEVICE`).

2. **Top-Right Zone — `2×4` Rotary Potentiometer Bank (`Knob_48`–`Knob_55`, `K1`–`K8`) + Transport / Shift Row**:
   - **8 Rotary Knobs (`K1`–`K4` Top Row, `K5`–`K8` Bottom Row)**:
     - Renders a realistic circular potentiometer dial with a 270° track arc, live value arc, angular pointer line, target label, live Windows volume (`VOL XX%`), and physical knob pickup readout (`KNOB XX%`).
   - **3 Rectangular Transport & Shift Buttons (`Trans_91`, `Trans_93`, `Trans_98`)**:
     - Located directly beneath the `2×4` knob bank matching the physical `PLAY/PAUSE`, `REC`, and `SHIFT` buttons.

3. **Bottom Full-Width Zone — 25-Note Synth-Action Piano Keyboard (`Key_48` `C3` to `Key_72` `C5`)**:
   - Authentic two-octave overlapping piano keybed with **15 full-height white keys** and **10 recessed black sharp/flat keys** (`C#`, `D#`, `F#`, `G#`, `A#`).
   - Displays each key's assigned action label vertically on white keys and compactly on black keys, with custom color tinting and cyan selection borders.

---

## 3. Inspector, Drafts, and Testing

The inspector shows the selected control, with **Follow hardware selection**, **Edit mode — pause live actions**, and **Pickup — prevent volume jumps** at the top.

- **Follow hardware selection (MIDI Learn)** selects the control you touch. Every control keeps its own unsaved draft when you select a different control, including selection from physical MIDI input.
- Edit **Label**, **Action**, and the relevant target fields. The secondary device field appears only for a two-device swap. Knobs hide color fields; keys expose their screen color.
- **Apply (Ctrl+S)** saves only the selected draft and updates its hardware mapping. Other drafts remain intact. Label/color edits do not force endpoint rediscovery.
- **Revert** discards only the selected draft and restores its saved mapping.
- **Test draft action (Ctrl+T)** runs the displayed draft without saving. With no pending edits, it tests the saved mapping. A knob test explicitly sets its displayed target to **50% volume**. Testing is a deliberate live action and remains available in Edit mode.
- Draft status and **Apply / Revert / Test** stay visible in a fixed footer, even when fields scroll. Invalid required fields or unsupported knob actions disable Apply/Test; temporarily unavailable device mappings may still be saved for later use.
- Drafts are held in this running app session, not written to a separate draft file. Apply before quitting or restarting if you want to retain them across process exits.
- **Edit mode** pauses physical MIDI actions and on-screen knob-wheel volume changes. It does not disable explicit Test or the **Mute saved device (0%)** command.
- **More actions…** contains Mute saved device, Clear mapping in draft, Refresh devices & LEDs (F5), Keep running in tray, and Reset entire profile. Clear is reversible until Apply. Reset still asks for confirmation and discards all drafts.

### Keyboard navigation and focus

- **Tab / Shift+Tab** move between pads, scenes, tracks, knobs, transport, piano, and the inspector. Each hardware group remembers its last focused member, so you do not have to Tab through all 90 controls.
- **Arrow keys** select adjacent controls within a group, following the physical rows and columns. On the piano, **Left/Right** move one semitone, including every black key. Group edges stop movement; **Home/End** select the first/last control in the group.
- **F6** moves from the deck to the label editor, or from the inspector back to the selected mapping. Native text fields and dropdowns keep their normal arrow-key behavior.
- **Enter/Space on the deck select only**. **Ctrl+T** or the inspector's Test button explicitly runs the selected mapping/draft; Ctrl+S still applies it. Right-click testing remains available.
- A white focus ring with a black outline marks the keyboard target. Cyan marks the selected mapping. MIDI Learn may change selection while you edit, but does not steal keyboard focus.
- All 90 mappings expose accessible names and selection semantics; the piano provides 25 individual accessible keys while remaining one lightweight painted canvas. Knobs expose their observed level/status. Full Narrator and high-contrast qualification remains separate from the tested keyboard/accessibility-object behavior.

## 4. Colors and Readable Knob Labels

- LED-equipped pads, scene buttons, and track buttons expose **Active LED color** and **Standby LED color**. Piano keys and transport buttons expose their on-screen color; knobs have no color fields.
- Color dropdowns and swatches both edit the draft. **Apply** commits the color and synchronizes hardware LEDs; **Revert** cancels the change. Blink colors remain available in the dropdowns.
- Knob tiles put **K-number**, **percentage**, and **device label** on separate lines. Labels wrap between words and use ellipses when space is limited. Hover for the full saved label and target; select a knob to see its full mapping in the inspector.
- The 5×8 matrix, scene/track rows, 2×4 knob bank, transport row, and 25-key layout retain their hardware positions.

---

### Live volume and pickup feedback

- Knobs and the speaker/microphone footer reconcile with Windows on the existing **5-second refresh**, including external volume/mute changes and default-device switches. Refresh waits while a knob was turned in the last 800 ms; F5 requests an immediate refresh.
- A changed volume, mute state, or endpoint re-arms pickup. Each tile shows **Awaiting turn**, **CW to 42%**, **CCW to 42%**, or **In sync**. CW means clockwise; CCW means counterclockwise. The zero-stop safety bypass remains available for reachable endpoints.
- **Updating...** identifies a commanded level awaiting readback. **Muted**, **Disconnected**, **Disabled**, and **Unavailable** are distinct from zero volume. Unknown levels show a dash instead of an invented percentage. Refresh failure marks the state unavailable until a successful refresh.
- At compact sizes, tiles shorten feedback and omit the dial artwork to keep numbers and guidance readable. Hover for the full status, saved label, and target; hardware positions do not change.
- Application-volume mappings have no session-volume observer yet. They show **No readback** (compact: **Unverified**) and use direct writes; endpoint pickup cannot validate an app session level.
- The footer refreshes telemetry while retaining your last action message. Bluetooth pad state is refreshed from the existing audio-endpoint evidence; it is not a general Bluetooth radio connection probe.

## 5. Knob Zero-Out, Sub-Millisecond Responsiveness & Soft-Takeover

APC-DECK includes dedicated signal conditioning and caching for the 8 hardware potentiometers (`K1`–`K8`):

### Clean `0%` Mute Floor & `100%` Ceiling Deadzones
- Analog MIDI potentiometers can jitter between `CC 0` and `CC 1` at the bottom stop, or `CC 126` and `CC 127` at the top stop.
- APC-DECK clamps:
  - **`CC <= 1` -> `0%` (`0.0`)** and automatically **mutes** the target Windows audio endpoint (`Mute = $true`) so turning a knob fully counter-clockwise guarantees complete silence.
  - **`CC >= 126` -> `100%` (`1.0`)** and ensures the endpoint is unmuted.
  - Any movement above `CC 1` automatically unmutes the endpoint and scales linearly from `1%` to `99%`.

### 60 Hz Sub-Millisecond Polling & Single-Control Redraw
- Knob events are drained at **60 Hz (16 ms)** using a 4-tier CoreAudio `MMDevice` cache and targeted single-control GDI+ invalidation (`Invalidate-ApcControl`), updating Windows volume and redrawing the rotary dial in **`0.15 ms – 1.0 ms`** without touching the other 89 controls.

### 1-Click `Zero-Out Selected Knob / Device (0% Mute)` Button
- In the right-hand Inspector, choose **More actions… → Mute saved device (0%)** to immediately set the selected knob or audio device button to `0%` and mute it in Windows.

### Optional `Knob Soft-Takeover (Pickup mode — prevent jumps)`
- Located at the top of the Inspector (`Knob Soft-Takeover (Pickup mode — prevent jumps)`).
- When enabled, if a physical knob's position does not match the current Windows volume (for example, right after boot or after changing volume in Windows), turning the knob will **not** cause a sudden volume jump—it waits until the physical knob crosses ("picks up") the current Windows volume level before locking on.
