# PulsePlan

A native iPhone MVP that connects heart-rate observations to an optional break in your calendar. Health analysis and Apple Foundation Models inference run on-device. No backend or cloud API key is required.

The app opens in a clearly labeled fictional demo day at **11:55 AM**, with 15 calendar events and simulated heart-rate readings. A deterministic, unvalidated pattern rule checks for a sustained rise before suggesting a pause. The model can choose a constrained calm pause; measurements, comparisons, and calendar availability are computed in Swift. If the model is unavailable or fails, an explicitly labeled fallback keeps the flow usable.

## Run

1. Open [`ios/PulsePlan.xcodeproj`](ios/PulsePlan.xcodeproj) in **Xcode 26 or newer**.
2. Select the **PulsePlan** scheme and an **iOS 26 or newer** simulator or iPhone.
3. For a physical device, select your own team in Signing & Capabilities and change the bundle identifier if needed. The checked-in signing settings belong to the original development setup.
4. Build and run. Demo mode needs no Health or Calendar permissions. Apple Intelligence availability affects the AI pause selection, not the demo's deterministic analysis or fallback.

## Try the demo

Tap **Analyze my signals → Review break → Add to demo day → See it in my day**. The first proposed break is **12:00–12:15**, between the morning meetings and 12:30 lunch. Explore **Your day** and **Health**, then use **Reset** in the demo banner to repeat. Demo changes stay inside the app and never write to Health or Calendar.

For real data, leave demo mode with **Exit** or **Connections → Explore a demo day**, then connect Health and Calendar separately. Health can read recorded heart rate, HRV (SDNN), resting heart rate, and sleep when available. A real calendar write requires reviewing the break, choosing a writable calendar, and tapping **Add to calendar**. The event is titled “Private reset” and omits health readings and AI explanations; its visibility and synchronization follow the selected calendar's settings.

Optional live collection is under **Health**. It starts and saves an “Other” workout in Apple Health and may affect activity metrics. Readings depend on supported hardware and permissions; this is not passive, continuous, all-day AirPods monitoring. Simulator use does not validate physical sensor streaming.

## Verify

From the repository root, with Xcode 26 or newer installed:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/check.sh
```

Or run the checks separately:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/PulsePlan.xcodeproj -scheme PulsePlan \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The root Swift package tests the app's actual [`Core`](ios/PulsePlan/Core) sources. Hardware HealthKit behavior, on-device model availability, and real calendar permissions/saves also need device verification.

## Repository

- [`ios/PulsePlan`](ios/PulsePlan): the active SwiftUI app, deterministic core, HealthKit, EventKit, and on-device suggestion code.
- [`Tests/PulsePlanCoreTests`](Tests/PulsePlanCoreTests): core logic tests, run with `swift test`.
- [`docs`](docs/README.md): implementation notes, research, and the canonical [visual design reference](docs/design/pulseplan-core/README.md).
- [`archive`](archive/README.md): preserved earlier prototypes; not dependencies of the active app.

This is an experimental, nonmedical hackathon MVP. Its heart-pattern rule is not clinically validated, does not diagnose stress, and cannot establish that a meeting caused a physiological change. Missing data or no triggered suggestion does not establish wellbeing. Background monitoring, reliable all-day capture, and App Store readiness are not claimed.
