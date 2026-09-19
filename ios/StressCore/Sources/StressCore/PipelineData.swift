import Foundation

/// Reads the files that `pipeline/` produces, so the Swift app and the Python
/// pipeline can run against identical inputs.
///
/// Without this the two implementations are only claimed to agree. With it,
/// `PipelineParityTests` actually checks.
public enum PipelineData {

    public enum LoadError: Error, LocalizedError {
        case malformedCSV(line: Int)
        case missingColumn(String)
        case badTimestamp(String)

        public var errorDescription: String? {
            switch self {
            case let .malformedCSV(line):   return "Malformed CSV at line \(line)."
            case let .missingColumn(name):  return "CSV is missing the \(name) column."
            case let .badTimestamp(value):  return "Could not parse timestamp \(value)."
            }
        }
    }

    /// Minutes since midnight from an ISO-8601 local timestamp
    /// (`2026-09-19T14:15:00`).
    ///
    /// Parsed by hand rather than with `DateFormatter`: these stamps carry no
    /// zone, and running them through a formatter would apply the device's
    /// zone and silently shift every reading when the demo is shown in another
    /// timezone. The clock time in the file is the clock time we want.
    static func minuteOfDay(fromISO timestamp: String) throws -> Int {
        guard let timePart = timestamp.split(separator: "T").last else {
            throw LoadError.badTimestamp(timestamp)
        }
        let pieces = timePart.split(separator: ":")
        guard pieces.count >= 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]),
              (0 ..< 24).contains(hour),
              (0 ..< 60).contains(minute)
        else { throw LoadError.badTimestamp(timestamp) }
        return hour * 60 + minute
    }

    /// Parses `data/biometrics.csv` — `timestamp,heart_rate,hrv`.
    public static func biometrics(fromCSV text: String) throws -> [BiometricSample] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let header = lines.first else { return [] }

        let columns = header.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let tsIndex = columns.firstIndex(of: "timestamp") else {
            throw LoadError.missingColumn("timestamp")
        }
        guard let hrIndex = columns.firstIndex(of: "heart_rate") else {
            throw LoadError.missingColumn("heart_rate")
        }
        guard let hrvIndex = columns.firstIndex(of: "hrv") else {
            throw LoadError.missingColumn("hrv")
        }

        return try lines.dropFirst().enumerated().map { offset, line in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count > max(tsIndex, hrIndex, hrvIndex),
                  let hr = Double(fields[hrIndex]),
                  let hrv = Double(fields[hrvIndex])
            else { throw LoadError.malformedCSV(line: offset + 2) }

            return BiometricSample(
                minuteOfDay: try minuteOfDay(fromISO: fields[tsIndex]),
                heartRate: hr,
                hrv: hrv
            )
        }
    }

    // MARK: - Calendar

    private struct RawEvent: Decodable {
        let title: String
        let type: String
        let start: String
        let end: String
        let back_to_back: Bool
    }

    /// The pipeline's `type` vocabulary mapped onto `MeetingKind`.
    ///
    /// Lossy by design — the Swift enum exists to drive layout and copy, not
    /// to mirror another schema. Anything unrecognised becomes `.sync`, which
    /// is the neutral "time with other people in it" case.
    public static func kind(forPipelineType type: String) -> MeetingKind {
        switch type {
        case "high_focus":  return .focus
        case "high_stakes": return .review
        case "one_on_one":  return .sync
        case "focus_time":  return .deepWork
        case "team":        return .sync
        case "lunch":       return .lunch
        default:            return .sync
        }
    }

    /// Parses `data/calendar.json`.
    ///
    /// The file carries its own `back_to_back` flags, but `Schedule`
    /// recomputes them from the times. Two sources of truth for the same fact
    /// is a bug waiting to happen, and the times are the ones that cannot be
    /// wrong. `pipelineBackToBackFlagsAgree` checks they match.
    public static func calendar(fromJSON data: Data) throws -> Schedule {
        let raw = try JSONDecoder().decode([RawEvent].self, from: data)
        return Schedule(
            try raw.enumerated().map { index, event in
                CalendarEvent(
                    id: "\(index)-\(event.title.lowercased().replacingOccurrences(of: " ", with: "-"))",
                    title: event.title,
                    kind: kind(forPipelineType: event.type),
                    start: try minuteOfDay(fromISO: event.start),
                    end: try minuteOfDay(fromISO: event.end)
                )
            }
        )
    }

    /// True when the file's own flags agree with the times in it.
    public static func pipelineBackToBackFlagsAgree(
        json data: Data,
        schedule: Schedule
    ) throws -> Bool {
        let raw = try JSONDecoder().decode([RawEvent].self, from: data)
        let computed = schedule.events.map(\.isBackToBack)
        guard raw.count == computed.count else { return false }
        return zip(raw.map(\.back_to_back), computed).allSatisfy { $0 == $1 }
    }
}
