import Foundation
import Observation
import StressCore

public enum DayRoute: Hashable {
    case suggestion
    case addBreak
    case added
}

/// State for the Example day tab: the analysed day, where we are in the
/// add-a-break flow, the editable draft, and the LLM explanation.
@MainActor
@Observable
public final class DayFlowModel {

    public enum ExplanationState: Equatable {
        case idle
        case loading
        case ready(String)
        case failed(String)

        public var isLoading: Bool { self == .loading }
    }

    /// The event the user is about to add. Editable, because the mockup's
    /// Starts/Ends rows are affordances, not decoration.
    public struct Draft: Equatable {
        public var title: String
        public var startMinute: Int
        public var endMinute: Int
        public var calendarName: String
        public var alert: String

        public var durationMinutes: Int { endMinute - startMinute }
    }

    public let day: DayModel
    public var path: [DayRoute] = []
    public var draft: Draft
    public private(set) var addedEvent: CalendarEvent?
    public private(set) var explanation: ExplanationState = .idle

    private let service: SuggestionProviding
    private let employeeFirstName: String
    private var explanationTask: Task<Void, Never>?

    public init(
        day: DayModel = SyntheticDay.day(),
        service: SuggestionProviding = StubSuggestionService(),
        employeeFirstName: String = "Sam"
    ) {
        self.day = day
        self.service = service
        self.employeeFirstName = employeeFirstName

        let suggestion = day.breakSuggestion
        self.draft = Draft(
            title: "Take a break",
            startMinute: suggestion?.start ?? 12 * 60,
            endMinute: suggestion?.end ?? 12 * 60 + 15,
            calendarName: "Personal",
            alert: "At time of event"
        )
    }

    public var suggestion: BreakSuggestion? { day.breakSuggestion }

    /// The calendar entry the readings changed during — the one that gets the
    /// terracotta marker on the day timeline.
    public var flaggedEventID: String? {
        day.detection.primaryEpisode?.overlappingEvents.first?.id
    }

    /// Schedule as displayed, including a break once it has been added.
    public var displayedEvents: [CalendarEvent] {
        guard let added = addedEvent else { return day.schedule.events }
        return (day.schedule.events + [added]).sorted { $0.start < $1.start }
    }

    public var draftFitsTheGap: Bool {
        guard let gap = suggestion?.gap else { return true }
        return draft.startMinute >= gap.start && draft.endMinute <= gap.end
    }

    // MARK: - Navigation

    public func openSuggestion() { path.append(.suggestion) }
    public func openAddBreak() { path.append(.addBreak) }

    public func confirmAdd() {
        addedEvent = CalendarEvent(
            id: "added-break",
            title: draft.title,
            kind: .focus,
            start: draft.startMinute,
            end: draft.endMinute
        )
        path.append(.added)
    }

    public func undoAdd() {
        addedEvent = nil
        path.removeAll()
    }

    public func backToDay() { path.removeAll() }

    public func dismissSuggestion() {
        explanationTask?.cancel()
        path.removeAll()
    }

    // MARK: - Explanation

    /// Fetches the "why this time" sentence.
    ///
    /// The model explains the slot; it never picks it. Placement is arithmetic
    /// over the calendar and stays in `BreakFinder`.
    public func requestExplanation() {
        guard let episode = day.detection.primaryEpisode else { return }

        explanationTask?.cancel()
        explanation = .loading

        let context = SuggestionContext(
            employeeFirstName: employeeFirstName,
            remainingEvents: day.schedule.events.filter { $0.start > episode.endMinute },
            dayLabel: day.label,
            breakSuggestion: day.breakSuggestion
        )

        explanationTask = Task { [service] in
            do {
                let text = try await service.getSuggestion(episode: episode, context: context)
                guard !Task.isCancelled else { return }
                explanation = .ready(text)
            } catch is CancellationError {
                // Leave the previous state alone — the user caused this.
            } catch {
                guard !Task.isCancelled else { return }
                explanation = .failed(
                    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                )
            }
        }
    }

    public func cancelExplanation() {
        explanationTask?.cancel()
        explanationTask = nil
        if explanation.isLoading { explanation = .idle }
    }
}

// MARK: - Live session

/// Drives the Live tab. Replays the scripted day as if it were arriving now,
/// which is what a HealthKit observer query would feed in a real build.
@MainActor
@Observable
public final class LiveSessionModel {

    public private(set) var currentBPM: Int
    public private(set) var sessionBaselineBPM: Int
    public private(set) var isCollecting = true

    public var deltaFromBaseline: Int { currentBPM - sessionBaselineBPM }

    private let samples: [BiometricSample]
    private var index: Int
    private var ticker: Task<Void, Never>?

    public init(day: DayModel = SyntheticDay.day()) {
        // Open on the 11:00 review, which is where the mockup's 84 bpm sits.
        let start = day.samples.firstIndex { $0.minuteOfDay >= 11 * 60 + 15 } ?? 0
        self.samples = day.samples
        self.index = start
        self.currentBPM = Int((day.samples[safe: start]?.heartRate ?? 84).rounded())

        // Session baseline is the first half hour of the session, matching the
        // detector's approach: a median, so one artefact cannot move it.
        let window = day.samples.prefix(30).map(\.heartRate).sorted()
        self.sessionBaselineBPM = Int(
            (window.isEmpty ? 78 : window[window.count / 2]).rounded()
        )
    }

    public func startCollecting() {
        guard ticker == nil else { return }
        isCollecting = true
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, self.isCollecting else { return }
                self.advance()
            }
        }
    }

    public func endCollection() {
        isCollecting = false
        ticker?.cancel()
        ticker = nil
    }

    private func advance() {
        index = min(index + 1, samples.count - 1)
        if let sample = samples[safe: index] {
            currentBPM = Int(sample.heartRate.rounded())
        }
    }

    deinit { ticker?.cancel() }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
