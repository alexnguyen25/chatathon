# PulsePlan — AirPods heart-rate POC

PulsePlan is a private, on-device health check-in: it reads today’s calendar
after permission and starts a voluntary HealthKit walking workout to display
live heart rate. It is deliberately not an employee-surveillance or
stress-diagnosis tool.

## What the POC proves

- A supported iPhone app can request HealthKit access and read live BPM during
  an active workout.
- The app can request calendar access separately and list today’s events.
- The app retains an in-session baseline and displays the current difference.
- The measurement remains on-device; there is no backend or manager-facing
  dashboard.

AirPods Pro 3 heart-rate monitoring is available only while an active workout
is running. AirPods do not provide a direct raw sensor/Bluetooth feed or
guaranteed live HRV. When an Apple Watch is also worn, HealthKit may choose the
watch as the highest-confidence source.

## Run on an iPhone

1. Open [PulsePlanIOS/Untitled Project.xcodeproj](PulsePlanIOS/Untitled%20Project.xcodeproj) in Xcode.
2. In **Signing & Capabilities**, choose your Apple Developer team and use a
   unique bundle identifier if Xcode requests one.
3. Connect a physical iPhone running iOS 26 or newer; select it as the run
   destination.
4. Pair and wear compatible AirPods Pro 3 and enable their heart-rate feature.
5. Run the app and tap **Connect calendar** to grant or decline calendar
   access independently.
6. Tap **Allow Health access**, then **Start measurement walk**.
   The live BPM value and its delta from the initial three-sample baseline will
   update as HealthKit delivers samples. Tap **End measurement** to finish the
   voluntary workout.

The Simulator can compile and present the interface, but it cannot validate a
real AirPods heart-rate stream.

## Verify locally

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 'PulsePlanIOS/Untitled Project.xcodeproj' -scheme MyApp \
  -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```
