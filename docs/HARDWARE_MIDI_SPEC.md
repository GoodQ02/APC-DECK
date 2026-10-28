# Akai Professional APC Key 25 — Hardware MIDI Specification

Complete technical reference for the **Akai Professional APC Key 25 (MK1)** (`USB\VID_09E8&PID_0027`) as implemented in [`ApcDeck.psm1`](../ApcDeck.psm1) and [`Open-ApcDeck.ps1`](../Open-ApcDeck.ps1).

---

## 1. USB & WinMM Device Identification

| Property | Value |
| :--- | :--- |
| **Device Name** | `APC Key 25` |
| **USB Vendor ID (`VID`)** | `0x09E8` (Akai Professional M.I. Corp.) |
| **USB Product ID (`PID`)** | `0x0027` |
| **WinMM Input Port** | `APC Key 25` (Default index `0` on GOOD-CUBE) |
| **WinMM Output Port** | `APC Key 25` (Default index `1` on GOOD-CUBE; index `0` is `Microsoft GS Wavetable Synth`) |
| **Total Mappable Controls** | **90** (`40` RGB Pads + `6` Scene/Stop + `8` Track + `8` Knobs + `3` Transport/Shift + `25` Piano Keys) |

---

## 2. Inbound MIDI Architecture (Controller -> Host PC)

The APC Key 25 splits its 90 physical controls across **two MIDI channels**:
- **MIDI Channel 1 (`0x90` Note On, `0x80` Note Off, `0xB0` Control Change)**:
  - `40` Clip Launch Pads (`5 rows × 8 columns`, `Pad_0`–`Pad_39`)
  - `5` Scene Launch Buttons + `1` Stop All Clips Button (`Scene_82`–`Scene_86`, `Scene_81`)
  - `8` Track/Device Buttons (`Track_64`–`Track_71`)
  - `8` Continuous Potentiometer Knobs (`Knob_48`–`Knob_55`, `K1`–`K8` in a `2×4` bank)
  - `3` Transport & Shift Buttons (`Trans_91` `PLAY/PAUSE`, `Trans_93` `REC`, `Trans_98` `SHIFT`)
- **MIDI Channel 2 (`0x91` Note On, `0x81` Note Off)**:
  - `25` Velocity-Sensitive Synth-Action Piano Keys (`Key_48` `C3` through `Key_72` `C5`)

### 2.1 Continuous Knobs (`Knob_48`–`Knob_55` / `K1`–`K8`) — Channel 1 Control Change (`0xB0`)

| Canonical `ControlId` | UI Badge | Physical `2×4` Position | MIDI Status | CC Number (Dec / Hex) | Value Range | Deadzone Floor / Ceiling in APC-DECK |
| :--- | :---: | :--- | :---: | :---: | :---: | :--- |
| `Knob_48` | `K1` | Top Row, Col 1 | `0xB0` (Ch 1 CC) | `48` (`0x30`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `Knob_49` | `K2` | Top Row, Col 2 | `0xB0` (Ch 1 CC) | `49` (`0x31`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `Knob_50` | `K3` | Top Row, Col 3 | `0xB0` (Ch 1 CC) | `50` (`0x32`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `Knob_51` | `K4` | Top Row, Col 4 | `0xB0` (Ch 1 CC) | `51` (`0x33`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `Knob_52` | `K5` | Bottom Row, Col 1 | `0xB0` (Ch 1 CC) | `52` (`0x34`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `Knob_53` | `K6` | Bottom Row, Col 2 | `0xB0` (Ch 1 CC) | `53` (`0x35`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `Knob_54` | `K7` | Bottom Row, Col 3 | `0xB0` (Ch 1 CC) | `54` (`0x36`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `Knob_55` | `K8` | Bottom Row, Col 4 | `0xB0` (Ch 1 CC) | `55` (`0x37`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |

### 2.2 `5×8` Clip Launch Pad Matrix (`Pad_0`–`Pad_39`) & Scene Column (`Scene_82`–`Scene_86`) — Channel 1 Notes (`0x90` / `0x80`)

Note numbers start at **bottom-left (`0`, `Pad_0`)** and increment left-to-right, bottom-to-top to **top-right (`39`, `Pad_39`)**:

| Grid Row | Col 1 | Col 2 | Col 3 | Col 4 | Col 5 | Col 6 | Col 7 | Col 8 | Scene Button (Right) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Row 1 (Top)** | `32` (`Pad_32`) | `33` (`Pad_33`) | `34` (`Pad_34`) | `35` (`Pad_35`) | `36` (`Pad_36`) | `37` (`Pad_37`) | `38` (`Pad_38`) | `39` (`Pad_39`) | `82` (`Scene_82`) |
| **Row 2** | `24` (`Pad_24`) | `25` (`Pad_25`) | `26` (`Pad_26`) | `27` (`Pad_27`) | `28` (`Pad_28`) | `29` (`Pad_29`) | `30` (`Pad_30`) | `31` (`Pad_31`) | `83` (`Scene_83`) |
| **Row 3** | `16` (`Pad_16`) | `17` (`Pad_17`) | `18` (`Pad_18`) | `19` (`Pad_19`) | `20` (`Pad_20`) | `21` (`Pad_21`) | `22` (`Pad_22`) | `23` (`Pad_23`) | `84` (`Scene_84`) |
| **Row 4** | `8` (`Pad_8`) | `9` (`Pad_9`) | `10` (`Pad_10`) | `11` (`Pad_11`) | `12` (`Pad_12`) | `13` (`Pad_13`) | `14` (`Pad_14`) | `15` (`Pad_15`) | `85` (`Scene_85`) |
| **Row 5 (Bottom)** | `0` (`Pad_0`) | `1` (`Pad_1`) | `2` (`Pad_2`) | `3` (`Pad_3`) | `4` (`Pad_4`) | `5` (`Pad_5`) | `6` (`Pad_6`) | `7` (`Pad_7`) | `86` (`Scene_86`) |

### 2.3 Track / Control Row, Stop All Clips & Transport/Shift — Channel 1 Notes (`0x90` / `0x80`)

| Canonical `ControlId` | UI Badge | Hardware Silkscreen | MIDI Note (Dec / Hex) | LED Capability |
| :--- | :---: | :--- | :---: | :--- |
| `Track_64` | `▲ UP` | Up / Clip Stop | `64` (`0x40`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `Track_65` | `▼ DOWN` | Down / Solo | `65` (`0x41`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `Track_66` | `◄ LEFT` | Left / Rec Arm | `66` (`0x42`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `Track_67` | `► RIGHT` | Right / Mute | `67` (`0x43`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `Track_68` | `VOL` | Volume / Select | `68` (`0x44`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `Track_69` | `PAN` | Pan | `69` (`0x45`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `Track_70` | `SEND` | Send | `70` (`0x46`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `Track_71` | `DEVICE` | Device | `71` (`0x47`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `Scene_81` | `STOP ALL` | Stop All Clips | `81` (`0x51`) | No Hardware LED (Custom UI Color Supported) |
| `Trans_91` | `PLAY/PAUSE` | Play / Pause | `91` (`0x5B`) | No Hardware LED (Custom UI Color Supported) |
| `Trans_93` | `REC` | Record | `93` (`0x5D`) | No Hardware LED (Custom UI Color Supported) |
| `Trans_98` | `SHIFT` | Shift | `98` (`0x62`) | No Hardware LED (Custom UI Color Supported) |

### 2.4 25-Note Piano Keyboard (`Key_48`–`Key_72`) — Channel 2 Notes (`0x91` / `0x81`)

- **Default Octave (`Oct 0`)**: Sends MIDI Notes **`48` (`C3`, `Key_48`) through `72` (`C5`, `Key_72`)** on **Channel 2** (`Status = 0x91` Note On with velocity `1..127`, `Status = 0x81` Note Off).
- Contains **15 full-height white keys** (`C3`, `D3`, `E3`, `F3`, `G3`, `A3`, `B3`, `C4`, `D4`, `E4`, `F4`, `G4`, `A4`, `B4`, `C5`) and **10 recessed black sharp/flat keys** (`C#3`, `D#3`, `F#3`, `G#3`, `A#3`, `C#4`, `D#4`, `F#4`, `G#4`, `A#4`).
- Pressing physical `Oct -` / `Oct +` shifts the transmitted note numbers in increments of `12` semitones across Channel 2.

---

## 3. Outbound LED Protocol (Host PC -> Controller)

To set hardware LEDs on the APC Key 25, send a 3-byte short message (`midiOutShortMsg`) with Status **`0x90`** (Channel 1 Note On), Data1 = **`Note Number`**, and Data2 = **`LED Velocity Code`**:

```text
Packed 32-bit WinMM Word = 0x90 | (NoteNumber << 8) | (VelocityCode << 16)
```

### 3.1 Clip Matrix Pads (`Notes 0..39`, `Pad_0`–`Pad_39`) — Bi-Color Green/Red (Amber Mix)

| Color Name (`ApcDeck`) | Velocity Code (Dec / Hex) | Visual Behavior |
| :--- | :---: | :--- |
| `Off` | `0` (`0x00`) | LED Off |
| `Green` | `1` (`0x01`) | Solid Green |
| `BlinkGreen` | `2` (`0x02`) | Blinking Green |
| `Red` | `3` (`0x03`) | Solid Red |
| `BlinkRed` | `4` (`0x04`) | Blinking Red |
| `Amber` | `5` (`0x05`) | Solid Amber / Yellow |
| `BlinkAmber` | `6` (`0x06`) | Blinking Amber / Yellow |

### 3.2 Scene Buttons (`Notes 82..86`, `Scene_82`–`Scene_86`) — Single-Color Green

| Color Name (`ApcDeck`) | Velocity Code | Visual Behavior |
| :--- | :---: | :--- |
| `Off` | `0` | LED Off |
| `Green` (or any solid color) | `1` | Solid Green |
| `Blink*` | `2` | Blinking Green |

### 3.3 Track Buttons (`Notes 64..71`, `Track_64`–`Track_71`) — Single-Color Red

| Color Name (`ApcDeck`) | Velocity Code | Visual Behavior |
| :--- | :---: | :--- |
| `Off` | `0` | LED Off |
| `Red` (or any solid color) | `1` | Solid Red |
| `Blink*` | `2` | Blinking Red |

---

## 4. Differential USB MIDI LED Caching & Safe STA WinMM Shutdown

1. **Differential LED Updates (`$script:LastSentLedVel` in `Sync-ApcHardwareLeds`)**:
   - Rather than transmitting all 54 `midiOutShortMsg` packets every 4 seconds, `Sync-ApcHardwareLeds` compares each pad's computed velocity against `$script:LastSentLedVel[$note]` and only sends USB MIDI packets for pads whose color/state actually changed (unless `-Force` is specified on startup or manual `F5` refresh).
2. **Lock-Free Concurrent Queue (`NativeBridge.EventQueue`)**:
   - The `winmm.dll` callback (`MidiInCallback`) runs on a high-priority multimedia thread. It ignores `0xF8` timing clock and `0xFE` active sensing noise, checks `if (Closing) return;`, and enqueues packed `(status, data1, data2)` integers into a lock-free `ConcurrentQueue<int>` drained at 60 Hz by the UI timer (`DrainEvents()`).
   - Within each 16ms frame, multiple CC messages for the same knob (`Knob_48`–`Knob_55`) are coalesced to the latest position (`$latestCc[$code] = $d2`) so the UI and CoreAudio always jump straight to the user's current physical finger position.
3. **Safe STA Shutdown (`NativeBridge.CloseDevice`)**:
   - Calling `midiInReset` or `midiInClose` synchronously from a Single-Threaded Apartment (`-STA`) UI thread deadlocks when `winmm.dll` waits on its multimedia callback lock.
   - `CloseDevice()` sets `Closing = true`, clears all hardware LEDs (`0..39`, `64..71`, `82..86`) via `midiOutShortMsg`, and closes `hMidiOut`, allowing the Windows kernel to reclaim `hMidiIn` cleanly on process termination.
