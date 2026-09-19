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

    public enum Palette {
        /// Warm paper, not white and not grey.
        public static let canvas   = Color(light: 0xF3F2EE, dark: 0x14150F)
        /// White cards sit *on* the paper — forms, lists, summaries.
        public static let surface  = Color(light: 0xFFFFFF, dark: 0x1D1F1B)
        /// Pale sage. Informational blocks, calendar entries, the sample-data
        /// pill. Never interactive on its own.
        public static let sage     = Color(light: 0xE3EAE1, dark: 0x232D25)
        public static let sageDeep = Color(light: 0xD3DED1, dark: 0x2C382E)
        public static let hairline = Color(light: 0xE4E3DD, dark: 0x2D302A)

        public static let ink          = Color(light: 0x14160F, dark: 0xF1F2EC)
        public static let inkSecondary = Color(light: 0x6B6F66, dark: 0xA7ADA2)
        public static let inkTertiary  = Color(light: 0x92988C, dark: 0x7B8178)

        /// Forest green. Primary actions, active tab, affirmative marks.
        public static let green     = Color(light: 0x2C5F4A, dark: 0x4E9C7B)
        public static let greenInk  = Color(light: 0x2C5F4A, dark: 0x6FBB97)

        /// Terracotta. The biometric signal, and only that.
        public static let signal    = Color(light: 0xC0604A, dark: 0xD98168)
    }

    /// Calendar entries are all one colour in the mockups — the calendar is
    /// context, not a categorical chart. Differentiation comes from the title.
    public static func calendarFill(flagged: Bool) -> Color {
        flagged ? Palette.sageDeep : Palette.sage
    }

    public enum Radius {
        public static let card: CGFloat = 14
        public static let block: CGFloat = 10
        public static let button: CGFloat = 12
        public static let tile: CGFloat = 18
    }

    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 36

        public static let screenMargin: CGFloat = 20
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
                .padding(.vertical, DS.Space.l)
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
