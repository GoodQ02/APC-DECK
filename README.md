# APC-DECK — Akai APC Key 25 Stream Deck Controller & Mapper

Native Windows visual controller, hardware LED synchronizer, and Stream Deck–style action mapper for the **Akai Professional APC Key 25** (`USB\VID_09E8&PID_0027`).

![APC-DECK Icon](assets/apc-deck.png)

`APC-DECK` turns all **87 physical controls** on the Akai APC Key 25—**8 rotary knobs (`K1`–`K8`)**, **40 RGB clip-launch pads (`5×8` matrix)**, **6 scene buttons**, **8 track/mode buttons**, and **25 synth-action piano keys (`C3`–`C5`)**—into a zero-latency audio mixer, device router, Bluetooth wake-up controller, and hotkey macro surface.

---

## Documentation Suite

| Document | Contents |
| :--- | :--- |
| **[README.md](README.md)** | Quick start, launching, default 87-control workstation layout, and verification |
| **[docs/USER_GUIDE.md](docs/USER_GUIDE.md)** | Step-by-step guide: opening the app, MIDI Learn, 1-click pad/key color customization, knob zero-out & soft-takeover pickup |
| **[docs/HARDWARE_MIDI_SPEC.md](docs/HARDWARE_MIDI_SPEC.md)** | Complete Akai APC Key 25 (MK1) MIDI IN/OUT protocol, note/CC coordinates, and hardware LED velocity table |
| **[docs/REA_STREAMDECK_ANALYSIS.md](docs/REA_STREAMDECK_ANALYSIS.md)** | Reverse-engineering dossier (REA Evidence IDs, SHA-256 digests, CoreAudio `IPolicyConfig` COM vtable, and WinRT RFCOMM `0x111E` Bluetooth wake-up) |

---

## How to Open `APC-DECK`

1. **Desktop Shortcut (Recommended)**:
   - Double-click **`APC-DECK`** on your Windows Desktop (`C:\Users\jdben\Desktop\APC-DECK.lnk`).
   - If `APC-DECK` is already running in the background or minimized to the system tray, double-clicking the desktop shortcut immediately restores the window to the foreground.
2. **From Any Terminal (PowerShell / CMD)**:
   ```powershell
   apc-deck
   ```
3. **Direct PowerShell Launch**:
   ```powershell
   pwsh -NoLogo -NoProfile -STA -File C:\Tools\apc-midi-deck\Open-ApcDeck.ps1
   ```
4. **CLI Modes**:
   ```powershell
   # Start minimized in the Windows System Tray
   pwsh -NoLogo -NoProfile -STA -File C:\Tools\apc-midi-deck\Open-ApcDeck.ps1 -Minimized

   # Inspect live MIDI indices, audio endpoints, and Bluetooth status as JSON
   pwsh -NoLogo -NoProfile -File C:\Tools\apc-midi-deck\Open-ApcDeck.ps1 -Mode Snapshot

   # Reset all 87 controls to the default workstation layout
   pwsh -NoLogo -NoProfile -File C:\Tools\apc-midi-deck\Open-ApcDeck.ps1 -Mode ResetDefaults

   # Stop a running background instance cleanly
   pwsh -NoLogo -NoProfile -File C:\Tools\apc-midi-deck\Open-ApcDeck.ps1 -Mode Stop
   ```

---

## Key Capabilities

- **60 Hz Zero-Latency Rotary Knobs (`K1`–`K8`) with Clean `0%` Zero-Out**:
  - Uses an in-memory CoreAudio `MMDevice` cache so turning any knob adjusts volume in `< 0.2 ms`.
  - **Deadzone Zero-Out (`CC <= 1` → `0%` & Auto-Mute)**: Turning a knob fully counter-clockwise snaps cleanly to `0%` and mutes the device so there is zero audio bleed; turning it up (`CC >= 2`) automatically unmutes. Turning fully clockwise (`CC >= 126`) snaps cleanly to `100%`.
  - **Optional Soft-Takeover (Pickup Mode)**: Check **Knob Soft-Takeover (Pickup mode)** in the Inspector to prevent sudden volume jumps when a physical knob position differs from Windows volume—the knob waits until you cross the current Windows volume level before locking on.
  - **1-Click Zero-Out Button**: Click **Zero Out Selected Knob / Device (0% Mute)** in the Inspector to immediately zero and mute any selected knob or device.
- **Full Hardware Pad & Visual Piano Key Color Customization**:
  - Configure both the **Active / ON Color** (`Auto`, `Green`, `BlinkGreen`, `Amber`, `BlinkAmber`, `Red`, `BlinkRed`, `Off`) and **Standby / Muted / OFF Color** (`Auto`, `Amber`, `Red`, `Green`, `BlinkAmber`, `BlinkRed`, `BlinkGreen`, `Off`) for any pad.
  - Use the **1-Click Instant Pad/Key Color Swatches** (`[Green]`, `[Amber]`, `[Red]`, `[Blink G]`, `[Blink A]`, `[Blink R]`, `[LED Off]`) to recolor any physical pad or on-screen piano key (`C3`–`C5`) immediately.
- **Stream Deck–Style MIDI Learn**:
  - Touch any knob, pad, scene/track button, or piano key on the physical APC Key 25 to highlight it in cyan and load its mapping in the right-hand Inspector.
  - Check **Edit-Only Mode (Mute actions while mapping)** to press pads/keys freely while assigning them without firing hotkeys or switching devices.

---

## Default 87-Control Layout

| Section | MIDI Coordinates | Default Assignment |
| :--- | :--- | :--- |
| **Knobs `K1`–`K8`** | Ch 1 `CC 48`–`55` | `K1` **Master Out**, `K2` **`COMMAND_CENTER`**, `K3` **`VOICE_CUBE`**, `K4` **`PS5_HEADPHONES`**, `K5` **`M-AUDIO-AUX`**, `K6` **`META_VR`**, `K7` **`CMD_MIC`**, `K8` **`PS5_MIC`** |
| **Pad Row 1 (Top)** | Ch 1 `Note 32`–`39` | **Set Default Device**: `CMD CTR` (`32`), `CUBE` (`33`), `PS5 HP` (`34`), `M-AUDIO` (`35`), `META VR` (`36`), `CMD MIC` (`37`), `PS5 MIC` (`38`), **`SWAP SPK A/B`** (`39`) |
| **Pad Row 2** | Ch 1 `Note 24`–`31` | **Mute / Unmute Toggle**: `Master` (`24`), `CMD CTR` (`25`), `CUBE` (`26`), `PS5 HP` (`27`), `M-AUDIO` (`28`), `META VR` (`29`), `CMD MIC` (`30`), `PS5 MIC` (`31`) |
| **Pad Row 3** | Ch 1 `Note 16`–`23` | **Enable / Disable Endpoint**: `CMD CTR` (`16`), `CUBE` (`17`), `PS5 HP` (`18`), `M-AUDIO` (`19`), `META VR` (`20`), `CMD MIC` (`21`), `PS5 MIC` (`22`), **`SWAP MIC A/B`** (`23`) |
| **Pad Row 4** | Ch 1 `Note 8`–`15` | **Bluetooth & Tools**: `RB Meta 00YS` (`8`), `RB Meta 01JY` (`9`), `Joes iPhone` (`10`), **`BALANCE 95%`** (`11`), `Sound CPL` (`12`), `Mic CPL` (`13`), `App Mixer` (`14`), `BT Settings` (`15`) |
| **Pad Row 5 (Bottom)** | Ch 1 `Note 0`–`7` | **Hotkeys & Media**: Speechify `Alt+Q` (`0`), `Alt+W` (`1`), `Alt+S` (`2`), `Alt+F` (`3`), `Alt+A` (`4`), Dictate `Win+H` (`5`), `Play/Pause` (`6`), `Next Track` (`7`) |
| **Scene & Track** | Ch 1 `Note 64`–`71`, `81`–`86` | Media transport (`Stop`, `Prev`, `Next`, `Vol+`, `Vol-`), `Mute Default Mic`, `Balance All`, and quick Windows Sound/Mixer launchers |
| **25 Piano Keys** | Ch 2 `Note 48`–`72` | `C3`–`C5` synth keys ready for custom hotkeys, soundboard triggers, or application launchers |

---

## Testing & Verification

Run the automated verification suite (validates 87-control profile schema, knob `0%`/`100%` deadzone clamping, hotkey chord parser, LED velocity overrides, live endpoint snapshot, and WinForms UI smoke test):

```powershell
pwsh -NoLogo -NoProfile -File C:\Tools\apc-midi-deck\Test-ApcDeck.ps1
```
