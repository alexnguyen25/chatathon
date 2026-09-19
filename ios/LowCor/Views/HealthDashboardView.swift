import SwiftUI
import Charts

struct HealthDashboardView: View {
    @ObservedObject var health: TodayHealthStore
    @ObservedObject var calendar: CalendarStore
    @StateObject private var measurement = HealthMeasurementStore()
    @StateObject private var history = MeasurementHistoryStore()
    @State private var showsCollection = false
    @State private var showsMetricGuide = false
    @ScaledMetric(relativeTo: .largeTitle) private var metricSize = 64

    private var latest: TodayHeartReading? { health.readings.last }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your signals, in context.")
                    .font(.title2.weight(.semibold))
                Text("Heart rate, HRV, and sleep add context to your day—not a diagnosis or a measure of stress.")
                    .font(.subheadline)
                    .foregroundStyle(LowCorTheme.secondary)
                    .padding(.top, -16)

                if let latest {
                    readingsCard(latest)
                } else {
                    emptyCard
                }

                additionalSignals

                Button { showsMetricGuide = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle").accessibilityHidden(true)
                        Text("Understand your health metrics")
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                }
                .foregroundStyle(LowCorTheme.forest)

                if !health.isDemo || measurement.isMeasuring { collectionCard }

                if !health.readings.isEmpty {
                    observations
                }

                if !health.isDemo && !history.sessions.isEmpty {
                    sessionHistory
                }

                Label("Health readings stay on your iPhone.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(LowCorTheme.secondary)
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(LowCorTheme.canvas)
        .foregroundStyle(LowCorTheme.ink)
        .refreshable { await health.refresh() }
        .navigationDestination(isPresented: $showsMetricGuide) { HealthInfoView() }
        .sheet(isPresented: $showsCollection) {
            HealthCollectionSheet(measurement: measurement, calendar: calendar)
        }
        .onChange(of: measurement.finishedSession) { _, session in
            guard let session else { return }
            if !history.sessions.contains(where: { $0.id == session.id }) {
                history.add(session)
            }
            Task { await health.refresh() }
        }
    }

    private var additionalSignals: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(health.isDemo ? "SIMULATED DAILY CONTEXT" : "YOUR DAILY CONTEXT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LowCorTheme.secondary)
            signalRow(
                title: "Heart rate variability", icon: "waveform.path.ecg",
                value: health.metrics.hrvSDNN.map { "\(Int($0.rounded())) ms" } ?? "Not recorded",
                detail: hrvDetail
            )
            Divider()
            signalRow(
                title: "Resting heart rate", icon: "heart",
                value: health.metrics.restingHeartRate.map { "\(Int($0.rounded())) BPM" } ?? "Not recorded",
                detail: "Today’s latest resting-rate estimate from Health. Different from your live heart rate."
            )
            Divider()
            signalRow(
                title: "Last night’s sleep", icon: "moon.zzz",
                value: health.metrics.sleepHours.map { String(format: "%.1f hours", $0) } ?? "Not recorded",
                detail: "Recorded asleep time, 6 PM yesterday–noon today. Time awake or only in bed isn’t counted."
            )
            Text(health.isDemo ? "All values and the personal HRV reference are fictional demo data." : "Missing data stays unknown. These signals require records from a compatible device or app; AirPods heart-rate capture does not provide every metric.")
                .font(.footnote)
                .foregroundStyle(LowCorTheme.secondary)
            if !health.isDemo {
                Button {
                    Task { await health.requestAccessAndLoad() }
                } label: {
                    Label(health.isLoading ? "Reading Health…" : "Connect more Health signals", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .disabled(health.isLoading)
            }
        }
        .healthSurface()
    }

    private var hrvDetail: String {
        let reference = health.metrics.hrvBaselineSDNN.map { "Your prior 7-day sample average: \(Int($0.rounded())) ms—not a population norm." }
            ?? "Your 7-day reference needs at least 3 earlier samples."
        guard let timestamp = health.metrics.hrvTimestamp else {
            return "SDNN in milliseconds. No readable sample today. " + reference
        }
        return "Latest at \(timestamp.formatted(date: .omitted, time: .shortened)) · \(health.metrics.hrvSampleCount) samples today. " + reference
    }

    private func signalRow(title: String, icon: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LowCorTheme.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(detail)
                .font(.footnote)
                .foregroundStyle(LowCorTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func readingsCard(_ reading: TodayHeartReading) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(health.isDemo ? "SIMULATED HEART RATE" : "LATEST HEART RATE", systemImage: "heart.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LowCorTheme.terracotta)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reading.bpm, format: .number.precision(.fractionLength(0)))
                    .font(.system(size: metricSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text("BPM").font(.headline).foregroundStyle(LowCorTheme.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Latest heart rate, \(Int(reading.bpm.rounded())) beats per minute")
            Text("Recorded \(reading.date.formatted(date: .omitted, time: .shortened)) · \(reading.source)")
                .font(.subheadline)
                .foregroundStyle(LowCorTheme.secondary)

            Chart(health.readings) { sample in
                PointMark(x: .value("Time", sample.date), y: .value("Heart rate", sample.bpm))
                    .symbolSize(18)
                    .foregroundStyle(LowCorTheme.terracotta)
                    .accessibilityLabel(sample.date.formatted(date: .omitted, time: .shortened))
                    .accessibilityValue("\(Int(sample.bpm.rounded())) beats per minute")
            }
            .chartYScale(domain: chartRange)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
            .frame(height: 160)
            .accessibilityLabel("Today’s recorded heart-rate samples. Individual points, not continuous monitoring.")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) { statistics }
                VStack(alignment: .leading, spacing: 16) { statistics }
            }
            Divider()
            Text("\(health.readings.count) samples today. Gaps mean no recorded readings, not a steady heart rate.")
                .font(.footnote)
                .foregroundStyle(LowCorTheme.secondary)
            Button {
                Task { await health.refresh() }
            } label: {
                Label(health.isLoading ? "Refreshing…" : "Refresh readings", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .disabled(health.isLoading)
        }
        .healthSurface()
    }

    private var chartRange: ClosedRange<Double> {
        let minimum = health.readings.map(\.bpm).min() ?? 60
        let maximum = health.readings.map(\.bpm).max() ?? 100
        return max(0, minimum - 10)...(maximum + 10)
    }

    @ViewBuilder private var statistics: some View {
        let values = health.readings.map(\.bpm)
        HealthStatistic(label: "Sample avg.", value: values.reduce(0, +) / Double(max(values.count, 1)))
        HealthStatistic(label: "Lowest", value: values.min() ?? 0)
        HealthStatistic(label: "Highest", value: values.max() ?? 0)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(LowCorTheme.terracotta)
                .accessibilityHidden(true)
            Text("A clearer picture of your day")
                .font(.title2.weight(.semibold))
            Text("Connect Apple Health to see heart-rate readings recorded by your compatible devices. Your day plan still works without them.")
                .font(.body)
                .foregroundStyle(LowCorTheme.secondary)
            Button {
                Task { await health.requestAccessAndLoad() }
            } label: {
                Label(health.isLoading ? "Reading Health…" : "Connect Apple Health", systemImage: "heart")
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(HealthActionStyle())
            .disabled(health.isLoading)
            Text(health.status)
                .font(.footnote)
                .foregroundStyle(LowCorTheme.secondary)
        }
        .healthSurface()
    }

    private var collectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: measurement.isMeasuring ? "waveform.path" : "sensor.tag.radiowaves.forward")
                    .font(.title2)
                    .foregroundStyle(LowCorTheme.forest)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(measurement.isMeasuring ? "Collection in progress" : "Capture a moment")
                        .font(.headline)
                    Text(measurement.isMeasuring ? "Your session is still running. Open it to end collection." : "Collect readings during a meeting or a focus session.")
                        .font(.subheadline)
                        .foregroundStyle(LowCorTheme.secondary)
                }
            }
            Button { showsCollection = true } label: {
                HStack {
                    Text(measurement.isMeasuring ? "Open live session" : "Set up live collection")
                    Spacer()
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
        }
        .padding(20)
        .background(LowCorTheme.sage, in: RoundedRectangle(cornerRadius: 20))
    }

    private var observations: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent observations").font(.title3.weight(.semibold))
            VStack(spacing: 16) {
                ForEach(Array(health.readings.suffix(5).reversed())) { reading in
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reading.date, style: .time).font(.subheadline.weight(.medium))
                            Text(reading.source).font(.caption).foregroundStyle(LowCorTheme.secondary)
                        }
                        Spacer(minLength: 0)
                        Text("\(Int(reading.bpm.rounded())) BPM")
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .healthSurface()
        }
    }

    private var sessionHistory: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your saved sessions").font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 20) {
                ForEach(history.sessions.prefix(3)) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.title).font(.subheadline.weight(.semibold))
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(LowCorTheme.secondary)
                        Text("\(Int(session.averageHeartRate.rounded())) BPM average · \(Int(session.peakHeartRate.rounded())) BPM peak")
                            .font(.subheadline).foregroundStyle(LowCorTheme.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .healthSurface()
        }
    }
}

private struct HealthStatistic: View {
    let label: String
    let value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(LowCorTheme.secondary)
            Text("\(Int(value.rounded())) BPM").font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HealthCollectionSheet: View {
    @ObservedObject var measurement: HealthMeasurementStore
    @ObservedObject var calendar: CalendarStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEventID = ""
    @State private var isFinishing = false
    @ScaledMetric(relativeTo: .largeTitle) private var metricSize = 72
    private var finishing: Bool { isFinishing || measurement.status.hasPrefix("Finishing") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(measurement.isMeasuring ? "One moment at a time." : "Add context to your readings.")
                        .font(.largeTitle.weight(.semibold))
                    Text("Use a short session to collect available heart-rate readings while you work.")
                        .foregroundStyle(LowCorTheme.secondary)

                    if !measurement.isMeasuring {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SESSION CONTEXT").font(.caption.weight(.semibold)).foregroundStyle(LowCorTheme.secondary)
                            Picker("Meeting or focus", selection: $selectedEventID) {
                                Text("Personal focus").tag("")
                                ForEach(calendar.events) { event in
                                    Text(event.title).tag(event.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(minHeight: 44)
                            if !calendar.connected {
                                Button("Connect calendar for meeting context") {
                                    Task { await calendar.requestAccessAndLoadToday() }
                                }.frame(minHeight: 44)
                            }
                        }
                        .healthSurface()
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Label(measurement.isMeasuring ? "COLLECTING VIA HEALTHKIT" : "LIVE HEART RATE", systemImage: "heart.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(LowCorTheme.terracotta)
                        HStack(alignment: .firstTextBaseline) {
                            Text(measurement.isMeasuring ? measurement.heartRate.map { String(Int($0.rounded())) } ?? "—" : "—")
                                .font(.system(size: metricSize, weight: .semibold, design: .rounded)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.4)
                            Text("BPM").font(.headline).foregroundStyle(LowCorTheme.secondary)
                        }
                        Text(measurement.status).font(.subheadline).foregroundStyle(LowCorTheme.secondary)
                        if measurement.isMeasuring, let baseline = measurement.baselineHeartRate {
                            Text("Session reference: \(Int(baseline.rounded())) BPM")
                                .font(.subheadline.weight(.medium))
                            Text("Mean of the first three readings, not your resting heart rate.")
                                .font(.footnote).foregroundStyle(LowCorTheme.secondary)
                        }
                    }
                    .healthSurface()

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Before you start", systemImage: "info.circle")
                            .font(.subheadline.weight(.semibold))
                        Text("Live collection starts and saves an “Other” workout in Apple Health and may affect activity metrics. Readings depend on your device; this is not passive, all-day AirPods monitoring.")
                            .font(.footnote).foregroundStyle(LowCorTheme.secondary)
                    }

                    if measurement.isMeasuring {
                        Button {
                            isFinishing = true
                            measurement.stopMeasurement()
                        } label: {
                            Text(finishing ? "Finishing session…" : "End collection & save")
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(HealthActionStyle())
                        .disabled(finishing)
                    } else if !calendar.isDemo {
                        Button("Allow live Health access") { measurement.requestAuthorization() }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        Button {
                            let title = calendar.events.first { $0.id == selectedEventID }?.title ?? "Personal focus"
                            measurement.startMeasurement(title: title)
                        } label: {
                            Text("Start collection").frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(HealthActionStyle())
                    }
                }
                .padding(24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(LowCorTheme.canvas)
            .foregroundStyle(LowCorTheme.ink)
            .navigationTitle("Live session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: measurement.isMeasuring) { _, active in
                if !active { isFinishing = false }
            }
        }
        .tint(LowCorTheme.forest)
    }
}

private struct HealthActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .background(LowCorTheme.forest, in: RoundedRectangle(cornerRadius: 14))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}

private extension View {
    func healthSurface() -> some View {
        self.padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}
