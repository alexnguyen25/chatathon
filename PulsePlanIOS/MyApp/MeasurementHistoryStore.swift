import Combine
import Foundation

struct MeasurementSession: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let startedAt: Date
    let endedAt: Date
    let averageHeartRate: Double
    let peakHeartRate: Double
}

@MainActor
final class MeasurementHistoryStore: ObservableObject {
    @Published private(set) var sessions: [MeasurementSession] = []

    private let storageKey = "pulsePlan.measurementSessions"

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode([MeasurementSession].self, from: data)
        else { return }
        sessions = saved.sorted { $0.startedAt > $1.startedAt }
    }

    func add(_ session: MeasurementSession) {
        sessions.insert(session, at: 0)
        sessions = Array(sessions.prefix(30))
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
