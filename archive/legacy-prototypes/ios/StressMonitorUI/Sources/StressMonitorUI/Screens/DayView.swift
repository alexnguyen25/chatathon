import SwiftUI
import StressCore

public struct DayView: View {

    @Bindable var model: DayFlowModel

    public init(model: DayFlowModel) {
        self._model = Bindable(model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                ScreenHeader(title: "Your day", subtitle: model.day.label) {
                    SampleDataPill()
                }
                DayTimeline(model: model)
                if model.suggestion != nil {
                    suggestionCard
                }
            }
            .padding(.horizontal, DS.Space.screenMargin)
            .padding(.vertical, DS.Space.l)
        }
        .background(DS.Palette.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            HStack(alignment: .center, spacing: DS.Space.l) {
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(DS.Palette.ink)
                    .frame(width: 48)
                VStack(alignment: .leading, spacing: 2) {
                    // tokens.semantics.suggestion: "Sage with explicit
                    // Suggested label." Nothing here should be mistaken for
                    // something the app already did.
                    Text("Suggested")
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.Palette.inkSecondary)
                    Text("Make room for a break")
                        .font(.system(.title3, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(DS.Palette.ink)
                    if let suggestion = model.suggestion {
                        Text("\(suggestion.timeRangeLabel) · Free in your calendar")
                            .font(.subheadline)
                            .foregroundStyle(DS.Palette.inkSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            PrimaryButton("Review suggestion") { model.openSuggestion() }
        }
        .padding(DS.Space.l)
        .sageCard()
    }
}

/// Time, calendar, and heart rate share one vertical axis.
///
/// Built from a single `y(forMinute:)` rather than composed from separate
/// charts: the whole point of the layout is that a calendar entry and the
/// readings beside it line up exactly, and two independently-scaled views
/// cannot promise that.
struct DayTimeline: View {

    let model: DayFlowModel

    private let dayStart = SyntheticDay.dayStartMinute
    private let dayEnd = SyntheticDay.dayEndMinute
    private let height: CGFloat = 580
    private let timeColumnWidth: CGFloat = 52
    private let chartWidth: CGFloat = 132

    private let bpmLow = 52.0
    private let bpmHigh = 108.0
    private let bpmTicks = [60, 80, 100]

    private func y(for minute: Int) -> CGFloat {
        let fraction = CGFloat(minute - dayStart) / CGFloat(dayEnd - dayStart)
        return fraction * height
    }

    private func x(forBPM bpm: Double, in width: CGFloat) -> CGFloat {
        let clamped = min(max(bpm, bpmLow), bpmHigh)
        return CGFloat((clamped - bpmLow) / (bpmHigh - bpmLow)) * width
    }

    /// One point per 30 minutes. Minute-level would be a solid smear at this
    /// width; half-hourly keeps the shape and leaves the dots legible.
    private var plotted: [BiometricSample] {
        model.day.samples.filter { ($0.minuteOfDay - dayStart) % 30 == 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            columnHeadings
            HStack(alignment: .top, spacing: 0) {
                timeColumn
                calendarColumn
                heartRateColumn
            }
            .frame(height: height)
        }
    }

    private var columnHeadings: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("Time")
                .font(.subheadline)
                .foregroundStyle(DS.Palette.inkSecondary)
                .frame(width: timeColumnWidth, alignment: .leading)
            Text("Calendar")
                .font(.subheadline)
                .foregroundStyle(DS.Palette.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("Heart rate (BPM)")
                    .font(.subheadline)
                    .foregroundStyle(DS.Palette.inkSecondary)
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        ForEach(bpmTicks, id: \.self) { tick in
                            Text("\(tick)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(DS.Palette.inkTertiary)
                                .offset(x: x(forBPM: Double(tick), in: geometry.size.width) - 9)
                        }
                    }
                }
                .frame(height: 16)
            }
            .frame(width: chartWidth, alignment: .leading)
        }
    }

    private var timeColumn: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: 9, through: 17, by: 1)), id: \.self) { hour in
                Text(hourLabel(hour))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(DS.Palette.inkSecondary)
                    .offset(y: y(for: hour * 60) - 9)
            }
        }
        .frame(width: timeColumnWidth, height: height, alignment: .topLeading)
    }

    private func hourLabel(_ hour: Int) -> String {
        let display = hour > 12 ? hour - 12 : hour
        return "\(display) \(hour < 12 ? "AM" : "PM")"
    }

    private var calendarColumn: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Hour rules, behind everything.
                ForEach(Array(stride(from: 9, through: 17, by: 1)), id: \.self) { hour in
                    Rectangle()
                        .fill(DS.Palette.hairline)
                        .frame(height: 1)
                        .offset(y: y(for: hour * 60))
                }

                ForEach(model.displayedEvents) { event in
                    eventBlock(event, width: geometry.size.width)
                }

                // The empty slot, drawn only while it is still empty.
                if let suggestion = model.suggestion, model.addedEvent == nil {
                    RoundedRectangle(cornerRadius: DS.Radius.block, style: .continuous)
                        .strokeBorder(
                            DS.Palette.green,
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                        )
                        .frame(
                            width: geometry.size.width - DS.Space.s,
                            height: max(y(for: suggestion.gap.end) - y(for: suggestion.gap.start) - 6, 18)
                        )
                        .offset(y: y(for: suggestion.gap.start) + 3)
                        .accessibilityLabel("Free slot, \(suggestion.gap.timeRangeLabel)")
                }
            }
        }
        .frame(height: height)
        .padding(.trailing, DS.Space.m)
    }

    private func eventBlock(_ event: CalendarEvent, width: CGFloat) -> some View {
        let isFlagged = event.id == model.flaggedEventID
        let isAdded = event.id == model.addedEvent?.id
        let blockHeight = max(y(for: event.end) - y(for: event.start) - 6, 22)

        return HStack(spacing: 0) {
            // Terracotta marker: the calendar entry the readings changed
            // during. The only place the signal colour touches the calendar.
            if isFlagged {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Palette.signal)
                    .frame(width: 4)
                    .padding(.vertical, 6)
            }
            Text(event.title)
                .font(.system(.subheadline, weight: isAdded ? .semibold : .regular))
                // tokens.semantics.savedEvent: "Solid green with text label."
                .foregroundStyle(isAdded ? Color.white : DS.Palette.ink)
                .padding(.leading, isFlagged ? DS.Space.m : DS.Space.l)
                .padding(.top, DS.Space.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: width - DS.Space.s, height: blockHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.block, style: .continuous)
                .fill(isAdded ? DS.Palette.green : DS.calendarFill(flagged: false))
        )
        .offset(y: y(for: event.start) + 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title), \(event.timeRangeLabel)")
    }

    private var heartRateColumn: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                ForEach(bpmTicks, id: \.self) { tick in
                    Rectangle()
                        .fill(DS.Palette.hairline)
                        .frame(width: 1, height: height)
                        .offset(x: x(forBPM: Double(tick), in: width))
                }

                Path { path in
                    for (index, sample) in plotted.enumerated() {
                        let point = CGPoint(
                            x: x(forBPM: sample.heartRate, in: width),
                            y: y(for: sample.minuteOfDay)
                        )
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                }
                .stroke(
                    DS.Palette.signal,
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )

                ForEach(plotted) { sample in
                    Circle()
                        .fill(DS.Palette.signal)
                        .frame(width: 5.5, height: 5.5)
                        .offset(
                            x: x(forBPM: sample.heartRate, in: width) - 2.75,
                            y: y(for: sample.minuteOfDay) - 2.75
                        )
                }
            }
        }
        .frame(width: chartWidth, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate through the day")
        .accessibilityValue(model.suggestion.map {
            "\($0.comparison.recentLabel) beats per minute before the gap, \($0.comparison.earlierLabel) earlier"
        } ?? "")
    }
}

#Preview {
    NavigationStack { DayView(model: DayFlowModel()) }
}
