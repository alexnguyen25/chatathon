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
    private let eventStore = EKEventStore()

    func requestAccessAndLoadToday() async {
        do {
            guard try await eventStore.requestFullAccessToEvents() else {
                status = "Calendar access was not granted. Health measurements still work."
                return
            }
            loadToday()
        } catch {
            status = "Calendar access could not be requested: \(error.localizedDescription)"
        }
    }

    private func loadToday() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }.map {
            CalendarEvent(
                id: $0.eventIdentifier,
                title: $0.title ?? "Untitled event",
                startDate: $0.startDate,
                endDate: $0.endDate,
                isAllDay: $0.isAllDay
            )
        }
        status = events.isEmpty ? "No events found for today." : "Loaded \(events.count) event\(events.count == 1 ? "" : "s") for today."
    }
}
