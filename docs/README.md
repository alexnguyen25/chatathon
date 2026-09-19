# PulsePlan documentation

The current product is the native iOS app in [`ios/PulsePlan`](../ios/PulsePlan), built with the **PulsePlan** scheme in [`ios/PulsePlan.xcodeproj`](../ios/PulsePlan.xcodeproj). Start with the [repository README](../README.md) for setup, demo steps, tests, and limits.

## Current implementation

- [Demo walkthrough](DEMO.md): the fictional 11:55 AM scenario and a short presentation script.
- [Health-signal rule](health-signal-rule.md): the deterministic, unvalidated gate used before a break suggestion.
- [Health information sources](health-info-sources.md): context and references for the app's explanatory copy.
- [Core visual design](design/pulseplan-core/README.md): canonical design reference, mockups, and [tokens](design/pulseplan-core/tokens.json). The concept and [implementation check](design/pulseplan-core/implementation-check.md) describe their point in time; current source determines shipped behavior.
- [On-device model research](research/2026-09-19-on-device-llm-health-calendar-analysis.md): research behind keeping health facts in deterministic code and constraining model output.

The demo's calendar and readings are fictional. Real HealthKit reads and EventKit saves are optional and permission-dependent. The model runs through Apple Foundation Models when available, with a labeled deterministic fallback. No Gemini key or Python pipeline is needed for the current app.

## Earlier work

The [original MVP design](superpowers/specs/2026-09-19-on-device-health-calendar-mvp-design.md) and [implementation plan](superpowers/plans/2026-09-19-on-device-health-calendar-mvp.md) are historical planning records. Research and design documents are preserved; older scope statements are not guarantees about the current app.

Earlier Swift prototypes, the Python/Gemini pipeline, generated data, and web dashboard are preserved under [`archive/legacy-prototypes`](../archive/README.md). Their instructions and contracts apply to those archived prototypes, not the active app.
