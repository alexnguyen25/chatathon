import SwiftUI
import StressCore

/// Tokens taken from the PulsePlan mockups.
///
/// The system is warm paper + forest green, with terracotta held back for one
/// job only: the biometric signal. Heart icon, heart-rate line, and the marker
/// on the calendar entry that the readings changed during — nothing else is
/// ever terracotta. That restraint is what keeps a warm palette from reading
/// as generic; the moment terracotta starts appearing on buttons or headings
/// it becomes the cream-and-clay look this is trying not to be.
public enum DS {

    /// Light values are `docs/design/pulseplan-core/tokens.json` verbatim —
    /// that file is the source of truth and these must not drift from it.
    /// Dark values are derived here, because tokens.json is light-only.
    public enum Palette {
        /// tokens: color.canvas
        public static let canvas   = Color(light: 0xF6F5F0, dark: 0x14150F)
        /// tokens: color.surface — white cards sit *on* the paper.
        public static let surface  = Color(light: 0xFFFFFF, dark: 0x1D1F1B)
        /// tokens: color.sage — informational blocks, calendar entries, the
        /// sample-data pill. Never interactive on its own.
        public static let sage     = Color(light: 0xE5ECE3, dark: 0x232D25)
        /// Derived: sage one step down, for a saved/selected entry.
        public static let sageDeep = Color(light: 0xD4DED1, dark: 0x2C382E)
        /// tokens: color.divider
        public static let hairline = Color(light: 0xD9DED7, dark: 0x2D302A)

        /// tokens: color.text
        public static let ink          = Color(light: 0x202C28, dark: 0xF1F2EC)
        /// tokens: color.secondary
        public static let inkSecondary = Color(light: 0x58635C, dark: 0xA7ADA2)
        /// Derived: between secondary and divider, for the quietest labels.
        public static let inkTertiary  = Color(light: 0x8C958E, dark: 0x7B8178)

        /// tokens: color.action — primary actions, active tab, affirmative
        /// marks.
        public static let green     = Color(light: 0x245C46, dark: 0x4E9C7B)
        public static let greenInk  = Color(light: 0x245C46, dark: 0x6FBB97)

        /// tokens: color.heartRate. Per tokens.semantics: "Terracotta with BPM
        /// units, never a stress severity indicator." It appears on the heart
        /// glyph, the HR line, and the marker on the entry the readings
        /// changed during — nowhere else.
        public static let signal    = Color(light: 0xA55442, dark: 0xD98168)
    }

    /// Calendar entries are all one colour in the mockups — the calendar is
    /// context, not a categorical chart. Differentiation comes from the title.
    public static func calendarFill(flagged: Bool) -> Color {
        flagged ? Palette.sageDeep : Palette.sage
    }

    /// tokens: layout
    public enum Radius {
        /// tokens: layout.surfaceRadius
        public static let card: CGFloat = 16
        /// Derived: inline blocks inside a card sit one step tighter.
        public static let block: CGFloat = 10
        /// tokens: layout.buttonRadius
        public static let button: CGFloat = 14
        public static let tile: CGFloat = 18
    }

    /// tokens: spacing
    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32

        /// tokens: layout.horizontalInset
        public static let screenMargin: CGFloat = 24
        /// tokens: layout.primaryButtonHeight
        public static let primaryButtonHeight: CGFloat = 54
        /// tokens: layout.minimumTouchTarget
        public static let minimumTouchTarget: CGFloat = 44
    }

    /// Critically damped by default; bounce only where a gesture's momentum
    /// preceded the motion.
    public static let settle = Animation.spring(duration: 0.4, bounce: 0)
    public static let momentum = Animation.spring(duration: 0.35, bounce: 0.2)

    public static func transition(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.18) : settle
    }
}

// MARK: - Type

// tokens.typography maps almost exactly onto SwiftUI's semantic text styles,
// so those are used rather than fixed point sizes. Fixed sizes would match the
// token file to the point but would stop scaling with Dynamic Type, and
// tokens.layout explicitly asks for system behaviour elsewhere.
//
//   token          size/weight   style used            delta
//   title          32 / 700      .largeTitle .bold     34pt, +2
//   section        22 / 600      .title2 .bold         exact
//   body           17 / 400      .body                 exact
//   caption        15 / 400      .subheadline          exact
//   metric         88 / 600      .system(size: 88)     exact, see readoutStyle

public extension View {
    /// Display titles in the mockups are heavy and tightly tracked. Tracking
    /// goes negative as size grows; it goes positive on the small uppercase
    /// labels further down.
    func displayTitleStyle() -> some View {
        self.font(.system(.largeTitle, design: .default, weight: .bold))
            .tracking(-1.0)
            .foregroundStyle(DS.Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    func subtitleStyle() -> some View {
        self.font(.system(.title3, design: .default, weight: .regular))
            .foregroundStyle(DS.Palette.inkSecondary)
    }

    func sectionHeadingStyle() -> some View {
        self.font(.system(.title2, design: .default, weight: .bold))
            .tracking(-0.4)
            .foregroundStyle(DS.Palette.ink)
    }

    func rowTitleStyle() -> some View {
        self.font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(DS.Palette.ink)
    }

    func rowBodyStyle() -> some View {
        self.font(.subheadline)
            .foregroundStyle(DS.Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    func captionStyle() -> some View {
        self.font(.footnote)
            .foregroundStyle(DS.Palette.inkSecondary)
    }

    /// Any number that can change must be monospaced, or the layout jitters.
    func readoutStyle(size: CGFloat, weight: Font.Weight = .bold) -> some View {
        self.font(.system(size: size, weight: weight).monospacedDigit())
            .foregroundStyle(DS.Palette.ink)
    }
}

// MARK: - Surfaces

public struct WhiteCard: ViewModifier {
    let radius: CGFloat
    public func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DS.Palette.surface)
        )
    }
}

public struct SageCard: ViewModifier {
    let radius: CGFloat
    public func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DS.Palette.sage)
        )
    }
}

public extension View {
    func whiteCard(radius: CGFloat = DS.Radius.card) -> some View {
        modifier(WhiteCard(radius: radius))
    }
    func sageCard(radius: CGFloat = DS.Radius.card) -> some View {
        modifier(SageCard(radius: radius))
    }
}

// MARK: - Shared controls

/// Full-width forest-green action. One per screen, at the bottom.
public struct PrimaryButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                // tokens: layout.primaryButtonHeight. `minHeight` rather than
                // a fixed height so Dynamic Type can grow it — a hard 54 would
                // clip the label at the larger accessibility sizes.
                .frame(minHeight: DS.Space.primaryButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                        .fill(DS.Palette.green)
                )
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// Quiet green text action — Cancel, Undo, Dismiss, Adjust time.
public struct TextAction: View {
    let title: String
    let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(DS.Palette.greenInk)
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// Feedback lands on touch-down, not on release.
public struct PressScaleStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(duration: 0.22, bounce: 0), value: configuration.isPressed)
    }
}

public struct SampleDataPill: View {
    public init() {}
    public var body: some View {
        Text("Sample data")
            .font(.system(.subheadline, weight: .regular))
            .foregroundStyle(DS.Palette.inkSecondary)
            .padding(.horizontal, DS.Space.l)
            .padding(.vertical, DS.Space.s)
            .background(Capsule().fill(DS.Palette.sage))
    }
}

/// The wordmark: a small ECG trace plus the name.
public struct Wordmark: View {
    public init() {}

    public var body: some View {
        HStack(spacing: DS.Space.s) {
            PulseTrace()
                .stroke(DS.Palette.green, style: StrokeStyle(lineWidth: 2,
                                                             lineCap: .round,
                                                             lineJoin: .round))
                .frame(width: 26, height: 18)
            Text("PulsePlan")
                .font(.system(.title3, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(DS.Palette.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PulsePlan")
    }
}

/// Drawn rather than an SF Symbol so the mark is the product's own.
public struct PulseTrace: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let midY = rect.midY
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.width * 0.24, y: midY))
        path.addLine(to: CGPoint(x: rect.width * 0.36, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.50, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.62, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        return path
    }
}

// MARK: - Colour resolution

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
