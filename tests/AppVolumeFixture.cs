namespace GoodCube.ApcDeck.Tests {
    using System;
    using System.Collections.Generic;
    using System.Collections.Concurrent;
    using System.Diagnostics;
    using System.Linq;
    using System.Threading;
    public sealed class FakeAppState {
        public string Id, Name="chrome";
        public volatile float Volume;
        public volatile bool Muted, FailWrites, Alive=true;
        public int Writes, LastWriter;
    }
    sealed class FakeAppSession : IAppSession {
        readonly FakeAppState state;
        public FakeAppSession(FakeAppState value) { state=value; }
        public string Id { get { return state.Id; } }
        public string Name { get { return state.Name; } }
        public string Display { get { return ""; } }
        public bool Alive { get { return state.Alive; } }
        public float Volume { get { return state.Volume; } set {
            if(state.FailWrites) throw new InvalidOperationException("Fixture write failure");
            state.Volume=value; state.LastWriter=Thread.CurrentThread.ManagedThreadId; Interlocked.Increment(ref state.Writes);
        } }
        public bool Muted { get { return state.Muted; } set { state.Muted=value; } }
        public void Dispose() { }
    }
    sealed class FakeAppSource : IAppSessionSource {
        public ConcurrentDictionary<string,FakeAppState> Rows=new ConcurrentDictionary<string,FakeAppState>();
        public int ScanThread, ScanCount, Delay;
        public bool Fail;
        public IEnumerable<IAppSession> Scan() {
            ScanThread=Thread.CurrentThread.ManagedThreadId; Interlocked.Increment(ref ScanCount);
            if(Fail) throw new InvalidOperationException("Fixture discovery failure");
            foreach(var row in Rows.Values) { if(Delay>0) Thread.Sleep(Delay); yield return new FakeAppSession(row); }
        }
        public void Dispose() { }
    }
    public static class AppVolumeFixture {
        static void Check(bool value,string message) { if(!value) throw new Exception(message); }
        static void Wait(Func<bool> condition,string reason) {
            var w=Stopwatch.StartNew(); while(!condition() && w.ElapsedMilliseconds<4000) Thread.Sleep(2);
            Check(condition(),"Timed out: "+reason);
        }
        static void Turn(AppVolumeWorker worker,int pct,bool pickup=true) {
            long rev=worker.Revision;
            Check(worker.Queue("Knob_55","chrome",pct,pickup,true,true),"Queue rejected");
            Wait(()=>worker.Revision>rev,"turn readback");
        }
        static void Refresh(AppVolumeWorker worker,FakeAppSource source) {
            int n=source.ScanCount; long rev=worker.Revision;
            worker.RequestRefresh(); Wait(()=>source.ScanCount>n && worker.Revision>rev,"refresh");
        }
        public static string Run() {
            int caller=Thread.CurrentThread.ManagedThreadId;
            var source=new FakeAppSource();
            var a=new FakeAppState { Id="device1|chrome-old-a",Volume=.2f };
            var b=new FakeAppState { Id="device2|chrome-old-b",Volume=.8f };
            var other=new FakeAppState { Id="other",Name="chromedriver",Volume=.6f };
            source.Rows[a.Id]=a; source.Rows[b.Id]=b; source.Rows[other.Id]=other;
            using(var worker=new AppVolumeWorker(()=>source)) {
                Wait(()=>worker.Read().Ready,"initial discovery");
                Check(source.ScanThread!=caller,"Discovery ran on caller thread");
                Check(worker.Read().Sessions.Length==3,"Session set incomplete");
                Turn(worker,0); Check(a.Writes==0 && b.Writes==0,"Zero bypassed pickup");
                Turn(worker,20); Check(a.Writes==1 && b.Writes==0,"Independent low pickup failed");
                Turn(worker,30); Check(Math.Abs(a.Volume-.3f)<.001 && b.Volume==.8f,"Waiting session jumped");
                a.Volume=.1f; Turn(worker,35); Check(a.Volume==.1f,"External change did not rearm pickup");
                Turn(worker,10); Turn(worker,80);
                Check(a.Volume==.8f && b.Volume==.8f,"Both sessions did not acquire independently");
                Check(other.Writes==0,"Process name matching touched another app");
                Check(a.LastWriter!=caller && a.LastWriter==source.ScanThread,"Session writes left owning thread");
                b.Muted=true; Turn(worker,50);
                Check(b.Muted && b.Volume==.8f && a.Volume==.5f,"Mute change did not rearm only its session");
                Refresh(worker,source); Turn(worker,45);
                Check(a.Volume==.45f,"Our confirmed writes rearmed pickup on refresh");
                source.Rows.TryRemove(a.Id,out a); source.Rows.TryRemove(b.Id,out b);
                var restarted=new FakeAppState { Id="device1|chrome-new",Volume=.3f };
                source.Rows[restarted.Id]=restarted; Refresh(worker,source);
                Turn(worker,90); Check(restarted.Writes==0,"Restart inherited old pickup ownership");
                Turn(worker,30); Check(restarted.Writes==1,"Restart could not acquire pickup");
                restarted.FailWrites=true; Turn(worker,40);
                Check(worker.Read().Sessions.Single(s=>s.Id==restarted.Id).Available==false,"Failed write presented as confirmed");
                restarted.FailWrites=false; Refresh(worker,source); Turn(worker,90);
                Check(restarted.Writes==1,"Write failure did not reset pickup");
                Turn(worker,30); restarted.Alive=false; Turn(worker,40);
                Check(!worker.Read().Sessions.Single(s=>s.Id==restarted.Id).Available,"Expired session remained available");
                source.Rows.TryRemove(restarted.Id,out restarted); Refresh(worker,source);
                Check(!worker.Read().Sessions.Any(s=>s.Name=="chrome"),"Exited app stayed in snapshot");
                source.Fail=true; Refresh(worker,source); Check(worker.Read().Error.Contains("discovery"),"Discovery failure hidden");
                source.Fail=false;
                restarted.Alive=true; restarted.Volume=.5f; source.Rows[restarted.Id]=restarted; Refresh(worker,source);
                Turn(worker,50,false); Turn(worker,0,false);
                Check(restarted.Volume==0 && restarted.Muted,"Explicit direct zero did not mute");
                Turn(worker,100,false); Check(restarted.Volume==1 && !restarted.Muted,"Full-scale did not unmute");
                // Slow discovery yields to pending turns between sessions; queue stays cheap.
                source.Delay=25;
                for(int i=0;i<12;i++) source.Rows["extra"+i]=new FakeAppState {Id="extra"+i,Name="unrelated",Volume=.5f};
                int scans=source.ScanCount; worker.RequestRefresh(); Wait(()=>source.ScanCount>scans,"slow scan start");
                var enqueue=Stopwatch.StartNew(); worker.Queue("Knob_55","chrome",75,false,true,true); enqueue.Stop();
                Wait(()=>Math.Abs(restarted.Volume-.75f)<.001,"turn during discovery");
                Check(enqueue.Elapsed.TotalMilliseconds<20,"Queue blocked on discovery");
                Check(worker.Read().LastCommandMs<150,"Turn waited for whole slow discovery");
                return "APP_VOLUME_TESTS_OK: independent multi-endpoint sessions, exact process match, external volume/mute, own-write confirmation, restart identity, expired/disappeared sessions, discovery/write failure, zero/full-scale, MTA ownership, queue during discovery. QueueMs="+enqueue.Elapsed.TotalMilliseconds.ToString("F3")+" CommandMs="+worker.Read().LastCommandMs.ToString("F2");
            }
        }
    }
}
