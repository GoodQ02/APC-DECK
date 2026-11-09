namespace GoodCube.ApcDeck {
    using System;
    using System.Drawing;
    using System.Runtime.InteropServices;
    using System.Windows.Forms;

    public static class DeckMotion {
        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool SystemParametersInfo(uint action, uint parameter, out int value, uint flags);
        // Windows Accessibility > Visual effects > Animation effects. Fail quiet.
        public static bool AnimationsEnabled {
            get { int enabled; return SystemParametersInfo(0x1042, 0, out enabled, 0) && enabled != 0; }
        }
    }

    public partial class SurfaceTile {
        private Rectangle hoverBounds;
        private Rectangle pressedBounds;
        public Rectangle HoverFeedbackBounds { get { return hoverBounds; } }
        public Rectangle PressedFeedbackBounds { get { return pressedBounds; } }
        protected virtual Rectangle HitFeedbackBounds(Point point) { return ClientRectangle.Contains(point) ? ClientRectangle : Rectangle.Empty; }
        private void ChangeHover(Rectangle next) {
            if (hoverBounds == next) return;
            Rectangle old = hoverBounds; hoverBounds = next;
            if (!old.IsEmpty) Invalidate(old);
            if (!next.IsEmpty) Invalidate(next);
        }
        public void ClearPressedFeedback() {
            Rectangle old = pressedBounds; pressedBounds = Rectangle.Empty;
            if (!old.IsEmpty) Invalidate(old);
        }
        protected override void OnMouseMove(MouseEventArgs e) {
            ChangeHover(Enabled ? HitFeedbackBounds(e.Location) : Rectangle.Empty);
            base.OnMouseMove(e);
        }
        protected override void OnMouseLeave(EventArgs e) {
            ChangeHover(Rectangle.Empty); ClearPressedFeedback(); base.OnMouseLeave(e);
        }
        protected override void OnMouseDown(MouseEventArgs e) {
            if (Enabled && e.Button == MouseButtons.Left) {
                pressedBounds = HitFeedbackBounds(e.Location);
                if (!pressedBounds.IsEmpty) Invalidate(pressedBounds);
            }
            base.OnMouseDown(e);
        }
        protected override void OnMouseUp(MouseEventArgs e) { ClearPressedFeedback(); base.OnMouseUp(e); }
        protected override void OnMouseCaptureChanged(EventArgs e) { if (!Capture) ClearPressedFeedback(); base.OnMouseCaptureChanged(e); }
        protected override void OnEnabledChanged(EventArgs e) {
            if (!Enabled) { ChangeHover(Rectangle.Empty); ClearPressedFeedback(); }
            base.OnEnabledChanged(e);
        }
        protected override void OnKeyDown(KeyEventArgs e) {
            if (Enabled && e.Modifiers == Keys.None && (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space)) {
                pressedBounds = FocusBounds; Invalidate(pressedBounds);
            }
            base.OnKeyDown(e);
        }
        protected override void OnKeyUp(KeyEventArgs e) {
            if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) ClearPressedFeedback();
            base.OnKeyUp(e);
        }
        protected override void WndProc(ref Message message) {
            // Navigation suppresses managed KeyUp; still clear on the native release.
            if (message.Msg == 0x0101 || message.Msg == 0x0105) ClearPressedFeedback();
            base.WndProc(ref message);
        }
        private void DrawInteraction(Graphics g) {
            if (!Enabled) return;
            Rectangle bounds = !pressedBounds.IsEmpty ? pressedBounds : hoverBounds;
            if (bounds.IsEmpty) return;
            bounds.Inflate(-2, -2);
            if (bounds.Width < 4 || bounds.Height < 4) return;
            // A neutral two-tone outline remains legible over custom LED/key colors.
            Color ink = DeckTheme.HighContrast ? SystemColors.WindowText : Color.FromArgb(226,232,240);
            using (var edge = new Pen(DeckTheme.HighContrast ? SystemColors.Window : Color.Black, 3)) g.DrawRectangle(edge, bounds);
            using (var edge = new Pen(ink, 1)) g.DrawRectangle(edge, bounds);
            if (!pressedBounds.IsEmpty) {
                using (var edge = new Pen(ink, 3)) g.DrawLine(edge, bounds.Left + 2, bounds.Bottom - 1, bounds.Right - 2, bounds.Bottom - 1);
            }
        }
    }

    public partial class KeybedCanvas {
        protected override Rectangle HitFeedbackBounds(Point point) {
            for (int pass = 0; pass < 2; pass++)
                for (int i = 0; i < 25; i++)
                    if (BlackKeys[i] == (pass == 0) && KeyBounds[i].Contains(point)) return KeyFocusBounds[i];
            return Rectangle.Empty;
        }
    }

    public class AppliedFeedbackLabel : Label {
        private readonly Timer feedbackTimer = new Timer();
        private long started;
        private int alpha;
        public bool FeedbackActive { get; private set; }
        public bool FeedbackTimerRunning { get { return feedbackTimer.Enabled; } }
        // Injectable preference reader supports isolated tests without changing Windows.
        public Func<bool> AnimationPreference = () => DeckMotion.AnimationsEnabled;
        public AppliedFeedbackLabel() {
            DoubleBuffered = true;
            feedbackTimer.Interval = 30;
            feedbackTimer.Tick += (sender, args) => AdvanceFeedback();
        }
        public void ShowFeedback() {
            feedbackTimer.Stop(); FeedbackActive = true; alpha = 255;
            started = Environment.TickCount64; Invalidate();
            if (CanAnimate()) feedbackTimer.Start();
        }
        public void ClearFeedback() {
            feedbackTimer.Stop();
            if (!FeedbackActive) return;
            FeedbackActive = false; alpha = 0; Invalidate();
        }
        private void AdvanceFeedback() {
            if (!CanAnimate()) {
                feedbackTimer.Stop(); alpha = 255; Invalidate(); return;
            }
            long elapsed = Environment.TickCount64 - started;
            if (elapsed < 1200) return;
            if (elapsed >= 1360) { ClearFeedback(); return; }
            int next = (int)(255 * (1360 - elapsed) / 160);
            if (alpha != next) { alpha = next; Invalidate(); }
        }
        private bool CanAnimate() {
            Form owner = FindForm();
            return Visible && owner != null && owner.WindowState != FormWindowState.Minimized && !DeckTheme.HighContrast && AnimationPreference();
        }
        protected override void OnVisibleChanged(EventArgs e) {
            if (!Visible) { feedbackTimer.Stop(); alpha = 255; }
            base.OnVisibleChanged(e);
        }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);
            if (!FeedbackActive) return;
            Color ink = DeckTheme.HighContrast ? SystemColors.WindowText : Color.FromArgb(56,189,248);
            using (var edge = new Pen(Color.FromArgb(alpha, ink), 2)) e.Graphics.DrawLine(edge, 2, Height - 2, Width - 3, Height - 2);
        }
        protected override void Dispose(bool disposing) { if (disposing) feedbackTimer.Dispose(); base.Dispose(disposing); }
    }
}
