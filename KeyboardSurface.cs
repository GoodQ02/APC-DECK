namespace GoodCube.ApcDeck {
    using System;
    using System.Drawing;
    using System.Windows.Forms;
    internal static class DeckFocus {
        internal static bool IsNavigation(Keys keys) {
            if ((keys & (Keys.Control | Keys.Alt)) != 0) return false;
            switch (keys & Keys.KeyCode) {
                case Keys.Left: case Keys.Right: case Keys.Up: case Keys.Down:
                case Keys.Home: case Keys.End: case Keys.Enter: case Keys.Space: case Keys.Tab: return true;
                default: return false;
            }
        }
        internal static void Draw(Graphics g, Rectangle bounds) {
            bounds.Inflate(-5, -5);
            if (bounds.Width < 4 || bounds.Height < 4) return;
            using (var outer = new Pen(Color.Black, 4)) g.DrawRectangle(outer, bounds);
            using (var inner = new Pen(Color.White, 2)) g.DrawRectangle(inner, bounds);
        }
    }

    public partial class BufferedButton {
        public bool MappingSelected { get; set; }
        public string MappingValue { get; set; }
        protected override bool IsInputKey(Keys keys) { return DeckFocus.IsNavigation(keys) || base.IsInputKey(keys); }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);
            if (Focused) DeckFocus.Draw(e.Graphics, ClientRectangle);
        }
        protected override AccessibleObject CreateAccessibilityInstance() { return new MappingAccessibleObject(this); }
        private class MappingAccessibleObject : ControlAccessibleObject {
            private readonly BufferedButton button;
            public MappingAccessibleObject(BufferedButton owner) : base(owner) { button = owner; }
            public override AccessibleRole Role { get { return AccessibleRole.PushButton; } }
            public override string DefaultAction { get { return "Select mapping"; } }
            public override string Value { get { return button.MappingValue ?? ""; } }
            public override AccessibleStates State { get { return base.State | AccessibleStates.Selectable | (button.MappingSelected ? AccessibleStates.Selected : 0); } }
            public override void DoDefaultAction() {
                if (button.InvokeRequired) { button.BeginInvoke(new Action(DoDefaultAction)); return; }
                button.Focus(); button.PerformClick();
            }
        }
    }

    public partial class SurfaceTile {
        private bool mappingSelected;
        public bool MappingSelected {
            get { return mappingSelected; }
            set {
                if (mappingSelected == value) return;
                mappingSelected = value;
                if (IsHandleCreated) AccessibilityNotifyClients(AccessibleEvents.StateChange, -1);
            }
        }
        private string mappingValue;
        public string MappingValue {
            get { return mappingValue; }
            set {
                if (mappingValue == value) return;
                mappingValue = value;
                if (IsHandleCreated) AccessibilityNotifyClients(AccessibleEvents.ValueChange, -1);
            }
        }
        protected override bool IsInputKey(Keys keys) { return DeckFocus.IsNavigation(keys) || base.IsInputKey(keys); }
        protected virtual Rectangle FocusBounds { get { return ClientRectangle; } }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);
            if (Focused) DeckFocus.Draw(e.Graphics, FocusBounds);
        }
        protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
        protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }
        public void SelectMapping() {
            if (InvokeRequired) { BeginInvoke(new Action(SelectMapping)); return; }
            Focus();
            OnClick(EventArgs.Empty);
        }
        protected override AccessibleObject CreateAccessibilityInstance() { return new TileAccessibleObject(this); }
        private class TileAccessibleObject : ControlAccessibleObject {
            private readonly SurfaceTile tile;
            public TileAccessibleObject(SurfaceTile owner) : base(owner) { tile = owner; }
            public override AccessibleRole Role { get { return AccessibleRole.PushButton; } }
            public override string DefaultAction { get { return "Select mapping"; } }
            public override string Value { get { return tile.MappingValue ?? ""; } }
            public override AccessibleStates State { get { return base.State | AccessibleStates.Selectable | (tile.MappingSelected ? AccessibleStates.Selected : 0); } }
            public override void DoDefaultAction() { tile.SelectMapping(); }
        }
    }

    // One lightweight canvas; 25 virtual accessibility children retain the real key geometry.
    public class KeybedCanvas : SurfaceTile {
        public readonly Rectangle[] KeyBounds = new Rectangle[25];
        public readonly Rectangle[] KeyFocusBounds = new Rectangle[25];
        public readonly string[] KeyNames = new string[25];
        public readonly string[] KeyValues = new string[25];
        public readonly bool[] BlackKeys = new bool[25];
        private int focusNote = 48;
        private int selectedNote = -1;
        public event EventHandler KeySelectionRequested;
        public void UpdateKeyDescription(int note, string name, string value) {
            int index = note - 48;
            if (KeyNames[index] != name) {
                KeyNames[index] = name;
                if (IsHandleCreated) AccessibilityNotifyClients(AccessibleEvents.NameChange, index);
            }
            if (KeyValues[index] != value) {
                KeyValues[index] = value;
                if (IsHandleCreated) AccessibilityNotifyClients(AccessibleEvents.ValueChange, index);
            }
        }
        public int FocusNote {
            get { return focusNote; }
            set {
                int next = Math.Max(48, Math.Min(72, value));
                if (focusNote == next) return;
                focusNote = next;
                Invalidate();
                if (Focused) AccessibilityNotifyClients(AccessibleEvents.Focus, focusNote - 48);
            }
        }
        public int SelectedNote {
            get { return selectedNote; }
            set {
                if (selectedNote == value) return;
                int old = selectedNote;
                selectedNote = value;
                if (IsHandleCreated) {
                    if (old >= 48) AccessibilityNotifyClients(AccessibleEvents.StateChange, old - 48);
                    if (value >= 48) AccessibilityNotifyClients(AccessibleEvents.Selection, value - 48);
                }
            }
        }
        protected override Rectangle FocusBounds { get { return KeyFocusBounds[FocusNote - 48]; } }
        protected override void OnGotFocus(EventArgs e) {
            base.OnGotFocus(e);
            AccessibilityNotifyClients(AccessibleEvents.Focus, FocusNote - 48);
        }
        public void SelectNote(int note) {
            if (InvokeRequired) { BeginInvoke(new Action(() => SelectNote(note))); return; }
            FocusNote = note;
            Focus();
            if (KeySelectionRequested != null) KeySelectionRequested(this, EventArgs.Empty);
        }
        protected override AccessibleObject CreateAccessibilityInstance() { return new PianoAccessibleObject(this); }
        private class PianoAccessibleObject : ControlAccessibleObject {
            private readonly KeybedCanvas piano;
            private readonly PianoKeyAccessibleObject[] keys = new PianoKeyAccessibleObject[25];
            public PianoAccessibleObject(KeybedCanvas owner) : base(owner) {
                piano = owner;
                for (int i = 0; i < 25; i++) keys[i] = new PianoKeyAccessibleObject(owner, this, i);
            }
            public override AccessibleRole Role { get { return AccessibleRole.Grouping; } }
            public override int GetChildCount() { return 25; }
            public override AccessibleObject GetChild(int index) { return index >= 0 && index < 25 ? keys[index] : null; }
            public override AccessibleObject GetFocused() { return piano.Focused ? keys[piano.FocusNote - 48] : null; }
            public override AccessibleObject GetSelected() { return piano.SelectedNote >= 48 ? keys[piano.SelectedNote - 48] : null; }
            public override AccessibleObject HitTest(int x, int y) {
                Point p = piano.PointToClient(new Point(x, y));
                for (int pass = 0; pass < 2; pass++)
                    for (int i = 0; i < 25; i++)
                        if (piano.BlackKeys[i] == (pass == 0) && piano.KeyBounds[i].Contains(p)) return keys[i];
                return base.HitTest(x, y);
            }
        }
        private class PianoKeyAccessibleObject : AccessibleObject {
            private readonly KeybedCanvas piano;
            private readonly AccessibleObject parent;
            private readonly int index;
            public PianoKeyAccessibleObject(KeybedCanvas owner, AccessibleObject parentObject, int keyIndex) { piano = owner; parent = parentObject; index = keyIndex; }
            public override AccessibleObject Parent { get { return parent; } }
            public override string Name { get { return piano.KeyNames[index] ?? ("Piano key " + (index + 48)); } set { } }
            public override string Value { get { return piano.KeyValues[index] ?? "Unassigned"; } }
            public override string Description { get { return "Select to edit. Left and Right move by semitone. Ctrl+T explicitly tests the selected mapping."; } }
            public override string DefaultAction { get { return "Select mapping"; } }
            public override AccessibleRole Role { get { return AccessibleRole.PushButton; } }
            public override Rectangle Bounds { get { return piano.RectangleToScreen(piano.KeyBounds[index]); } }
            public override AccessibleStates State {
                get { return AccessibleStates.Focusable | AccessibleStates.Selectable |
                    (piano.Focused && piano.FocusNote == index + 48 ? AccessibleStates.Focused : 0) |
                    (piano.SelectedNote == index + 48 ? AccessibleStates.Selected : 0) |
                    (!piano.Visible ? AccessibleStates.Invisible : 0); }
            }
            public override void DoDefaultAction() { piano.SelectNote(index + 48); }
            public override void Select(AccessibleSelection flags) { if ((flags & (AccessibleSelection.TakeFocus | AccessibleSelection.TakeSelection)) != 0) DoDefaultAction(); }
            public override AccessibleObject Navigate(AccessibleNavigation direction) {
                if (direction == AccessibleNavigation.Next || direction == AccessibleNavigation.Right) return parent.GetChild(index + 1);
                if (direction == AccessibleNavigation.Previous || direction == AccessibleNavigation.Left) return parent.GetChild(index - 1);
                return null;
            }
        }
    }
}
