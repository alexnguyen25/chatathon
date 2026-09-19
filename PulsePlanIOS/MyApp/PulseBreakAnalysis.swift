import Foundation

struct PulseBreakEvidence: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let detail: String
}

/// Computed observations, never model-authored measurements or a stress diagnosis.
struct PulseBreakAnalysis {
    var evidence: [PulseBreakEvidence] = []
    var continuousMinutes = 0
    var recordedSleepIsShort = false
    var readingsChanged = false
    var heartSignal: PulseHeartSignal?

    var prompt: String {
        evidence.map { "\($0.title): \($0.detail)" }.joined(separator: "\n")
    }

    static func build(readings: [TodayHeartReading], metrics: HealthMetricSnapshot,
                      events: [CalendarEvent], now: Date, slot: DateInterval?) -> Self {
        var result = Self()
        result.heartSignal = PulseHeartSignal.assess(readings, now: now)
        let contextEnd = slot?.start ?? now
        let dayStart = Calendar.current.startOfDay(for: now)
        let timed = events.filter { !$0.isAllDay && $0.endDate > $0.startDate && $0.endDate > dayStart }
        var merged: [DateInterval] = []
        for event in timed.filter({ $0.startDate < contextEnd }).sorted(by: { $0.startDate < $1.startDate }) {
            let interval = DateInterval(start: max(dayStart, event.startDate), end: min(contextEnd, event.endDate))
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else { merged.append(interval) }
        }
        if let run = merged.last, abs(run.end.timeIntervalSince(contextEnd)) < 1 {
            result.continuousMinutes = Int(run.duration / 60)
        }
        let workload = result.continuousMinutes > 0
            ? "\(result.continuousMinutes) minutes of back-to-back calendar blocks before \(contextEnd.formatted(date: .omitted, time: .shortened)). Calendar load is context, not the reason this app flags a break."
            : "\(timed.count) timed calendar blocks today. Availability alone does not trigger a break suggestion."
        result.evidence.append(PulseBreakEvidence(id: "schedule", symbol: "calendar", title: "Room after a busy stretch", detail: workload))

        let observed = readings.filter { $0.date >= dayStart && $0.date <= now && $0.bpm.isFinite && $0.bpm > 0 }
        let cutoff = now.addingTimeInterval(-30 * 60)
        let recent = observed.filter { $0.date >= cutoff }
        let earlier = observed.filter { $0.date < cutoff }
        if recent.count >= 3, earlier.count >= 3 {
            let recentMean = recent.map(\.bpm).reduce(0, +) / Double(recent.count)
            let earlierMean = earlier.map(\.bpm).reduce(0, +) / Double(earlier.count)
            result.readingsChanged = result.heartSignal?.shouldSuggest ?? false
            result.evidence.append(PulseBreakEvidence(id: "heart", symbol: "heart", title: "Heart-rate context",
                detail: "Last 30 min: \(Int(recentMean.rounded())) BPM sample average (\(recent.count) readings), versus \(Int(earlierMean.rounded())) earlier (\(earlier.count)). Activity and recording conditions can explain differences."))
        } else {
            result.evidence.append(PulseBreakEvidence(id: "heart", symbol: "heart", title: "Limited heart-rate context",
                detail: "Not enough recent and earlier readings to compare. An open calendar slot alone will not trigger a suggestion."))
        }

        if let hrv = metrics.hrvSDNN, hrv.isFinite, hrv > 0,
           let timestamp = metrics.hrvTimestamp, timestamp >= dayStart, timestamp <= now,
           let baseline = metrics.hrvBaselineSDNN, baseline.isFinite, baseline > 0 {
            let difference = Int(((hrv - baseline) / baseline * 100).rounded())
            let comparison = difference == 0 ? "about the same as" : "\(abs(difference))% \(difference < 0 ? "below" : "above")"
            result.evidence.append(PulseBreakEvidence(id: "hrv", symbol: "waveform.path.ecg", title: "HRV in your own context",
                detail: "Latest SDNN: \(Int(hrv.rounded())) ms at \(timestamp.formatted(date: .omitted, time: .shortened)); \(comparison) your prior 7-day sample average of \(Int(baseline.rounded())) ms. This is not a stress score; recording conditions matter."))
        } else if let hrv = metrics.hrvSDNN, hrv.isFinite, hrv > 0,
                  let timestamp = metrics.hrvTimestamp, timestamp >= dayStart, timestamp <= now {
            result.evidence.append(PulseBreakEvidence(id: "hrv", symbol: "waveform.path.ecg", title: "HRV without a comparison",
                detail: "Latest SDNN: \(Int(hrv.rounded())) ms. Not enough prior readings for a personal comparison; no universal good/bad threshold is applied."))
        }
        if let sleep = metrics.sleepHours, sleep.isFinite, sleep > 0 {
            result.recordedSleepIsShort = sleep < 7
            let hours = Int(sleep)
            let minutes = Int(((sleep - Double(hours)) * 60).rounded())
            result.evidence.append(PulseBreakEvidence(id: "sleep", symbol: "bed.double", title: "Recorded sleep",
                detail: "\(hours)h \(minutes)m recorded overnight. \(sleep < 7 ? "Less than the general 7+ hour recommendation for adults 18–60. " : "")Records can be incomplete; a break does not replace sleep."))
        }
        return result
    }
}
