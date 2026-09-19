import Foundation

/// Optional values are deliberately unknown rather than represented as zero.
struct HealthMetricSnapshot: Sendable {
    let hrvSDNN: Double?
    let hrvBaselineSDNN: Double?
    let restingHeartRate: Double?
    let sleepHours: Double?
    let hrvSampleCount: Int
    let hrvTimestamp: Date?

    static let empty = HealthMetricSnapshot(hrvSDNN: nil, hrvBaselineSDNN: nil, restingHeartRate: nil, sleepHours: nil, hrvSampleCount: 0, hrvTimestamp: nil)

    static func demo(now: Date) -> HealthMetricSnapshot {
        HealthMetricSnapshot(hrvSDNN: 26, hrvBaselineSDNN: 44, restingHeartRate: 72, sleepHours: 5.6, hrvSampleCount: 4, hrvTimestamp: now.addingTimeInterval(-20 * 60))
    }

    var summary: String {
        let hrv = hrvSDNN.map { "Latest HRV SDNN: \(Int($0.rounded())) ms; \(hrvSampleCount) samples available today" } ?? "HRV SDNN: unavailable"
        let baseline = hrvBaselineSDNN.map { "prior seven-day personal sample average: \(Int($0.rounded())) ms (not a population norm)" } ?? "seven-day personal HRV reference: unavailable (requires at least three samples)"
        let resting = restingHeartRate.map { "Today's recorded resting heart rate: \(Int($0.rounded())) BPM" } ?? "Resting heart rate: unavailable"
        let sleep = sleepHours.map { "Recorded asleep time in last night's window: \(String(format: "%.1f", $0)) hours" } ?? "Last night's sleep: unavailable"
        return "\(hrv); \(baseline). \(resting). \(sleep). Different recording conditions and incomplete wearable coverage limit comparisons. These are observations, not diagnoses or stress measurements."
    }

    /// Merge overlapping sleep records from devices/stages so elapsed time is
    /// counted once. Inputs must already exclude awake and in-bed categories.
    nonisolated static func mergedSleepHours(_ intervals: [DateInterval]) -> Double? {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return nil }
        var seconds = 0.0
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                seconds += current.duration
                current = interval
            }
        }
        return (seconds + current.duration) / 3600
    }
}
