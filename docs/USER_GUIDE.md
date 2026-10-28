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
  - `Ctrl+S` — **Apply & Save Mapping**
  - `Ctrl+T` — **Test Selected Action Now**
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

## 3. MIDI Learn, Edit-Only Mode & Live Target Validation

Located at the top of the right-hand **Stream Deck Inspector**:
- **`Auto-Select on Physical Touch (MIDI Learn)` (Checked by default)**:
  - Pressing any physical pad, scene/track button, transport button, or piano key—or turning any knob—on the APC Key 25 automatically highlights that control in cyan (`< 13 ms`) and loads its settings into the Inspector while executing its bound action.
- **`Edit-Only Mode (Mute actions while mapping)`**:
  - Check this box when you want to press physical buttons or turn knobs on the keyboard strictly to select and configure them **without** firing hotkeys, switching audio devices, or changing volumes.
- **Live Target Validation Indicator**:
  - Below `Primary Target`, APC-DECK validates your input in real time (`0.01 ms` in-memory lookup) and displays `✓ Matched: <Device Name>` for audio endpoints or `✓ Valid hotkey chord` for keyboard shortcuts.

---

## 4. Customizing Pad LEDs & Piano Key Colors

Select any control on the canvas (or touch it on the hardware) to customize its colors in the right-hand Inspector:

### Hardware Pad LED Colors (`Pad_0`–`Pad_39`, `Scene_82`–`Scene_86`, `Track_64`–`Track_71`)
- **`Active / ON Hardware LED & Key Color` (`LedColor`)**:
  - The color sent to the APC Key 25 pad when the control is active (or as its steady color for hotkeys/macros).
  - Supported values: `Auto`, `Green`, `BlinkGreen`, `Amber`, `BlinkAmber`, `Red`, `BlinkRed`, `Off`.
- **`Standby / Muted / OFF Pad LED Color` (`OffLedColor`)**:
  - The color shown on the pad when its assigned audio device is **not** currently the default device (or when a Bluetooth device is disconnected).
  - Set to `Amber` to keep all mapped pads illuminated in standby, or `Off` if you only want the currently active device lit.
- **`1-Click Instant Hardware Pad / Key Color Swatches`**:
  - Click **`Green`**, **`Amber`**, **`Red`**, **`Blink G`**, **`Blink A`**, **`Blink R`**, or **`Off`** in the swatch bar to immediately apply, save, and transmit that color to the physical APC Key 25 pad.
- **`Refresh Devices & Sync LEDs (F5)` Button**:
  - Re-scans all Windows audio/Bluetooth endpoints and force-synchronizes all 54 hardware LED states to the APC Key 25.

### Piano Key & Transport Button Visual Colors (`Key_48`–`Key_72`, `Trans_91`–`Trans_98`)
- While the physical 25-note keyboard and transport buttons do not contain hardware LEDs, selecting any piano key or transport button and clicking a **1-Click Color Swatch** customizes its **on-screen key color** so you can visually color-code octave zones and macro groups.

---

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
- In the right-hand Inspector, click **`Zero-Out Selected Knob / Device (0% Mute)`** to immediately set the selected knob or audio device button to `0%` and mute it in Windows.

### Optional `Knob Soft-Takeover (Pickup mode — prevent jumps)`
- Located at the top of the Inspector (`Knob Soft-Takeover (Pickup mode — prevent jumps)`).
- When enabled, if a physical knob's position does not match the current Windows volume (for example, right after boot or after changing volume in Windows), turning the knob will **not** cause a sudden volume jump—it waits until the physical knob crosses ("picks up") the current Windows volume level before locking on.
