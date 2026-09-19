import Combine
import Foundation
import HealthKit

@MainActor
final class TodayHealthStore: ObservableObject {
    @Published private(set) var readings: [TodayHeartReading] = []
    @Published private(set) var status = "Connect Health to read today’s heart-rate data."
    @Published private(set) var isLoading = false
    @Published private(set) var isDemo = false
    @Published private(set) var metrics: HealthMetricSnapshot = .empty
    private var dataRevision = 0

    func setDemo(_ day: PulseDemoDay?) {
        dataRevision += 1
        isLoading = false
        isDemo = day != nil
        readings = day?.readings ?? []
        metrics = day.map { .demo(now: $0.now) } ?? .empty
        status = day == nil ? "Connect Health to read your recorded signals." : "Fictional readings for the demo day. Nothing is written to Apple Health."
    }

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType(.heartRate)
    private let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
    private let restingType = HKQuantityType(.restingHeartRate)
    private let sleepType = HKCategoryType(.sleepAnalysis)

    var summary: String {
        let prefix = isDemo ? "FICTIONAL DEMO DATA. " : ""
        guard let latest = readings.last else {
            return prefix + "No readable heart-rate samples for today. Data may be unavailable or Health read access may not have been granted. " + metrics.summary
        }
        let average = readings.reduce(0) { $0 + $1.bpm } / Double(readings.count)
        return prefix + "Today: \(readings.count) heart-rate samples; sample average \(Int(average.rounded())) BPM. Latest: \(Int(latest.bpm.rounded())) BPM at \(latest.date.formatted(date: .abbreviated, time: .shortened)), source: \(latest.source). Samples are intermittent and do not establish stress or its cause. " + metrics.summary
    }

    func requestAccessAndLoad() async {
        guard !isDemo else { return }
        guard !isLoading else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Health data is unavailable on this device."
            return
        }
        isLoading = true
        let revision = dataRevision
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [heartRateType, hrvType, restingType, sleepType])
            guard revision == dataRevision, !isDemo else { return }
            await loadToday(revision: revision)
        } catch {
            guard revision == dataRevision, !isDemo else { return }
            readings = []
            metrics = .empty
            status = "Could not request Health access: \(error.localizedDescription)"
        }
        if revision == dataRevision { isLoading = false }
    }

    func refresh() async {
        guard !isDemo else { return }
        guard !isLoading else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Health data is unavailable on this device."
            return
        }
        isLoading = true
        let revision = dataRevision
        await loadToday(revision: revision)
        if revision == dataRevision { isLoading = false }
    }

    private func loadToday(revision: Int) async {
        status = "Reading available Health signals…"
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -7, to: start) ?? start.addingTimeInterval(-7 * 86400)
        // Last night's window is yesterday 18:00 through today 12:00 (or now).
        let yesterday = calendar.date(byAdding: .day, value: -1, to: start) ?? start.addingTimeInterval(-86400)
        let sleepStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) ?? yesterday
        let sleepEnd = min(now, calendar.date(bySettingHour: 12, minute: 0, second: 0, of: start) ?? now)
        // Each query fails independently: absent sleep never erases heart rate.
        async let heartSamples = query(heartRateType, start: start, end: now, limit: 1000)
        async let hrvSamples = query(hrvType, start: weekStart, end: now)
        async let restingSamples = query(restingType, start: start, end: now, limit: 1)
        async let sleepSamples = query(sleepType, start: sleepStart, end: sleepEnd, strictStart: false)
        let (heart, hrv, resting, sleep) = await (heartSamples, hrvSamples, restingSamples, sleepSamples)
        guard revision == dataRevision, !isDemo else { return }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        readings = (heart as? [HKQuantitySample] ?? []).compactMap { sample in
            let bpm = sample.quantity.doubleValue(for: bpmUnit)
            guard bpm.isFinite, bpm > 0 else { return nil }
            return TodayHeartReading(id: sample.uuid, date: sample.startDate, bpm: bpm, source: sample.sourceRevision.source.name)
        }.sorted { $0.date < $1.date }
        let hrvValues = (hrv as? [HKQuantitySample] ?? []).filter {
            let value = $0.quantity.doubleValue(for: .secondUnit(with: .milli))
            return value.isFinite && value > 0
        }
        let todayHRV = hrvValues.filter { $0.startDate >= start }
        let previousHRV = hrvValues.filter { $0.startDate < start }
        let reference = previousHRV.count >= 3
            ? previousHRV.reduce(0) { $0 + $1.quantity.doubleValue(for: .secondUnit(with: .milli)) } / Double(previousHRV.count)
            : nil
        let restingBPM = (resting.first as? HKQuantitySample)?.quantity.doubleValue(for: bpmUnit)
        let asleepValues = Set([HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue])
        let asleep = (sleep as? [HKCategorySample] ?? []).compactMap { sample -> DateInterval? in
            guard asleepValues.contains(sample.value) else { return nil }
            let lower = max(sample.startDate, sleepStart)
            let upper = min(sample.endDate, sleepEnd)
            return upper > lower ? DateInterval(start: lower, end: upper) : nil
        }
        metrics = HealthMetricSnapshot(
            hrvSDNN: todayHRV.first?.quantity.doubleValue(for: .secondUnit(with: .milli)),
            hrvBaselineSDNN: reference,
            restingHeartRate: restingBPM.flatMap { $0.isFinite && $0 > 0 ? $0 : nil },
            sleepHours: HealthMetricSnapshot.mergedSleepHours(asleep),
            hrvSampleCount: todayHRV.count,
            hrvTimestamp: todayHRV.first?.startDate
        )
        status = "Read available Health signals. Missing values may mean no records or no read permission."
    }

    private func query(_ type: HKSampleType, start: Date, end: Date, limit: Int = HKObjectQueryNoLimit, strictStart: Bool = true) async -> [HKSample] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: strictStart ? .strictStartDate : [])
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            healthStore.execute(query)
        }
    }
}
