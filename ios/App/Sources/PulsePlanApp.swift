import SwiftUI
import StressCore
import StressMonitorUI

@main
struct PulsePlanApp: App {
    var body: some Scene {
        WindowGroup {
            AppShell(service: Self.suggestionService())
        }
    }

    /// Falls back to the canned provider when no key is configured, so the
    /// demo always runs. A missing key should not be the reason a screen is
    /// blank on stage.
    private static func suggestionService() -> SuggestionProviding {
        let store = InfoPlistAPIKeyStore()
        if (try? store.apiKey()) != nil {
            return AnthropicSuggestionService(keyStore: store)
        }
        print("[PulsePlan] No ANTHROPIC_API_KEY found — using the canned explanation.")
        return StubSuggestionService()
    }
}
