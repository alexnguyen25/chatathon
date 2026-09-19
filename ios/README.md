# PulsePlan — meeting-load stress monitor (iOS)

A SwiftUI screen that joins a synthetic minute-level biometric stream against a
work calendar, detects one sustained-stress episode, and offers a single
calendar-aware action.

## Layout

```
ios/
  StressCore/          SwiftPM package — models, detector, synthetic day, LLM service.
                       No SwiftUI, no UIKit, no platform floor. Builds on Windows.
  StressMonitorUI/     SwiftPM package — SwiftUI + Swift Charts. iOS 17+. macOS only.
  App/                 App entry point and Info.plist.
  Config/              Base.xcconfig + the Secrets.xcconfig template.
  scripts/             swift-env.ps1 — Windows build environment.
  project.yml          XcodeGen spec. No .xcodeproj is checked in.
  DESIGN.md            Visual direction: palette, type, geometry, motion.
```

The split between `StressCore` and `StressMonitorUI` is the important part. The
detector is the thing most worth testing and the thing least in need of a UI
framework, so it is kept in a package with no platform requirement. That is
what lets `swift test` run on a Windows machine with no Apple toolchain
anywhere in sight.

## Running the tests

**On Windows** (verified on Windows 11 ARM64, Swift 6.4.0, VS Build Tools 2022):

```powershell
. .\ios\scripts\swift-env.ps1     # dot-sourced, not executed
cd ios\StressCore
swift test
```

`swift-env.ps1` exists because Swift on Windows needs three things the
installer does not wire up: the MSVC environment for `link.exe`, the toolchain
on `PATH`, and `SDKROOT` pointing at the Platform SDK where the standard
library actually lives.

**On macOS:**

```bash
cd ios/StressCore && swift test
brew install xcodegen
cd ios && xcodegen generate
xcodebuild build -project PulsePlan.xcodeproj -scheme PulsePlan \
  -destination 'generic/platform=iOS Simulator'
```

CI runs both on a `macos-15` runner — see `.github/workflows/ios.yml`.

## Detection

Two signals, doing different jobs.

**Heart rate is what the user sees.** It is intuitive, and the screens quote it
as two ranges — 84–96 during the last hour against 68–76 earlier. A range, not
an average: "84–96 over that hour" is an observation about a window, whereas
"your heart rate is 90" is a claim about a person.

**HRV is what corroborates it.** Heart rate alone rises when you stand up or
drink coffee. The persistence check on HRV is what separates a real sustained
stretch from a busy ten minutes:

- **Baseline** — median HRV over the first 30 minutes. Median, not mean, so one
  artefact in the window cannot move it. Per-person, per-day; a fixed
  population threshold would be meaningless.
- **Threshold** — 20% below that baseline.
- **Persistence** — the drop must hold for 15 unbroken minutes. A single
  recovered sample ends the run, so two 10-minute dips separated by one good
  minute do not add up to an episode.
- **Context** — entries overlapping the depressed window, extended *backwards*
  through the unbroken chain leading into it, because HRV lags what caused it.

**Placement is arithmetic, not generation.** `BreakFinder` picks the slot from
the calendar; the LLM writes only the explanation, and the system prompt tells
it never to propose a different time. A language model that cannot see the
calendar has no business choosing a time on it.

The comparison excludes a 30-minute ramp buffer between the two windows. Heart
rate ramps rather than steps, and letting the earlier window run up to the
recent one drags the transition into the baseline and flattens the very
difference being reported.

Scripted scenario, from `swift run StressDemo`:

```
Window        11:16–12:11    Peak drop     32.1%
Duration      56 min         Episodes      1
Contributing  Planning, Focus, Design review

Slot          12:00 – 12:15  (15 min)
Sits in gap   12:00–12:30    (30 min free, Design review → Lunch)
Heart rate    84–96 bpm recently, 68–76 bpm earlier   (+18)
```

## API key

```bash
cp ios/Config/Secrets.xcconfig.example ios/Config/Secrets.xcconfig
# set ANTHROPIC_API_KEY=sk-ant-...
```

`Secrets.xcconfig` is gitignored. The value flows xcconfig → Info.plist →
`InfoPlistAPIKeyStore` at runtime. With no key set the app falls back to
`StubSuggestionService`, so the demo still runs.

**This is prototype-only.** A key in Info.plist ships inside the app bundle and
can be extracted from it by anyone with the `.ipa`. Shipping this means moving
the call server-side, with the key held by the server, behind explicit consent
and least-privilege calendar access — and with no individual health telemetry
ever reaching a manager.

## What this is not

Synthetic demonstration data. HRV reflects recovery and load; it is not a
measure of mood, emotion, or health, and nothing here is a medical assessment.
Every message is addressed to the employee and to nobody else.
