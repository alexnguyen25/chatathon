import SwiftUI
import StressCore

public struct BreakAddedView: View {

    @Bindable var model: DayFlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    public init(model: DayFlowModel) {
        self._model = Bindable(model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                confirmation
                eventCard
                middaySection
                Text("Your real calendar has not changed.")
                    .font(.footnote)
                    .foregroundStyle(DS.Palette.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                actions
            }
            .padding(.horizontal, DS.Space.screenMargin)
            .padding(.bottom, DS.Space.l)
        }
        .background(DS.Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
        .task {
            // Settles once on arrival. Success confirmation earns a small
            // moment; it does not earn confetti.
            withAnimation(DS.transition(reduceMotion: reduceMotion)) { hasAppeared = true }
        }
    }

    private var confirmation: some View {
        VStack(spacing: DS.Space.m) {
            RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                .fill(DS.Palette.sage)
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(DS.Palette.green)
                )
                .scaleEffect(hasAppeared || reduceMotion ? 1.0 : 0.88)
                .opacity(hasAppeared || reduceMotion ? 1 : 0)

            Text("Break added")
                .font(.system(.largeTitle, weight: .bold))
                .tracking(-1.0)
                .foregroundStyle(DS.Palette.ink)
            Text("Saved to your example calendar.")
                .subtitleStyle()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Space.s)
    }

    private var eventCard: some View {
        VStack(spacing: 0) {
            row(model.draft.title, weight: .bold)
            divider
            row(model.day.label)
            divider
            row(clockLabel(forMinuteOfDay: model.draft.startMinute)
                + " – " + clockLabel(forMinuteOfDay: model.draft.endMinute))
            divider
            row("\(model.draft.calendarName) · Example calendar")
        }
        .whiteCard()
    }

    private var divider: some View {
        Divider().overlay(DS.Palette.hairline).padding(.horizontal, DS.Space.l)
    }

    private func row(_ text: String, weight: Font.Weight = .regular) -> some View {
        HStack {
            Text(text)
                .font(.system(.body, weight: weight).monospacedDigit())
                .foregroundStyle(DS.Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.m)
    }

    // MARK: - Midday

    /// The three entries around the new break, so the result is visible in
    /// context rather than asserted.
    private var middaySection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("Your midday").sectionHeadingStyle()

            VStack(spacing: 0) {
                ForEach(Array(middayEntries.enumerated()), id: \.offset) { index, entry in
                    timelineRow(entry, isFirst: index == 0, isLast: index == middayEntries.count - 1)
                }
            }
            .padding(.vertical, DS.Space.m)
            .whiteCard()
        }
    }

    private struct MiddayEntry {
        let time: String
        let title: String
        let detail: String
        let isBreak: Bool
    }

    private var middayEntries: [MiddayEntry] {
        guard let gap = model.suggestion?.gap else { return [] }
        var entries: [MiddayEntry] = []
        if let previous = gap.previousEvent {
            entries.append(MiddayEntry(
                time: clockLabel(forMinuteOfDay: previous.start),
                title: previous.title,
                detail: "Ends at \(clockLabel(forMinuteOfDay: previous.end))",
                isBreak: false
            ))
        }
        entries.append(MiddayEntry(
            time: clockLabel(forMinuteOfDay: model.draft.startMinute),
            title: model.draft.title,
            detail: "\(model.draft.durationMinutes) minutes",
            isBreak: true
        ))
        if let next = gap.nextEvent {
            entries.append(MiddayEntry(
                time: clockLabel(forMinuteOfDay: next.start),
                title: next.title,
                detail: "",
                isBreak: false
            ))
        }
        return entries
    }

    private func timelineRow(_ entry: MiddayEntry, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DS.Space.m) {
            Text(entry.time)
                .font(.system(.subheadline, weight: entry.isBreak ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(entry.isBreak ? DS.Palette.greenInk : DS.Palette.inkSecondary)
                .frame(width: 74, alignment: .leading)

            // Connector, drawn per row so the dots line up with the text.
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : DS.Palette.hairline)
                    .frame(width: 2, height: 8)
                Circle()
                    .fill(entry.isBreak ? DS.Palette.green : DS.Palette.hairline)
                    .frame(width: entry.isBreak ? 13 : 11, height: entry.isBreak ? 13 : 11)
                Rectangle()
                    .fill(isLast ? Color.clear : DS.Palette.hairline)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 13)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .font(.system(.body, weight: entry.isBreak ? .semibold : .regular))
                    .foregroundStyle(entry.isBreak ? DS.Palette.greenInk : DS.Palette.ink)
                if !entry.detail.isEmpty {
                    Text(entry.detail)
                        .font(.subheadline)
                        .foregroundStyle(DS.Palette.inkSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.bottom, isLast ? 0 : DS.Space.m)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: DS.Space.m) {
            PrimaryButton("Back to your day") { model.backToDay() }
            TextAction("Undo") { model.undoAdd() }
        }
    }
}

#Preview {
    let model = DayFlowModel()
    model.confirmAdd()
    return NavigationStack { BreakAddedView(model: model) }
}
