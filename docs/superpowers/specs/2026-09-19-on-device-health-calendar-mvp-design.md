# LowCor on-device health and calendar MVP

## Goal

Demonstrate a private iPhone experience that pairs a user-selected day's
calendar events with voluntary HealthKit workout measurements. The demo's
moment of delight is live heart-rate display during a walking workout,
including supported AirPods heart-rate data when HealthKit supplies it.

## Scope

- Read the user's calendar events for the current day after explicit
  EventKit permission.
- Start and finish a voluntary walking workout after explicit HealthKit
  permission.
- Display live heart rate, a baseline from the first three readings, and the
  difference from that baseline.
- Save a small, local daily snapshot containing calendar-event metadata,
  an optional completed measurement summary, and a user-authored reflection.
- Keep calendar access and HealthKit access independently optional.

## Non-goals

- No account, server, network synchronization, web dashboard, or manager
  view.
- No direct Bluetooth or raw AirPods sensor connection. HealthKit is the
  app's supported source for heart-rate samples.
- No background collection, medical claims, stress diagnosis, or automated
  scheduling recommendation.
- No design-polish work beyond functional iPhone screens.

## Architecture

`HealthMeasurementStore` owns a live `HKWorkoutSession` and
`HKLiveWorkoutBuilder`. It exposes the latest beats-per-minute reading,
the in-session baseline, and a finished measurement summary.

`CalendarStore` owns an `EKEventStore`. It requests calendar permission only
when the user asks to connect a calendar, then returns same-day events from
the calendars selected by the user.

`DaySnapshotStore` persists minimal app-owned data locally. HealthKit and
EventKit remain the systems of record; LowCor does not copy raw health
samples or entire calendar histories.

The app composes the three stores into one current-day screen. Both the live
measurement and the calendar list must remain usable if the other permission
is denied or unavailable.

## Local data model

- `LiveMeasurement`: current BPM, first-three-reading baseline, start time,
  and optional end time.
- `DayEvent`: stable event identifier, title, start/end date, and all-day
  flag.
- `DaySnapshot`: date, the current day's event metadata, optional finished
  measurement summary, and optional user reflection.

Snapshots are stored only in the app sandbox. Event identifiers allow the app
to refresh the current calendar view without treating its local copy as a
calendar source of truth.

## Permissions and failure behavior

HealthKit and EventKit requests are separate, initiated only by a clearly
labeled user action, and described in the app's usage strings. The interface
must explain that calendar access and Health access can each be skipped.

If HealthKit is unavailable, denied, or provides no live heart-rate sample,
the user sees a direct status message and can still use calendar context. If
calendar access is denied or no events exist, the health measurement still
works. Workout-start and collection failures end cleanly and never leave the
UI falsely marked as measuring.

## Verification

- Unit-test snapshot mapping and baseline calculation without device APIs.
- Build for a generic iPhone target with code signing disabled.
- On a physical iPhone, verify independent Health and calendar permission
  flows, a same-day calendar read, workout start/end, and live BPM display.
- Treat a successful real AirPods heart-rate stream as device validation, not
  as a Simulator requirement.
