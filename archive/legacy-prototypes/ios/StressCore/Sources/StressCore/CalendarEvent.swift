/// The kind of meeting, used both for the chart band labels and as context in
/// the suggestion prompt. A 45-minute all-hands and a 45-minute focus block are
/// not the same load, and the nudge should be able to tell them apart.
public enum MeetingKind: String, Sendable, CaseIterable, Codable {
    case planning
    case focus
    case review
    case lunch
    case deepWork
    case sync
    case wrapUp

    public var shortLabel: String {
        switch self {
        case .planning: return "Planning"
        case .focus:    return "Focus"
        case .review:   return "Review"
        case .lunch:    return "Lunch"
        case .deepWork: return "Deep work"
        case .sync:     return "Sync"
        case .wrapUp:   return "Wrap-up"
        }
    }

    /// Solo work you control versus time with other people in it. Used to
    /// order context in the prompt and to decide what a break can sit next
    /// to — never to diagnose anything.
    public var isCollaborative: Bool {
        switch self {
        case .review, .sync, .planning: return true
        case .focus, .deepWork, .lunch, .wrapUp: return false
        }
    }
}

/// One entry on the work calendar.
///
/// Like `BiometricSample`, times are minutes since local midnight. `end` is
/// exclusive, so a 09:30–09:45 standup is `start: 570, end: 585` and does not
/// overlap a 09:45 meeting by a minute.
public struct CalendarEvent: Sendable, Hashable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let kind: MeetingKind
    public let start: Int
    public let end: Int

    /// True when this event begins within `Schedule.backToBackToleranceMinutes`
    /// of the previous event ending. Set by `Schedule`, not by the caller.
    public internal(set) var isBackToBack: Bool

    public init(
        id: String,
        title: String,
        kind: MeetingKind,
        start: Int,
        end: Int,
        isBackToBack: Bool = false
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.start = start
        self.end = end
        self.isBackToBack = isBackToBack
    }

    public var durationMinutes: Int { end - start }

    public var timeRangeLabel: String {
        clockLabel(forMinuteOfDay: start) + "–" + clockLabel(forMinuteOfDay: end)
    }

    /// Half-open overlap test: touching ranges do not overlap.
    public func overlaps(start otherStart: Int, end otherEnd: Int) -> Bool {
        start < otherEnd && otherStart < end
    }
}

/// An ordered day of calendar events, with back-to-back relationships resolved.
public struct Schedule: Sendable, Hashable {
    /// A gap this size or smaller is not a real break — you are still walking
    /// back to your desk. Two meetings separated by <= this are back-to-back.
    public static let backToBackToleranceMinutes = 5

    public let events: [CalendarEvent]

    public init(_ events: [CalendarEvent]) {
        let sorted = events.sorted { $0.start < $1.start }
        var resolved: [CalendarEvent] = []
        resolved.reserveCapacity(sorted.count)
        for (index, event) in sorted.enumerated() {
            var copy = event
            if index > 0 {
                let gap = event.start - sorted[index - 1].end
                copy.isBackToBack = gap <= Schedule.backToBackToleranceMinutes
            } else {
                copy.isBackToBack = false
            }
            resolved.append(copy)
        }
        self.events = resolved
    }

    public func events(overlapping start: Int, _ end: Int) -> [CalendarEvent] {
        events.filter { $0.overlaps(start: start, end: end) }
    }

    /// First event beginning at or after `minute`.
    public func firstEvent(startingAtOrAfter minute: Int) -> CalendarEvent? {
        events.first { $0.start >= minute }
    }

    /// Extends `subset` backwards through any meetings that ran back-to-back
    /// into it.
    ///
    /// HRV falls with a lag. By the time the signal has dropped 20% below
    /// baseline, the meeting that started the cascade is often already over, so
    /// a raw overlap test under-reports the block the person actually sat
    /// through — it will happily tell you "2 meetings" about a morning that
    /// was unmistakably three with no breaks. Walking back through the
    /// unbroken chain recovers the meeting block as a human would describe it.
    public func contributingChain(for subset: [CalendarEvent]) -> [CalendarEvent] {
        guard
            let earliest = subset.min(by: { $0.start < $1.start }),
            let latest = subset.max(by: { $0.start < $1.start }),
            var lower = events.firstIndex(where: { $0.id == earliest.id }),
            let upper = events.firstIndex(where: { $0.id == latest.id })
        else { return subset }

        while lower > 0,
              events[lower].start - events[lower - 1].end <= Schedule.backToBackToleranceMinutes {
            lower -= 1
        }
        return Array(events[lower ... upper])
    }

    /// The length of the longest unbroken chain of back-to-back meetings within
    /// `subset`, counted in meetings.
    ///
    /// Three meetings with no gaps returns 3 — not 2. The number a person cares
    /// about is "how many did I sit through without a break", not how many
    /// transitions there were.
    public static func longestBackToBackRun(in subset: [CalendarEvent]) -> Int {
        guard !subset.isEmpty else { return 0 }
        let sorted = subset.sorted { $0.start < $1.start }
        var best = 1
        var current = 1
        for index in 1 ..< sorted.count {
            let gap = sorted[index].start - sorted[index - 1].end
            if gap <= backToBackToleranceMinutes {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }
}
