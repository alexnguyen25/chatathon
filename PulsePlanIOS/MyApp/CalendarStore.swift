import Combine
import EventKit
import Foundation

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var status = "Connect your calendar to see today’s schedule."
    @Published private(set) var writableCalendars: [EKCalendar] = []
    @Published private(set) var connected = false
    @Published private(set) var isDemo = false
    private var demoDay: PulseDemoDay?
    var currentDate: Date { demoDay?.now ?? Date() }

    func setDemo(_ day: PulseDemoDay?) {
        demoDay = day
        isDemo = day != nil
        events = day?.events ?? []
        writableCalendars = []
        connected = day != nil
        status = day == nil ? "Connect your calendar to see today’s schedule." : "Fictional schedule. Demo changes stay inside PulsePlan."
        if day == nil { refresh() }
    }
    private let eventStore = EKEventStore()

    var defaultCalendarID: String? {
        if isDemo { return "pulseplan-demo-calendar" }
        guard connected else { return nil }
        if let calendar = eventStore.defaultCalendarForNewEvents,
           writableCalendars.contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) {
            return calendar.calendarIdentifier
        }
        return writableCalendars.first?.calendarIdentifier
    }

    func requestAccessAndLoadToday() async {
        guard !isDemo else { return }
        do {
            guard try await eventStore.requestFullAccessToEvents() else {
                refresh()
                status = "Calendar access was not granted. Health measurements still work."
                return
            }
            loadToday()
        } catch {
            status = "Calendar access could not be requested: \(error.localizedDescription)"
        }
    }

    /// Refreshes existing permission state without presenting a permission prompt.
    func refresh() {
        guard !isDemo else { return }
        connected = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        guard connected else {
            events = []
            writableCalendars = []
            status = "Connect your calendar to see today’s schedule."
            return
        }
        loadToday()
    }

    func loadToday() {
        guard !isDemo else { return }
        connected = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        guard connected else {
            events = []
            writableCalendars = []
            status = "Calendar access is needed to check your schedule."
            return
        }
        writableCalendars = eventStore.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = eventStore.events(matching: predicate)
            .filter { $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }.map {
            CalendarEvent(
                id: $0.eventIdentifier ?? $0.calendarItemIdentifier,
                title: $0.title ?? "Untitled event",
                startDate: $0.startDate,
                endDate: $0.endDate,
                isAllDay: $0.isAllDay
            )
        }
        status = events.isEmpty ? "No events found for today." : "Loaded \(events.count) event\(events.count == 1 ? "" : "s") for today."
    }

    /// Reads every accessible calendar, including read-only calendars, before proposing a gap.
    func nextAvailableBreak(now: Date? = nil) -> DateInterval? {
        let now = now ?? currentDate
        if isDemo {
            let end = Calendar.current.startOfDay(for: currentDate).addingTimeInterval(24 * 60 * 60)
            return Self.nextReviewableBreak(now: now, before: end,
                                            busy: events.map { DateInterval(start: $0.startDate, end: $0.endDate) })
        }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
              let dayEnd = Calendar.current.date(byAdding: .day, value: 1,
                                                to: Calendar.current.startOfDay(for: now)) else { return nil }
        let limit = min(dayEnd, now.addingTimeInterval(8 * 60 * 60))
        let busy = busyIntervals(from: now, to: limit)
        return Self.nextReviewableBreak(now: now, before: limit, busy: busy)
    }

    /// A current meeting supplies the review window; its exact end is eligible.
    /// When already free, leave five minutes to review and confirm the break.
    nonisolated static func nextReviewableBreak(now: Date, before limit: Date, busy: [DateInterval]) -> DateInterval? {
        let currentlyBusy = busy.contains { $0.start <= now && $0.end > now }
        let earliestStart = currentlyBusy ? now : now.addingTimeInterval(5 * 60)
        return nextAvailableSlot(after: earliestStart, before: limit, busy: busy)
    }

    /// Pure gap search: touching event boundaries are allowed; overlapping busy intervals are skipped.
    nonisolated static func nextAvailableSlot(
        after now: Date,
        before limit: Date,
        busy: [DateInterval],
        duration: TimeInterval = 15 * 60
    ) -> DateInterval? {
        guard duration.isFinite, duration > 0,
              now.timeIntervalSinceReferenceDate.isFinite,
              limit.timeIntervalSinceReferenceDate.isFinite,
              now < limit else { return nil }
        // The caller already includes review time. Keep meeting boundaries exact:
        // a meeting ending at noon leaves a break available at noon, not 12:01.
        var candidate = now
        for interval in busy.sorted(by: { $0.start < $1.start }) {
            guard interval.end > candidate, interval.start < limit else { continue }
            if candidate.addingTimeInterval(duration) <= interval.start { break }
            candidate = interval.end
        }
        let end = candidate.addingTimeInterval(duration)
        guard end <= limit else { return nil }
        return DateInterval(start: candidate, end: end)
    }

    /// Call only after the user reviews and confirms the proposed calendar entry.
    @discardableResult
    func saveBreak(start: Date, end: Date, calendarID: String) throws -> String {
        if isDemo {
            guard calendarID == "pulseplan-demo-calendar", start > currentDate, end > start else { throw SchedulingError.invalidTime }
            guard !events.contains(where: { $0.startDate < end && $0.endDate > start }) else { throw SchedulingError.conflict }
            let id = "demo-break-\(UUID().uuidString)"
            events.append(CalendarEvent(id: id, title: "Private reset", startDate: start, endDate: end, isAllDay: false))
            events.sort { $0.startDate < $1.startDate }
            status = "Break added to the demo day only."
            return id
        }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            refresh()
            throw SchedulingError.accessRequired
        }
        guard start.timeIntervalSinceReferenceDate.isFinite,
              end.timeIntervalSinceReferenceDate.isFinite,
              start > Date(), end > start else { throw SchedulingError.invalidTime }
        guard let calendar = eventStore.calendar(withIdentifier: calendarID),
              calendar.allowsContentModifications else { throw SchedulingError.calendarUnavailable }
        guard busyIntervals(from: start, to: end).isEmpty else { throw SchedulingError.conflict }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = "Private reset"
        event.startDate = start
        event.endDate = end
        event.availability = .busy
        // Keep physiological details and meeting titles out of the calendar entry.
        event.notes = "A short break planned with PulsePlan."
        try eventStore.save(event, span: .thisEvent, commit: true)
        loadToday()
        status = "Your break was added to \(calendar.title)."
        return event.eventIdentifier ?? event.calendarItemIdentifier
    }

    private func busyIntervals(from start: Date, to end: Date) -> [DateInterval] {
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        return eventStore.events(matching: predicate).compactMap { event in
            guard event.status != .canceled, event.availability != .free,
                  let eventStart = event.startDate, let eventEnd = event.endDate,
                  eventEnd > eventStart, eventStart < end, eventEnd > start else { return nil }
            return DateInterval(start: eventStart, end: eventEnd)
        }
    }

    enum SchedulingError: LocalizedError {
        case accessRequired, invalidTime, calendarUnavailable, conflict

        var errorDescription: String? {
            switch self {
            case .accessRequired: "Connect your calendar before adding a break."
            case .invalidTime: "That time has passed. Generate a new suggestion for an upcoming break."
            case .calendarUnavailable: "Choose a calendar that allows new events."
            case .conflict: "Your schedule changed and this slot is now busy. Generate a new suggestion."
            }
        }
    }
}
