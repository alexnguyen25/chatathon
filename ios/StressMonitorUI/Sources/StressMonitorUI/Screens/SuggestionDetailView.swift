import SwiftUI
import StressCore

public struct SuggestionDetailView: View {

    @Bindable var model: DayFlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: DayFlowModel) {
        self._model = Bindable(model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                Text("A little room to reset").displayTitleStyle()

                if let suggestion = model.suggestion {
                    slotCard(suggestion)
                    whySection(suggestion)
                }

                disclaimer
                makeItYours
                actions
            }
            .padding(.horizontal, DS.Space.screenMargin)
            .padding(.bottom, DS.Space.l)
        }
        .background(DS.Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackLabel("Your day") { model.backToDay() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text("Sample data")
                    .font(.subheadline)
                    .foregroundStyle(DS.Palette.inkSecondary)
            }
        }
        .task { model.requestExplanation() }
        .onDisappear { model.cancelExplanation() }
    }

    // MARK: - Slot

    private func slotCard(_ suggestion: BreakSuggestion) -> some View {
        HStack(alignment: .center, spacing: DS.Space.l) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(DS.Palette.green)
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("Suggested break")
                    .font(.subheadline)
                    .foregroundStyle(DS.Palette.inkSecondary)
                Text(suggestion.timeRangeLabel)
                    .font(.system(.title, weight: .bold).monospacedDigit())
                    .tracking(-0.6)
                    .foregroundStyle(DS.Palette.ink)
                Text("\(suggestion.durationMinutes) minutes · Before \(suggestion.gap.nextEvent?.title.lowercased() ?? "your next event")")
                    .font(.subheadline)
                    .foregroundStyle(DS.Palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.l)
        .sageCard()
    }

    // MARK: - Why

    private func whySection(_ suggestion: BreakSuggestion) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            Text("Why this time?").sectionHeadingStyle()

            reasonRow(
                icon: "calendar",
                tint: DS.Palette.ink,
                title: "A clear gap",
                body: "\(suggestion.gap.previousEvent?.title ?? "The previous event") ends at \(clockLabel(forMinuteOfDay: suggestion.gap.start)).\n\(suggestion.gap.nextEvent?.title ?? "The next event") starts at \(clockLabel(forMinuteOfDay: suggestion.gap.end))."
            )

            Divider().overlay(DS.Palette.hairline)

            reasonRow(
                icon: "heart",
                tint: DS.Palette.signal,
                title: "A change in the readings",
                body: "\(suggestion.comparison.recentLabel) BPM during the last hour,\ncompared with \(suggestion.comparison.earlierLabel) earlier."
            )

            Divider().overlay(DS.Palette.hairline)

            explanationRow
        }
    }

    private func reasonRow(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: DS.Space.l) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).rowTitleStyle()
                Text(body).rowBodyStyle()
            }
            Spacer(minLength: 0)
        }
    }

    /// The generated sentence. Kept inside "Why this time?" because that is
    /// what it is — another reason, not a separate feature.
    @ViewBuilder
    private var explanationRow: some View {
        HStack(alignment: .top, spacing: DS.Space.l) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(DS.Palette.ink)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: DS.Space.s) {
                HStack(spacing: DS.Space.s) {
                    Text("In your words").rowTitleStyle()
                    if model.explanation.isLoading {
                        Button("Cancel") { model.cancelExplanation() }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DS.Palette.greenInk)
                    }
                }
                switch model.explanation {
                case .idle:
                    Button("Explain this slot") { model.requestExplanation() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DS.Palette.greenInk)
                case .loading:
                    SkeletonLines(reduceMotion: reduceMotion)
                case let .ready(text):
                    Text(text).rowBodyStyle()
                case let .failed(message):
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(DS.Palette.inkTertiary)
                        Button("Try again") { model.requestExplanation() }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DS.Palette.greenInk)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .animation(DS.transition(reduceMotion: reduceMotion), value: model.explanation)
    }

    // MARK: - Tail

    private var disclaimer: some View {
        Text("Heart rate varies with movement and other factors.\nThis is a suggested pause, not a stress diagnosis.")
            .rowBodyStyle()
    }

    private var makeItYours: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("Make it yours").sectionHeadingStyle()
            Text("Step away, stretch, or sit quietly.").rowBodyStyle()
        }
    }

    private var actions: some View {
        VStack(spacing: DS.Space.l) {
            PrimaryButton("Review calendar event") { model.openAddBreak() }
            HStack {
                TextAction("Adjust time") { model.openAddBreak() }
                Spacer()
                TextAction("Dismiss") { model.dismissSuggestion() }
            }
            .padding(.horizontal, DS.Space.xl)
        }
    }
}

/// Placeholder lines rather than a spinner: a spinner says "blocked", this
/// says "text is coming, and it will land here" — and it is trivially
/// interruptible, which a modal spinner is not.
struct SkeletonLines: View {
    let reduceMotion: Bool
    private let widths: [CGFloat] = [1.0, 0.86, 0.5]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(widths.enumerated()), id: \.offset) { index, fraction in
                GeometryReader { geometry in
                    Capsule()
                        .fill(DS.Palette.inkTertiary.opacity(0.22))
                        .frame(width: geometry.size.width * fraction, height: 9)
                        .modifier(Breathing(reduceMotion: reduceMotion, delayIndex: index))
                }
                .frame(height: 9)
            }
        }
        .accessibilityLabel("Writing an explanation")
    }
}

struct Breathing: ViewModifier {
    let reduceMotion: Bool
    let delayIndex: Int

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(0.7)
        } else {
            content.phaseAnimator([0.45, 1.0]) { view, phase in
                view.opacity(phase)
            } animation: { _ in
                .easeInOut(duration: 0.9).delay(Double(delayIndex) * 0.12)
            }
        }
    }
}

/// `< Your day` — the mockups use a word, not a bare chevron.
struct BackLabel: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "chevron.left")
                    .font(.system(.body, weight: .semibold))
                Text(title).font(.system(.title3, weight: .regular))
            }
            .foregroundStyle(DS.Palette.greenInk)
        }
        .buttonStyle(PressScaleStyle())
    }
}

#Preview {
    NavigationStack { SuggestionDetailView(model: DayFlowModel()) }
}
