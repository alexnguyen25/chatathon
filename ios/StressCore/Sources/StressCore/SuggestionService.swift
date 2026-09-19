import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // Linux / Windows put URLSession here
#endif

/// Everything the model needs about the day that isn't already in the episode.
public struct SuggestionContext: Sendable, Hashable {
    /// The person's own first name, used to keep the message direct rather than
    /// clinical. Never a manager's, never sent anywhere else.
    public var employeeFirstName: String
    /// Remaining calendar after the episode, so the suggestion can propose a
    /// move that does not collide with something else.
    public var remainingEvents: [CalendarEvent]
    public var dayLabel: String
    /// The slot the app has already picked. The model writes the *reason*, not
    /// the time — placement is arithmetic over the calendar and should not be
    /// left to a language model that cannot see it.
    public var breakSuggestion: BreakSuggestion?

    public init(
        employeeFirstName: String,
        remainingEvents: [CalendarEvent],
        dayLabel: String = "today",
        breakSuggestion: BreakSuggestion? = nil
    ) {
        self.employeeFirstName = employeeFirstName
        self.remainingEvents = remainingEvents
        self.dayLabel = dayLabel
        self.breakSuggestion = breakSuggestion
    }
}

public enum SuggestionError: Error, LocalizedError, Sendable {
    case missingAPIKey
    case badResponse(status: Int, body: String)
    case emptyCompletion
    case refused(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Anthropic API key. Add ANTHROPIC_API_KEY to Secrets.xcconfig."
        case let .badResponse(status, body):
            return "Anthropic API returned \(status). \(body)"
        case .emptyCompletion:
            return "The model returned no text."
        case let .refused(reason):
            return "The request was declined: \(reason)"
        }
    }
}

/// Indirection so previews, tests, and the simulator can run the whole screen
/// without a key or a network.
public protocol SuggestionProviding: Sendable {
    func getSuggestion(episode: StressEpisode, context: SuggestionContext) async throws -> String
}

/// Where the key comes from.
///
/// The key is never in source. `Secrets.xcconfig` (gitignored) sets
/// `ANTHROPIC_API_KEY`, the build setting flows into Info.plist, and this reads
/// it back at runtime. `Secrets.xcconfig.example` is the committed template.
///
/// This is acceptable for a prototype and **not** acceptable for production: a
/// key in Info.plist ships inside the app bundle and can be extracted from it.
/// Shipping this means moving the call server-side, behind consent, with the
/// key held by the server. See the note in README.
public protocol APIKeyStore: Sendable {
    func apiKey() throws -> String
}

public struct InfoPlistAPIKeyStore: APIKeyStore {
    public let infoDictionaryKey: String

    public init(infoDictionaryKey: String = "ANTHROPIC_API_KEY") {
        self.infoDictionaryKey = infoDictionaryKey
    }

    public func apiKey() throws -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String
        guard let value, !value.isEmpty, value != "$(ANTHROPIC_API_KEY)" else {
            throw SuggestionError.missingAPIKey
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Calls the Anthropic Messages API directly over URLSession.
///
/// Swift has no official Anthropic SDK, so this is raw HTTP against
/// `POST /v1/messages` with the documented headers.
public struct AnthropicSuggestionService: SuggestionProviding {

    /// Named by the caller. `claude-sonnet-4-5` is still an active model;
    /// `claude-sonnet-5` is the current generation if this is ever revisited.
    public static let defaultModel = "claude-sonnet-4-5"

    private let keyStore: APIKeyStore
    private let model: String
    private let session: URLSession
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(
        keyStore: APIKeyStore = InfoPlistAPIKeyStore(),
        model: String = AnthropicSuggestionService.defaultModel,
        session: URLSession = .shared
    ) {
        self.keyStore = keyStore
        self.model = model
        self.session = session
    }

    public func getSuggestion(
        episode: StressEpisode,
        context: SuggestionContext
    ) async throws -> String {
        let key = try keyStore.apiKey()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "max_tokens": 300,
            "system": Self.systemPrompt,
            "messages": [
                ["role": "user", "content": Self.userPrompt(episode: episode, context: context)]
            ]
        ])

        // Cooperative cancellation: if the view's Task is cancelled while this
        // is in flight, URLSession tears the request down and throws here,
        // which is what makes the loading state genuinely interruptible rather
        // than merely hidden.
        try Task.checkCancellation()
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(status) else {
            throw SuggestionError.badResponse(
                status: status,
                body: String(data: data, encoding: .utf8) ?? "<no body>"
            )
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Safety classifiers can decline with HTTP 200, so stop_reason is
        // checked before content is read.
        if let stop = json?["stop_reason"] as? String, stop == "refusal" {
            let detail = (json?["stop_details"] as? [String: Any])?["explanation"] as? String
            throw SuggestionError.refused(detail ?? "no explanation given")
        }

        let blocks = json?["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw SuggestionError.emptyCompletion }
        return text
    }

    // MARK: - Prompt

    // Written without `\` line continuations on purpose: in a Swift multiline
    // literal the continuation keeps the next line's leading indentation, which
    // silently injects double spaces mid-sentence.
    /// Public so the prompt can be inspected without a network call — see the
    /// StressDemo executable and SuggestionPromptTests.
    public static let systemPrompt = """
    You help an employee notice and respond to meeting load. You are writing
    directly to that person. Your output is shown to them and to nobody else —
    never to a manager, never to HR.

    The app has already chosen the break time from their calendar. You are
    writing the short explanation of why that time, not choosing it. Never
    propose a different time.

    Rules:
    - Write 2 sentences, maximum 40 words. No preamble, no sign-off.
    - Ground both sentences in the specific named meetings and the specific
    readings given. A sentence that would be true for any person on any day is
    a failed sentence.
    - Heart rate varies with movement, posture, caffeine, and conversation.
    Describe what was observed; do not diagnose, do not attribute it to stress
    as a fact, and do not imply anything medical.
    - Make it optional in tone. It is their call.
    - No emoji, no exclamation marks, no wellness-speak ("recharge",
    "self-care", "take a breather", "listen to your body").
    """

    public static func userPrompt(episode: StressEpisode, context: SuggestionContext) -> String {
        let meetings = episode.contributingEvents
            .map { "\($0.title) (\($0.kind.shortLabel), \($0.timeRangeLabel))" }
            .joined(separator: "; ")

        let remaining = context.remainingEvents.isEmpty
            ? "nothing else scheduled"
            : context.remainingEvents
                .map { "\($0.title) at \(clockLabel(forMinuteOfDay: $0.start))" }
                .joined(separator: "; ")

        let next = episode.nextEvent.map {
            "\($0.title), \($0.kind.shortLabel), \($0.timeRangeLabel)"
        } ?? "nothing scheduled after the episode"

        var breakLines = "- No specific slot was found."
        if let suggestion = context.breakSuggestion {
            let comparison = suggestion.comparison
            breakLines = """
            - Chosen slot: \(suggestion.timeRangeLabel), \(suggestion.durationMinutes) minutes.
            - It sits in a clear \(suggestion.gap.durationMinutes)-minute gap: \(suggestion.gap.previousEvent?.title ?? "nothing") ends at \(clockLabel(forMinuteOfDay: suggestion.gap.start)), \(suggestion.gap.nextEvent?.title ?? "nothing") starts at \(clockLabel(forMinuteOfDay: suggestion.gap.end)).
            - Heart rate \(comparison.recentLabel) bpm over the hour before that gap, against \(comparison.earlierLabel) bpm earlier in the day.
            """
        }

        return """
        Person: \(context.employeeFirstName)
        Day: \(context.dayLabel)

        The break the app has chosen (synthetic demo data):
        \(breakLines)

        Corroborating signal:
        - Heart-rate variability stayed at least 20% below their own morning baseline for \(episode.durationMinutes) minutes continuously, from \(episode.timeRangeLabel).
        - Baseline \(Int(episode.baselineHRV.rounded()))ms, low point \(Int(episode.minimumHRV.rounded()))ms, a \(Int(episode.maxDropPercent.rounded()))% drop.
        - Calendar in that block: \(meetings)
        - Consecutive entries with no gap: \(episode.backToBackCount)
        - Next thing on their calendar: \(next)
        - Rest of the day: \(remaining)

        Write the explanation.
        """
    }
}

/// Canned provider for previews, tests, and demoing without a key.
public struct StubSuggestionService: SuggestionProviding {
    public var delay: Duration
    public var result: Result<String, Error>

    public init(
        delay: Duration = .milliseconds(1400),
        result: Result<String, Error> = .success(
            "Design review ends at 12:00 and lunch does not start until 12:30, "
            + "so the half hour in between is already clear. Your heart rate ran "
            + "84–96 through that review, against 68–76 earlier in the morning."
        )
    ) {
        self.delay = delay
        self.result = result
    }

    public func getSuggestion(
        episode: StressEpisode,
        context: SuggestionContext
    ) async throws -> String {
        try await Task.sleep(for: delay)   // cancellable by construction
        return try result.get()
    }
}
