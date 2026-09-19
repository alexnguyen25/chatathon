import Foundation

struct CalendarEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}

struct TodayHeartReading: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let bpm: Double
    let source: String
}
