# On-device Health and Calendar MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a functional iPhone MVP that reads today's calendar events and presents live HealthKit workout heart rate entirely on device.

**Architecture:** HealthKit and EventKit stay as sources of truth. A live HealthKit store and a current-day EventKit store feed one functional SwiftUI screen; no data leaves the iPhone.

**Tech Stack:** Swift 6, SwiftUI, HealthKit, EventKit, XCTest, Xcode.

**Spec:** `docs/superpowers/specs/2026-09-19-on-device-health-calendar-mvp-design.md`

## Global Constraints

- Keep all health and calendar data on the iPhone; do not add a server, account, or network request.
- Read heart rate from HealthKit rather than direct Bluetooth or raw AirPods APIs.
- Request Health and Calendar access separately from explicit taps.
- Treat denied, empty, and unavailable integrations as usable states.

---

### Task 1: Add reusable app data types

**Files:**
- Create: `Sources/PulsePlanCore/DaySnapshot.swift`
- Create: `Tests/PulsePlanCoreTests/DaySnapshotTests.swift`

**Interfaces:**
- Produces: `DayEvent`, `MeasurementSummary`, and `DaySnapshot` values used by iOS stores.

- [ ] Add `Equatable`, `Codable`, `Sendable` value types for event metadata, a finished measurement, and a local daily snapshot.
- [ ] Add XCTest coverage that verifies optional measurement/reflection and event metadata survive model construction.
- [ ] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`.

### Task 2: Read today’s calendar after user consent

**Files:**
- Create: `PulsePlanIOS/MyApp/CalendarStore.swift`
- Modify: `PulsePlanIOS/Untitled Project.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `@Published var events: [DayEvent]`, `@Published var status: String`, and `requestAccessAndLoadToday()`.

- [ ] Implement an `@MainActor` `CalendarStore` using `EKEventStore` to request full calendar access and map only today’s events to `DayEvent` values sorted by start date.
- [ ] Set `NSCalendarsFullAccessUsageDescription` in Debug and Release to explain private same-day schedule context.
- [ ] Build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project 'PulsePlanIOS/Untitled Project.xcodeproj' -scheme MyApp -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`.

### Task 3: Connect calendar and health flows in the functional screen

**Files:**
- Modify: `PulsePlanIOS/MyApp/ContentView.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: `HealthMeasurementStore` and `CalendarStore`.
- Produces: independent Calendar and Health actions, event list, live BPM/baseline, and truthful failure/empty states.

- [ ] Add a Connect calendar action that runs the calendar request/load flow and renders today’s event title and time.
- [ ] Keep the HealthKit measurement flow independent and clear its active state for workout-start or runtime failure.
- [ ] Update device run instructions for granting both permissions and validating a live AirPods-fed HealthKit workout.
- [ ] Run package tests and the unsigned generic iPhone build.
