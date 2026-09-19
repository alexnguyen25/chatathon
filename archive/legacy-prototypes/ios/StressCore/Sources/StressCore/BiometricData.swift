/// A single minute-level biometric reading.
///
/// Time is stored as minutes since local midnight rather than `Date` so the
/// scenario is reproducible regardless of time zone, and so this type carries
/// no Foundation dependency.
public struct BiometricSample: Sendable, Hashable, Identifiable {
    /// Minutes since local midnight. 540 == 09:00.
    public let minuteOfDay: Int
    /// Beats per minute.
    public let heartRate: Double
    /// RMSSD in milliseconds.
    public let hrv: Double

    public var id: Int { minuteOfDay }

    public init(minuteOfDay: Int, heartRate: Double, hrv: Double) {
        self.minuteOfDay = minuteOfDay
        self.heartRate = heartRate
        self.hrv = hrv
    }
}

extension BiometricSample {
    /// "09:35" — for logging and axis labels.
    public var clockLabel: String {
        let h = minuteOfDay / 60
        let m = minuteOfDay % 60
        return (h < 10 ? "0" : "") + "\(h)" + ":" + (m < 10 ? "0" : "") + "\(m)"
    }
}

/// Formats a minute-of-day as `HH:mm`.
public func clockLabel(forMinuteOfDay minute: Int) -> String {
    let h = minute / 60
    let m = minute % 60
    return (h < 10 ? "0" : "") + "\(h)" + ":" + (m < 10 ? "0" : "") + "\(m)"
}

/// A small, fully deterministic PRNG (SplitMix64).
///
/// `SystemRandomNumberGenerator` is explicitly *not* used anywhere in this
/// package: the demo scenario must produce byte-identical data on every run and
/// every machine, otherwise the tests below are meaningless and the on-stage
/// behaviour is a coin flip.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform in -1.0 ... 1.0.
    public mutating func symmetricUnit() -> Double {
        let v = Double(next() >> 11) * (1.0 / 9007199254740992.0)
        return v * 2.0 - 1.0
    }
}
