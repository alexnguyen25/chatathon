// Historical UI, excluded from the current app target.
import Combine
import HealthKit
import SwiftUI

struct ContentView: View {
    @StateObject private var measurement = HealthMeasurementStore()
    @StateObject private var calendar = CalendarStore()
    @StateObject private var history = MeasurementHistoryStore()
    @State private var selectedEventID: String?

    private var selectedEvent: CalendarEvent? {
        calendar.events.first { $0.id == selectedEventID }
    }

    var body: some View {
        TabView {
            liveTab
                .tabItem { Label("Live", systemImage: "heart.text.square") }
            ExampleDayView()
                .tabItem { Label("Example day", systemImage: "calendar") }
        }
        .tint(PulsePlanTheme.forest)
    }

    private var liveTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                Label("PulsePlan", systemImage: "waveform.path.ecg")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PulsePlanTheme.ink)
                    .tint(PulsePlanTheme.forest)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Live heart rate")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(PulsePlanTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Label(measurement.isMeasuring ? "Collecting via HealthKit" : "Ready for a private focus session", systemImage: "circle.fill")
                    .foregroundStyle(PulsePlanTheme.secondary)
                    .tint(measurement.isMeasuring ? .green : PulsePlanTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                GroupBox("Meeting context") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(calendar.status).font(.footnote).foregroundStyle(.secondary)
                        Button("Connect calendar") { Task { await calendar.requestAccessAndLoadToday() } }.buttonStyle(.bordered)
                        if !calendar.events.isEmpty {
                            Picker("Session context", selection: $selectedEventID) {
                                Text("Personal focus").tag(nil as String?)
                                ForEach(calendar.events) { event in
                                    Text(event.title).tag(Optional(event.id))
                                }
                            }
                            Text(selectedEvent.map { "Saving this session with \($0.title)." } ?? "Saving this as personal focus time.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Live focus session") {
                    VStack(spacing: 12) {
                        Text(measurement.status).foregroundStyle(PulsePlanTheme.secondary).multilineTextAlignment(.center)
                        Image(systemName: "heart").font(.system(size: 34)).foregroundStyle(PulsePlanTheme.terracotta)
                        Text(measurement.heartRate.map { "\(Int($0.rounded()))" } ?? "—").font(.system(size: 88, weight: .semibold, design: .rounded)).foregroundStyle(PulsePlanTheme.ink).monospacedDigit()
                        Text("BPM · Latest reading").foregroundStyle(PulsePlanTheme.secondary)
                        if let baseline = measurement.baselineHeartRate, let current = measurement.heartRate {
                            Text("Baseline \(Int(baseline.rounded())) BPM · \(Int((current - baseline).rounded())) BPM from baseline").font(.footnote).foregroundStyle(.secondary)
                        }
                        Button(measurement.isMeasuring ? "End session" : "Start focus session") {
                            measurement.isMeasuring
                                ? measurement.stopMeasurement()
                                : measurement.startMeasurement(title: selectedEvent?.title ?? "Personal focus")
                        }.buttonStyle(.borderedProminent).tint(measurement.isMeasuring ? .red : PulsePlanTheme.forest)
                        Button("Allow Health access") { measurement.requestAuthorization() }.buttonStyle(.bordered)
                    }
                }
                GroupBox("Recent sessions") {
                    if history.sessions.isEmpty {
                        Text("Finished focus sessions will appear here on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(history.sessions.prefix(5)) { session in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title).font(.subheadline.weight(.medium))
                                    Text("Avg \(Int(session.averageHeartRate.rounded())) BPM · Peak \(Int(session.peakHeartRate.rounded())) BPM · \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Text("Health and calendar data stay on this device. This is context tracking, not a stress or medical diagnosis.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding()
        }
        .onChange(of: measurement.finishedSession) { _, session in
            if let session { history.add(session) }
        }
        .background(PulsePlanTheme.canvas)
    }
}

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
                Task { @MainActor in
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
            builder.endCollection(withEnd: date) { _, _ in
                builder.finishWorkout { _, error in
                    Task { @MainActor in
                        self.isMeasuring = false
                        self.session = nil
                        self.builder = nil
                        if error == nil, let record {
                            self.finishedSession = record
                            self.status = "Session saved locally and in Health."
                        } else {
                            self.status = "Measurement ended with an error."
                        }
                    }
                }
            }
            workoutSession.end()
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

#Preview {
    ContentView()
}
