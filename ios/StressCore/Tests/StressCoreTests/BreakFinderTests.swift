import XCTest
@testable import StressCore

final class BreakFinderTests: XCTestCase {

    // MARK: - Gaps

    func testGapsAreTheClearStretchesBetweenEvents() {
        let gaps = BreakFinder.gaps(in: SyntheticDay.schedule())

        // 12:00–12:30 between the review and lunch is the one the flow uses.
        XCTAssertTrue(gaps.contains {
            $0.start == 12 * 60 && $0.end == 12 * 60 + 30
        })

        // Planning starts exactly at 09:00, so there is no gap before it.
        XCTAssertFalse(gaps.contains { $0.start == SyntheticDay.dayStartMinute })
    }

    func testGapsShorterThanTheBreakAreNotOffered() {
        let schedule = Schedule([
            CalendarEvent(id: "a", title: "A", kind: .sync, start: 600, end: 660),
            CalendarEvent(id: "b", title: "B", kind: .sync, start: 668, end: 720)  // 8 min
        ])
        let gaps = BreakFinder.gaps(in: schedule, minimumMinutes: 15)
        XCTAssertFalse(gaps.contains { $0.start == 660 })
    }

    func testGapsCarryTheEventsOnEitherSide() throws {
        let gaps = BreakFinder.gaps(in: SyntheticDay.schedule())
        let midday = try XCTUnwrap(gaps.first { $0.start == 12 * 60 })
        XCTAssertEqual(midday.previousEvent?.id, "design-review")
        XCTAssertEqual(midday.nextEvent?.id, "lunch")
        XCTAssertEqual(midday.durationMinutes, 30)
    }

    // MARK: - The suggestion

    func testSuggestionLandsInTheMiddayGap() throws {
        let day = SyntheticDay.day()
        let suggestion = try XCTUnwrap(day.breakSuggestion)

        XCTAssertEqual(suggestion.start, 12 * 60)
        XCTAssertEqual(suggestion.end, 12 * 60 + 15)
        XCTAssertEqual(suggestion.durationMinutes, 15)
        XCTAssertEqual(suggestion.gap.previousEvent?.title, "Design review")
        XCTAssertEqual(suggestion.gap.nextEvent?.title, "Lunch")
    }

    func testSuggestionNeverOverrunsAShortGap() throws {
        // A 20-minute gap must yield a 15-minute break, not a 15-minute break
        // that spills into the next meeting.
        let schedule = Schedule([
            CalendarEvent(id: "a", title: "A", kind: .review, start: 9 * 60, end: 11 * 60),
            CalendarEvent(id: "b", title: "B", kind: .sync, start: 11 * 60 + 20, end: 12 * 60)
        ])
        let samples = SyntheticDay.samples()
        let detection = StressDetector.analyze(samples: samples, schedule: schedule)
        let suggestion = try XCTUnwrap(
            BreakFinder.suggest(samples: samples, schedule: schedule, detection: detection)
        )
        XCTAssertLessThanOrEqual(suggestion.end, suggestion.gap.end)
    }

    func testComparisonMatchesTheCopyOnTheDetailScreen() throws {
        let suggestion = try XCTUnwrap(SyntheticDay.day().breakSuggestion)
        let comparison = suggestion.comparison

        // The detail screen reads:
        // "84–96 BPM during the last hour, compared with 68–76 earlier."
        XCTAssertEqual(comparison.recentLabel, "84–96")
        XCTAssertEqual(comparison.earlierLabel, "68–76")
        XCTAssertGreaterThan(comparison.riseBPM, 15)
        XCTAssertGreaterThan(comparison.recentHigh, comparison.earlierHigh)
    }

    func testSuggestionIsBackedByTheCorroboratingEpisode() throws {
        let suggestion = try XCTUnwrap(SyntheticDay.day().breakSuggestion)
        let episode = try XCTUnwrap(suggestion.episode)
        XCTAssertGreaterThan(episode.durationMinutes, 45)
        XCTAssertEqual(episode.overlappingEvents.map(\.id), ["design-review"])
    }

    func testNoGapMeansNoSuggestionRatherThanAnInventedSlot() {
        // A wall-to-wall day. Proposing a break the person cannot take would
        // be worse than proposing nothing.
        let schedule = Schedule([
            CalendarEvent(id: "a", title: "A", kind: .sync,
                          start: SyntheticDay.dayStartMinute, end: SyntheticDay.dayEndMinute)
        ])
        let samples = SyntheticDay.samples()
        let detection = StressDetector.analyze(samples: samples, schedule: schedule)
        XCTAssertNil(
            BreakFinder.suggest(samples: samples, schedule: schedule, detection: detection)
        )
    }

    func testSuggestionIsDeterministic() {
        XCTAssertEqual(SyntheticDay.day().breakSuggestion, SyntheticDay.day().breakSuggestion)
    }
}
