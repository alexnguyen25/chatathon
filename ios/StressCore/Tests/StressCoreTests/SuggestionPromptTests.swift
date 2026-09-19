import XCTest
@testable import StressCore

/// The prompt is the product here — an explanation that could apply to anyone
/// on any day is worthless. These pin the specifics into it without a network
/// call.
final class SuggestionPromptTests: XCTestCase {

    private func fixture() throws -> (StressEpisode, SuggestionContext) {
        let day = SyntheticDay.day()
        let episode = try XCTUnwrap(day.detection.primaryEpisode)
        let context = SuggestionContext(
            employeeFirstName: "Sam",
            remainingEvents: day.schedule.events.filter { $0.start > episode.endMinute },
            dayLabel: SyntheticDay.dayLabel,
            breakSuggestion: day.breakSuggestion
        )
        return (episode, context)
    }

    func testPromptCarriesThePersistenceDuration() throws {
        let (episode, context) = try fixture()
        let prompt = AnthropicSuggestionService.userPrompt(episode: episode, context: context)
        XCTAssertTrue(prompt.contains("\(episode.durationMinutes) minutes continuously"))
        XCTAssertTrue(prompt.contains(episode.timeRangeLabel))
    }

    func testPromptCarriesTheChosenSlotAndItsGap() throws {
        let (episode, context) = try fixture()
        let prompt = AnthropicSuggestionService.userPrompt(episode: episode, context: context)
        XCTAssertTrue(prompt.contains("12:00 – 12:15"))
        XCTAssertTrue(prompt.contains("Design review ends at 12:00"))
        XCTAssertTrue(prompt.contains("Lunch starts at 12:30"))
    }

    func testPromptCarriesBothHeartRateRanges() throws {
        let (episode, context) = try fixture()
        let prompt = AnthropicSuggestionService.userPrompt(episode: episode, context: context)
        let comparison = try XCTUnwrap(context.breakSuggestion).comparison
        XCTAssertTrue(prompt.contains("\(comparison.recentLabel) bpm"))
        XCTAssertTrue(prompt.contains("\(comparison.earlierLabel) bpm"))
    }

    func testPromptNamesEveryContributingCalendarEntry() throws {
        let (episode, context) = try fixture()
        let prompt = AnthropicSuggestionService.userPrompt(episode: episode, context: context)
        for title in ["Planning", "Focus", "Design review"] {
            XCTAssertTrue(prompt.contains(title), "missing \(title)")
        }
        XCTAssertTrue(prompt.contains("Consecutive entries with no gap: 3"))
    }

    func testSystemPromptKeepsTimeSelectionAwayFromTheModel() {
        let system = AnthropicSuggestionService.systemPrompt
        XCTAssertTrue(system.contains("Never"))
        XCTAssertTrue(system.contains("not choosing it"))
    }

    func testSystemPromptForbidsTheThingsThatWouldMakeThisAMedicalClaim() {
        // Fragments are kept short so they never span a line wrap in the
        // literal — the assertion should fail when the *meaning* is removed,
        // not when the paragraph is rewrapped.
        let system = AnthropicSuggestionService.systemPrompt
        XCTAssertTrue(system.contains("never to a manager"))
        XCTAssertTrue(system.contains("do not diagnose"))
        XCTAssertTrue(system.contains("not attribute it to stress"))
        XCTAssertFalse(system.contains("  "), "no double spaces from line continuations")
    }

    func testMissingKeyIsReportedRatherThanSendingAnEmptyHeader() {
        struct EmptyStore: APIKeyStore {
            func apiKey() throws -> String { throw SuggestionError.missingAPIKey }
        }
        let service = AnthropicSuggestionService(keyStore: EmptyStore())
        let day = SyntheticDay.day()

        let expectation = expectation(description: "throws")
        Task {
            do {
                _ = try await service.getSuggestion(
                    episode: day.detection.primaryEpisode!,
                    context: SuggestionContext(employeeFirstName: "Sam", remainingEvents: [])
                )
                XCTFail("should have thrown")
            } catch let error as SuggestionError {
                guard case .missingAPIKey = error else {
                    return XCTFail("wrong error: \(error)")
                }
                expectation.fulfill()
            } catch {
                XCTFail("wrong error type: \(error)")
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testStubIsCancellable() async {
        let stub = StubSuggestionService(delay: .seconds(30))
        let day = SyntheticDay.day()

        let task = Task {
            try await stub.getSuggestion(
                episode: day.detection.primaryEpisode!,
                context: SuggestionContext(employeeFirstName: "Sam", remainingEvents: [])
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("cancelled task should not return a value")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
}
