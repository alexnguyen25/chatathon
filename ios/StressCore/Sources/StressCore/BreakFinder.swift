/// An empty stretch between two calendar entries.
public struct CalendarGap: Sendable, Hashable {
    public let start: Int
    public let end: Int
    public let previousEvent: CalendarEvent?
    public let nextEvent: CalendarEvent?

    public var durationMinutes: Int { end - start }
    public var timeRangeLabel: String {
        clockLabel(forMinuteOfDay: start) + "–" + clockLabel(forMinuteOfDay: end)
    }
}

/// Recent heart rate against earlier heart rate, as a range rather than a
/// single number.
///
/// A range is used deliberately. One averaged figure invites the reading
/// "my heart rate is 90", which is a claim about the person; a spread reads as
/// what it is — an observation about a window of time.
public struct HeartRateComparison: Sendable, Hashable {
    public let recentLow: Int
    public let recentHigh: Int
    public let earlierLow: Int
    public let earlierHigh: Int
    public let recentStart: Int
    public let recentEnd: Int

    public var recentLabel: String { "\(recentLow)–\(recentHigh)" }
    public var earlierLabel: String { "\(earlierLow)–\(earlierHigh)" }
    /// Midpoint-to-midpoint rise, for the prompt.
    public var riseBPM: Int {
        ((recentLow + recentHigh) - (earlierLow + earlierHigh)) / 2
    }
}

/// A proposed break: when, in which gap, and the two reasons behind it.
public struct BreakSuggestion: Sendable, Hashable, Identifiable {
    public let start: Int
    public let end: Int
    public let gap: CalendarGap
    public let comparison: HeartRateComparison
    /// The corroborating HRV episode, when there is one. The break stands on
    /// the calendar gap alone; this only strengthens it.
    public let episode: StressEpisode?

    public var id: Int { start }
    public var durationMinutes: Int { end - start }
    public var timeRangeLabel: String {
        clockLabel(forMinuteOfDay: start) + " – " + clockLabel(forMinuteOfDay: end)
    }
}

public enum BreakFinder {

    public static let defaultBreakMinutes = 15
    /// A gap shorter than this is not usable — by the time you have stood up
    /// it is over.
    public static let minimumGapMinutes = 15

    /// Every clear stretch between events, within the working day.
    public static func gaps(
        in schedule: Schedule,
        dayStart: Int = SyntheticDay.dayStartMinute,
        dayEnd: Int = SyntheticDay.dayEndMinute,
        minimumMinutes: Int = minimumGapMinutes
    ) -> [CalendarGap] {
        let events = schedule.events.sorted { $0.start < $1.start }
        guard !events.isEmpty else {
            return [CalendarGap(start: dayStart, end: dayEnd,
                                previousEvent: nil, nextEvent: nil)]
        }

        var result: [CalendarGap] = []
        var cursor = dayStart
        var previous: CalendarEvent?

        for event in events {
            if event.start - cursor >= minimumMinutes {
                result.append(CalendarGap(start: cursor, end: event.start,
                                          previousEvent: previous, nextEvent: event))
            }
            cursor = max(cursor, event.end)
            previous = event
        }
        if dayEnd - cursor >= minimumMinutes {
            result.append(CalendarGap(start: cursor, end: dayEnd,
                                      previousEvent: previous, nextEvent: nil))
        }
        return result
    }

    /// Integer BPM range across a window.
    ///
    /// Nearest rounding, not outward. Rounding outward looks conservative but
    /// widens every range by up to a beat at each end, which overstates the
    /// spread — and a range is the one thing on this screen the user is
    /// invited to compare against another range.
    public static func heartRateRange(
        in samples: [BiometricSample],
        from start: Int,
        to end: Int
    ) -> (low: Int, high: Int)? {
        let window = samples.filter { $0.minuteOfDay >= start && $0.minuteOfDay < end }
        guard let low = window.map(\.heartRate).min(),
              let high = window.map(\.heartRate).max() else { return nil }
        return (Int(low.rounded()), Int(high.rounded()))
    }

    /// Picks the break.
    ///
    /// The order matters: find where heart rate actually changed, then find
    /// the first usable gap *after* it. Proposing a break the person cannot
    /// take, or one unrelated to anything that happened, is worse than
    /// proposing nothing — so this returns nil rather than inventing a slot.
    /// Excluded between the "earlier" and "recent" windows.
    ///
    /// Heart rate does not step, it ramps. Letting the earlier window run right
    /// up to the recent one drags the transition minutes into the baseline and
    /// flattens the very difference being reported — the comparison ends up
    /// quietly understating itself. Comparing two settled periods with the
    /// ramp left out is both more honest and what the copy already implies.
    public static let rampBufferMinutes = 30

    public static func suggest(
        samples: [BiometricSample],
        schedule: Schedule,
        detection: DetectionResult,
        breakMinutes: Int = defaultBreakMinutes,
        recentWindowMinutes: Int = 60
    ) -> BreakSuggestion? {
        let available = gaps(in: schedule, minimumMinutes: breakMinutes)
        guard !available.isEmpty else { return nil }

        // Anchor on the corroborated episode when there is one; otherwise on
        // the single hour with the highest mean heart rate.
        let anchorEnd: Int
        if let episode = detection.primaryEpisode {
            anchorEnd = episode.endMinute
        } else if let peak = peakHour(in: samples, windowMinutes: recentWindowMinutes) {
            anchorEnd = peak
        } else {
            return nil
        }

        // First usable gap at or after the anchor; fall back to the last gap
        // of the day so a late episode still gets an answer.
        let gap = available.first { $0.end > anchorEnd } ?? available[available.count - 1]

        let recentStart = max(
            SyntheticDay.dayStartMinute,
            min(anchorEnd, gap.start) - recentWindowMinutes
        )
        let recentEnd = min(anchorEnd, gap.start)
        let earlierEnd = recentStart - rampBufferMinutes
        guard recentEnd > recentStart,
              earlierEnd > SyntheticDay.dayStartMinute,
              let recent = heartRateRange(in: samples, from: recentStart, to: recentEnd),
              let earlier = heartRateRange(
                in: samples, from: SyntheticDay.dayStartMinute, to: earlierEnd
              )
        else { return nil }

        return BreakSuggestion(
            start: gap.start,
            end: min(gap.start + breakMinutes, gap.end),
            gap: gap,
            comparison: HeartRateComparison(
                recentLow: recent.low,
                recentHigh: recent.high,
                earlierLow: earlier.low,
                earlierHigh: earlier.high,
                recentStart: recentStart,
                recentEnd: recentEnd
            ),
            episode: detection.primaryEpisode
        )
    }

    /// End minute of the highest-mean-heart-rate window of `windowMinutes`.
    private static func peakHour(in samples: [BiometricSample], windowMinutes: Int) -> Int? {
        guard samples.count > windowMinutes else { return nil }
        var best: (end: Int, mean: Double)?
        for startIndex in 0 ... (samples.count - windowMinutes) {
            let window = samples[startIndex ..< startIndex + windowMinutes]
            let mean = window.reduce(0) { $0 + $1.heartRate } / Double(windowMinutes)
            if best == nil || mean > best!.mean {
                best = (window[window.endIndex - 1].minuteOfDay, mean)
            }
        }
        return best?.end
    }
}
