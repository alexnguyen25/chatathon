import SwiftUI

/// One chronological view connects the schedule, its observations, and the proposed action.
struct DayAgendaView: View {
    @ObservedObject var calendar: CalendarStore
    @ObservedObject var health: TodayHealthStore
    var proposedSlot: DateInterval?
    var savedEventID: String?
    var onReview: () -> Void
    var onConnect: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedEvent: CalendarEvent?

    private var allDayEvents: [CalendarEvent] { calendar.events.filter(\.isAllDay) }
    private var timeline: [AgendaEntry] {
        var entries = calendar.events.filter { !$0.isAllDay }.map(AgendaEntry.event)
        if let proposedSlot { entries.append(.suggestion(proposedSlot)) }
        return entries.sorted { $0.start < $1.start }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if !calendar.connected {
                    connectionPrompt
                } else {
                    if !allDayEvents.isEmpty { allDaySection }
                    if timeline.isEmpty {
                        emptyDay
                    } else {
                        agenda
                    }
                    Label("Readings show what was recorded, not what caused a change.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(LowCorTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(LowCorTheme.canvas)
        .foregroundStyle(LowCorTheme.ink)
        .refreshable {
            calendar.refresh()
            await health.refresh()
        }
        .sheet(item: $selectedEvent) { event in
            AgendaEventDetail(event: event, readings: readings(during: event), isSavedBreak: event.id == savedEventID,
                              now: calendar.currentDate, isDemo: calendar.isDemo)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.title3.weight(.semibold))
            Text("Your schedule and heart rate, together.")
                .font(.subheadline)
                .foregroundStyle(LowCorTheme.secondary)
            if calendar.connected {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { summaryLabels }
                    VStack(alignment: .leading, spacing: 8) { summaryLabels }
                }
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder private var summaryLabels: some View {
        Label("\(calendar.events.count) event\(calendar.events.count == 1 ? "" : "s")", systemImage: "calendar")
        Label("\(health.readings.count) reading\(health.readings.count == 1 ? "" : "s")", systemImage: "heart")
    }

    private var connectionPrompt: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(LowCorTheme.forest)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text("See the shape of your day")
                    .font(.title2.weight(.semibold))
                Text("Connect your calendar to bring meetings, health readings, and room for a break into one place.")
                    .foregroundStyle(LowCorTheme.secondary)
            }
            Button(action: onConnect) {
                Text("Connect calendar")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(AgendaPrimaryButtonStyle())
            Text("Nothing is added until you review and confirm it.")
                .font(.footnote)
                .foregroundStyle(LowCorTheme.secondary)
        }
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var emptyDay: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("A little more breathing room", systemImage: "sun.max")
                .font(.title3.weight(.semibold))
                .foregroundStyle(LowCorTheme.forest)
            Text(allDayEvents.isEmpty ? "No events on your calendar today." : "No timed events on your calendar today.")
                .font(.headline)
            Text("Head to Today to find a time for a break. It will appear here alongside your schedule.")
                .foregroundStyle(LowCorTheme.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LowCorTheme.sage, in: RoundedRectangle(cornerRadius: 20))
    }

    private var allDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL DAY")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(LowCorTheme.secondary)
            ForEach(allDayEvents) { event in
                Button { selectedEvent = event } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundStyle(LowCorTheme.forest)
                            .accessibilityHidden(true)
                        Text(event.title).font(.subheadline.weight(.medium))
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LowCorTheme.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(AgendaRowButtonStyle())
                .accessibilityHint("Show event and heart-rate observations")
            }
        }
    }

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TIMELINE")
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                Spacer()
                Text("Tap an event for details")
                    .font(.caption)
            }
            .foregroundStyle(LowCorTheme.secondary)

            LazyVStack(spacing: 0) {
                ForEach(timeline) { entry in
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            timeLabel(entry.start)
                            entryContent(entry)
                        }
                        .padding(.bottom, 20)
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 12) {
                                timeLabel(entry.start)
                                Rectangle()
                                    .fill(LowCorTheme.secondary.opacity(0.18))
                                    .frame(width: 1)
                                    .frame(maxHeight: .infinity)
                            }
                            .frame(width: 60)
                            entryContent(entry)
                                .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
    }

    private func timeLabel(_ date: Date) -> some View {
        Text(date.formatted(date: .omitted, time: .shortened))
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(LowCorTheme.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 16)
    }

    @ViewBuilder private func entryContent(_ entry: AgendaEntry) -> some View {
        switch entry {
        case .event(let event):
            Button { selectedEvent = event } label: {
                AgendaEventCard(event: event, readings: readings(during: event), isSavedBreak: event.id == savedEventID, now: calendar.currentDate)
            }
            .buttonStyle(AgendaRowButtonStyle())
            .accessibilityHint("Show event and heart-rate observations")
        case .suggestion(let slot):
            VStack(alignment: .leading, spacing: 12) {
                Label("SUGGESTED BREAK", systemImage: "cup.and.saucer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LowCorTheme.forest)
                Text("A moment for yourself")
                    .font(.headline)
                Text("\(slot.start.formatted(date: .omitted, time: .shortened)) – \(slot.end.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(LowCorTheme.secondary)
                Button(action: onReview) {
                    HStack {
                        Text("Review break")
                        Spacer()
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(LowCorTheme.forest)
                .accessibilityHint("Review before adding to your calendar")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LowCorTheme.sage.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(LowCorTheme.forest.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
        }
    }

    private func readings(during event: CalendarEvent) -> [TodayHeartReading] {
        health.readings.filter { $0.date >= event.startDate && $0.date < event.endDate }
    }
}

private enum AgendaEntry: Identifiable {
    case event(CalendarEvent)
    case suggestion(DateInterval)

    var start: Date {
        switch self {
        case .event(let event): event.startDate
        case .suggestion(let slot): slot.start
        }
    }

    var id: String {
        switch self {
        case .event(let event): "event-\(event.id)-\(event.startDate.timeIntervalSince1970)"
        case .suggestion(let slot): "suggestion-\(slot.start.timeIntervalSince1970)"
        }
    }
}

private struct AgendaEventCard: View {
    let event: CalendarEvent
    let readings: [TodayHeartReading]
    let isSavedBreak: Bool
    let now: Date

    private var isCurrent: Bool { event.startDate <= now && event.endDate > now }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isSavedBreak {
                Label("BREAK ADDED", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
            } else if isCurrent {
                Label("HAPPENING NOW", systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LowCorTheme.forest)
            }
            HStack(alignment: .top, spacing: 8) {
                Text(event.title).font(.headline)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
            Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(isSavedBreak ? .white.opacity(0.9) : LowCorTheme.secondary)
            if let average = agendaAverage(readings) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(average) BPM average", systemImage: "heart")
                        .font(.subheadline.weight(.medium))
                    Text("\(readings.count) recorded sample\(readings.count == 1 ? "" : "s")")
                        .font(.caption)
                }
                .foregroundStyle(isSavedBreak ? .white : LowCorTheme.terracotta)
                .padding(.top, 4)
            } else if event.startDate <= now {
                Text("No readings in this window")
                    .font(.caption)
                    .foregroundStyle(isSavedBreak ? .white.opacity(0.9) : LowCorTheme.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(isSavedBreak ? .white : LowCorTheme.ink)
        .background(isSavedBreak ? LowCorTheme.forest : .white, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if isCurrent && !isSavedBreak {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(LowCorTheme.forest.opacity(0.45), lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct AgendaEventDetail: View {
    let event: CalendarEvent
    let readings: [TodayHeartReading]
    let isSavedBreak: Bool
    let now: Date
    let isDemo: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if isDemo { Label("Demo data · fictional event and readings", systemImage: "flask").font(.caption).foregroundStyle(LowCorTheme.forest) }
                    VStack(alignment: .leading, spacing: 12) {
                        Label(isSavedBreak ? "YOUR BREAK" : "CALENDAR EVENT", systemImage: isSavedBreak ? "cup.and.saucer" : "calendar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LowCorTheme.forest)
                        Text(event.title).font(.title.weight(.bold))
                        Text(event.startDate.formatted(date: .complete, time: .omitted))
                            .foregroundStyle(LowCorTheme.secondary)
                        Text(event.isAllDay ? "All day" : "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.headline)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Heart rate in this window").font(.title3.weight(.semibold))
                        if let average = agendaAverage(readings) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(average)").font(.largeTitle.weight(.semibold)).monospacedDigit()
                                Text("BPM sample average").font(.subheadline)
                            }
                            .foregroundStyle(LowCorTheme.terracotta)
                            Text("\(readings.count) recorded samples. These observations do not tell us whether this event caused a change.")
                                .font(.subheadline)
                                .foregroundStyle(LowCorTheme.secondary)
                        } else {
                            Text(event.startDate > now ? "This event is still ahead. No readings are available for this time yet." : "No heart-rate samples are available for this time. Missing readings do not mean a low or high heart rate.")
                                .foregroundStyle(LowCorTheme.secondary)
                        }
                    }
                    if !readings.isEmpty {
                        LazyVStack(spacing: 0) {
                            ForEach(readings) { reading in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(reading.date.formatted(date: .omitted, time: .standard))
                                        Spacer(minLength: 12)
                                        Text("\(Int(reading.bpm.rounded())) BPM")
                                            .fontWeight(.semibold)
                                            .monospacedDigit()
                                            .foregroundStyle(LowCorTheme.terracotta)
                                    }
                                    Text(reading.source)
                                        .font(.caption)
                                        .foregroundStyle(LowCorTheme.secondary)
                                }
                                .padding(.vertical, 12)
                                .accessibilityElement(children: .combine)
                                Divider()
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(LowCorTheme.ink)
            .background(LowCorTheme.canvas)
            .navigationTitle("Event details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(LowCorTheme.forest)
                }
            }
        }
    }
}

private func agendaAverage(_ readings: [TodayHeartReading]) -> Int? {
    guard !readings.isEmpty else { return nil }
    return Int((readings.reduce(0) { $0 + $1.bpm } / Double(readings.count)).rounded())
}

private struct AgendaRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.68 : 1)
    }
}

private struct AgendaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .background(LowCorTheme.forest.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}
