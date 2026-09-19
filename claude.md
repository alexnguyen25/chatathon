# Working on PulsePlan

Read [README.md](README.md) for the current run and verification commands and [docs/README.md](docs/README.md) for design and research references.

## Active implementation

- Xcode project: `ios/PulsePlan.xcodeproj`; scheme: `PulsePlan`; Xcode 26+, iOS 26+.
- App entry: `ios/PulsePlan/App/PulsePlanApp.swift` → `Views/TodayView.swift`.
- Shared logic: `ios/PulsePlan/Core`. The root `Package.swift` compiles these same sources for `swift test`; tests belong in `Tests/PulsePlanCoreTests`.
- Integrations: `Health`, `Calendar`, and `Suggestions` inside `ios/PulsePlan`.
- Visual design reference: `docs/design/pulseplan-core`; retain the research and design history.
- `archive/legacy-prototypes` contains superseded implementations, not active dependencies. Do not wire its Python/Gemini pipeline, generated JSON, or old Swift packages into the app by accident.

## Product boundaries

Demo mode defaults to a fictional 11:55 AM day with 15 events. Demo mutations must stay separate from real Health and Calendar data. Keep fictional data and fallback output visibly labeled.

The deterministic heart-pattern rule gates suggestions. Apple Foundation Models selects a constrained calm pause only after that gate fires; it must not invent measurements, override the gate, diagnose stress, or claim calendar events caused health changes. Preserve the labeled fallback when model inference is unavailable or fails.

Real HealthKit and Calendar access is optional. A real break save requires explicit review and confirmation, checks current conflicts, and excludes physiological details and AI explanations from the event. “Private reset” is an event title, not a guarantee about the destination calendar's sharing settings.

Live collection starts and saves a workout; it is not guaranteed passive AirPods or continuous background monitoring. Do not claim clinical validation or App Store readiness. Distinguish core test/build results from device verification.

Before changing files, inspect the working tree and preserve unrelated edits. Keep documentation aligned with source, run relevant core tests, and build the iOS scheme after app changes. Personal signing settings may need adjustment on another developer's device.
