import SwiftUI
import StressCore

public struct AddBreakView: View {

    @Bindable var model: DayFlowModel
    @State private var editingField: Field?

    enum Field: Hashable { case starts, ends }

    public init(model: DayFlowModel) {
        self._model = Bindable(model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text("Add a break").displayTitleStyle()
                    Text("Review before adding").subtitleStyle()
                    Text("Sample data")
                        .font(.subheadline)
                        .foregroundStyle(DS.Palette.inkTertiary)
                }

                formCard
                fitRow

                if let suggestion = model.suggestion {
                    gapPreview(suggestion)
                }

                Text("Showcase only. This adds to the example calendar.")
                    .font(.footnote)
                    .foregroundStyle(DS.Palette.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: DS.Space.m) {
                    PrimaryButton("Add to example calendar") { model.confirmAdd() }
                    TextAction("Cancel") { model.backToDay() }
                }
            }
            .padding(.horizontal, DS.Space.screenMargin)
            .padding(.bottom, DS.Space.l)
        }
        .background(DS.Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // Custom BackLabel in the toolbar; without this the system chevron
        // renders too and the screen shows two back buttons.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackLabel("Suggestion") { model.path.removeLast() }
            }
        }
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(spacing: 0) {
            formRow("Title", value: model.draft.title)
            divider
            formRow("Date", value: model.day.label + ", 2026")
            divider
            timeRow("Starts", minute: model.draft.startMinute, field: .starts)
            divider
            timeRow("Ends", minute: model.draft.endMinute, field: .ends)
            divider
            formRow("Calendar", value: model.draft.calendarName, dotted: true, chevron: true)
            divider
            formRow("Alert", value: model.draft.alert, chevron: true)
        }
        .whiteCard()
    }

    private var divider: some View {
        Divider().overlay(DS.Palette.hairline).padding(.leading, DS.Space.l)
    }

    private func formRow(
        _ label: String,
        value: String,
        dotted: Bool = false,
        chevron: Bool = false
    ) -> some View {
        HStack(spacing: DS.Space.s) {
            Text(label)
                .font(.body)
                .foregroundStyle(DS.Palette.ink)
            Spacer()
            if dotted {
                Circle().fill(DS.Palette.green).frame(width: 9, height: 9)
            }
            Text(value)
                .font(.body)
                .foregroundStyle(DS.Palette.ink)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.Palette.inkTertiary)
            }
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.l)
    }

    /// Starts/Ends are real controls. A chevron that does nothing is a lie
    /// about what the screen can do, and "Adjust time" on the previous screen
    /// routes straight here.
    private func timeRow(_ label: String, minute: Int, field: Field) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DS.settle) {
                    editingField = editingField == field ? nil : field
                }
            } label: {
                HStack {
                    Text(label)
                        .font(.body)
                        .foregroundStyle(DS.Palette.ink)
                    Spacer()
                    Text(clockLabel(forMinuteOfDay: minute))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(editingField == field ? DS.Palette.greenInk : DS.Palette.ink)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DS.Palette.inkTertiary)
                        .rotationEffect(.degrees(editingField == field ? 90 : 0))
                }
                .padding(.horizontal, DS.Space.l)
                .padding(.vertical, DS.Space.l)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if editingField == field {
                Stepper5Minutes(
                    minute: field == .starts
                        ? $model.draft.startMinute
                        : $model.draft.endMinute,
                    onChange: { keepDraftOrdered(changed: field) }
                )
                .padding(.horizontal, DS.Space.l)
                .padding(.bottom, DS.Space.m)
            }
        }
    }

    /// Ends must stay after Starts, and the break must stay at least 5
    /// minutes long — enforced here rather than trusted to the user.
    private func keepDraftOrdered(changed: Field) {
        if model.draft.endMinute - model.draft.startMinute < 5 {
            switch changed {
            case .starts: model.draft.endMinute = model.draft.startMinute + 5
            case .ends:   model.draft.startMinute = model.draft.endMinute - 5
            }
        }
    }

    // MARK: - Fit

    private var fitRow: some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: model.draftFitsTheGap ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(model.draftFitsTheGap ? DS.Palette.green : DS.Palette.signal)
            Text(fitMessage)
                .font(.subheadline)
                .foregroundStyle(DS.Palette.ink)
            Spacer(minLength: 0)
        }
    }

    private var fitMessage: String {
        guard let gap = model.suggestion?.gap else { return "Added to the example calendar." }
        let previous = gap.previousEvent?.title ?? "the previous event"
        let next = gap.nextEvent?.title ?? "the next event"
        return model.draftFitsTheGap
            ? "Fits between \(previous) and \(next)."
            : "Overlaps \(previous) or \(next)."
    }

    // MARK: - Gap preview

    private func gapPreview(_ suggestion: BreakSuggestion) -> some View {
        let gap = suggestion.gap
        let total = CGFloat(gap.durationMinutes)
        let breakShare = CGFloat(model.draft.durationMinutes) / max(total, 1)

        return VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(gap.timeRangeLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(DS.Palette.inkSecondary)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Text("Break · \(model.draft.durationMinutes) min")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: geometry.size.width * min(max(breakShare, 0.2), 1.0))
                        .frame(maxHeight: .infinity)
                        .background(DS.Palette.green)
                    if breakShare < 1 {
                        Text("Free · \(gap.durationMinutes - model.draft.durationMinutes) min")
                            .font(.subheadline)
                            .foregroundStyle(DS.Palette.ink)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(DS.Palette.surface)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.block, style: .continuous))
            }
            .frame(height: 46)
            .animation(DS.settle, value: model.draft.durationMinutes)

            HStack {
                Text(clockLabel(forMinuteOfDay: gap.start))
                Spacer()
                Text(clockLabel(forMinuteOfDay: model.draft.endMinute))
                Spacer()
                Text(clockLabel(forMinuteOfDay: gap.end))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(DS.Palette.inkSecondary)
        }
        .padding(DS.Space.l)
        .sageCard()
    }
}

/// Five-minute granularity: a break is not a thing you schedule to the minute.
struct Stepper5Minutes: View {
    @Binding var minute: Int
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: DS.Space.m) {
            stepButton("minus") { minute -= 5; onChange() }
            Text(clockLabel(forMinuteOfDay: minute))
                .font(.system(.title3, weight: .semibold).monospacedDigit())
                .foregroundStyle(DS.Palette.ink)
                .frame(minWidth: 72)
            stepButton("plus") { minute += 5; onChange() }
            Spacer()
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(DS.Palette.greenInk)
                .frame(width: 40, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.block, style: .continuous)
                        .fill(DS.Palette.sage)
                )
        }
        .buttonStyle(PressScaleStyle())
    }
}

#Preview {
    NavigationStack { AddBreakView(model: DayFlowModel()) }
}
