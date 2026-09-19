# Archived prototypes

The working PulsePlan MVP lives in [`ios/PulsePlan`](../ios/PulsePlan) and [`ios/PulsePlan.xcodeproj`](../ios/PulsePlan.xcodeproj). Everything in `legacy-prototypes` is preserved for project history and reference; it is not part of the active app's build or test targets.

The archive retains the earlier directory layout where practical:

- `ios/`: the alternate StressCore / StressMonitorUI prototype and its project configuration.
- `pipeline/`, `requirements.txt`, `data/`, and `PIPELINE_OVERVIEW.md`: the Python/Gemini synthetic-data pipeline and its output contract.
- `web-dashboard-archive/`: the earlier HTML dashboard.
- `Sources/`, `Tests/`, and `Package.swift`: the earlier root LoadAnalyzer package and tests.
- `early-native-ui/`: superseded native view implementations.

Internal READMEs, links, commands, model choices, and scope claims are historical and may be stale. They are not instructions for running the current app. No archived API configuration or generated dataset is required by the active on-device MVP. See the [current README](../README.md) instead.
