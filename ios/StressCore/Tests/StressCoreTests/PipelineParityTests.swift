import XCTest
@testable import StressCore

/// Checks the Swift detector against `pipeline/analyze_stress.py` on the
/// repository's own data files.
///
/// Two implementations of the same detection is a liability unless something
/// keeps them honest. These tests read `data/biometrics.csv` and
/// `data/calendar.json` and assert the Swift detector reproduces the exact
/// episode recorded in `data/detected_episodes.json`.
final class PipelineParityTests: XCTestCase {

    /// `<repo>/data`, resolved from this file rather than the working
    /// directory — `swift test` does not promise a cwd.
    private var dataDirectory: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 5 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("data")
    }

    private func loadSamples() throws -> [BiometricSample] {
        let text = try String(
            contentsOf: dataDirectory.appendingPathComponent("biometrics.csv"),
            encoding: .utf8
        )
        return try PipelineData.biometrics(fromCSV: text)
    }

    private func loadSchedule() throws -> Schedule {
        let data = try Data(contentsOf: dataDirectory.appendingPathComponent("calendar.json"))
        return try PipelineData.calendar(fromJSON: data)
    }

    // MARK: - Loading

    func testBiometricsCSVLoads() throws {
        let samples = try loadSamples()
        XCTAssertEqual(samples.count, 481)              // 09:00–17:00 inclusive
        let first = try XCTUnwrap(samples.first)
        XCTAssertEqual(first.minuteOfDay, 9 * 60)
        XCTAssertEqual(first.hrv, 63.1, accuracy: 0.001)
        XCTAssertEqual(first.heartRate, 68.4, accuracy: 0.001)
        XCTAssertEqual(samples.last?.minuteOfDay, 17 * 60)
    }

    func testTimestampsAreReadAsWallClockNotDeviceLocalTime() throws {
        // No zone in the file, so a DateFormatter would shift every reading
        // when the demo runs in another timezone. 14:15 must stay 14:15.
        XCTAssertEqual(
            try PipelineData.minuteOfDay(fromISO: "2026-09-19T14:15:00"),
            14 * 60 + 15
        )
    }

    func testCalendarJSONLoads() throws {
        let schedule = try loadSchedule()
        XCTAssertEqual(schedule.events.count, 8)
        XCTAssertEqual(schedule.events.first?.title, "Standup")
        XCTAssertEqual(schedule.events.last?.title, "All-Hands")
    }

    func testCalendarBackToBackFlagsAgreeWithItsOwnTimes() throws {
        // The file states back_to_back per event *and* carries the times it
        // could be derived from. If those ever disagree, one of them is a lie.
        let data = try Data(contentsOf: dataDirectory.appendingPathComponent("calendar.json"))
        let schedule = try PipelineData.calendar(fromJSON: data)
        XCTAssertTrue(
            try PipelineData.pipelineBackToBackFlagsAgree(json: data, schedule: schedule),
            "calendar.json back_to_back flags disagree with its own start/end times"
        )
    }

    // MARK: - Parity

    func testSwiftReproducesThePythonBaselineAndThreshold() throws {
        let samples = try loadSamples()
        let result = StressDetector.analyze(
            samples: samples,
            schedule: try loadSchedule(),
            configuration: .pipelineParity
        )
        // suggestions.json records baseline 64.8, threshold 51.8.
        XCTAssertEqual(result.baselineHRV, 64.8, accuracy: 0.05)
        XCTAssertEqual(result.threshold, 51.8, accuracy: 0.05)
    }

    func testSwiftReproducesThePythonEpisodeExactly() throws {
        let result = StressDetector.analyze(
            samples: try loadSamples(),
            schedule: try loadSchedule(),
            configuration: .pipelineParity
        )

        XCTAssertEqual(result.episodes.count, 1)
        let episode = try XCTUnwrap(result.primaryEpisode)

        // detected_episodes.json: 14:15 -> 15:07, 52 minutes.
        // Python's `end` is the first *recovered* sample; ours is the last
        // depressed one, so it reads one minute earlier for the same span.
        XCTAssertEqual(episode.startMinute, 14 * 60 + 15)
        XCTAssertEqual(episode.endMinute, 15 * 60 + 6)
        XCTAssertEqual(episode.durationMinutes, 52)

        XCTAssertEqual(
            episode.overlappingEvents.map(\.title),
            ["Sprint Planning", "Cross-team Sync"]
        )
        XCTAssertTrue(episode.overlappingEvents.contains { $0.isBackToBack })
        XCTAssertEqual(episode.nextEvent?.title, "Deep Work Block")
        XCTAssertEqual(episode.nextEvent?.start, 15 * 60 + 15)
    }

    // MARK: - The divergence, pinned

    /// The two configurations genuinely disagree, and this records by how much
    /// rather than leaving it to be discovered during a demo.
    ///
    /// `pipeline/analyze_stress.py` uses a 60-minute **mean** baseline and a
    /// 20-minute persistence floor. The spec this app was written to — and
    /// `claude.md` — call for a 30-minute **median** baseline and 15 minutes.
    /// Same data, different answer. The team needs to pick one.
    func testDefaultAndPipelineConfigurationsDisagreeOnTheSameData() throws {
        let samples = try loadSamples()
        let schedule = try loadSchedule()

        let strict = StressDetector.analyze(
            samples: samples, schedule: schedule, configuration: .default
        )
        let parity = StressDetector.analyze(
            samples: samples, schedule: schedule, configuration: .pipelineParity
        )

        XCTAssertNotEqual(
            strict.baselineHRV, parity.baselineHRV,
            "median-of-30 and mean-of-60 should not coincidentally match"
        )
        // A shorter persistence floor can only ever find the same or more.
        XCTAssertGreaterThanOrEqual(strict.episodes.count, parity.episodes.count)
    }
}
