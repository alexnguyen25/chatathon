public struct BiometricSample: Sendable {
    public let minute: Int
    public let heartRate: Double
    public let hrv: Double
    public let meetingCountInPreviousHour: Int

    public init(minute: Int, heartRate: Double, hrv: Double, meetingCountInPreviousHour: Int) {
        self.minute = minute
        self.heartRate = heartRate
        self.hrv = hrv
        self.meetingCountInPreviousHour = meetingCountInPreviousHour
    }
}

public struct LoadEpisode: Equatable, Sendable {
    public let startMinute: Int
    public let durationMinutes: Int

    public init(startMinute: Int, durationMinutes: Int) {
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
    }
}

public struct LoadAnalyzer {
    public init() {}

    public func sustainedLoadEpisode(in samples: [BiometricSample]) -> LoadEpisode? {
        guard samples.count >= 3 else { return nil }

        let baselineSamples = samples.prefix(2)
        let baselineHeartRate = baselineSamples.map(\.heartRate).reduce(0, +) / 2
        let baselineHRV = baselineSamples.map(\.hrv).reduce(0, +) / 2

        var currentStart: Int?
        var longestEpisode: LoadEpisode?

        for sample in samples {
            let isElevatedLoad = sample.heartRate >= baselineHeartRate + 10
                && sample.hrv <= baselineHRV * 0.8
                && sample.meetingCountInPreviousHour >= 2

            if isElevatedLoad {
                currentStart = currentStart ?? sample.minute
                continue
            }

            if let start = currentStart {
                let episode = LoadEpisode(startMinute: start, durationMinutes: sample.minute - start)
                if episode.durationMinutes >= 3 && (longestEpisode == nil || episode.durationMinutes > longestEpisode!.durationMinutes) {
                    longestEpisode = episode
                }
                currentStart = nil
            }
        }

        if let start = currentStart, let lastMinute = samples.last?.minute {
            let episode = LoadEpisode(startMinute: start, durationMinutes: lastMinute - start + 1)
            if episode.durationMinutes >= 3 && (longestEpisode == nil || episode.durationMinutes > longestEpisode!.durationMinutes) {
                longestEpisode = episode
            }
        }

        return longestEpisode
    }
}
