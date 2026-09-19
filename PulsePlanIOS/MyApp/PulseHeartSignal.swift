import Foundation

/// An unvalidated MVP pattern detector, not a stress detector or medical threshold.
struct PulseHeartSignal {
    enum State { case insufficientData, noSustainedRise, sustainedRise }
    let state: State
    let recentAverage: Double?
    let earlierAverage: Double?
    let sampleCount: Int
    let spanMinutes: Int

    var shouldSuggest: Bool { state == .sustainedRise }

    var observation: String {
        guard let recentAverage, let earlierAverage else {
            return "There aren’t enough fresh, time-spread readings to compare with earlier today."
        }
        return "Your last 30 minutes averaged \(Int(recentAverage.rounded())) BPM, compared with \(Int(earlierAverage.rounded())) BPM earlier today."
    }

    static func assess(_ readings: [TodayHeartReading], now: Date) -> Self {
        let start = Calendar.current.startOfDay(for: now)
        let observed = readings.filter { $0.date >= start && $0.date <= now && $0.bpm.isFinite && $0.bpm > 0 }
            .sorted { $0.date < $1.date }
        let cutoff = now.addingTimeInterval(-30 * 60)
        let recent = observed.filter { $0.date >= cutoff }
        let earlier = observed.filter { $0.date < cutoff }
        guard recent.count >= 4, earlier.count >= 4,
              let first = recent.first, let last = recent.last,
              let earlierFirst = earlier.first, let earlierLast = earlier.last,
              last.date.timeIntervalSince(first.date) >= 15 * 60,
              earlierLast.date.timeIntervalSince(earlierFirst.date) >= 15 * 60,
              now.timeIntervalSince(last.date) <= 10 * 60,
              zip(recent, recent.dropFirst()).allSatisfy({ $1.date.timeIntervalSince($0.date) <= 10 * 60 }) else {
            return Self(state: .insufficientData, recentAverage: nil, earlierAverage: nil,
                        sampleCount: recent.count, spanMinutes: 0)
        }
        let recentMean = recent.map(\.bpm).reduce(0, +) / Double(recent.count)
        let earlierMean = earlier.map(\.bpm).reduce(0, +) / Double(earlier.count)
        // Product heuristic only. Repeated elevation avoids triggering on one spike.
        let boundary = max(earlierMean + 20, earlierMean * 1.25)
        let elevatedFraction = Double(recent.filter { $0.bpm >= boundary }.count) / Double(recent.count)
        let sustained = recentMean >= boundary && elevatedFraction >= 0.8
        return Self(state: sustained ? .sustainedRise : .noSustainedRise,
                    recentAverage: recentMean, earlierAverage: earlierMean,
                    sampleCount: recent.count, spanMinutes: Int(last.date.timeIntervalSince(first.date) / 60))
    }
}
