/// The scripted demo day: Monday 21 September, 09:00–17:00, minute-level.
///
/// Everything here is synthetic. The shape is authored rather than sampled so
/// the presentation is deterministic:
///
///   - Heart rate sits in the high 60s / low 70s through the morning, then
///     climbs into the 84–96 range during the 11:00 design review.
///   - HRV falls far enough, for long enough, during that same hour to clear
///     the persistence check — so the elevated reading is corroborated rather
///     than being a single noisy stretch.
///   - 12:00–12:30 is clear calendar between the review ending and lunch
///     starting. That gap is where the suggested break goes.
///   - One short sub-threshold HRV dip in the afternoon that the persistence
///     check is supposed to throw away.
public enum SyntheticDay {

    public static let dayStartMinute = 9 * 60    // 09:00
    public static let dayEndMinute = 17 * 60     // 17:00
    public static let dayLabel = "Mon, Sep 21"

    public static func schedule() -> Schedule {
        Schedule([
            CalendarEvent(id: "planning", title: "Planning",
                          kind: .planning, start: 9 * 60, end: 10 * 60),
            CalendarEvent(id: "focus", title: "Focus",
                          kind: .focus, start: 10 * 60, end: 11 * 60),
            CalendarEvent(id: "design-review", title: "Design review",
                          kind: .review, start: 11 * 60, end: 12 * 60),
            // 12:00–12:30 is deliberately empty.
            CalendarEvent(id: "lunch", title: "Lunch",
                          kind: .lunch, start: 12 * 60 + 30, end: 13 * 60 + 15),
            CalendarEvent(id: "deep-work", title: "Deep work",
                          kind: .deepWork, start: 13 * 60 + 30, end: 15 * 60),
            CalendarEvent(id: "team-sync", title: "Team sync",
                          kind: .sync, start: 15 * 60 + 15, end: 16 * 60),
            CalendarEvent(id: "wrap-up", title: "Wrap-up",
                          kind: .wrapUp, start: 16 * 60 + 15, end: 17 * 60)
        ])
    }

    /// Heart rate anchors, authored to land on the ranges the UI quotes:
    /// 68–76 through the morning, 84–96 across the 11:00 review.
    private static let hrAnchors: [(minute: Int, value: Double)] = [
        (9 * 60,       70),
        (9 * 60 + 30,  68),
        (10 * 60,      72),
        (10 * 60 + 30, 76),   // settled morning tops out here
        (10 * 60 + 45, 79),   // ramp, in the buffer the comparison excludes
        (11 * 60,      84),   // review begins, already elevated
        (11 * 60 + 20, 88),
        (11 * 60 + 40, 92),
        (12 * 60,      96),   // review ends, peak
        (12 * 60 + 10, 88),
        (12 * 60 + 30, 78),   // recovered inside the open gap
        (13 * 60,      74),
        (13 * 60 + 30, 76),
        (14 * 60 + 30, 80),
        (15 * 60,      75),
        (15 * 60 + 15, 82),
        (16 * 60,      76),
        (17 * 60,      72)
    ]

    /// HRV anchors. The 20% threshold lands near 49.6ms; the crossings are
    /// positioned relative to that line on purpose:
    ///
    ///   11:15–12:12  below it continuously        -> the episode
    ///   14:21–14:31  below it for ~11 minutes     -> rejected, too short
    private static let hrvAnchors: [(minute: Int, value: Double)] = [
        (9 * 60,       62.0),
        (10 * 60,      61.0),
        (10 * 60 + 30, 59.0),
        (11 * 60,      56.0),   // review begins
        (11 * 60 + 10, 52.0),
        (11 * 60 + 20, 47.0),
        (11 * 60 + 40, 43.0),
        (12 * 60,      42.0),   // trough
        (12 * 60 + 10, 48.0),   // recovery starts in the gap
        (12 * 60 + 20, 55.0),
        (12 * 60 + 30, 60.0),
        (13 * 60 + 15, 61.0),
        (13 * 60 + 30, 58.0),
        (14 * 60 + 15, 58.0),
        (14 * 60 + 20, 47.0),   // short artefact, not meeting-correlated
        (14 * 60 + 28, 47.0),
        (14 * 60 + 34, 58.0),
        (15 * 60,      57.0),
        (15 * 60 + 15, 54.0),
        (16 * 60,      58.0),
        (17 * 60,      60.0)
    ]

    private static func interpolate(
        _ minute: Int,
        in anchors: [(minute: Int, value: Double)]
    ) -> Double {
        if minute <= anchors[0].minute { return anchors[0].value }
        if let last = anchors.last, minute >= last.minute { return last.value }
        for index in 1 ..< anchors.count {
            let upper = anchors[index]
            guard minute <= upper.minute else { continue }
            let lower = anchors[index - 1]
            let span = Double(upper.minute - lower.minute)
            guard span > 0 else { return upper.value }
            let t = Double(minute - lower.minute) / span
            return lower.value + (upper.value - lower.value) * t
        }
        return anchors[anchors.count - 1].value
    }

    /// Builds the day. Same `seed` always yields identical output.
    ///
    /// Jitter is small enough that it cannot push a sample across the ~49.6ms
    /// threshold and change which episodes fire, but large enough that the
    /// line reads as a signal rather than a drawn curve.
    public static func samples(seed: UInt64 = 20_260_921) -> [BiometricSample] {
        var rng = SeededGenerator(seed: seed)
        var result: [BiometricSample] = []
        result.reserveCapacity(dayEndMinute - dayStartMinute + 1)
        for minute in dayStartMinute ... dayEndMinute {
            let hrvJitter = rng.symmetricUnit() * 0.5
            // Kept under half a beat so it cannot move a rounded range
            // endpoint — the screens quote those ranges verbatim.
            let hrJitter = rng.symmetricUnit() * 0.45
            result.append(
                BiometricSample(
                    minuteOfDay: minute,
                    heartRate: interpolate(minute, in: hrAnchors) + hrJitter,
                    hrv: interpolate(minute, in: hrvAnchors) + hrvJitter
                )
            )
        }
        return result
    }

    public static func analyzed(
        seed: UInt64 = 20_260_921,
        configuration: DetectorConfiguration = .default
    ) -> (samples: [BiometricSample], schedule: Schedule, result: DetectionResult) {
        let samples = samples(seed: seed)
        let schedule = schedule()
        let result = StressDetector.analyze(
            samples: samples, schedule: schedule, configuration: configuration
        )
        return (samples, schedule, result)
    }

    /// The full picture the screens are built from.
    public static func day(seed: UInt64 = 20_260_921) -> DayModel {
        let analyzed = analyzed(seed: seed)
        return DayModel(
            label: dayLabel,
            samples: analyzed.samples,
            schedule: analyzed.schedule,
            detection: analyzed.result,
            breakSuggestion: BreakFinder.suggest(
                samples: analyzed.samples,
                schedule: analyzed.schedule,
                detection: analyzed.result
            )
        )
    }
}

/// Everything one screen-load needs, resolved once.
public struct DayModel: Sendable {
    public let label: String
    public let samples: [BiometricSample]
    public let schedule: Schedule
    public let detection: DetectionResult
    public let breakSuggestion: BreakSuggestion?

    public init(
        label: String,
        samples: [BiometricSample],
        schedule: Schedule,
        detection: DetectionResult,
        breakSuggestion: BreakSuggestion?
    ) {
        self.label = label
        self.samples = samples
        self.schedule = schedule
        self.detection = detection
        self.breakSuggestion = breakSuggestion
    }
}
