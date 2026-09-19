import XCTest
@testable import StressCore

final class StressDetectorTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a flat day at `baseHRV`, then forces `depressedMinutes` of
    /// samples starting at `dipStart` down to `dipHRV`.
    private func day(
        baseHRV: Double = 60,
        dipStart: Int = 11 * 60,
        depressedMinutes: Int,
        dipHRV: Double = 40
    ) -> [BiometricSample] {
        (9 * 60 ... 17 * 60).map { minute in
            let depressed = minute >= dipStart && minute < dipStart + depressedMinutes
            return BiometricSample(
                minuteOfDay: minute,
                heartRate: 70,
                hrv: depressed ? dipHRV : baseHRV
            )
        }
    }

    private func analyze(
        _ samples: [BiometricSample],
        schedule: Schedule = Schedule([])
    ) -> DetectionResult {
        StressDetector.analyze(samples: samples, schedule: schedule)
    }

    // MARK: - Baseline

    func testBaselineUsesMedianOfFirstThirtyMinutes() {
        // Two wild artefacts inside the baseline window. A mean would be
        // dragged by them; a median must not be.
        var samples = day(depressedMinutes: 0)
        samples[3] = BiometricSample(minuteOfDay: samples[3].minuteOfDay, heartRate: 70, hrv: 300)
        samples[7] = BiometricSample(minuteOfDay: samples[7].minuteOfDay, heartRate: 70, hrv: 2)
        XCTAssertEqual(StressDetector.baseline(for: samples), 60, accuracy: 0.001)
    }

    func testBaselineIgnoresSamplesAfterTheWindow() {
        // Everything after 09:30 collapses; the baseline must not follow it.
        let samples = (9 * 60 ... 17 * 60).map { minute in
            BiometricSample(
                minuteOfDay: minute,
                heartRate: 70,
                hrv: minute < 9 * 60 + 30 ? 64 : 20
            )
        }
        XCTAssertEqual(StressDetector.baseline(for: samples), 64, accuracy: 0.001)
    }

    // MARK: - Persistence check

    func testSingleDepressedSampleDoesNotTrigger() {
        let result = analyze(day(depressedMinutes: 1))
        XCTAssertTrue(result.episodes.isEmpty, "one noisy reading must never raise an episode")
    }

    func testFourteenMinutesIsRejectedAndFifteenIsAccepted() {
        // The boundary is the whole contract of the detector, so pin both sides.
        XCTAssertTrue(analyze(day(depressedMinutes: 14)).episodes.isEmpty)

        let accepted = analyze(day(depressedMinutes: 15)).episodes
        XCTAssertEqual(accepted.count, 1)
        XCTAssertEqual(accepted.first?.durationMinutes, 15)
    }

    func testRecoveryBreaksARunSoTwoShortDipsDoNotCombine() {
        // 10 minutes down, one minute recovered, 10 minutes down again.
        // Twenty depressed samples in total, but no 15-minute run.
        var samples = day(depressedMinutes: 0)
        func depress(_ range: Range<Int>) {
            for minute in range {
                samples[minute - 9 * 60] = BiometricSample(
                    minuteOfDay: minute, heartRate: 70, hrv: 40
                )
            }
        }
        depress(11 * 60 ..< 11 * 60 + 10)
        depress(11 * 60 + 11 ..< 11 * 60 + 21)
        XCTAssertTrue(analyze(samples).episodes.isEmpty)
    }

    func testThresholdIsTwentyPercentBelowBaseline() {
        let result = analyze(day(depressedMinutes: 0))
        XCTAssertEqual(result.threshold, 48, accuracy: 0.001) // 60 * 0.8

        // 49ms is an 18.3% drop: real, but under the bar, for any duration.
        XCTAssertTrue(analyze(day(depressedMinutes: 120, dipHRV: 49)).episodes.isEmpty)

        // 47ms clears it.
        XCTAssertEqual(analyze(day(depressedMinutes: 120, dipHRV: 47)).episodes.count, 1)
    }

    // MARK: - Determinism

    func testGeneratorIsDeterministicAcrossRuns() {
        XCTAssertEqual(SyntheticDay.samples(), SyntheticDay.samples())
    }

    func testDifferentSeedsChangeJitterButNotTheEpisode() {
        let a = SyntheticDay.analyzed(seed: 1)
        let b = SyntheticDay.analyzed(seed: 99)
        XCTAssertNotEqual(a.samples, b.samples, "jitter should differ")
        XCTAssertEqual(
            a.result.episodes.count, b.result.episodes.count,
            "but jitter must never change which episodes fire"
        )
        XCTAssertEqual(a.result.episodes.count, 1)
    }

    // MARK: - The scripted scenario

    func testScriptedDayProducesExactlyOneEpisode() {
        XCTAssertEqual(
            SyntheticDay.analyzed().result.episodes.count, 1,
            "the afternoon dips must not be promoted to episodes"
        )
    }

    func testScriptedEpisodeMatchesTheDesignReview() throws {
        let day = SyntheticDay.analyzed()
        let episode = try XCTUnwrap(day.result.primaryEpisode)

        XCTAssertEqual(day.result.baselineHRV, 62, accuracy: 1.0)
        XCTAssertEqual(day.result.threshold, 49.6, accuracy: 1.0)

        // Starts partway into the 11:00 review, ends just inside the open gap.
        XCTAssertGreaterThanOrEqual(episode.startMinute, 11 * 60 + 8)
        XCTAssertLessThanOrEqual(episode.startMinute, 11 * 60 + 22)
        XCTAssertGreaterThanOrEqual(episode.endMinute, 12 * 60 + 5)
        XCTAssertLessThanOrEqual(episode.endMinute, 12 * 60 + 20)

        XCTAssertGreaterThan(episode.durationMinutes, 45)
        XCTAssertEqual(episode.maxDropPercent, 32.0, accuracy: 3.0)
    }

    func testScriptedEpisodeCarriesItsCalendarContext() throws {
        let episode = try XCTUnwrap(SyntheticDay.analyzed().result.primaryEpisode)

        XCTAssertEqual(episode.overlappingEvents.map(\.id), ["design-review"])

        // Focus ran straight into the review with no gap, so it belongs to the
        // block the person actually sat through.
        XCTAssertEqual(
            episode.contributingEvents.map(\.id),
            ["planning", "focus", "design-review"]
        )
        XCTAssertEqual(episode.backToBackCount, 3)

        // Lunch is the next thing, and the gap before it is the opening.
        XCTAssertEqual(episode.nextEvent?.id, "lunch")
    }

    func testAfternoonBlipCrossesThresholdButIsTooShortToCount() {
        let day = SyntheticDay.analyzed()
        let window = day.samples.filter {
            $0.minuteOfDay >= 14 * 60 + 10 && $0.minuteOfDay <= 14 * 60 + 45
        }
        let depressed = window.filter { $0.hrv < day.result.threshold }

        XCTAssertFalse(depressed.isEmpty, "the blip should genuinely cross the threshold")
        XCTAssertLessThan(depressed.count, 15, "but not for long enough to be an episode")
        XCTAssertFalse(
            day.result.episodes.contains { $0.startMinute > 13 * 60 },
            "nothing in the afternoon should be reported"
        )
    }

    func testHRVRecoversInTheOpenGapBeforeLunch() throws {
        let day = SyntheticDay.analyzed()
        let atLunch = try XCTUnwrap(day.samples.first { $0.minuteOfDay == 12 * 60 + 30 })
        XCTAssertGreaterThan(atLunch.hrv, day.result.threshold)
    }

    func testHeartRateMatchesTheRangesTheScreensQuote() throws {
        let day = SyntheticDay.analyzed()

        // "84–96 BPM during the last hour, compared with 68–76 earlier."
        // The earlier window stops a ramp-buffer short of the recent one, so
        // the climb into the review is in neither.
        let recent = try XCTUnwrap(
            BreakFinder.heartRateRange(in: day.samples, from: 11 * 60, to: 12 * 60)
        )
        let earlier = try XCTUnwrap(
            BreakFinder.heartRateRange(
                in: day.samples,
                from: 9 * 60,
                to: 11 * 60 - BreakFinder.rampBufferMinutes
            )
        )
        XCTAssertEqual(recent.low, 84, accuracy: 1)
        XCTAssertEqual(recent.high, 96, accuracy: 1)
        XCTAssertEqual(earlier.low, 68, accuracy: 1)
        XCTAssertEqual(earlier.high, 76, accuracy: 1)
    }

    func testHeartRateRisesAsHRVFalls() throws {
        let day = SyntheticDay.analyzed()
        let trough = try XCTUnwrap(day.samples.min { $0.hrv < $1.hrv })
        let settled = try XCTUnwrap(day.samples.first { $0.minuteOfDay == 9 * 60 + 5 })
        XCTAssertGreaterThan(trough.heartRate, settled.heartRate + 15)
    }

    /// Not an assertion so much as the sanity check: prints the episode the
    /// demo will actually show, so a human can eyeball it in CI output.
    func testPrintEpisodeSummary() throws {
        let day = SyntheticDay.analyzed()
        let episode = try XCTUnwrap(day.result.primaryEpisode)
        print("""

        ── detected episode ──────────────────────────────
          baseline HRV      \(String(format: "%.1f", day.result.baselineHRV)) ms
          threshold (-20%)  \(String(format: "%.1f", day.result.threshold)) ms
          window            \(episode.timeRangeLabel)
          duration          \(episode.durationMinutes) min
          trough HRV        \(String(format: "%.1f", episode.minimumHRV)) ms
          max drop          \(String(format: "%.1f", episode.maxDropPercent))%
          overlapping       \(episode.overlappingEvents.map(\.title).joined(separator: ", "))
          contributing      \(episode.contributingEvents.map(\.title).joined(separator: ", "))
          back-to-back      \(episode.backToBackCount)
          next on calendar  \(episode.nextEvent.map { "\($0.title) at \(clockLabel(forMinuteOfDay: $0.start))" } ?? "none")
          episodes total    \(day.result.episodes.count)
        ──────────────────────────────────────────────────
        """)
    }

    // MARK: - Back-to-back resolution

    func testBackToBackFlagsRespectTheFiveMinuteTolerance() {
        let schedule = Schedule([
            CalendarEvent(id: "a", title: "A", kind: .planning, start: 600, end: 615),
            CalendarEvent(id: "b", title: "B", kind: .sync, start: 618, end: 660),   // 3 min gap
            CalendarEvent(id: "c", title: "C", kind: .review, start: 720, end: 750)  // 60 min gap
        ])
        XCTAssertEqual(schedule.events.map(\.isBackToBack), [false, true, false])
        XCTAssertEqual(Schedule.longestBackToBackRun(in: schedule.events), 2)
    }
}
