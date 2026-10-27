# Akai Professional APC Key 25 — Hardware MIDI Specification

Complete technical reference for the **Akai Professional APC Key 25 (MK1)** (`USB\VID_09E8&PID_0027`) as implemented in [`ApcDeck.psm1`](../ApcDeck.psm1).

---

## 1. USB & WinMM Device Identification

| Property | Value |
| :--- | :--- |
| **Device Name** | `APC Key 25` |
| **USB Vendor ID (`VID`)** | `0x09E8` (Akai Professional M.I. Corp.) |
| **USB Product ID (`PID`)** | `0x0027` |
| **WinMM Input Port** | `APC Key 25` (Default index `0` on GOOD-CUBE) |
| **WinMM Output Port** | `APC Key 25` (Default index `1` on GOOD-CUBE; index `0` is `Microsoft GS Wavetable Synth`) |

---

## 2. Inbound MIDI Architecture (Controller -> Host PC)

The APC Key 25 splits its controls across **two MIDI channels**:
- **MIDI Channel 1 (`0x90` Note On, `0x80` Note Off, `0xB0` Control Change)**:
  - 40 Clip Launch Pads (`5 rows x 8 columns`)
  - 5 Scene Launch Buttons
  - 1 Stop All Clips Button + 8 Track/Device Buttons
  - 8 Continuous Potentiometer Knobs (`K1`–`K8`)
- **MIDI Channel 2 (`0x91` Note On, `0x81` Note Off)**:
  - 25 Velocity-Sensitive Piano Keys (`C3`–`C5`)

### 2.1 Continuous Knobs (`K1`–`K8`) — Channel 1 Control Change (`0xB0`)

| Control ID | Physical Position | MIDI Status | CC Number (Dec / Hex) | Value Range | Deadzone Floor / Ceiling in APC-DECK |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `K1` | Top Row, Knob 1 | `0xB0` (Ch 1 CC) | `48` (`0x30`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `K2` | Top Row, Knob 2 | `0xB0` (Ch 1 CC) | `49` (`0x31`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `K3` | Top Row, Knob 3 | `0xB0` (Ch 1 CC) | `50` (`0x32`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `K4` | Top Row, Knob 4 | `0xB0` (Ch 1 CC) | `51` (`0x33`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `K5` | Top Row, Knob 5 | `0xB0` (Ch 1 CC) | `52` (`0x34`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `K6` | Top Row, Knob 6 | `0xB0` (Ch 1 CC) | `53` (`0x35`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `K7` | Top Row, Knob 7 | `0xB0` (Ch 1 CC) | `54` (`0x36`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |
| `K8` | Top Row, Knob 8 | `0xB0` (Ch 1 CC) | `55` (`0x37`) | `0`–`127` | `0..1` -> `0%` + Mute; `126..127` -> `100%` |

### 2.2 5x8 Clip Launch Pad Matrix (`R1P1`–`R5P8`) — Channel 1 Notes (`0x90` / `0x80`)

Note numbers start at **bottom-left (`0`)** and increment left-to-right, bottom-to-top to **top-right (`39`)**:

| Grid Row | Col 1 | Col 2 | Col 3 | Col 4 | Col 5 | Col 6 | Col 7 | Col 8 | Scene Button (Right) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Row 1 (Top)** | `32` (`R1P1`) | `33` (`R1P2`) | `34` (`R1P3`) | `35` (`R1P4`) | `36` (`R1P5`) | `37` (`R1P6`) | `38` (`R1P7`) | `39` (`R1P8`) | `82` (`SCENE1`) |
| **Row 2** | `24` (`R2P1`) | `25` (`R2P2`) | `26` (`R2P3`) | `27` (`R2P4`) | `28` (`R2P5`) | `29` (`R2P6`) | `30` (`R2P7`) | `31` (`R2P8`) | `83` (`SCENE2`) |
| **Row 3** | `16` (`R3P1`) | `17` (`R3P2`) | `18` (`R3P3`) | `19` (`R3P4`) | `20` (`R3P5`) | `21` (`R3P6`) | `22` (`R3P7`) | `23` (`R3P8`) | `84` (`SCENE3`) |
| **Row 4** | `8` (`R4P1`) | `9` (`R4P2`) | `10` (`R4P3`) | `11` (`R4P4`) | `12` (`R4P5`) | `13` (`R4P6`) | `14` (`R4P7`) | `15` (`R4P8`) | `85` (`SCENE4`) |
| **Row 5 (Bottom)** | `0` (`R5P1`) | `1` (`R5P2`) | `2` (`R5P3`) | `3` (`R5P4`) | `4` (`R5P5`) | `5` (`R5P6`) | `6` (`R5P7`) | `7` (`R5P8`) | `86` (`SCENE5`) |

### 2.3 Track / Control Row & Shift — Channel 1 Notes (`0x90` / `0x80`)

| Control ID | Hardware Label | MIDI Note (Dec / Hex) | LED Capability |
| :--- | :--- | :--- | :--- |
| `TRACK1` | Up / Clip Stop | `64` (`0x40`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `TRACK2` | Down / Solo | `65` (`0x41`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `TRACK3` | Left / Rec Arm | `66` (`0x42`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `TRACK4` | Right / Mute | `67` (`0x43`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `TRACK5` | Volume / Select | `68` (`0x44`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `TRACK6` | Pan | `69` (`0x45`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `TRACK7` | Send | `70` (`0x46`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `TRACK8` | Device | `71` (`0x47`) | Single-Color Red (`0`=Off, `1`=Red, `2`=Blink Red) |
| `STOP_CLIPS` | Stop All Clips | `81` (`0x51`) | No LED |
| `PLAY_BTN` | Play / Pause | `91` (`0x5B`) | No LED |
| `REC_BTN` | Record | `93` (`0x5D`) | No LED |
| `SHIFT_BTN` | Shift | `98` (`0x62`) | No LED |

### 2.4 25-Note Piano Keyboard (`KEY_48`–`KEY_72`) — Channel 2 Notes (`0x91` / `0x81`)

- **Default Octave (`Oct 0`)**: Sends MIDI Notes **`48` (`C3`) through `72` (`C5`)** on **Channel 2** (`Status = 0x91` Note On with velocity `1..127`, `Status = 0x81` Note Off).
- Pressing physical `Oct -` / `Oct +` shifts the transmitted note numbers in increments of `12` semitones across Channel 2.

---

## 3. Outbound LED Protocol (Host PC -> Controller)

To set hardware LEDs on the APC Key 25, send a 3-byte short message (`midiOutShortMsg`) with Status **`0x90`** (Channel 1 Note On), Data1 = **`Note Number`**, and Data2 = **`LED Velocity Code`**:

```text
Packed 32-bit WinMM Word = 0x90 | (NoteNumber << 8) | (VelocityCode << 16)
```

### 3.1 Clip Matrix Pads (`Notes 0..39`) — Bi-Color Green/Red (Amber Mix)

| Color Name (`ApcDeck`) | Velocity Code (Dec / Hex) | Visual Behavior |
| :--- | :--- | :--- |
| `Off` | `0` (`0x00`) | LED Off |
| `Green` | `1` (`0x01`) | Solid Green |
| `BlinkGreen` | `2` (`0x02`) | Blinking Green |
| `Red` | `3` (`0x03`) | Solid Red |
| `BlinkRed` | `4` (`0x04`) | Blinking Red |
| `Amber` | `5` (`0x05`) | Solid Amber / Yellow |
| `BlinkAmber` | `6` (`0x06`) | Blinking Amber / Yellow |

### 3.2 Scene Buttons (`Notes 82..86`) — Single-Color Green

| Color Name (`ApcDeck`) | Velocity Code | Visual Behavior |
| :--- | :--- | :--- |
| `Off` | `0` | LED Off |
| `Green` (or any solid color) | `1` | Solid Green |
| `Blink*` | `2` | Blinking Green |

### 3.3 Track Buttons (`Notes 64..71`) — Single-Color Red

| Color Name (`ApcDeck`) | Velocity Code | Visual Behavior |
| :--- | :--- | :--- |
| `Off` | `0` | LED Off |
| `Red` (or any solid color) | `1` | Solid Red |
| `Blink*` | `2` | Blinking Red |
