import Combine
import Foundation
import HealthKit

@MainActor
final class HealthMeasurementStore: NSObject, ObservableObject {
    @Published private(set) var heartRate: Double?
    @Published private(set) var baselineHeartRate: Double?
    @Published private(set) var isMeasuring = false
    @Published private(set) var status = "Allow Health access, then start a focus session."
    @Published private(set) var finishedSession: MeasurementSession?
    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType(.heartRate)
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var readings: [Double] = []
    private var sessionTitle = "Personal focus"
    private var sessionStart = Date()

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { status = "Health data is unavailable on this device."; return }
        Task {
            do {
                try await healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [heartRateType])
                status = "Health access requested. You can now start a focus session."
            } catch { status = "Health access could not be requested: \(error.localizedDescription)" }
        }
    }

    func startMeasurement(title: String) {
        guard session == nil else { return }
        do {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .other
            configuration.locationType = .unknown
            let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let newBuilder = newSession.associatedWorkoutBuilder()
            newSession.delegate = self
            newBuilder.delegate = self
            newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session = newSession; builder = newBuilder; readings = []; heartRate = nil; baselineHeartRate = nil; isMeasuring = true; finishedSession = nil
            sessionTitle = title
            status = "Measuring live heart rate for \(title)."
            let start = Date()
            sessionStart = start
            newSession.prepare(); newSession.startActivity(with: start)
            newBuilder.beginCollection(withStart: start) { [weak self] success, error in
                Task { @MainActor [weak self] in
                    guard let self, !success else { return }
                    self.status = "Could not start collection: \(error?.localizedDescription ?? "Unknown error")"
                    self.isMeasuring = false; self.session = nil; self.builder = nil
                }
            }
        } catch { status = "Could not create workout session: \(error.localizedDescription)" }
    }

    func stopMeasurement() { session?.stopActivity(with: Date()); status = "Finishing measurement…" }
}

extension HealthMeasurementStore: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .stopped else { return }
        Task { @MainActor [weak self] in
            guard let self, let builder else { return }
            let record = self.makeSessionRecord(endedAt: date)
            workoutSession.end()
            defer {
                self.isMeasuring = false
                self.session = nil
                self.builder = nil
            }
            do {
                try await builder.endCollection(at: date)
                _ = try await builder.finishWorkout()
                if let record {
                    self.finishedSession = record
                    self.status = "Session saved locally and in Health."
                } else {
                    self.status = "Session ended without heart-rate readings."
                }
            } catch {
                self.status = "Measurement could not be saved: \(error.localizedDescription)"
            }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.isMeasuring = false; self?.session = nil; self?.builder = nil
            self?.status = "Workout session failed: \(error.localizedDescription)"
        }
    }

    private func makeSessionRecord(endedAt: Date) -> MeasurementSession? {
        guard !readings.isEmpty else { return nil }
        return MeasurementSession(
            id: UUID(),
            title: sessionTitle,
            startedAt: sessionStart,
            endedAt: endedAt,
            averageHeartRate: readings.reduce(0, +) / Double(readings.count),
            peakHeartRate: readings.max() ?? 0
        )
    }
}

extension HealthMeasurementStore: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let type = HKQuantityType(.heartRate)
        guard collectedTypes.contains(type), let quantity = workoutBuilder.statistics(for: type)?.mostRecentQuantity() else { return }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        Task { @MainActor [weak self] in
            guard let self else { return }
            heartRate = bpm; readings.append(bpm)
            if readings.count >= 3 { baselineHeartRate = readings.prefix(3).reduce(0, +) / 3 }
        }
    }
}
