# Reverse Engineering Report: Elgato Stream Deck Audio & Bluetooth Plugins

Static and runtime-corroborated reverse engineering analysis performed with **REA (`reverse-engineer-anything`)** to extract the Windows CoreAudio, PolicyConfig COM, and WinRT Bluetooth RFCOMM wake-up mechanisms used in **APC-DECK** ([`ApcDeck.psm1`](../ApcDeck.psm1)).

---

## 1. Inspected Artifacts & Cryptographic Digests

| Plugin | Artifact Path | SHA-256 Digest | Module MVID | REA Evidence IDs |
| :--- | :--- | :--- | :--- | :--- |
| **Bluetooth Monitor / Connector** (`me.rumkee.bluetooth.monitor`) | `C:\Users\jdben\AppData\Roaming\Elgato\StreamDeck\Plugins\me.rumkee.bluetooth.monitor.sdPlugin\me.rumkee.bluetooth.monitor.dll` | `206c345df9445451e9b2dd4055448a91e576a60693d25c6130a6f6f3d0c8d8b1` | `551fdab0-99a4-48b9-bb8a-d8ec4d2c9409` | `ev_f3aca4d13de0cb083fcc6aebe38a30d2da50ab26a4d688553ac34339addf5a9b`, `ev_716a72a36dbc3ffb28ba5ed899e1bfc6754b031590e0e6518faf4647cb125ca3`, `ev_ebddfde645e177d72a680b399b94322c8b548088366efa915e552e47e6c4ee69` |
| **BarRaider Audio Meter** (`com.barraider.audiometer`) | `C:\Users\jdben\AppData\Roaming\Elgato\StreamDeck\Plugins\com.barraider.audiometer.sdPlugin\com.barraider.audiometer.exe` | `146ae5a52fffc45c02e86105abdbfce52854fe86f621e50c158d4d4367b7622b` | `29db29ba-81a9-404c-904a-c4fa986aeaa6` | `ev_cbc48a9278eb9b2d9f43a648891d47f0812202800c99d0bd96d763d4fa4002de`, `ev_8c43cc1736a12946fc3748a76f30b21df10a2d35aea824d5971e53c6f1329c68` |
| **Audio Mixer** (`com.javanpoirier.audiomixer`) | `C:\Users\jdben\AppData\Roaming\Elgato\StreamDeck\Plugins\com.javanpoirier.audiomixer.sdPlugin\com.javanpoirier.audiomixer.exe` | `89b5292d4bc6c9f62f514f52fa08c0ef3e6dc9cfbf450c5749bd07f013946c60` | `876e54b1-...` | `ev_d7ad9cfd1a6529ba4cb94455f81c007a2131101f3229cacb72125d2512508852`, `ev_347ab6ea98cbebf0f5961161d485a150c3da03979d7bbb334cb3216a466d3058` |

---

## 2. Bluetooth Audio Connection Mechanism (`me.rumkee.bluetooth.monitor.dll`)

### 2.1 Static Metadata Findings (`ev_716a72a36dbc3ffb28ba5ed899e1bfc6754b031590e0e6518faf4647cb125ca3`)
Inspection of type `me.rumkee.bluetooth.monitor.MonitorAction` (`0x02000008`), `BluetoothDeviceHelper` (`0x02000006`), and compiler-generated async state machine `<Connect>d__17` (`0x02000010`) revealed how the Stream Deck Bluetooth plugin forces Windows to connect to a paired Bluetooth headset/speaker without opening the Windows Settings UI:

- **`MonitorAction::<KeyPressed>d__9::MoveNext` (`0x06000049`, RVA `71176`)**:
  - Invokes `BluetoothDeviceHelper::LoadDeviceFromId(string deviceId, Logger logger)` (`0x06000018`, RVA `67340`) followed by `BluetoothDeviceHelper::Connect(uint serviceId, Logger logger)` (`0x06000019`, RVA `67412`) with constant **`serviceId = 4382` (`0x111E`, Handsfree Bluetooth Service UUID)**.
- **`BluetoothDeviceHelper::<Connect>d__17::MoveNext` (`0x0600006e`, RVA `72888`)**:
  1. Queries `Windows.Devices.Bluetooth.BluetoothDevice.FromIdAsync(deviceId)`.
  2. Calls `GetRfcommServicesForIdAsync(RfcommServiceId.FromShortId(0x111E), BluetoothCacheMode.Uncached)`.
  3. Instantiates a `Windows.Networking.Sockets.StreamSocket` (`<socket>5__2`, field token `0x0400004d`) and calls `ConnectAsync(service.ConnectionHostName, service.ConnectionServiceName)` on the Handsfree RFCOMM endpoint, then immediately disposes the socket.
  4. Opening the RFCOMM channel causes the Windows Bluetooth stack to wake up the remote audio device and negotiate both Handsfree (`0x111E`) and A2DP Audio Sink (`0x110B`) profiles automatically.

### 2.2 Runtime Integration in `ApcDeck.psm1`
- **Assembly Re-use**: `ApcDeck.psm1` loads `me.rumkee.bluetooth.monitor.dll` directly from the Stream Deck plugin directory when invoking `BluetoothConnect`.
- **STA Deadlock Mitigation**: Because WinForms runs on a Single-Threaded Apartment (`-STA`) thread, synchronously blocking on WinRT `Task.GetAwaiter().GetResult()` inside the UI thread can deadlock WinRT context continuations. `ApcDeck.psm1` executes `BluetoothDeviceHelper.Connect(4382)` inside an isolated background MTA `[PowerShell]::Create()` runspace with a 4.5-second timeout and derives live connection status in `0 ms` by correlating `System.Devices.Aep.DeviceAddress` (MAC address) against `MMDeviceEnumerator` endpoint states (`Active` vs `Unplugged`).

---

## 3. Windows CoreAudio & PolicyConfig COM (`com.barraider.audiometer.exe` & `AudioSwitcher.AudioApi.CoreAudio.dll`)

### 3.1 Static Metadata Findings (`ev_8c43cc1736a12946fc3748a76f30b2d1f10a2d35aea824d5971e53c6f1329c68`)
- **`NAudio.CoreAudioApi.MMDeviceEnumerator`**:
  - Used by `com.barraider.audiometer.exe` (`AudioMeterAction`, token `0x0200000a`, `ConnectToInputDevice` `0x06000031`, `ConnectToOutputDevice` `0x06000032`) to enumerate `DataFlow.Render` and `DataFlow.Capture` endpoints across `DeviceState.Active | Disabled | Unplugged`.
  - Volume and mute state are controlled directly via `MMDevice.AudioEndpointVolume.MasterVolumeLevelScalar` (`0.0f` to `1.0f`) and `MMDevice.AudioEndpointVolume.Mute`.
- **Undocumented Windows `IPolicyConfig` COM Interface (`{f8679f50-850a-41cf-9c72-430f290290c8}`)**:
  - Activated via CLSID `CPolicyConfigClient` (`{870af99c-171d-4f9e-af0d-e63df40c2bc9}`).
  - Provides two critical methods unavailable in public Win32 APIs:
    - `SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string wszDeviceId, int role)` — switches the active Windows default playback or recording device across `eConsole (0)`, `eMultimedia (1)`, and `eCommunications (2)` roles.
    - `SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string wszDeviceId, [MarshalAs(UnmanagedType.Bool)] bool bVisible)` — enables (`true`) or disables (`false`) an audio endpoint in Windows Sound Settings without requiring administrator elevation.

### 3.2 Runtime Integration in `ApcDeck.psm1`
- Embedded directly inside `GoodCube.ApcDeck.NativeBridge` (`ApcDeck.psm1`) alongside `winmm.dll` (`midiInOpen`, `midiOutOpen`, `midiOutShortMsg`) and `user32.dll` (`keybd_event`).
- Combined with `$script:EndpointCache` so 60 Hz MIDI CC knob turns update `MasterVolumeLevelScalar` in sub-millisecond time without re-enumerating COM devices on every tick.
