import XCTest
@testable import PulsePlanCore

final class LoadAnalyzerTests: XCTestCase {
func testDetectsSustainedElevatedLoadDuringMeetingHeavyWindow() {
    let samples = [
        BiometricSample(minute: 0, heartRate: 70, hrv: 60, meetingCountInPreviousHour: 0),
        BiometricSample(minute: 1, heartRate: 71, hrv: 59, meetingCountInPreviousHour: 0),
        BiometricSample(minute: 2, heartRate: 86, hrv: 40, meetingCountInPreviousHour: 3),
        BiometricSample(minute: 3, heartRate: 85, hrv: 39, meetingCountInPreviousHour: 3),
        BiometricSample(minute: 4, heartRate: 84, hrv: 38, meetingCountInPreviousHour: 3),
        BiometricSample(minute: 5, heartRate: 83, hrv: 39, meetingCountInPreviousHour: 3)
    ]

    let episode = LoadAnalyzer().sustainedLoadEpisode(in: samples)

    XCTAssertEqual(episode, LoadEpisode(startMinute: 2, durationMinutes: 4))
}
}
