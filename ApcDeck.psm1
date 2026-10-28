Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ModuleRoot = $PSScriptRoot
$script:ConfigDir  = Join-Path $env:LOCALAPPDATA 'GoodCube\ApcMidiDeck'
$script:ConfigPath = Join-Path $script:ConfigDir 'profile.json'

# Load NAudio.Wasapi from existing Stream Deck AudioMeter plugin
$script:AudioMeterDir = Join-Path $env:APPDATA 'Elgato\StreamDeck\Plugins\com.barraider.audiometer.sdPlugin'
if (Test-Path (Join-Path $script:AudioMeterDir 'NAudio.Wasapi.dll')) {
    Add-Type -Path (Join-Path $script:AudioMeterDir 'NAudio.Core.dll')
    Add-Type -Path (Join-Path $script:AudioMeterDir 'NAudio.Wasapi.dll')
}

# Compile WinMM MIDI + CoreAudio PolicyConfig + Win32 Window/Hotkey C# Bridge
if (-not ('GoodCube.ApcDeck.NativeBridge' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Concurrent;
using System.Runtime.InteropServices;

namespace GoodCube.ApcDeck {
    [Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPolicyConfig {
        int GetMixFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr ppFormat);
        int GetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, bool bDefault, IntPtr ppFormat);
        int ResetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName);
        int SetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr pEndpointFormat, IntPtr MixFormat);
        int GetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, bool bDefault, IntPtr pmftDefaultPeriod, IntPtr pmftMinimumPeriod);
        int SetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr pmftPeriod);
        int GetShareMode([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr pMode);
        int SetShareMode([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr mode);
        int GetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, bool bFxStore, IntPtr key, IntPtr pv);
        int SetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, bool bFxStore, IntPtr key, IntPtr pv);
        int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, int role);
        int SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, [MarshalAs(UnmanagedType.Bool)] bool bVisible);
    }

    [ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")]
    public class PolicyConfigClient { }

    public struct MidiEventRecord {
        public int Status;
        public int Command;
        public int Channel;
        public int Data1;
        public int Data2;
        public DateTime Timestamp;
    }

    public static class NativeBridge {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        public struct MIDIINCAPS {
            public ushort wMid;
            public ushort wPid;
            public uint vDriverVersion;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string szPname;
            public uint dwSupport;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        public struct MIDIOUTCAPS {
            public ushort wMid;
            public ushort wPid;
            public uint vDriverVersion;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string szPname;
            public ushort wTechnology;
            public ushort wVoices;
            public ushort wNotes;
            public ushort wChannelMask;
            public uint dwSupport;
        }

        public delegate void MidiInProc(IntPtr hMidiIn, uint wMsg, IntPtr dwInstance, IntPtr dwParam1, IntPtr dwParam2);

        [DllImport("winmm.dll", CharSet = CharSet.Auto)]
        public static extern uint midiInGetNumDevs();

        [DllImport("winmm.dll", CharSet = CharSet.Auto)]
        public static extern uint midiInGetDevCaps(UIntPtr uDeviceID, out MIDIINCAPS pmic, uint cbmic);

        [DllImport("winmm.dll")]
        public static extern uint midiInOpen(out IntPtr lphMidiIn, uint uDeviceID, MidiInProc dwCallback, IntPtr dwInstance, uint dwFlags);

        [DllImport("winmm.dll")]
        public static extern uint midiInStart(IntPtr hMidiIn);

        [DllImport("winmm.dll")]
        public static extern uint midiInStop(IntPtr hMidiIn);

        [DllImport("winmm.dll")]
        public static extern uint midiInReset(IntPtr hMidiIn);

        [DllImport("winmm.dll")]
        public static extern uint midiInClose(IntPtr hMidiIn);

        [DllImport("winmm.dll", CharSet = CharSet.Auto)]
        public static extern uint midiOutGetNumDevs();

        [DllImport("winmm.dll", CharSet = CharSet.Auto)]
        public static extern uint midiOutGetDevCaps(UIntPtr uDeviceID, out MIDIOUTCAPS pmoc, uint cbmoc);

        [DllImport("winmm.dll")]
        public static extern uint midiOutOpen(out IntPtr lphMidiOut, uint uDeviceID, IntPtr dwCallback, IntPtr dwInstance, uint dwFlags);

        [DllImport("winmm.dll")]
        public static extern uint midiOutShortMsg(IntPtr hMidiOut, uint dwMsg);

        [DllImport("winmm.dll")]
        public static extern uint midiOutClose(IntPtr hMidiOut);

        [DllImport("user32.dll")]
        public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

        [DllImport("kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumDesktopWindows(IntPtr hDesktop, EnumWindowsProc lpfn, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        private static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

        [DllImport("user32.dll")]
        private static extern bool CloseDesktop(IntPtr hDesktop);

        [DllImport("user32.dll")]
        private static extern IntPtr GetThreadDesktop(uint dwThreadId);

        [DllImport("kernel32.dll")]
        private static extern uint GetCurrentThreadId();

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        private static extern bool GetUserObjectInformation(IntPtr hObj, int nIndex, System.Text.StringBuilder pvInfo, int nLength, out int lpnLengthNeeded);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        private static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct STARTUPINFOW {
            public int cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public int dwX;
            public int dwY;
            public int dwXSize;
            public int dwYSize;
            public int dwXCountChars;
            public int dwYCountChars;
            public int dwFillAttribute;
            public int dwFlags;
            public short wShowWindow;
            public short cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct PROCESS_INFORMATION {
            public IntPtr hProcess;
            public IntPtr hThread;
            public int dwProcessId;
            public int dwThreadId;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CreateProcessW(
            string lpApplicationName,
            string lpCommandLine,
            IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes,
            bool bInheritHandles,
            uint dwCreationFlags,
            IntPtr lpEnvironment,
            string lpCurrentDirectory,
            ref STARTUPINFOW lpStartupInfo,
            out PROCESS_INFORMATION lpProcessInformation);

        [DllImport("kernel32.dll")]
        private static extern bool CloseHandle(IntPtr hObject);

        public static string GetCurrentDesktopName() {
            IntPtr hDesk = GetThreadDesktop(GetCurrentThreadId());
            if (hDesk == IntPtr.Zero) return "";
            var sb = new System.Text.StringBuilder(256);
            int len = 0;
            if (GetUserObjectInformation(hDesk, 2, sb, 256, out len)) {
                return sb.ToString();
            }
            return "";
        }

        public static int LaunchOnDefaultDesktop(string commandLine, string workingDir) {
            var si = new STARTUPINFOW();
            si.cb = Marshal.SizeOf(typeof(STARTUPINFOW));
            si.lpDesktop = @"WinSta0\Default";
            si.dwFlags = 1; // STARTF_USESHOWWINDOW
            si.wShowWindow = 0; // SW_HIDE
            PROCESS_INFORMATION pi;
            uint flags = 0x00000010; // CREATE_NEW_CONSOLE
            if (CreateProcessW(null, commandLine, IntPtr.Zero, IntPtr.Zero, false, flags, IntPtr.Zero, workingDir, ref si, out pi)) {
                CloseHandle(pi.hThread);
                CloseHandle(pi.hProcess);
                return pi.dwProcessId;
            }
            return 0;
        }

        public static IntPtr FindWindowByTitle(string exactTitle) {
            if (string.IsNullOrEmpty(exactTitle)) return IntPtr.Zero;
            IntPtr found = IntPtr.Zero;
            EnumWindowsProc cb = delegate(IntPtr hWnd, IntPtr lParam) {
                var sb = new System.Text.StringBuilder(256);
                if (GetWindowText(hWnd, sb, 256) > 0) {
                    string t = sb.ToString();
                    if (string.Equals(t, exactTitle, StringComparison.OrdinalIgnoreCase) ||
                        t.IndexOf("Akai APC Key 25 Stream Deck Controller", StringComparison.OrdinalIgnoreCase) >= 0) {
                        found = hWnd;
                        if (IsWindowVisible(hWnd)) return false;
                    }
                }
                return true;
            };
            EnumWindows(cb, IntPtr.Zero);
            if (found == IntPtr.Zero) {
                IntPtr hDef = OpenDesktop("Default", 0, false, 0x0041); // DESKTOP_READOBJECTS | DESKTOP_ENUMERATE
                if (hDef != IntPtr.Zero) {
                    try {
                        EnumDesktopWindows(hDef, cb, IntPtr.Zero);
                    } finally {
                        CloseDesktop(hDef);
                    }
                }
            }
            return found;
        }

        private static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
        private static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
        private const uint SWP_NOSIZE = 0x0001;
        private const uint SWP_NOMOVE = 0x0002;
        private const uint SWP_SHOWWINDOW = 0x0040;

        private const uint CALLBACK_FUNCTION = 0x00030000;
        private const uint MIM_DATA = 0x3C3;
        private const uint KEYEVENTF_EXTENDEDKEY = 0x0001;
        private const uint KEYEVENTF_KEYUP = 0x0002;

        private static IntPtr _hMidiIn = IntPtr.Zero;
        private static IntPtr _hMidiOut = IntPtr.Zero;
        private static MidiInProc _callbackDelegate = new MidiInProc(OnMidiIn);
        public static readonly ConcurrentQueue<MidiEventRecord> EventQueue = new ConcurrentQueue<MidiEventRecord>();

        public static void HideConsoleWindow() {
            IntPtr cw = GetConsoleWindow();
            if (cw != IntPtr.Zero) {
                ShowWindow(cw, 0); // SW_HIDE
            }
        }

        public static void BringFormToFront(IntPtr formHandle) {
            if (formHandle == IntPtr.Zero) return;
            // Calling ShowWindow twice ensures Win32 STARTUPINFO.wShowWindow (SW_HIDE from wscript) is consumed on the first call
            ShowWindow(formHandle, 1); // SW_SHOWNORMAL
            ShowWindow(formHandle, 9); // SW_RESTORE
            ShowWindow(formHandle, 5); // SW_SHOW
            SetWindowPos(formHandle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
            SetWindowPos(formHandle, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
            SetForegroundWindow(formHandle);
        }

        private static void OnMidiIn(IntPtr hMidiIn, uint wMsg, IntPtr dwInstance, IntPtr dwParam1, IntPtr dwParam2) {
            if (wMsg != MIM_DATA) return;
            uint raw = unchecked((uint)dwParam1.ToInt64());
            int status = (int)(raw & 0xFF);
            int cmd = status & 0xF0;
            int ch = status & 0x0F;
            int d1 = (int)((raw >> 8) & 0xFF);
            int d2 = (int)((raw >> 16) & 0xFF);
            if (cmd == 0x80 || cmd == 0x90 || cmd == 0xB0) {
                EventQueue.Enqueue(new MidiEventRecord {
                    Status = status,
                    Command = cmd,
                    Channel = ch,
                    Data1 = d1,
                    Data2 = d2,
                    Timestamp = DateTime.Now
                });
            }
        }

        public static bool IsOpen {
            get { return _hMidiIn != IntPtr.Zero; }
        }

        public static bool HasMidiOut {
            get { return _hMidiOut != IntPtr.Zero; }
        }

        public static int FindMidiInIndex(string namePattern) {
            uint count = midiInGetNumDevs();
            for (uint i = 0; i < count; i++) {
                MIDIINCAPS caps;
                if (midiInGetDevCaps(new UIntPtr(i), out caps, (uint)Marshal.SizeOf(typeof(MIDIINCAPS))) == 0) {
                    if (caps.szPname != null && caps.szPname.IndexOf(namePattern, StringComparison.OrdinalIgnoreCase) >= 0) {
                        return (int)i;
                    }
                }
            }
            return -1;
        }

        public static int FindMidiOutIndex(string namePattern) {
            uint count = midiOutGetNumDevs();
            for (uint i = 0; i < count; i++) {
                MIDIOUTCAPS caps;
                if (midiOutGetDevCaps(new UIntPtr(i), out caps, (uint)Marshal.SizeOf(typeof(MIDIOUTCAPS))) == 0) {
                    if (caps.szPname != null && caps.szPname.IndexOf(namePattern, StringComparison.OrdinalIgnoreCase) >= 0) {
                        return (int)i;
                    }
                }
            }
            return -1;
        }

        public static string OpenDevice(string namePattern) {
            CloseDevice();
            string result = "OK";
            var task = System.Threading.Tasks.Task.Run(() => {
                int inIdx = FindMidiInIndex(namePattern);
                if (inIdx < 0) {
                    result = "MIDI Input device matching '" + namePattern + "' not found.";
                    return;
                }
                uint rcIn = midiInOpen(out _hMidiIn, (uint)inIdx, _callbackDelegate, IntPtr.Zero, CALLBACK_FUNCTION);
                if (rcIn != 0) {
                    _hMidiIn = IntPtr.Zero;
                    result = "midiInOpen failed with code " + rcIn + " (check if another app holds exclusive MIDI access).";
                    return;
                }
                midiInStart(_hMidiIn);

                int outIdx = FindMidiOutIndex(namePattern);
                if (outIdx >= 0) {
                    uint rcOut = midiOutOpen(out _hMidiOut, (uint)outIdx, IntPtr.Zero, IntPtr.Zero, 0);
                    if (rcOut != 0) _hMidiOut = IntPtr.Zero;
                }
            });
            task.Wait(1500);
            return result;
        }

        public static void SendPadLed(int note, int velocity, int channel = 0) {
            if (_hMidiOut == IntPtr.Zero) return;
            uint msg = (uint)((0x90 | (channel & 0x0F)) | ((note & 0x7F) << 8) | ((velocity & 0x7F) << 16));
            midiOutShortMsg(_hMidiOut, msg);
        }

        public static void ClearAllPadLeds() {
            if (_hMidiOut == IntPtr.Zero) return;
            for (int n = 0; n < 40; n++) SendPadLed(n, 0, 0);
            for (int n = 64; n <= 71; n++) SendPadLed(n, 0, 0);
            for (int n = 81; n <= 86; n++) SendPadLed(n, 0, 0);
        }

        public static void CloseDevice() {
            IntPtr hIn = _hMidiIn;
            IntPtr hOut = _hMidiOut;
            _hMidiIn = IntPtr.Zero;
            _hMidiOut = IntPtr.Zero;
            var task = System.Threading.Tasks.Task.Run(() => {
                if (hIn != IntPtr.Zero) {
                    try {
                        midiInStop(hIn);
                        midiInReset(hIn);
                        midiInClose(hIn);
                    } catch { }
                }
                if (hOut != IntPtr.Zero) {
                    try {
                        midiOutClose(hOut);
                    } catch { }
                }
            });
            task.Wait(600);
            MidiEventRecord dummy;
            while (EventQueue.TryDequeue(out dummy)) { }
        }

        public static void SetDefaultAudioEndpoint(string deviceId) {
            if (string.IsNullOrWhiteSpace(deviceId)) return;
            var client = (IPolicyConfig)new PolicyConfigClient();
            client.SetDefaultEndpoint(deviceId, 0); // Console
            client.SetDefaultEndpoint(deviceId, 1); // Multimedia
            client.SetDefaultEndpoint(deviceId, 2); // Communications
        }

        public static void SetAudioEndpointVisibility(string deviceId, bool visible) {
            if (string.IsNullOrWhiteSpace(deviceId)) return;
            var client = (IPolicyConfig)new PolicyConfigClient();
            client.SetEndpointVisibility(deviceId, visible);
        }

        public static void SendChord(byte[] modifiers, byte mainKey) {
            if (modifiers != null) {
                for (int i = 0; i < modifiers.Length; i++) {
                    keybd_event(modifiers[i], 0, 0, UIntPtr.Zero);
                }
            }
            keybd_event(mainKey, 0, 0, UIntPtr.Zero);
            keybd_event(mainKey, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
            if (modifiers != null) {
                for (int i = modifiers.Length - 1; i >= 0; i--) {
                    keybd_event(modifiers[i], 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                }
            }
        }

        public static void SendMediaKey(byte vkCode) {
            keybd_event(vkCode, 0, KEYEVENTF_EXTENDEDKEY, UIntPtr.Zero);
            keybd_event(vkCode, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, UIntPtr.Zero);
        }
    }
}
"@
}

# Sub-millisecond CoreAudio MMDevice cache for ultra-responsive knob turns
$script:EndpointCache     = @{}
$script:SharedEnumerator  = $null

function Clear-AudioEndpointCache {
    $script:EndpointCache.Clear()
}

function Get-SharedEnumerator {
    if ($null -eq $script:SharedEnumerator) {
        $script:SharedEnumerator = [NAudio.CoreAudioApi.MMDeviceEnumerator]::new()
    }
    return $script:SharedEnumerator
}

function Initialize-BluetoothHelper {
    $btDir = Join-Path $env:APPDATA 'Elgato\StreamDeck\Plugins\me.rumkee.bluetooth.monitor.sdPlugin'
    if (-not ('BluetoothController.Helpers.BluetoothDeviceHelper' -as [type]) -and (Test-Path $btDir)) {
        try {
            $null = [Reflection.Assembly]::LoadFrom((Join-Path $btDir 'StreamDeckLib.dll'))
            $null = [Reflection.Assembly]::LoadFrom((Join-Path $btDir 'Microsoft.Windows.SDK.NET.dll'))
            $null = [Reflection.Assembly]::LoadFrom((Join-Path $btDir 'WinRT.Runtime.dll'))
            $null = [Reflection.Assembly]::LoadFrom((Join-Path $btDir 'Microsoft.Extensions.Logging.Abstractions.dll'))
            $null = [Reflection.Assembly]::LoadFrom((Join-Path $btDir 'me.rumkee.bluetooth.monitor.dll'))
        } catch { }
    }
}

function Get-AudioEndpointsSnapshot {
    $enum = Get-SharedEnumerator
    $defaultOut = try { $enum.GetDefaultAudioEndpoint([NAudio.CoreAudioApi.DataFlow]::Render, [NAudio.CoreAudioApi.Role]::Multimedia).ID } catch { '' }
    $defaultIn  = try { $enum.GetDefaultAudioEndpoint([NAudio.CoreAudioApi.DataFlow]::Capture, [NAudio.CoreAudioApi.Role]::Communications).ID } catch { '' }

    $items = [Collections.Generic.List[object]]::new()
    foreach ($flow in @([NAudio.CoreAudioApi.DataFlow]::Render, [NAudio.CoreAudioApi.DataFlow]::Capture)) {
        $eps = $enum.EnumerateAudioEndPoints($flow, [NAudio.CoreAudioApi.DeviceState]::All)
        foreach ($ep in $eps) {
            $stateStr = $ep.State.ToString()
            if ($stateStr -notin @('Active', 'Disabled', 'Unplugged')) { continue }
            $volPct = $null
            $muted  = $false
            if ($stateStr -eq 'Active') {
                try {
                    $volPct = [int][math]::Round($ep.AudioEndpointVolume.MasterVolumeLevelScalar * 100)
                    $muted  = [bool]$ep.AudioEndpointVolume.Mute
                } catch { }
            }
            $items.Add([pscustomobject]@{
                ID          = $ep.ID
                FriendlyName= $ep.FriendlyName
                Flow        = $flow.ToString()
                State       = $stateStr
                IsDefault   = ($ep.ID -eq $defaultOut -or $ep.ID -eq $defaultIn)
                VolumePct   = $volPct
                Muted       = $muted
            })
        }
    }
    return $items.ToArray()
}

function Get-PairedBluetoothDevices {
    param([object[]]$AudioSnapshot = $null)
    if ($null -eq $AudioSnapshot) {
        $AudioSnapshot = Get-AudioEndpointsSnapshot
    }
    $known = @(
        @{ Name = 'RB Meta 00YS'; DeviceId = 'Bluetooth#Bluetooth5c:b2:6d:f9:c3:3c-98:59:49:bc:85:b6'; Match = 'RB Meta 00YS|RB_CLEAR' },
        @{ Name = 'RB Meta 01JY'; DeviceId = 'Bluetooth#Bluetooth5c:b2:6d:f9:c3:3c-98:59:49:7f:f4:e7'; Match = 'RB Meta 01JY|_RB-BLUE' },
        @{ Name = 'Joes iPhone';  DeviceId = 'Bluetooth#Bluetooth5c:b2:6d:f9:c3:3c-80:b9:89:32:ef:6d'; Match = 'Joes iPhone' },
        @{ Name = 'Joes_Black_TrackPAD'; DeviceId = 'Bluetooth#Bluetooth5c:b2:6d:f9:c3:3c-c0:95:6d:05:a7:4c'; Match = 'Joes_Black_TrackPAD' }
    )
    $list = [Collections.Generic.List[object]]::new()
    foreach ($k in $known) {
        $activeEp = @($AudioSnapshot | Where-Object { $_.State -eq 'Active' -and $_.FriendlyName -match $k.Match } | Select-Object -First 1)
        $status = if ($activeEp.Count -gt 0) { 'Connected' } else { 'Disconnected' }
        $list.Add([pscustomobject]@{
            Name     = $k.Name
            DeviceId = $k.DeviceId
            Status   = $status
        })
    }
    return $list.ToArray()
}

function Resolve-AudioEndpoint {
    param(
        [string]$MatchPattern,
        [ValidateSet('All','Render','Capture')][string]$Flow = 'All',
        [switch]$IncludeDisabled,
        [switch]$UseCache
    )
    if ([string]::IsNullOrWhiteSpace($MatchPattern)) { return $null }
    $cacheKey = "$Flow|$IncludeDisabled|$MatchPattern"
    if ($UseCache -and $script:EndpointCache.ContainsKey($cacheKey)) {
        $cached = $script:EndpointCache[$cacheKey]
        try {
            if ($cached -and $cached.State.ToString() -eq 'Active') { return $cached }
        } catch { }
        [void]$script:EndpointCache.Remove($cacheKey)
    }

    $enum = Get-SharedEnumerator
    if ($MatchPattern -eq '@DefaultRender') {
        $dev = try { $enum.GetDefaultAudioEndpoint([NAudio.CoreAudioApi.DataFlow]::Render, [NAudio.CoreAudioApi.Role]::Multimedia) } catch { $null }
        if ($UseCache -and $dev) { $script:EndpointCache[$cacheKey] = $dev }
        return $dev
    }
    if ($MatchPattern -eq '@DefaultCapture') {
        $dev = try { $enum.GetDefaultAudioEndpoint([NAudio.CoreAudioApi.DataFlow]::Capture, [NAudio.CoreAudioApi.Role]::Communications) } catch { $null }
        if ($UseCache -and $dev) { $script:EndpointCache[$cacheKey] = $dev }
        return $dev
    }
    $stateMask = if ($IncludeDisabled) { [NAudio.CoreAudioApi.DeviceState]::All } else { [NAudio.CoreAudioApi.DeviceState]::Active }
    $flows = if ($Flow -eq 'Render') { @([NAudio.CoreAudioApi.DataFlow]::Render) }
             elseif ($Flow -eq 'Capture') { @([NAudio.CoreAudioApi.DataFlow]::Capture) }
             else { @([NAudio.CoreAudioApi.DataFlow]::Render, [NAudio.CoreAudioApi.DataFlow]::Capture) }

    foreach ($f in $flows) {
        $eps = $enum.EnumerateAudioEndPoints($f, $stateMask)
        foreach ($ep in $eps) {
            if ($ep.ID -ieq $MatchPattern -or $ep.FriendlyName -ieq $MatchPattern -or $ep.FriendlyName.IndexOf($MatchPattern, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                if ($UseCache) { $script:EndpointCache[$cacheKey] = $ep }
                return $ep
            }
        }
    }
    return $null
}

function Convert-MidiCcToScalar {
    param([int]$MidiValue)
    # Deadzone clamping: CC <= 1 snaps cleanly to 0.0 (0% zeroed out), CC >= 126 snaps to 1.0 (100%)
    if ($MidiValue -le 1)   { return [double]0.0 }
    if ($MidiValue -ge 126) { return [double]1.0 }
    return [double](($MidiValue - 1) / 125.0)
}

function Get-CurrentMappingVolumePct {
    param([pscustomobject]$Mapping)
    switch ($Mapping.ActionType) {
        'VolumeMasterOut' {
            $ep = Resolve-AudioEndpoint -MatchPattern '@DefaultRender' -Flow Render -UseCache
            if ($ep) { return [int][math]::Round($ep.AudioEndpointVolume.MasterVolumeLevelScalar * 100) }
        }
        'VolumeDefaultMic' {
            $ep = Resolve-AudioEndpoint -MatchPattern '@DefaultCapture' -Flow Capture -UseCache
            if ($ep) { return [int][math]::Round($ep.AudioEndpointVolume.MasterVolumeLevelScalar * 100) }
        }
        'VolumeDevice' {
            $ep = Resolve-AudioEndpoint -MatchPattern $Mapping.Target -Flow All -UseCache
            if ($ep) { return [int][math]::Round($ep.AudioEndpointVolume.MasterVolumeLevelScalar * 100) }
        }
    }
    return $null
}

function Set-AudioVolumeByMapping {
    param(
        [pscustomobject]$Mapping,
        [int]$MidiValue,
        [switch]$AutoMuteAtZero = $true
    )
    $scalar = Convert-MidiCcToScalar -MidiValue $MidiValue
    $pct = [int][math]::Round($scalar * 100)
    $isZero = ($pct -eq 0)

    switch ($Mapping.ActionType) {
        'VolumeMasterOut' {
            $ep = Resolve-AudioEndpoint -MatchPattern '@DefaultRender' -Flow Render -UseCache
            if ($ep) {
                $ep.AudioEndpointVolume.MasterVolumeLevelScalar = [float]$scalar
                if ($AutoMuteAtZero) { $ep.AudioEndpointVolume.Mute = $isZero }
                return "$($ep.FriendlyName): $pct%$(if($isZero){' (ZEROED/MUTED)'}else{''})"
            }
        }
        'VolumeDefaultMic' {
            $ep = Resolve-AudioEndpoint -MatchPattern '@DefaultCapture' -Flow Capture -UseCache
            if ($ep) {
                $ep.AudioEndpointVolume.MasterVolumeLevelScalar = [float]$scalar
                if ($AutoMuteAtZero) { $ep.AudioEndpointVolume.Mute = $isZero }
                return "$($ep.FriendlyName): $pct%$(if($isZero){' (ZEROED/MUTED)'}else{''})"
            }
        }
        'VolumeDevice' {
            $ep = Resolve-AudioEndpoint -MatchPattern $Mapping.Target -Flow All -UseCache
            if ($ep) {
                $ep.AudioEndpointVolume.MasterVolumeLevelScalar = [float]$scalar
                if ($AutoMuteAtZero) { $ep.AudioEndpointVolume.Mute = $isZero }
                return "$($ep.FriendlyName): $pct%$(if($isZero){' (ZEROED/MUTED)'}else{''})"
            }
            return "Device '$($Mapping.Target)' is not active."
        }
        'VolumeApp' {
            $out = Resolve-AudioEndpoint -MatchPattern '@DefaultRender' -Flow Render -UseCache
            if ($out) {
                $sessions = $out.AudioSessionManager.Sessions
                $matched = 0
                for ($i = 0; $i -lt $sessions.Count; $i++) {
                    $s = $sessions[$i]
                    $procId = [int]$s.GetProcessID
                    if ($procId -le 0) { continue }
                    $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
                    if (($proc -and $proc.ProcessName -match [regex]::Escape($Mapping.Target)) -or ($s.DisplayName -and $s.DisplayName -match [regex]::Escape($Mapping.Target))) {
                        $s.SimpleAudioVolume.Volume = [float]$scalar
                        if ($AutoMuteAtZero) { $s.SimpleAudioVolume.Mute = $isZero }
                        $matched++
                    }
                }
                if ($matched -gt 0) { return "App '$($Mapping.Target)' ($matched session): $pct%" }
            }
            return "No active audio session for '$($Mapping.Target)'."
        }
    }
    return "Unmapped knob ($pct%)"
}

function Parse-HotkeyChord {
    param([string]$ChordText)
    if ([string]::IsNullOrWhiteSpace($ChordText)) { return $null }
    $parts = @($ChordText -split '\+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if (-not $parts.Count) { return $null }
    $mods = [Collections.Generic.List[byte]]::new()
    $mainVk = [byte]0

    $keyMap = @{
        'CTRL' = 0x11; 'CONTROL' = 0x11
        'ALT'  = 0x12; 'MENU'    = 0x12
        'SHIFT'= 0x10
        'WIN'  = 0x5B; 'LWIN'    = 0x5B
        'SPACE'= 0x20; 'ENTER'   = 0x0D; 'RETURN' = 0x0D
        'TAB'  = 0x09; 'ESC'     = 0x1B; 'ESCAPE' = 0x1B
        'BACKSPACE' = 0x08; 'DELETE' = 0x2E; 'DEL' = 0x2E
        'UP'   = 0x26; 'DOWN'    = 0x28; 'LEFT'   = 0x25; 'RIGHT' = 0x27
        'HOME' = 0x24; 'END'     = 0x23; 'PGUP'   = 0x21; 'PGDN'  = 0x22
        'F1' = 0x70; 'F2' = 0x71; 'F3' = 0x72; 'F4' = 0x73; 'F5' = 0x74; 'F6' = 0x75
        'F7' = 0x76; 'F8' = 0x77; 'F9' = 0x78; 'F10'= 0x79; 'F11'= 0x7A; 'F12'= 0x7B
        'F13'= 0x7C; 'F14'= 0x7D; 'F15'= 0x7E; 'F16'= 0x7F
    }

    for ($i = 0; $i -lt $parts.Count; $i++) {
        $token = $parts[$i].ToUpperInvariant()
        if ($i -lt ($parts.Count - 1) -and $token -in @('CTRL','CONTROL','ALT','MENU','SHIFT','WIN','LWIN')) {
            [void]$mods.Add([byte]$keyMap[$token])
        } elseif ($keyMap.ContainsKey($token)) {
            $mainVk = [byte]$keyMap[$token]
        } elseif ($token.Length -eq 1) {
            $ch = [int][char]$token[0]
            if (($ch -ge 65 -and $ch -le 90) -or ($ch -ge 48 -and $ch -le 57)) {
                $mainVk = [byte]$ch
            }
        }
    }
    if ($mainVk -eq 0) { return $null }
    return [pscustomobject]@{
        Modifiers = $mods.ToArray()
        MainKey   = $mainVk
    }
}

function Invoke-ApcAction {
    param(
        [Parameter(Mandatory)][pscustomobject]$Mapping
    )
    switch ($Mapping.ActionType) {
        'None' {
            return 'No action assigned.'
        }
        'SetDefaultDevice' {
            $ep = Resolve-AudioEndpoint -MatchPattern $Mapping.Target -IncludeDisabled
            if (-not $ep) { return "Audio endpoint '$($Mapping.Target)' not found." }
            if ($ep.State.ToString() -eq 'Disabled') {
                [GoodCube.ApcDeck.NativeBridge]::SetAudioEndpointVisibility($ep.ID, $true)
                Start-Sleep -Milliseconds 120
            }
            [GoodCube.ApcDeck.NativeBridge]::SetDefaultAudioEndpoint($ep.ID)
            Clear-AudioEndpointCache
            return "Default audio device set to: $($ep.FriendlyName)"
        }
        'SwapDevices' {
            $epA = Resolve-AudioEndpoint -MatchPattern $Mapping.Target -IncludeDisabled
            $epB = Resolve-AudioEndpoint -MatchPattern $Mapping.SecondaryTarget -IncludeDisabled
            if (-not $epA -or -not $epB) { return "Swap devices need both Primary ('$($Mapping.Target)') and Secondary ('$($Mapping.SecondaryTarget)')." }
            $enum = Get-SharedEnumerator
            $curOut = try { $enum.GetDefaultAudioEndpoint([NAudio.CoreAudioApi.DataFlow]::Render, [NAudio.CoreAudioApi.Role]::Multimedia).ID } catch { '' }
            $curIn  = try { $enum.GetDefaultAudioEndpoint([NAudio.CoreAudioApi.DataFlow]::Capture, [NAudio.CoreAudioApi.Role]::Communications).ID } catch { '' }
            $chooseB = ($epA.ID -eq $curOut -or $epA.ID -eq $curIn)
            $chosen = if ($chooseB) { $epB } else { $epA }
            if ($chosen.State.ToString() -eq 'Disabled') {
                [GoodCube.ApcDeck.NativeBridge]::SetAudioEndpointVisibility($chosen.ID, $true)
                Start-Sleep -Milliseconds 120
            }
            [GoodCube.ApcDeck.NativeBridge]::SetDefaultAudioEndpoint($chosen.ID)
            Clear-AudioEndpointCache
            return "Swapped active audio device to: $($chosen.FriendlyName)"
        }
        'MuteToggle' {
            $ep = Resolve-AudioEndpoint -MatchPattern $Mapping.Target -UseCache
            if (-not $ep) { return "Audio device '$($Mapping.Target)' is not active." }
            $newMute = -not [bool]$ep.AudioEndpointVolume.Mute
            $ep.AudioEndpointVolume.Mute = $newMute
            $stateText = if ($newMute) { 'MUTED' } else { 'LIVE (Unmuted)' }
            return "$($ep.FriendlyName): $stateText"
        }
        'EndpointEnableToggle' {
            $ep = Resolve-AudioEndpoint -MatchPattern $Mapping.Target -IncludeDisabled
            if (-not $ep) { return "Audio endpoint '$($Mapping.Target)' not found." }
            $currentlyActive = ($ep.State.ToString() -eq 'Active')
            $makeVisible = -not $currentlyActive
            [GoodCube.ApcDeck.NativeBridge]::SetAudioEndpointVisibility($ep.ID, $makeVisible)
            Clear-AudioEndpointCache
            $stateText = if ($makeVisible) { 'ENABLED (Active)' } else { 'DISABLED (Hidden)' }
            return "$($ep.FriendlyName): $stateText"
        }
        'BalanceAll' {
            & pwsh.exe -NoLogo -NoProfile -WindowStyle Hidden -File 'C:\Tools\elgato-mcp\Audio-Control.ps1' balance-all
            Clear-AudioEndpointCache
            return 'Balanced all workstation outputs & normalized microphones to 95%.'
        }
        'BluetoothConnect' {
            $targetName = $Mapping.Target
            # Run WinRT RFCOMM Handsfree wake-up in an isolated MTA runspace so STA UI never blocks
            $ps = [PowerShell]::Create()
            $null = $ps.AddScript({
                param($tName)
                $btDir = Join-Path $env:APPDATA 'Elgato\StreamDeck\Plugins\me.rumkee.bluetooth.monitor.sdPlugin'
                if (-not (Test-Path $btDir)) { return "Stream Deck Bluetooth plugin not found." }
                $null = [Reflection.Assembly]::LoadFrom((Join-Path $btDir 'StreamDeckLib.dll'))
                $null = [Reflection.Assembly]::LoadFrom((Join-Path $btDir 'Microsoft.Windows.SDK.NET.dll'))
                $null = [Reflection.Assembly]::LoadFrom((Join-Path $btDir 'WinRT.Runtime.dll'))
                $null = [Reflection.Assembly]::LoadFrom((Join-Path $btDir 'Microsoft.Extensions.Logging.Abstractions.dll'))
                $null = [Reflection.Assembly]::LoadFrom((Join-Path $btDir 'me.rumkee.bluetooth.monitor.dll'))
                $logger = [Microsoft.Extensions.Logging.Abstractions.NullLogger]::Instance
                $dict = [BluetoothController.Helpers.BluetoothDeviceHelper]::GetAllPairedBluetoothDevices($logger).GetAwaiter().GetResult()
                $devId = $null
                $devName = $tName
                foreach ($kv in $dict.GetEnumerator()) {
                    if ($kv.Key -ieq $tName -or $kv.Value -ieq $tName -or $kv.Key.IndexOf($tName, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        $devName = [string]$kv.Key
                        $devId   = [string]$kv.Value
                        break
                    }
                }
                if (-not $devId) { return "Paired Bluetooth device '$tName' not found." }
                $helper = [BluetoothController.Helpers.BluetoothDeviceHelper]::new()
                $loaded = $helper.LoadDeviceFromId($devId, $logger).GetAwaiter().GetResult()
                if (-not $loaded) { return "Could not load Bluetooth device '$devName'." }
                $ok = $helper.Connect(4382, $logger).GetAwaiter().GetResult()
                return "Bluetooth '$devName' RFCOMM wake-up sent (Result=$ok, Status=$($helper.Status))."
            }).AddArgument($targetName)
            $async = $ps.BeginInvoke()
            if ($async.AsyncWaitHandle.WaitOne(4500)) {
                $res = @($ps.EndInvoke($async)) -join ' '
                $ps.Dispose()
                Clear-AudioEndpointCache
                return $res
            } else {
                $ps.Dispose()
                Clear-AudioEndpointCache
                return "Bluetooth '$targetName' wake-up dispatched in background."
            }
        }
        'Hotkey' {
            $parsed = Parse-HotkeyChord -ChordText $Mapping.Target
            if (-not $parsed) { return "Unrecognized hotkey format '$($Mapping.Target)'. Use e.g. Alt+Q, Win+H, Ctrl+Shift+M." }
            [GoodCube.ApcDeck.NativeBridge]::SendChord($parsed.Modifiers, $parsed.MainKey)
            return "Sent hotkey: $($Mapping.Target)"
        }
        'MediaKey' {
            $vkMap = @{
                'PlayPause'  = [byte]0xB3
                'NextTrack'  = [byte]0xB0
                'PrevTrack'  = [byte]0xB1
                'Stop'       = [byte]0xB2
                'VolumeMute' = [byte]0xAD
                'VolumeDown' = [byte]0xAE
                'VolumeUp'   = [byte]0xAF
            }
            $vk = if ($vkMap.ContainsKey($Mapping.Target)) { $vkMap[$Mapping.Target] } else { [byte]0xB3 }
            [GoodCube.ApcDeck.NativeBridge]::SendMediaKey($vk)
            return "Sent media key: $($Mapping.Target)"
        }
        'SystemCommand' {
            switch ($Mapping.Target) {
                'sound-cpl'      { Start-Process 'control.exe' -ArgumentList 'mmsys.cpl,,0'; return 'Opened Windows Sound Control Panel (Playback).' }
                'recording-cpl'  { Start-Process 'control.exe' -ArgumentList 'mmsys.cpl,,1'; return 'Opened Windows Sound Control Panel (Recording).' }
                'app-mixer'      { Start-Process 'explorer.exe' -ArgumentList 'ms-settings:apps-volume'; return 'Opened Windows App Volume Mixer.' }
                'sound-settings' { Start-Process 'explorer.exe' -ArgumentList 'ms-settings:sound'; return 'Opened Windows Sound Settings.' }
                'bt-settings'    { Start-Process 'explorer.exe' -ArgumentList 'ms-settings:bluetooth'; return 'Opened Windows Bluetooth Settings.' }
                default {
                    if (-not [string]::IsNullOrWhiteSpace($Mapping.Target)) {
                        Start-Process -FilePath $Mapping.Target
                        return "Launched: $($Mapping.Target)"
                    }
                }
            }
        }
    }
    return "Action '$($Mapping.ActionType)' executed."
}

function Convert-ColorNameToApcVelocity {
    param([string]$ColorName, [int]$DefaultVel = 5)
    # Akai APC Key 25 (MK1) Pad LED velocities:
    # 0 = Off, 1 = Solid Green, 2 = Blink Green, 3 = Solid Red, 4 = Blink Red, 5 = Solid Amber, 6 = Blink Amber
    switch ($ColorName) {
        'Off'        { return 0 }
        'Green'      { return 1 }
        'BlinkGreen' { return 2 }
        'Red'        { return 3 }
        'BlinkRed'   { return 4 }
        'Amber'      { return 5 }
        'BlinkAmber' { return 6 }
        default      { return $DefaultVel }
    }
}

function Get-PadLedVelocity {
    param(
        [pscustomobject]$Mapping,
        [object[]]$AudioSnapshot,
        [object[]]$BtSnapshot
    )
    if (-not $Mapping -or $Mapping.ActionType -eq 'None') {
        if ($Mapping -and $Mapping.PSObject.Properties['LedColor'] -and $Mapping.LedColor -notin @('','Auto','Off')) {
            return (Convert-ColorNameToApcVelocity -ColorName $Mapping.LedColor -DefaultVel 0)
        }
        return 0
    }

    $onColor  = if ($Mapping.PSObject.Properties['LedColor'] -and $Mapping.LedColor) { [string]$Mapping.LedColor } else { 'Auto' }
    $offColor = if ($Mapping.PSObject.Properties['OffLedColor'] -and $Mapping.OffLedColor) { [string]$Mapping.OffLedColor } else { 'Auto' }

    switch ($Mapping.ActionType) {
        'SetDefaultDevice' {
            $match = @($AudioSnapshot | Where-Object { $_.FriendlyName -match [regex]::Escape($Mapping.Target) -or $_.ID -eq $Mapping.Target } | Select-Object -First 1)
            if (-not $match.Count) { return 0 }
            if ($match[0].State -eq 'Disabled') {
                return $(if ($offColor -ne 'Auto') { Convert-ColorNameToApcVelocity $offColor 3 } else { 3 })
            }
            if ($match[0].IsDefault) {
                return $(if ($onColor -notin @('Auto','')) { Convert-ColorNameToApcVelocity $onColor 1 } else { 1 })
            }
            return $(if ($offColor -ne 'Auto') { Convert-ColorNameToApcVelocity $offColor 5 } else { 5 })
        }
        'SwapDevices' {
            $matchA = @($AudioSnapshot | Where-Object { $_.FriendlyName -match [regex]::Escape($Mapping.Target) -or $_.ID -eq $Mapping.Target } | Select-Object -First 1)
            if ($matchA.Count -and $matchA[0].IsDefault) {
                return $(if ($onColor -notin @('Auto','')) { Convert-ColorNameToApcVelocity $onColor 1 } else { 1 })
            }
            return $(if ($offColor -ne 'Auto') { Convert-ColorNameToApcVelocity $offColor 5 } else { 5 })
        }
        'MuteToggle' {
            $match = if ($Mapping.Target -eq '@DefaultCapture') {
                @($AudioSnapshot | Where-Object { $_.Flow -eq 'Capture' -and $_.IsDefault } | Select-Object -First 1)
            } elseif ($Mapping.Target -eq '@DefaultRender') {
                @($AudioSnapshot | Where-Object { $_.Flow -eq 'Render' -and $_.IsDefault } | Select-Object -First 1)
            } else {
                @($AudioSnapshot | Where-Object { $_.FriendlyName -match [regex]::Escape($Mapping.Target) -or $_.ID -eq $Mapping.Target } | Select-Object -First 1)
            }
            if (-not $match.Count -or $match[0].State -ne 'Active') { return 0 }
            if ($match[0].Muted) {
                return $(if ($offColor -ne 'Auto') { Convert-ColorNameToApcVelocity $offColor 3 } else { 3 })
            }
            return $(if ($onColor -notin @('Auto','')) { Convert-ColorNameToApcVelocity $onColor 1 } else { 1 })
        }
        'EndpointEnableToggle' {
            $match = @($AudioSnapshot | Where-Object { $_.FriendlyName -match [regex]::Escape($Mapping.Target) -or $_.ID -eq $Mapping.Target } | Select-Object -First 1)
            if (-not $match.Count) { return 0 }
            if ($match[0].State -eq 'Active') {
                return $(if ($onColor -notin @('Auto','')) { Convert-ColorNameToApcVelocity $onColor 1 } else { 1 })
            }
            return $(if ($offColor -ne 'Auto') { Convert-ColorNameToApcVelocity $offColor 3 } else { 3 })
        }
        'BluetoothConnect' {
            $bt = @($BtSnapshot | Where-Object { $_.Name -match [regex]::Escape($Mapping.Target) -or $_.DeviceId -eq $Mapping.Target } | Select-Object -First 1)
            if ($bt.Count -and $bt[0].Status -eq 'Connected') {
                return $(if ($onColor -notin @('Auto','')) { Convert-ColorNameToApcVelocity $onColor 1 } else { 1 })
            }
            return $(if ($offColor -ne 'Auto') { Convert-ColorNameToApcVelocity $offColor 3 } else { 3 })
        }
        default {
            return (Convert-ColorNameToApcVelocity -ColorName $onColor -DefaultVel 5)
        }
    }
}

function Sync-ApcHardwareLeds {
    param(
        [hashtable]$ProfileMap,
        [object[]]$AudioSnapshot = $null,
        [object[]]$BtSnapshot = $null
    )
    if (-not [GoodCube.ApcDeck.NativeBridge]::HasMidiOut) { return }
    if ($null -eq $AudioSnapshot) { $AudioSnapshot = Get-AudioEndpointsSnapshot }
    if ($null -eq $BtSnapshot)    { $BtSnapshot = @() }

    for ($note = 0; $note -lt 40; $note++) {
        $id = "Pad_$note"
        $vel = if ($ProfileMap.ContainsKey($id)) {
            Get-PadLedVelocity -Mapping $ProfileMap[$id] -AudioSnapshot $AudioSnapshot -BtSnapshot $BtSnapshot
        } else { 0 }
        [GoodCube.ApcDeck.NativeBridge]::SendPadLed($note, $vel, 0)
    }
    foreach ($note in @(64..71)) {
        $id = "Track_$note"
        $vel = if ($ProfileMap.ContainsKey($id)) {
            $m = $ProfileMap[$id]
            if ($m.LedColor -eq 'Off') { 0 }
            elseif ($m.LedColor -match '^Blink') { 2 }
            elseif ($m.ActionType -ne 'None') { 1 }
            else { 0 }
        } else { 0 }
        [GoodCube.ApcDeck.NativeBridge]::SendPadLed($note, $vel, 0)
    }
    foreach ($note in @(82..86)) {
        $id = "Scene_$note"
        $vel = if ($ProfileMap.ContainsKey($id)) {
            $m = $ProfileMap[$id]
            if ($m.LedColor -eq 'Off') { 0 }
            elseif ($m.LedColor -match '^Blink') { 2 }
            elseif ($m.ActionType -ne 'None') { 1 }
            else { 0 }
        } else { 0 }
        [GoodCube.ApcDeck.NativeBridge]::SendPadLed($note, $vel, 0)
    }
}

function New-DefaultApcProfile {
    $controls = [Collections.Generic.List[object]]::new()
    function Add-Map($id, $kind, $channel, $code, $label, $actionType, $target = '', $secTarget = '', $led = 'Auto', $offLed = 'Auto') {
        $controls.Add([pscustomobject]@{
            ControlId       = $id
            ControlKind     = $kind      # Knob, Pad, Scene, Track, Key
            Channel         = $channel   # 0 = Ch1 (Pads/Knobs), 1 = Ch2 (Piano Keys)
            Code            = $code      # CC 48..55 or Note number
            Label           = $label
            ActionType      = $actionType
            Target          = $target
            SecondaryTarget = $secTarget
            LedColor        = $led       # Auto, Green, BlinkGreen, Amber, BlinkAmber, Red, BlinkRed, Off
            OffLedColor     = $offLed    # Auto, Amber, Red, Green, BlinkAmber, BlinkRed, BlinkGreen, Off
        })
    }

    # 8 Rotary Knobs (K1..K8 -> CC 48..55 on Channel 1)
    Add-Map 'Knob_48' 'Knob' 0 48 'K1: MASTER OUT'   'VolumeMasterOut'  '@DefaultRender'
    Add-Map 'Knob_49' 'Knob' 0 49 'K2: CMD CENTER'   'VolumeDevice'     'COMMAND_CENTER'
    Add-Map 'Knob_50' 'Knob' 0 50 'K3: VOICE CUBE'   'VolumeDevice'     'VOICE_CUBE'
    Add-Map 'Knob_51' 'Knob' 0 51 'K4: PS5 HEADPH'   'VolumeDevice'     'PS5_HEADPHONES'
    Add-Map 'Knob_52' 'Knob' 0 52 'K5: M-AUDIO AUX'  'VolumeDevice'     'M-AUDIO-AUX'
    Add-Map 'Knob_53' 'Knob' 0 53 'K6: META VR OUT'  'VolumeDevice'     'META_VR'
    Add-Map 'Knob_54' 'Knob' 0 54 'K7: CMD MIC'      'VolumeDevice'     'CMD_MIC'
    Add-Map 'Knob_55' 'Knob' 0 55 'K8: PS5 MIC'      'VolumeDevice'     'PS5_MIC'

    # Row 1 of Pads (Top Row, Notes 32..39): Select Default Audio Output / Input + A/B Swaps
    Add-Map 'Pad_32' 'Pad' 0 32 'OUT: CMD CTR'   'SetDefaultDevice' 'COMMAND_CENTER' '' 'Green' 'Amber'
    Add-Map 'Pad_33' 'Pad' 0 33 'OUT: CUBE'      'SetDefaultDevice' 'VOICE_CUBE'     '' 'Green' 'Amber'
    Add-Map 'Pad_34' 'Pad' 0 34 'OUT: PS5 HP'    'SetDefaultDevice' 'PS5_HEADPHONES' '' 'Green' 'Amber'
    Add-Map 'Pad_35' 'Pad' 0 35 'OUT: M-AUDIO'   'SetDefaultDevice' 'M-AUDIO-AUX'    '' 'Green' 'Amber'
    Add-Map 'Pad_36' 'Pad' 0 36 'OUT: META VR'   'SetDefaultDevice' 'META_VR'        '' 'Green' 'Amber'
    Add-Map 'Pad_37' 'Pad' 0 37 'MIC: CMD USB'   'SetDefaultDevice' 'CMD_MIC'        '' 'Green' 'Amber'
    Add-Map 'Pad_38' 'Pad' 0 38 'MIC: PS5 LINK'  'SetDefaultDevice' 'PS5_MIC'        '' 'Green' 'Amber'
    Add-Map 'Pad_39' 'Pad' 0 39 'SWAP SPK A/B'   'SwapDevices'      'COMMAND_CENTER' 'VOICE_CUBE' 'Green' 'Amber'

    # Row 2 of Pads (Notes 24..31): Mute / Unmute per device (Green = Live, Red = Muted)
    Add-Map 'Pad_24' 'Pad' 0 24 'MUTE MASTER'    'MuteToggle' '@DefaultRender'  '' 'Green' 'Red'
    Add-Map 'Pad_25' 'Pad' 0 25 'MUTE CMD CTR'   'MuteToggle' 'COMMAND_CENTER'  '' 'Green' 'Red'
    Add-Map 'Pad_26' 'Pad' 0 26 'MUTE CUBE'      'MuteToggle' 'VOICE_CUBE'      '' 'Green' 'Red'
    Add-Map 'Pad_27' 'Pad' 0 27 'MUTE PS5 HP'    'MuteToggle' 'PS5_HEADPHONES'  '' 'Green' 'Red'
    Add-Map 'Pad_28' 'Pad' 0 28 'MUTE M-AUDIO'   'MuteToggle' 'M-AUDIO-AUX'     '' 'Green' 'Red'
    Add-Map 'Pad_29' 'Pad' 0 29 'MUTE META VR'   'MuteToggle' 'META_VR'         '' 'Green' 'Red'
    Add-Map 'Pad_30' 'Pad' 0 30 'MUTE CMD MIC'   'MuteToggle' 'CMD_MIC'         '' 'Green' 'Red'
    Add-Map 'Pad_31' 'Pad' 0 31 'MUTE PS5 MIC'   'MuteToggle' 'PS5_MIC'         '' 'Green' 'Red'

    # Row 3 of Pads (Notes 16..23): Activate / Deactivate Windows Audio Endpoints (Enable / Disable)
    Add-Map 'Pad_16' 'Pad' 0 16 'EN/DIS CMD'     'EndpointEnableToggle' 'COMMAND_CENTER' '' 'Green' 'Red'
    Add-Map 'Pad_17' 'Pad' 0 17 'EN/DIS CUBE'    'EndpointEnableToggle' 'VOICE_CUBE'     '' 'Green' 'Red'
    Add-Map 'Pad_18' 'Pad' 0 18 'EN/DIS PS5 HP'  'EndpointEnableToggle' 'PS5_HEADPHONES' '' 'Green' 'Red'
    Add-Map 'Pad_19' 'Pad' 0 19 'EN/DIS M-AUD'   'EndpointEnableToggle' 'M-AUDIO-AUX'    '' 'Green' 'Red'
    Add-Map 'Pad_20' 'Pad' 0 20 'EN/DIS VR OUT'  'EndpointEnableToggle' 'META_VR'        '' 'Green' 'Red'
    Add-Map 'Pad_21' 'Pad' 0 21 'EN/DIS CMD MIC' 'EndpointEnableToggle' 'CMD_MIC'        '' 'Green' 'Red'
    Add-Map 'Pad_22' 'Pad' 0 22 'EN/DIS PS5 MIC' 'EndpointEnableToggle' 'PS5_MIC'        '' 'Green' 'Red'
    Add-Map 'Pad_23' 'Pad' 0 23 'SWAP MIC A/B'   'SwapDevices'          'CMD_MIC'        'PS5_MIC' 'Green' 'Amber'

    # Row 4 of Pads (Notes 8..15): Bluetooth Connect + Audio Balance + Windows Sound Panels
    Add-Map 'Pad_8'  'Pad' 0 8  'BT: META CLR'   'BluetoothConnect' 'RB Meta 00YS'   '' 'Green' 'Red'
    Add-Map 'Pad_9'  'Pad' 0 9  'BT: META BLU'   'BluetoothConnect' 'RB Meta 01JY'   '' 'Green' 'Red'
    Add-Map 'Pad_10' 'Pad' 0 10 'BT: IPHONE'     'BluetoothConnect' 'Joes iPhone'    '' 'Green' 'Red'
    Add-Map 'Pad_11' 'Pad' 0 11 'BALANCE 95%'    'BalanceAll'       ''               '' 'Green' 'Off'
    Add-Map 'Pad_12' 'Pad' 0 12 'SOUND CPL'      'SystemCommand'    'sound-cpl'      '' 'Amber' 'Off'
    Add-Map 'Pad_13' 'Pad' 0 13 'MIC CPL'        'SystemCommand'    'recording-cpl'  '' 'Amber' 'Off'
    Add-Map 'Pad_14' 'Pad' 0 14 'APP MIXER'      'SystemCommand'    'app-mixer'      '' 'Amber' 'Off'
    Add-Map 'Pad_15' 'Pad' 0 15 'BT SETTINGS'    'SystemCommand'    'bt-settings'    '' 'Amber' 'Off'

    # Row 5 of Pads (Bottom Row, Notes 0..7): Speechify Hotkeys + Voice Dictation + Media Transport
    Add-Map 'Pad_0'  'Pad' 0 0  'READ (Alt+Q)'   'Hotkey'   'Alt+Q'      '' 'Amber' 'Off'
    Add-Map 'Pad_1'  'Pad' 0 1  'PAUSE (Alt+W)'  'Hotkey'   'Alt+W'      '' 'Amber' 'Off'
    Add-Map 'Pad_2'  'Pad' 0 2  'SLOW (Alt+S)'   'Hotkey'   'Alt+S'      '' 'Amber' 'Off'
    Add-Map 'Pad_3'  'Pad' 0 3  'FAST (Alt+F)'   'Hotkey'   'Alt+F'      '' 'Amber' 'Off'
    Add-Map 'Pad_4'  'Pad' 0 4  'SPEAK (Alt+A)'  'Hotkey'   'Alt+A'      '' 'Amber' 'Off'
    Add-Map 'Pad_5'  'Pad' 0 5  'DICTATE Win+H'  'Hotkey'   'Win+H'      '' 'Green' 'Off'
    Add-Map 'Pad_6'  'Pad' 0 6  'MEDIA PLAY'     'MediaKey' 'PlayPause'  '' 'Green' 'Off'
    Add-Map 'Pad_7'  'Pad' 0 7  'MEDIA NEXT'     'MediaKey' 'NextTrack'  '' 'Amber' 'Off'

    # 5 Round Scene Buttons on the Right (Notes 82..86) + Stop All Clips (81)
    Add-Map 'Scene_82' 'Scene' 0 82 'CLIP STOP'   'MediaKey'      'Stop'            '' 'Green' 'Off'
    Add-Map 'Scene_83' 'Scene' 0 83 'SOLO'        'MediaKey'      'PrevTrack'       '' 'Green' 'Off'
    Add-Map 'Scene_84' 'Scene' 0 84 'REC ARM'     'Hotkey'        'Win+H'           '' 'Green' 'Off'
    Add-Map 'Scene_85' 'Scene' 0 85 'MUTE MIC'    'MuteToggle'    '@DefaultCapture' '' 'Green' 'Off'
    Add-Map 'Scene_86' 'Scene' 0 86 'SELECT'      'BalanceAll'    ''                '' 'Green' 'Off'
    Add-Map 'Scene_81' 'Scene' 0 81 'STOP ALL'    'MediaKey'      'PlayPause'       '' 'Green' 'Off'

    # 8 Track / Knob-Mode Buttons Below the Grid (Notes 64..71)
    Add-Map 'Track_64' 'Track' 0 64 'UP'          'MediaKey'      'VolumeUp'        '' 'Red' 'Off'
    Add-Map 'Track_65' 'Track' 0 65 'DOWN'        'MediaKey'      'VolumeDown'      '' 'Red' 'Off'
    Add-Map 'Track_66' 'Track' 0 66 'LEFT'        'MediaKey'      'PrevTrack'       '' 'Red' 'Off'
    Add-Map 'Track_67' 'Track' 0 67 'RIGHT'       'MediaKey'      'NextTrack'       '' 'Red' 'Off'
    Add-Map 'Track_68' 'Track' 0 68 'VOLUME'      'SystemCommand' 'sound-cpl'       '' 'Red' 'Off'
    Add-Map 'Track_69' 'Track' 0 69 'PAN'         'SystemCommand' 'app-mixer'       '' 'Red' 'Off'
    Add-Map 'Track_70' 'Track' 0 70 'SEND'        'SystemCommand' 'bt-settings'     '' 'Red' 'Off'
    Add-Map 'Track_71' 'Track' 0 71 'DEVICE'      'SystemCommand' 'sound-settings'  '' 'Red' 'Off'

    # 25 Piano Keys (Channel 2, Notes 48..72 -> C3..C5)
    $noteNames = @('C','C#','D','D#','E','F','F#','G','G#','A','A#','B')
    for ($n = 48; $n -le 72; $n++) {
        $oct = [int][math]::Floor(($n / 12) - 1)
        $nm  = $noteNames[$n % 12] + $oct
        Add-Map "Key_$n" 'Key' 1 $n "KEY $nm" 'None' '' '' 'Off' 'Off'
    }

    return $controls.ToArray()
}

function Load-ApcProfile {
    if (Test-Path -LiteralPath $script:ConfigPath) {
        try {
            $raw = Get-Content -Raw -LiteralPath $script:ConfigPath | ConvertFrom-Json
            if ($raw -and $raw.Controls) {
                $map = @{}
                foreach ($c in $raw.Controls) {
                    if (-not $c.PSObject.Properties['OffLedColor']) {
                        $c | Add-Member -NotePropertyName 'OffLedColor' -NotePropertyValue 'Auto' -Force
                    }
                    $map[[string]$c.ControlId] = $c
                }
                $added = $false
                foreach ($def in (New-DefaultApcProfile)) {
                    if (-not $map.ContainsKey($def.ControlId)) {
                        $map[$def.ControlId] = $def
                        $added = $true
                    }
                }
                if ($added) { $null = Save-ApcProfile -ProfileMap $map }
                return $map
            }
        } catch { }
    }
    $map = @{}
    foreach ($def in (New-DefaultApcProfile)) {
        $map[$def.ControlId] = $def
    }
    $null = Save-ApcProfile -ProfileMap $map
    return $map
}

function Save-ApcProfile {
    param([Parameter(Mandatory)][hashtable]$ProfileMap)
    New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null
    $ordered = @($ProfileMap.Values | Sort-Object ControlKind, Code)
    $payload = [ordered]@{
        UpdatedAt = [datetime]::Now.ToString('o')
        Device    = 'Akai APC Key 25'
        Controls  = $ordered
    }
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:ConfigPath -Encoding utf8
    return $script:ConfigPath
}

Export-ModuleMember -Function @(
    'Clear-AudioEndpointCache',
    'Get-AudioEndpointsSnapshot',
    'Get-PairedBluetoothDevices',
    'Resolve-AudioEndpoint',
    'Convert-MidiCcToScalar',
    'Get-CurrentMappingVolumePct',
    'Set-AudioVolumeByMapping',
    'Invoke-ApcAction',
    'Convert-ColorNameToApcVelocity',
    'Get-PadLedVelocity',
    'Sync-ApcHardwareLeds',
    'New-DefaultApcProfile',
    'Load-ApcProfile',
    'Save-ApcProfile',
    'Parse-HotkeyChord'
)
