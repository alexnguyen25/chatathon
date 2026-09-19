/// Thresholds for episode detection.
///
/// These are demo defaults for synthetic data, not clinical cut-offs. HRV is a
/// noisy signal that responds to posture, caffeine, speech and hydration as
/// much as to workload; everything here supports a voluntary suggestion and
/// nothing here diagnoses anything.
public struct DetectorConfiguration: Sendable, Hashable {

    /// How the personal baseline is summarised.
    public enum BaselineStatistic: Sendable, Hashable {
        /// Resistant to artefacts — one bad reading in the window cannot move
        /// it. The default, and what this project's spec calls for.
        case median
        /// What `pipeline/analyze_stress.py` uses. Kept so the Swift detector
        /// can reproduce that script's published output exactly.
        case mean
    }

    /// Window from the first sample of the day used to establish the personal
    /// baseline.
    public var baselineWindowMinutes: Int
    /// Fractional drop below baseline that counts as depressed. 0.20 == 20%.
    public var dropFraction: Double
    /// How long the drop must persist before it is an episode. This is the
    /// whole point of the detector: one bad minute is noise, not a signal.
    public var persistenceMinutes: Int
    public var baselineStatistic: BaselineStatistic

    public init(
        baselineWindowMinutes: Int = 30,
        dropFraction: Double = 0.20,
        persistenceMinutes: Int = 15,
        baselineStatistic: BaselineStatistic = .median
    ) {
        self.baselineWindowMinutes = baselineWindowMinutes
        self.dropFraction = dropFraction
        self.persistenceMinutes = persistenceMinutes
        self.baselineStatistic = baselineStatistic
    }

    /// Median of the first 30 minutes, 20% drop, 15-minute persistence.
    public static let `default` = DetectorConfiguration()

    /// Exactly what `pipeline/analyze_stress.py` does: mean of the first 60
    /// minutes, 20% drop, 20-minute persistence.
    ///
    /// These are **not** the same thresholds as `.default`, and the difference
    /// is not cosmetic — see `PipelineParityTests`. This preset exists so the
    /// two implementations can be checked against each other on the same data
    /// while the team decides which set of numbers is the real one.
    public static let pipelineParity = DetectorConfiguration(
        baselineWindowMinutes: 60,
        dropFraction: 0.20,
        persistenceMinutes: 20,
        baselineStatistic: .mean
    )
}

/// A sustained-stress episode: a contiguous run of depressed HRV long enough to
/// clear the persistence check, joined to whatever was on the calendar.
public struct StressEpisode: Sendable, Hashable, Identifiable {
    public let startMinute: Int
    public let endMinute: Int
    public let baselineHRV: Double
    /// Lowest HRV observed inside the episode.
    public let minimumHRV: Double
    /// Meetings literally overlapping the depressed window, in start order.
    public let overlappingEvents: [CalendarEvent]
    /// `overlappingEvents` extended backwards through the unbroken meeting
    /// chain that led into them. This is the set the nudge should talk about:
    /// HRV lags, so the meeting that triggered the decline is usually already
    /// over by the time the threshold is crossed.
    public let contributingEvents: [CalendarEvent]
    /// Meetings in the longest unbroken chain within `contributingEvents`.
    public let backToBackCount: Int
    /// First meeting starting at or after the episode ends — what the nudge
    /// can actually act on.
    public let nextEvent: CalendarEvent?

    public var id: Int { startMinute }

    /// Inclusive of both endpoints: a run from minute 598 to 718 is 121 minutes
    /// of readings, because both ends are depressed samples.
    public var durationMinutes: Int { endMinute - startMinute + 1 }

    /// Peak drop below baseline, as a percentage.
    public var maxDropPercent: Double {
        guard baselineHRV > 0 else { return 0 }
        return (baselineHRV - minimumHRV) / baselineHRV * 100.0
    }

    public var timeRangeLabel: String {
        clockLabel(forMinuteOfDay: startMinute) + "–" + clockLabel(forMinuteOfDay: endMinute)
    }
}

/// Result of a full-day analysis.
public struct DetectionResult: Sendable, Hashable {
    public let baselineHRV: Double
    /// Absolute HRV value below which a sample counts as depressed.
    public let threshold: Double
    public let episodes: [StressEpisode]

    /// The episode worth surfacing — longest wins, since a 2-hour depression is
    /// a more meaningful story than a 16-minute one.
    public var primaryEpisode: StressEpisode? {
        episodes.max { $0.durationMinutes < $1.durationMinutes }
    }
}

public enum StressDetector {

    /// Median of `values`. Even counts average the two middle elements.
    public static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 1 {
            return sorted[mid]
        }
        return (sorted[mid - 1] + sorted[mid]) / 2.0
    }

    /// Personal baseline: median HRV over the first `baselineWindowMinutes` of
    /// available data. Per-person and per-day, never a population constant —
    /// a 38ms resting HRV is unremarkable for one person and alarming for
    /// another, so a fixed threshold would be meaningless.
    public static func baseline(
        for samples: [BiometricSample],
        configuration: DetectorConfiguration = .default
    ) -> Double {
        guard let first = samples.first else { return 0 }
        let cutoff = first.minuteOfDay + configuration.baselineWindowMinutes
        let filtered = samples.filter { $0.minuteOfDay < cutoff }.map(\.hrv)
        let window = filtered.isEmpty ? samples.map(\.hrv) : filtered
        guard !window.isEmpty else { return 0 }

        switch configuration.baselineStatistic {
        case .median:
            return median(window)
        case .mean:
            return window.reduce(0, +) / Double(window.count)
        }
    }

    /// Full-day analysis.
    ///
    /// Scans for maximal contiguous runs of samples below the threshold, then
    /// discards any run shorter than `persistenceMinutes`. A gap of even one
    /// recovered sample ends a run — this is intentionally strict, so a signal
    /// that keeps bouncing back above baseline is not quietly accumulated into
    /// an episode it never earned.
    public static func analyze(
        samples: [BiometricSample],
        schedule: Schedule,
        configuration: DetectorConfiguration = .default
    ) -> DetectionResult {
        let base = baseline(for: samples, configuration: configuration)
        let threshold = base * (1.0 - configuration.dropFraction)
        guard base > 0, !samples.isEmpty else {
            return DetectionResult(baselineHRV: base, threshold: threshold, episodes: [])
        }

        let ordered = samples.sorted { $0.minuteOfDay < $1.minuteOfDay }
        var episodes: [StressEpisode] = []
        var runStart: Int?
        var runMinimum = Double.greatestFiniteMagnitude

        func closeRun(endingAt end: Int) {
            guard let start = runStart else { return }
            let duration = end - start + 1
            if duration >= configuration.persistenceMinutes {
                let overlapping = schedule.events(overlapping: start, end + 1)
                let contributing = schedule.contributingChain(for: overlapping)
                episodes.append(
                    StressEpisode(
                        startMinute: start,
                        endMinute: end,
                        baselineHRV: base,
                        minimumHRV: runMinimum,
                        overlappingEvents: overlapping,
                        contributingEvents: contributing,
                        backToBackCount: Schedule.longestBackToBackRun(in: contributing),
                        nextEvent: schedule.firstEvent(startingAtOrAfter: end)
                    )
                )
            }
            runStart = nil
            runMinimum = .greatestFiniteMagnitude
        }

        var previousMinute: Int?
        for sample in ordered {
            let depressed = sample.hrv < threshold
            // A hole in the data ends any open run; we cannot claim persistence
            // across minutes we never measured.
            if let previous = previousMinute, sample.minuteOfDay != previous + 1 {
                closeRun(endingAt: previous)
            }
            if depressed {
                if runStart == nil { runStart = sample.minuteOfDay }
                runMinimum = min(runMinimum, sample.hrv)
            } else {
                closeRun(endingAt: sample.minuteOfDay - 1)
            }
            previousMinute = sample.minuteOfDay
        }
        if let last = previousMinute { closeRun(endingAt: last) }

        return DetectionResult(baselineHRV: base, threshold: threshold, episodes: episodes)
    }
}
