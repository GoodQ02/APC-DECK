using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using NAudio.CoreAudioApi;

namespace GoodCube.ApcDeck {
    // All session COM objects are created, read, written and released by one MTA worker.
    public interface IAppSession : IDisposable {
        string Id { get; } string Name { get; } string Display { get; }
        bool Alive { get; } float Volume { get; set; } bool Muted { get; set; }
    }
    public interface IAppSessionSource : IDisposable { IEnumerable<IAppSession> Scan(); }
    sealed class CoreAppSession : IAppSession {
        readonly AudioSessionControl control;
        public string Id { get; private set; } public string Name { get; private set; }
        public string Display { get; private set; }
        public CoreAppSession(string endpoint, AudioSessionControl value, string name) {
            control=value; Name=name; Id=endpoint+"|"+value.GetSessionInstanceIdentifier; Display=value.DisplayName;
        }
        public bool Alive { get { return control.State != NAudio.CoreAudioApi.Interfaces.AudioSessionState.AudioSessionStateExpired; } }
        public float Volume { get { return control.SimpleAudioVolume.Volume; } set { control.SimpleAudioVolume.Volume=value; } }
        public bool Muted { get { return control.SimpleAudioVolume.Mute; } set { control.SimpleAudioVolume.Mute=value; } }
        public void Dispose() { control.Dispose(); }
    }
    sealed class CoreAppSource : IAppSessionSource {
        readonly MMDeviceEnumerator enumerator=new MMDeviceEnumerator();
        public IEnumerable<IAppSession> Scan() {
            foreach (var device in enumerator.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active)) {
                AudioSessionManager manager=null;
                try {
                    manager=device.AudioSessionManager; manager.RefreshSessions();
                    var sessions=manager.Sessions;
                    for(int i=0;i<sessions.Count;i++) {
                        var control=sessions[i]; IAppSession result=null;
                        try {
                            if(control.GetProcessID>0 && control.State!=NAudio.CoreAudioApi.Interfaces.AudioSessionState.AudioSessionStateExpired) {
                                using(var process=Process.GetProcessById((int)control.GetProcessID))
                                    result=new CoreAppSession(device.ID,control,process.ProcessName);
                            }
                        } catch { /* Session/process exited during discovery. */ }
                        if(result==null) control.Dispose(); else yield return result;
                    }
                } finally { if(manager!=null) manager.Dispose(); device.Dispose(); }
            }
        }
        public void Dispose() { enumerator.Dispose(); }
    }
    public sealed class AppSessionView {
        public string Id, Name, Display;
        public int Percent;
        public bool Muted, Available;
        public string[] Acquired;
        public string[] Waiting;
    }
    public sealed class AppVolumeSnapshot {
        public AppSessionView[] Sessions=new AppSessionView[0];
        public string Error="";
        public bool Ready;
        public long Revision;
        public double DiscoveryMs, LastCommandMs;
    }
    public sealed class AppVolumeWorker : IDisposable {
        sealed class Gate { public bool Acquired; public int Previous=-1; public int Epoch; }
        sealed class Entry {
            public IAppSession Session; public int Percent; public bool Muted, Available;
            public Dictionary<string,Gate> Gates=new Dictionary<string,Gate>();
        }
        sealed class Command {
            public string Key, Target; public int Percent, Epoch; public bool Pickup, AutoMute, Physical;
            public long Queued;
        }
        readonly Func<IAppSessionSource> factory;
        readonly Thread thread;
        readonly AutoResetEvent wake=new AutoResetEvent(false);
        readonly ConcurrentDictionary<string,Command> turns=new ConcurrentDictionary<string,Command>();
        readonly ConcurrentQueue<Command> explicitCommands=new ConcurrentQueue<Command>();
        readonly Dictionary<string,Entry> entries=new Dictionary<string,Entry>();
        readonly object snapshotLock=new object();
        AppVolumeSnapshot snapshot=new AppVolumeSnapshot();
        volatile bool stop;
        int refresh=1, epoch, explicitCount, reset;
        long revision;
        bool ready;
        string error="";
        double discoveryMs, commandMs;
        public AppVolumeWorker() : this(()=>new CoreAppSource()) { }
        public AppVolumeWorker(Func<IAppSessionSource> sourceFactory) {
            factory=sourceFactory; thread=new Thread(Run); thread.IsBackground=true;
            thread.Name="APC-DECK app audio"; thread.SetApartmentState(ApartmentState.MTA); thread.Start();
        }
        public void RequestRefresh() { Interlocked.Exchange(ref refresh,1); wake.Set(); }
        public void ResetPickup() { Interlocked.Increment(ref epoch); Interlocked.Exchange(ref reset,1); wake.Set(); }
        public bool IsRunning { get { return thread.IsAlive && !stop; } }
        public long Revision { get { lock(snapshotLock) return snapshot.Revision; } }
        public AppVolumeSnapshot Read() { lock(snapshotLock) return snapshot; }
        public static bool Matches(AppSessionView s,string target) { return Matches(s.Name,s.Display,target); }
        static bool Matches(string name,string display,string target) {
            target=(target??"").Trim(); if(target.Length==0) return false;
            string process=target.EndsWith(".exe",StringComparison.OrdinalIgnoreCase)?target.Substring(0,target.Length-4):target;
            return String.Equals(name,process,StringComparison.OrdinalIgnoreCase) ||
                (!String.IsNullOrEmpty(display) && display.IndexOf(target,StringComparison.OrdinalIgnoreCase)>=0);
        }
        public bool Queue(string key,string target,int percent,bool pickup,bool autoMute,bool physical) {
            if(!IsRunning || String.IsNullOrWhiteSpace(target)) return false;
            var command=new Command { Key=key+"|"+target.ToLowerInvariant(), Target=target,
                Percent=Math.Max(0,Math.Min(100,percent)), Pickup=pickup, AutoMute=autoMute, Physical=physical,
                Epoch=Volatile.Read(ref epoch), Queued=Stopwatch.GetTimestamp() };
            if(physical) turns[command.Key]=command;
            else {
                if(Interlocked.Increment(ref explicitCount)>64) { Interlocked.Decrement(ref explicitCount); return false; }
                explicitCommands.Enqueue(command);
            }
            wake.Set(); return true;
        }
        void Observe(Entry entry) {
            if(!entry.Session.Alive) throw new InvalidOperationException("Session ended");
            int percent=(int)Math.Round(entry.Session.Volume*100); bool muted=entry.Session.Muted;
            if(!entry.Available || entry.Percent!=percent || entry.Muted!=muted) entry.Gates.Clear();
            entry.Percent=percent; entry.Muted=muted; entry.Available=true;
        }
        void Apply(Command command) {
            if(command.Physical && command.Epoch!=Volatile.Read(ref epoch)) return;
            int matched=0;
            foreach(var entry in entries.Values) {
                if(!Matches(entry.Session.Name,entry.Session.Display,command.Target)) continue;
                matched++;
                try {
                    // Cached handle only: no enumeration/process/name discovery on a turn.
                    Observe(entry);
                    Gate gate;
                    if(!entry.Gates.TryGetValue(command.Key,out gate) || gate.Epoch!=command.Epoch) {
                        gate=new Gate { Epoch=command.Epoch }; entry.Gates[command.Key]=gate;
                    }
                    bool crossed=gate.Previous>=0 && ((gate.Previous<=entry.Percent && command.Percent>=entry.Percent) ||
                        (gate.Previous>=entry.Percent && command.Percent<=entry.Percent));
                    gate.Previous=command.Percent;
                    if(!command.Pickup || Math.Abs(command.Percent-entry.Percent)<=1 || crossed) gate.Acquired=true;
                    if(!gate.Acquired) continue;
                    entry.Session.Volume=command.Percent/100f;
                    if(command.AutoMute) entry.Session.Muted=command.Percent==0;
                    // Read the write back; never present a failed request as a confirmed value.
                    entry.Percent=(int)Math.Round(entry.Session.Volume*100); entry.Muted=entry.Session.Muted;
                    if(!command.Pickup) entry.Gates.Clear();
                } catch(Exception ex) { entry.Available=false; entry.Gates.Clear(); error="App volume failed: "+ex.Message; }
            }
            if(matched==0) error="No app audio session; start audio and refresh before retrying.";
            commandMs=(Stopwatch.GetTimestamp()-command.Queued)*1000.0/Stopwatch.Frequency;
            Publish();
        }
        void DrainCommands() {
            Command command;
            while(explicitCommands.TryDequeue(out command)) { Interlocked.Decrement(ref explicitCount); Apply(command); }
            foreach(var key in turns.Keys) if(turns.TryRemove(key,out command)) Apply(command);
        }
        void Publish() {
            var value=new AppVolumeSnapshot { Ready=ready, Error=error, Revision=++revision,
                DiscoveryMs=discoveryMs, LastCommandMs=commandMs,
                Sessions=entries.Values.Select(e=>new AppSessionView { Id=e.Session.Id, Name=e.Session.Name,
                    Display=e.Session.Display, Percent=e.Percent, Muted=e.Muted, Available=e.Available,
                    Acquired=e.Gates.Where(g=>g.Value.Acquired && g.Value.Epoch==Volatile.Read(ref epoch)).Select(g=>g.Key).ToArray(),
                    Waiting=e.Gates.Where(g=>!g.Value.Acquired || g.Value.Epoch!=Volatile.Read(ref epoch)).Select(g=>g.Key).ToArray() }).ToArray() };
            lock(snapshotLock) snapshot=value;
        }
        void Refresh(IAppSessionSource source) {
            var watch=Stopwatch.StartNew(); var seen=new HashSet<string>(); error="";
            try {
                foreach(var session in source.Scan()) {
                    if(stop) { session.Dispose(); break; }
                    Entry entry;
                    if(entries.TryGetValue(session.Id,out entry)) { entry.Session.Dispose(); entry.Session=session; }
                    else { entry=new Entry { Session=session }; entries[session.Id]=entry; }
                    seen.Add(session.Id);
                    try { Observe(entry); } catch { entry.Available=false; entry.Gates.Clear(); }
                    // Yield between discovered sessions so turns do not wait for the whole scan.
                    DrainCommands();
                }
                foreach(var id in entries.Keys.Where(id=>!seen.Contains(id)).ToArray()) { entries[id].Session.Dispose(); entries.Remove(id); }
                ready=true;
            } catch(Exception ex) {
                error="App session discovery failed: "+ex.Message;
                foreach(var entry in entries.Values) { entry.Available=false; entry.Gates.Clear(); }
            }
            discoveryMs=watch.Elapsed.TotalMilliseconds; Publish();
        }
        void Run() {
            try {
                using(var source=factory()) {
                    while(!stop) {
                        if(Interlocked.Exchange(ref reset,0)!=0) Publish();
                        DrainCommands();
                        if(Interlocked.Exchange(ref refresh,0)!=0) Refresh(source);
                        if(!stop) wake.WaitOne();
                    }
                }
            } catch(Exception ex) { error="App audio worker failed: "+ex.Message; ready=false; Publish(); }
            finally { foreach(var entry in entries.Values) { try { entry.Session.Dispose(); } catch { } } }
        }
        public void Dispose() { stop=true; wake.Set(); if(thread.Join(1000)) wake.Dispose(); }
    }
}
