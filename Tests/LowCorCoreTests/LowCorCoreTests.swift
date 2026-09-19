import Foundation
import XCTest
@testable import LowCorCore

final class LowCorCoreTests: XCTestCase {
    private var now: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 12))!
    }

    private func time(_ minutes: Double) -> Date { now.addingTimeInterval(minutes * 60) }

    private func reading(_ minutes: Double, _ bpm: Double) -> TodayHeartReading {
        TodayHeartReading(id: UUID(), date: time(minutes), bpm: bpm, source: "Test fixture")
    }

    private var baseline: [TodayHeartReading] {
        [-90.0, -80, -70, -60].map { reading($0, 70) }
    }

    private func recent(_ bpm: Double) -> [TodayHeartReading] {
        [-25.0, -20, -15, -10, -5].map { reading($0, bpm) }
    }

    private func busy(_ start: Double, _ end: Double) -> DateInterval {
        DateInterval(start: time(start), end: time(end))
    }

    private func event(_ id: String, _ start: Double, _ end: Double, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: id, startDate: time(start), endDate: time(end), isAllDay: allDay)
    }

    private func metrics(hrv: Double? = nil, baseline: Double? = nil, sleep: Double? = nil,
                         timestamp: Date? = nil) -> HealthMetricSnapshot {
        HealthMetricSnapshot(hrvSDNN: hrv, hrvBaselineSDNN: baseline, restingHeartRate: nil,
                             sleepHours: sleep, hrvSampleCount: hrv == nil ? 0 : 1, hrvTimestamp: timestamp)
    }

    private func analysis(_ metrics: HealthMetricSnapshot, events: [CalendarEvent] = []) -> PulseBreakAnalysis {
        PulseBreakAnalysis.build(readings: baseline + recent(70), metrics: metrics,
                                 events: events, now: now, slot: nil)
    }

    func testFictionalDemoHasSustainedRiseAndNoonOpening() throws {
        let demo = PulseDemoDay(date: now)
        let signal = PulseHeartSignal.assess(demo.readings, now: demo.now)
        XCTAssertEqual(signal.state, .sustainedRise)
        XCTAssertTrue(signal.shouldSuggest)
        let slot = try XCTUnwrap(CalendarAvailability.nextReviewableBreak(
            now: demo.now, before: time(60), busy: demo.events.map {
                DateInterval(start: $0.startDate, end: $0.endDate)
            }))
        XCTAssertEqual(slot.start, now)
        XCTAssertEqual(slot.duration, 15 * 60)
    }

    func testStableReadingsDoNotSuggestBreak() {
        let signal = PulseHeartSignal.assess(baseline + recent(70), now: now)
        XCTAssertEqual(signal.state, .noSustainedRise)
        XCTAssertFalse(signal.shouldSuggest)
        XCTAssertEqual(signal.recentAverage, 70)
        XCTAssertEqual(signal.earlierAverage, 70)
        XCTAssertEqual(signal.sampleCount, 5)
        XCTAssertEqual(signal.spanMinutes, 20)
    }

    func testOneLargeSpikeDoesNotCountAsSustained() {
        let samples = baseline + [-25.0, -20, -15, -10].map { reading($0, 70) } + [reading(-5, 250)]
        XCTAssertEqual(PulseHeartSignal.assess(samples, now: now).state, .noSustainedRise)
    }

    func testEmptyAndTooFewReadingsAreInsufficient() {
        for samples in [[], baseline + [reading(-10, 120)], recent(120)] {
            let signal = PulseHeartSignal.assess(samples, now: now)
            XCTAssertEqual(signal.state, .insufficientData)
            XCTAssertFalse(signal.shouldSuggest)
            XCTAssertNil(signal.recentAverage)
        }
    }

    func testStaleLastReadingIsInsufficient() {
        let samples = baseline + [-30.0, -25, -20, -15].map { reading($0, 120) }
        XCTAssertEqual(PulseHeartSignal.assess(samples, now: now).state, .insufficientData)
    }

    func testGapOverTenMinutesIsInsufficient() {
        let samples = baseline + [-29.0, -25, -10, -5].map { reading($0, 120) }
        XCTAssertEqual(PulseHeartSignal.assess(samples, now: now).state, .insufficientData)
    }

    func testRecentReadingsMustSpanFifteenMinutes() {
        let samples = baseline + [-8.0, -6, -4, -2].map { reading($0, 120) }
        XCTAssertEqual(PulseHeartSignal.assess(samples, now: now).state, .insufficientData)
    }

    func testEarlierReadingsMustSpanFifteenMinutes() {
        let samples = [-44.0, -43, -42, -41].map { reading($0, 70) } + recent(120)
        XCTAssertEqual(PulseHeartSignal.assess(samples, now: now).state, .insufficientData)
    }

    func testFuturePreviousDayAndInvalidValuesCannotCreateRise() {
        let ignored = [reading(1, 200), reading(10, 200), reading(-24 * 60, 1),
                       reading(-5, .nan), reading(-10, .infinity), reading(-15, 0), reading(-20, -50)]
        let signal = PulseHeartSignal.assess(baseline + recent(70) + ignored, now: now)
        XCTAssertEqual(signal.state, .noSustainedRise)
        XCTAssertEqual(signal.recentAverage, 70)
        XCTAssertEqual(signal.earlierAverage, 70)
        XCTAssertEqual(signal.sampleCount, 5)
    }

    func testRepeatedReadingAtOneTimestampDoesNotProvideTimeCoverage() {
        let duplicate = reading(-5, 120)
        XCTAssertEqual(PulseHeartSignal.assess(baseline + Array(repeating: duplicate, count: 10), now: now).state,
                       .insufficientData)
    }

    func testUnsortedReadingsGiveSameSignal() {
        let samples = baseline + recent(120)
        let forward = PulseHeartSignal.assess(samples, now: now)
        let reverse = PulseHeartSignal.assess(Array(samples.reversed()), now: now)
        XCTAssertEqual(reverse.state, forward.state)
        XCTAssertEqual(reverse.recentAverage, forward.recentAverage)
        XCTAssertEqual(reverse.spanMinutes, forward.spanMinutes)
    }

    func testFreeCalendarLeavesFiveMinutesForReview() throws {
        let slot = try XCTUnwrap(CalendarAvailability.nextReviewableBreak(now: now, before: time(60), busy: []))
        XCTAssertEqual(slot.start, time(5))
        XCTAssertEqual(slot.end, time(20))
    }

    func testMeetingEndIsEligibleWithoutExtraMinute() throws {
        let slot = try XCTUnwrap(CalendarAvailability.nextReviewableBreak(
            now: time(-5), before: time(60), busy: [busy(-30, 0)]))
        XCTAssertEqual(slot.start, now)
    }

    func testUnsortedOverlappingAndNestedMeetingsAreSkipped() throws {
        let slot = try XCTUnwrap(CalendarAvailability.nextAvailableSlot(
            after: now, before: time(90), busy: [busy(10, 40), busy(-5, 20), busy(15, 25), busy(40, 50)]))
        XCTAssertEqual(slot.start, time(50))
    }

    func testExactFifteenMinuteGapFits() throws {
        let slot = try XCTUnwrap(CalendarAvailability.nextAvailableSlot(
            after: now, before: time(60), busy: [busy(-30, 0), busy(15, 60)]))
        XCTAssertEqual(slot.start, now)
        XCTAssertEqual(slot.end, time(15))
    }

    func testNoSlotReturnsNil() {
        XCTAssertNil(CalendarAvailability.nextAvailableSlot(after: now, before: time(60), busy: [busy(-10, 55)]))
        XCTAssertNil(CalendarAvailability.nextReviewableBreak(now: now, before: time(19), busy: []))
    }

    func testInvalidDurationAndReversedWindowReturnNil() {
        for duration in [0.0, -1, .infinity, .nan] {
            XCTAssertNil(CalendarAvailability.nextAvailableSlot(after: now, before: time(60), busy: [], duration: duration))
        }
        XCTAssertNil(CalendarAvailability.nextAvailableSlot(after: now, before: time(-1), busy: []))
    }

    func testSleepMergesDuplicateOverlappingAndTouchingIntervals() throws {
        let intervals = [busy(-360, -180), busy(-480, -300), busy(-480, -300), busy(-180, -120)]
        XCTAssertEqual(try XCTUnwrap(HealthMetricSnapshot.mergedSleepHours(intervals)), 6, accuracy: 0.0001)
    }

    func testSleepAddsSeparatePeriodsAndIgnoresZeroLength() throws {
        XCTAssertEqual(try XCTUnwrap(HealthMetricSnapshot.mergedSleepHours(
            [busy(-480, -360), busy(-300, -240), busy(-200, -200)])), 3, accuracy: 0.0001)
        XCTAssertNil(HealthMetricSnapshot.mergedSleepHours([]))
        XCTAssertNil(HealthMetricSnapshot.mergedSleepHours([busy(-1, -1)]))
    }

    func testUnavailableMetricsRemainAbsentFromEvidence() {
        let result = analysis(.empty)
        XCTAssertEqual(result.evidence.map(\.id), ["schedule", "heart"])
        XCTAssertFalse(result.recordedSleepIsShort)
        XCTAssertFalse(result.readingsChanged)
        XCTAssertTrue(HealthMetricSnapshot.empty.summary.contains("unavailable"))
    }

    func testInvalidOptionalMetricsAreExcludedFromEvidence() {
        for value in [0.0, -1, .nan, .infinity] {
            let result = analysis(metrics(hrv: value, baseline: 44, sleep: value, timestamp: time(-5)))
            XCTAssertFalse(result.evidence.contains { $0.id == "hrv" || $0.id == "sleep" })
            XCTAssertFalse(result.recordedSleepIsShort)
        }
    }

    func testHRVRequiresCurrentNonFutureTimestamp() {
        for timestamp in [nil, time(1), time(-24 * 60)] {
            XCTAssertFalse(analysis(metrics(hrv: 26, baseline: 44, timestamp: timestamp)).evidence.contains { $0.id == "hrv" })
        }
        let result = analysis(metrics(hrv: 26, baseline: 44, timestamp: time(-5)))
        XCTAssertTrue(result.evidence.contains { $0.id == "hrv" && $0.title == "HRV in your own context" })
    }

    func testHRVWithoutValidPersonalBaselineHasNoComparison() {
        for reference in [nil, 0, -1, Double.nan, Double.infinity] {
            let result = analysis(metrics(hrv: 26, baseline: reference, timestamp: time(-5)))
            XCTAssertTrue(result.evidence.contains { $0.id == "hrv" && $0.title == "HRV without a comparison" })
        }
    }

    func testCalendarEvidenceMergesBusyRunAndIgnoresAllDayAndInvalidEvents() {
        let events = [event("a", -90, -45), event("b", -60, -30), event("c", -30, 15),
                      event("all-day", -600, 600, allDay: true), event("invalid", -100, -110)]
        let result = analysis(.empty, events: events)
        XCTAssertEqual(result.continuousMinutes, 90)
        XCTAssertFalse(result.readingsChanged)
    }

    func testFictionalDemoEvidenceUsesActualSignalAndOptionalObservations() {
        let demo = PulseDemoDay(date: now)
        let result = PulseBreakAnalysis.build(readings: demo.readings, metrics: .demo(now: demo.now),
                                              events: demo.events, now: demo.now, slot: busy(0, 15))
        XCTAssertTrue(result.readingsChanged)
        XCTAssertEqual(result.continuousMinutes, 180)
        XCTAssertEqual(result.evidence.map(\.id), ["schedule", "heart", "hrv", "sleep"])
        XCTAssertTrue(result.prompt.contains("Activity and recording conditions can explain differences"))
    }
}
