# APC-DECK User Guide

Complete operational guide for **APC-DECK** ([`Open-ApcDeck.ps1`](../Open-ApcDeck.ps1) / [`ApcDeck.psm1`](../ApcDeck.psm1)), the Stream Deck–style visual audio, Bluetooth, LED, and hotkey mapper for the **Akai Professional APC Key 25**.

---

## 1. Opening & Managing APC-DECK

### Desktop Shortcut (Recommended)
Double-click **`APC-DECK`** on your Windows Desktop (`C:\Users\jdben\Desktop\APC-DECK.lnk`).
- If APC-DECK is not running yet, it opens the interactive visual controller window and lights up your APC Key 25 pads.
- If APC-DECK is already running in the background or minimized to the System Tray, double-clicking the Desktop shortcut immediately brings the existing window to the front of your screen.

### Command Line (`C:\Tools\bin`)
From any PowerShell or Command Prompt window:

```powershell
# Open the visual mapper window (or bring existing instance to front)
apc-deck

# Start silently in the Windows System Tray
apc-deck -Mode Tray

# Stop the running APC-DECK instance cleanly (turns off hardware LEDs)
apc-deck -Mode Stop
```

### System Tray Behavior
- Clicking the window **`X`** button minimizes APC-DECK to the **Windows System Tray** so your knobs, pads, and piano keys continue working in the background without cluttering the taskbar.
- **Double-click** the `APC-DECK` tray icon (or right-click -> **Open APC-DECK Window**) to restore the window.
- Use the **`Quit App`** button in the top toolbar (or right-click tray icon -> **Quit APC-DECK**) to exit completely and turn off all APC Key 25 LEDs.

---

## 2. Navigating the Visual Surface

The left canvas renders all **87 physical controls** of the Akai APC Key 25:
1. **Top Row — 8 Endless/Potentiometer Knobs (`K1`–`K8`)**:
   - Displays each knob's assigned label, target audio endpoint, live Windows volume percentage (`VOL XX%`), and last physical knob position (`KNOB XX%`).
   - Includes a bright cyan live level bar at the bottom of each knob card.
2. **Center Matrix — 5x8 RGB Clip Launch Grid (`R1P1`–`R5P8`) + 5 Scene Launch Buttons (`SCENE1`–`SCENE5`)**:
   - Each pad displays its custom label, action type, and current LED color state.
   - Active audio devices and connected Bluetooth devices glow bright green (`Green`), while standby devices glow warm amber (`Amber`) or your custom standby color.
3. **Control Row — 8 Track/Mode Buttons (`STOP_CLIPS` + `TRACK1`–`TRACK8`)**:
   - Red-LED capable utility buttons pre-mapped to media transport (`Play/Pause`, `Prev`, `Next`, `Stop`), `Master Mute`, `Mic Mute`, `Task Manager`, and `Lock PC`.
4. **Bottom Bed — 25-Note Piano Keyboard (`KEY_48` `C3` to `KEY_72` `C5`)**:
   - Full two-octave keyboard (15 white keys, 10 black sharps/flats) that can trigger any audio switch, Bluetooth wake-up, hotkey chord, or PowerShell script.

---

## 3. MIDI Learn vs. Edit-Only Mode

Located in the top toolbar:
- **`MIDI Learn: Select on Press` (Checked by default)**:
  - Pressing any physical pad, button, piano key, or turning any knob on the APC Key 25 automatically selects that control in the right-hand Inspector and executes its bound action.
- **`Edit-Only Mode (Mute Actions)`**:
  - Check this box when you want to press physical buttons or turn knobs on the keyboard strictly to select and configure them **without** firing hotkeys, switching audio devices, or changing volumes.

---

## 4. Customizing Pad LEDs & Piano Key Colors

Select any control on the canvas (or press it on the hardware) to open its settings in the right-hand **Selected Control Inspector**:

### Hardware Pad LED Colors (`R1P1`–`R5P8`, `SCENE1`–`SCENE5`, `TRACK1`–`TRACK8`)
- **Active Hardware LED (`LedColor`)**: The color sent to the APC Key 25 pad when the control is active (or as its steady color for hotkeys/macros).
  - Supported values: `Auto`, `Green`, `Amber`, `Red`, `BlinkGreen`, `BlinkAmber`, `BlinkRed`, `Off`.
- **Standby LED (`OffLedColor`)**: The color shown on the pad when its assigned audio device is **not** currently the default device (or when a Bluetooth device is disconnected).
  - Set to `Amber` to keep all mapped pads illuminated in standby, or `Off` if you only want the currently active device lit.
- **Quick Color Swatches**:
  - Click **`Green`**, **`Amber`**, **`Red`**, **`Blink G`**, **`Blink A`**, **`Blink R`**, or **`LED Off`** in the Quick Color Swatches bar to immediately apply and save that color and preview it live on the physical APC Key 25 pad.
- **`Sync Hardware LEDs` Button (Top Toolbar)**:
  - Re-transmits all 53 LED states to the APC Key 25 at any time.

### Piano Key Visual Colors (`KEY_48`–`KEY_72`)
- While the physical 25-note keyboard does not contain hardware LEDs, selecting any piano key and clicking a **Quick Color Swatch** (or setting `LedColor`) customizes its **on-screen key color** so you can visually color-code octave zones and macro groups.

---

## 5. Knob Zero-Out, Responsiveness & Soft-Takeover

APC-DECK includes dedicated signal conditioning for the 8 hardware potentiometers (`K1`–`K8`):

### Clean 0% Mute Floor & 100% Ceiling Deadzones
- Analog MIDI potentiometers often jitter between `CC 0` and `CC 1` at the bottom stop, or `CC 126` and `CC 127` at the top stop.
- APC-DECK clamps:
  - **`CC <= 1` -> `0%` (`0.0`)** and automatically **mutes** the target Windows audio endpoint (`Mute = $true`) so turning a knob all the way down guarantees complete silence.
  - **`CC >= 126` -> `100%` (`1.0`)** and ensures the endpoint is unmuted.
  - Any movement above `CC 1` automatically unmutes the endpoint and scales linearly from `2%` to `99%`.

### 60 Hz Sub-Millisecond Polling
- Knob events are drained at **60 Hz (16 ms)** using a pre-cached CoreAudio `MMDevice` table so turning multiple knobs simultaneously never lags or stutters.

### 1-Click `Zero-Out Selected Knob (0% + Mute)` Button
- In the right-hand Inspector, click **`Zero-Out Selected Knob (0% + Mute)`** to immediately set the selected knob's target audio device to `0%` and mute it in Windows.

### Optional `Knob Soft-Takeover (Pickup)` Mode
- Located in the top toolbar (`Knob Soft-Takeover (Pickup)`).
- When enabled, if a physical knob's position does not match the current Windows volume (for example, right after boot or after changing volume in Windows), turning the knob will **not** cause a sudden volume jump—it waits until the physical knob crosses ("picks up") the current Windows volume level before taking control.
