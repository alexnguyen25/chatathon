import Foundation
import StressCore

// Terminal rendering of the scripted day: the same data, detector, and prompt
// the SwiftUI screen uses, minus the parts that need an Apple SDK.

// `--pipeline` runs the Swift detector over the repository's own
// data/biometrics.csv + data/calendar.json using the same parameters as
// pipeline/analyze_stress.py, so the two implementations can be compared
// side by side. Without it, the scripted mockup day is used.
let usePipeline = CommandLine.arguments.contains("--pipeline")

func pipelineDay() throws -> DayModel {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0 ..< 5 { root.deleteLastPathComponent() }
    let dataDir = root.appendingPathComponent("data")

    let samples = try PipelineData.biometrics(
        fromCSV: String(
            contentsOf: dataDir.appendingPathComponent("biometrics.csv"),
            encoding: .utf8
        )
    )
    let schedule = try PipelineData.calendar(
        fromJSON: Data(contentsOf: dataDir.appendingPathComponent("calendar.json"))
    )
    let detection = StressDetector.analyze(
        samples: samples, schedule: schedule, configuration: .pipelineParity
    )
    return DayModel(
        label: "Sat, Sep 19 (pipeline fixtures)",
        samples: samples,
        schedule: schedule,
        detection: detection,
        breakSuggestion: BreakFinder.suggest(
            samples: samples, schedule: schedule, detection: detection
        )
    )
}

let day: DayModel
do {
    day = usePipeline ? try pipelineDay() : SyntheticDay.day()
} catch {
    print("Could not load pipeline data: \(error.localizedDescription)")
    exit(1)
}
let samples = day.samples
let result = day.detection

let columns = 96
let rows = 18
let hrvTop = 70.0
let hrvBottom = 30.0

let firstMinute = SyntheticDay.dayStartMinute
let lastMinute = SyntheticDay.dayEndMinute
let minutesPerColumn = Double(lastMinute - firstMinute) / Double(columns)

func minute(forColumn column: Int) -> Int {
    firstMinute + Int((Double(column) * minutesPerColumn).rounded())
}

/// Mean HRV of the samples falling in a column, so narrow features survive
/// the downsample instead of being skipped by point sampling.
func hrv(forColumn column: Int) -> Double {
    let lower = minute(forColumn: column)
    let upper = minute(forColumn: column + 1)
    let bucket = samples.filter { $0.minuteOfDay >= lower && $0.minuteOfDay < max(upper, lower + 1) }
    guard !bucket.isEmpty else { return samples.last?.hrv ?? 0 }
    return bucket.reduce(0) { $0 + $1.hrv } / Double(bucket.count)
}

func row(forHRV value: Double) -> Int {
    let clamped = min(max(value, hrvBottom), hrvTop)
    let fraction = (hrvTop - clamped) / (hrvTop - hrvBottom)
    return min(rows - 1, max(0, Int((fraction * Double(rows - 1)).rounded())))
}

let episode = result.primaryEpisode

func columnIsInEpisode(_ column: Int) -> Bool {
    guard let episode else { return false }
    let m = minute(forColumn: column)
    return m >= episode.startMinute && m <= episode.endMinute
}

// MARK: - Meeting band strip

var meetingStrip = Array(repeating: " ", count: columns)
var meetingLabels = Array(repeating: " ", count: columns)
for event in day.schedule.events {
    let start = max(0, Int(Double(event.start - firstMinute) / minutesPerColumn))
    let end = min(columns - 1, Int(Double(event.end - firstMinute) / minutesPerColumn))
    guard start <= end else { continue }
    for c in start ... end { meetingStrip[c] = "▄" }
    let label = event.kind.shortLabel
    let room = end - start + 1
    if room >= label.count {
        let offset = start + (room - label.count) / 2
        for (i, ch) in label.enumerated() where offset + i < columns {
            meetingLabels[offset + i] = String(ch)
        }
    }
}

// MARK: - Plot

let thresholdRow = row(forHRV: result.threshold)
let baselineRow = row(forHRV: result.baselineHRV)

var canvas = Array(repeating: Array(repeating: " ", count: columns), count: rows)
for c in 0 ..< columns {
    if baselineRow < rows { canvas[baselineRow][c] = "-" }
    if thresholdRow < rows { canvas[thresholdRow][c] = "." }
}
for c in 0 ..< columns {
    let r = row(forHRV: hrv(forColumn: c))
    canvas[r][c] = columnIsInEpisode(c) ? "#" : "*"
}

// MARK: - Output

print("")
print("  MEETING-LOAD STRESS MONITOR — \(day.label), synthetic data")
print("  " + String(repeating: "═", count: columns))
print("  " + meetingLabels.joined())
print("  " + meetingStrip.joined())

for r in 0 ..< rows {
    let axis: String
    if r == 0 { axis = "70" }
    else if r == rows - 1 { axis = "30" }
    else if r == baselineRow { axis = "\(Int(result.baselineHRV.rounded()))" }
    else if r == thresholdRow { axis = "\(Int(result.threshold.rounded()))" }
    else { axis = "  " }
    let suffix: String
    if r == baselineRow {
        suffix = usePipeline
            ? "  <- baseline (mean of first 60 min, pipeline parity)"
            : "  <- baseline (median of first 30 min)"
    }
    else if r == thresholdRow { suffix = "  <- threshold, 20% below baseline" }
    else { suffix = "" }
    print(String(format: "%2@", axis as NSString) + "|" + canvas[r].joined() + suffix)
}

var axisLine = Array(repeating: " ", count: columns)
for hour in stride(from: 9, through: 17, by: 1) {
    let c = Int(Double(hour * 60 - firstMinute) / minutesPerColumn)
    guard c >= 0, c < columns else { continue }
    let label = "\(hour)"
    for (i, ch) in label.enumerated() where c + i < columns {
        axisLine[c + i] = String(ch)
    }
}
print("  " + String(repeating: "─", count: columns))
print("  " + axisLine.joined())
print("   ms          * HRV      # HRV inside the detected episode      hours →")
print("")

guard let episode else {
    print("  No episode detected.")
    exit(0)
}

print("  DETECTED EPISODE")
print("  " + String(repeating: "─", count: 56))
func line(_ label: String, _ value: String) {
    let padded = label.padding(toLength: 22, withPad: " ", startingAt: 0)
    print("  \(padded)\(value)")
}
line("Window", episode.timeRangeLabel)
line("Duration", "\(episode.durationMinutes) min continuously below threshold")
line("Baseline", String(format: "%.1f ms", episode.baselineHRV))
line("Threshold", String(format: "%.1f ms", result.threshold))
line("Trough", String(format: "%.1f ms", episode.minimumHRV))
line("Peak drop", String(format: "%.1f%%", episode.maxDropPercent))
line("Overlapping", episode.overlappingEvents.map(\.title).joined(separator: ", "))
line("Contributing", episode.contributingEvents.map(\.title).joined(separator: ", "))
line("Back-to-back", "\(episode.backToBackCount)")
line("Next on calendar", episode.nextEvent.map {
    "\($0.title) at \(clockLabel(forMinuteOfDay: $0.start))"
} ?? "none")
line("Episodes in day", "\(result.episodes.count)")
print("")

// MARK: - Break

if let suggestion = day.breakSuggestion {
    print("  SUGGESTED BREAK")
    print("  " + String(repeating: "─", count: 56))
    line("Slot", "\(suggestion.timeRangeLabel)  (\(suggestion.durationMinutes) min)")
    line("Sits in gap", "\(suggestion.gap.timeRangeLabel)  (\(suggestion.gap.durationMinutes) min free)")
    line("Between", "\(suggestion.gap.previousEvent?.title ?? "—") and \(suggestion.gap.nextEvent?.title ?? "—")")
    line("Heart rate", "\(suggestion.comparison.recentLabel) bpm recently, \(suggestion.comparison.earlierLabel) bpm earlier")
    line("Rise", "+\(suggestion.comparison.riseBPM) bpm")
    print("")
} else {
    print("  No usable gap found — no break suggested.\n")
}

// MARK: - The prompt

let context = SuggestionContext(
    employeeFirstName: "Sam",
    remainingEvents: day.schedule.events.filter { $0.start > episode.endMinute },
    dayLabel: day.label,
    breakSuggestion: day.breakSuggestion
)

print("  PROMPT THAT WOULD BE SENT (model: \(AnthropicSuggestionService.defaultModel))")
print("  " + String(repeating: "─", count: 56))
for l in AnthropicSuggestionService.userPrompt(episode: episode, context: context)
    .split(separator: "\n", omittingEmptySubsequences: false) {
    print("  | \(l)")
}
print("")

// MARK: - Suggestion

let keyPresent = !(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "").isEmpty

struct EnvKeyStore: APIKeyStore {
    func apiKey() throws -> String {
        let v = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        guard !v.isEmpty else { throw SuggestionError.missingAPIKey }
        return v
    }
}

let service: SuggestionProviding = keyPresent
    ? AnthropicSuggestionService(keyStore: EnvKeyStore())
    : StubSuggestionService(delay: .milliseconds(200))

// The stub's text is canned for the scripted mockup day, so in --pipeline
// mode it describes a different day than the one just analysed. Say so
// rather than letting it read as output derived from the data above.
let suggestionSource: String
if keyPresent {
    suggestionSource = "live Anthropic API"
} else if usePipeline {
    suggestionSource = "stub — canned for the scripted day, NOT these fixtures"
} else {
    suggestionSource = "stub — set ANTHROPIC_API_KEY for a live call"
}
print("  SUGGESTION  (\(suggestionSource))")
print("  " + String(repeating: "─", count: 56))

let semaphore = DispatchSemaphore(value: 0)
Task {
    do {
        let text = try await service.getSuggestion(episode: episode, context: context)
        for l in text.split(separator: "\n", omittingEmptySubsequences: false) {
            print("  \(l.trimmingCharacters(in: .whitespaces))")
        }
    } catch {
        print("  failed: \(error.localizedDescription)")
    }
    print("")
    semaphore.signal()
}
semaphore.wait()
