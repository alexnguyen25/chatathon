import Foundation

/// Pure scheduling rules shared by the app and regression tests.
enum CalendarAvailability {
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

}
