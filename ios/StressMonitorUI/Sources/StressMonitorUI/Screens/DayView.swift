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
                // Once the break is on the calendar the card must stop
                // offering to add it — leaving "Review suggestion" there
                // invites adding the same break twice.
                if model.addedEvent != nil {
                    addedCard
                } else if model.suggestion != nil {
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

    private var addedCard: some View {
        HStack(alignment: .center, spacing: DS.Space.l) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(DS.Palette.green)
                .frame(width: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("Break added").rowTitleStyle()
                if let added = model.addedEvent {
                    Text("\(clockLabel(forMinuteOfDay: added.start)) – \(clockLabel(forMinuteOfDay: added.end)) · Example calendar")
                        .font(.subheadline)
                        .foregroundStyle(DS.Palette.inkSecondary)
                }
            }
            Spacer(minLength: 0)
            TextAction("Undo") { model.undoAdd() }
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

    // 580 pushed the suggestion card off-screen on a 6.1" phone. The whole
    // point of this screen is seeing the day *and* the suggested action
    // together, so the timeline yields the height.
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 380
    // Scaled: at accessibility sizes a fixed 52 wrapped "Time" to "Tim/e"
    // and "9 AM" onto two lines. Capped below, or the side columns eat the
    // calendar entirely.
    @ScaledMetric(relativeTo: .subheadline) private var timeColumnWidth: CGFloat = 54
    @ScaledMetric(relativeTo: .subheadline) private var chartWidth: CGFloat = 132

    @Environment(\.dynamicTypeSize) private var typeSize

    /// At accessibility text sizes three columns cannot share a phone width —
    /// scaling the side columns squeezed the calendar to a single character
    /// per line and the events vanished. The calendar is the actionable half,
    /// so the chart yields and its numbers are stated in text below instead.
    private var showsChart: Bool { !typeSize.isAccessibilitySize }
    private var effectiveTimeWidth: CGFloat { min(timeColumnWidth, 104) }
    private var effectiveChartWidth: CGFloat { min(chartWidth, 150) }

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
        // The 09:00 row sits at y == 0, so without a real gap here the
        // "Time" heading and the "9 AM" label collide.
        VStack(alignment: .leading, spacing: DS.Space.l) {
            columnHeadings
            HStack(alignment: .top, spacing: 0) {
                timeColumn
                calendarColumn
                if showsChart { heartRateColumn }
            }
            .frame(height: height)

            if !showsChart, let suggestion = model.suggestion {
                Text("Heart rate \(suggestion.comparison.recentLabel) BPM during the last hour, against \(suggestion.comparison.earlierLabel) earlier.")
                    .font(.subheadline)
                    .foregroundStyle(DS.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var columnHeadings: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("Time")
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(DS.Palette.inkSecondary)
                .frame(width: effectiveTimeWidth, alignment: .leading)
            Text("Calendar")
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(DS.Palette.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showsChart {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heart rate (BPM)")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
                .frame(width: effectiveChartWidth, alignment: .leading)
            }
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
        .frame(width: effectiveTimeWidth, height: height, alignment: .topLeading)
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
        // A 15-minute block is ~14pt at this scale, which sliced "Take a
        // break" in half. The floor has to clear a line of text, and short
        // blocks centre it rather than pinning it to the top.
        let naturalHeight = y(for: event.end) - y(for: event.start) - 6
        let blockHeight = max(naturalHeight, 30)
        let isShort = naturalHeight < 44

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
                .lineLimit(2)
                // Shrink before truncating: at accessibility sizes this was
                // rendering "Design r…", which is worse than slightly small.
                .minimumScaleFactor(0.7)
                .padding(.leading, isFlagged ? DS.Space.m : DS.Space.l)
                .padding(.trailing, DS.Space.s)
                .padding(.vertical, isShort ? 0 : DS.Space.m)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: isShort ? .leading : .topLeading
                )
        }
        .frame(width: width - DS.Space.s, height: blockHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.block, style: .continuous)
                .fill(isAdded ? DS.Palette.green : DS.calendarFill(flagged: false))
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.block, style: .continuous))
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
        .frame(width: effectiveChartWidth, height: height)
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
