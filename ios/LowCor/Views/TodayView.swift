import SwiftUI
import EventKit

struct TodayView: View {
    @StateObject private var health = TodayHealthStore()
    @StateObject private var calendar = CalendarStore()
    @StateObject private var suggestion = BreakSuggestionStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var connections = false
    @State private var reviewDraft: PulseBreakDraft?
    @State private var preparing = false
    @State private var showsHealthInfo = false
    @AppStorage("lowcor.lastBreakID") private var savedEventID = ""
    @AppStorage("lowcor.demoMode") private var demoMode = true
    @State private var demoSavedEventID = ""
    private var activeSavedEventID: String { demoMode ? demoSavedEventID : savedEventID }

    private var savedBreak: CalendarEvent? {
        calendar.events.first { $0.id == activeSavedEventID && $0.endDate > calendar.currentDate }
    }
    private var upcoming: [CalendarEvent] {
        calendar.events.filter { !$0.isAllDay && $0.startDate > calendar.currentDate }
    }
    private var happeningNow: [CalendarEvent] {
        calendar.events.filter { !$0.isAllDay && $0.startDate <= calendar.currentDate && $0.endDate > calendar.currentDate }
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                today.navigationTitle("LowCor").navigationBarTitleDisplayMode(.inline)
                    .toolbar { connectionsToolbar }
            }.tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
            NavigationStack {
                DayAgendaView(calendar: calendar, health: health,
                              proposedSlot: preparing || suggestion.isGenerating || suggestion.explanation.isEmpty ? nil : suggestion.slot,
                              savedEventID: activeSavedEventID, onReview: openReview, onConnect: { connections = true })
                    .navigationTitle("Your day").toolbar { connectionsToolbar }
            }.tabItem { Label("Your day", systemImage: "calendar") }.tag(1)
            NavigationStack {
                HealthDashboardView(health: health, calendar: calendar)
                    .navigationTitle("Health").toolbar { connectionsToolbar }
            }.tabItem { Label("Health", systemImage: "heart") }.tag(2)
        }
        .tint(LowCorTheme.forest).preferredColorScheme(.light)
        .safeAreaInset(edge: .top, spacing: 0) {
            if demoMode {
                HStack {
                    Label("Demo day · 11:55 AM", systemImage: "flask").font(.caption.weight(.semibold))
                    Spacer()
                    Button("Reset") { Task { await applyMode() } }.font(.caption.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44).disabled(preparing || suggestion.isGenerating)
                    Button("Exit") { demoMode = false }.font(.caption.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44).disabled(preparing || suggestion.isGenerating)
                }.padding(.horizontal, 24).foregroundStyle(LowCorTheme.forest).background(LowCorTheme.sage)
            }
        }
        .sheet(isPresented: $connections) {
            PulseConnectionsView(health: health, calendar: calendar, demoMode: $demoMode,
                                 canChangeMode: !preparing && !suggestion.isGenerating)
        }
        .sheet(item: $reviewDraft) { draft in
                PulseBreakReviewView(calendar: calendar, slot: draft.slot) { id in
                    if demoMode { demoSavedEventID = id } else { savedEventID = id }
                    suggestion.clear()
                } onShowDay: { tab = 1 }
        }
        .sheet(isPresented: $showsHealthInfo) {
            NavigationStack {
                HealthInfoView().toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { showsHealthInfo = false } }
                }
            }.tint(LowCorTheme.forest)
        }
        .task { await applyMode() }
        .onChange(of: demoMode) { _, _ in Task { await applyMode() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
    }

    @ToolbarContentBuilder private var connectionsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Connections", systemImage: "slider.horizontal.3") { connections = true }
                .frame(minWidth: 44, minHeight: 44)
        }
    }

    private var today: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                        .font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(LowCorTheme.secondary)
                    Text("Your day.\nA little more balanced.")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold)).tracking(-0.8)
                        .accessibilityAddTraits(.isHeader)
                }
                if let savedBreak { savedCard(savedBreak) } else { recommendationCard }
                if let analysis = suggestion.analysis, !suggestion.isGenerating { analysisCard(analysis) }
                contextSection
                agendaPreview
                Label("Health analysis stays on your iPhone", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(LowCorTheme.secondary)
                    .frame(maxWidth: .infinity).padding(.bottom, 8)
            }.frame(maxWidth: 640).padding(24).frame(maxWidth: .infinity)
        }
        .background(LowCorTheme.canvas).foregroundStyle(LowCorTheme.ink)
        .refreshable { await refresh() }
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label(suggestion.explanation.isEmpty ? "LISTEN TO YOUR SIGNALS" : "YOUR HEALTH CHECK-IN", systemImage: "sparkles")
                    .font(.caption.weight(.semibold)).tracking(1)
                Spacer(minLength: 0)
                Image(systemName: "cup.and.saucer").font(.title2).accessibilityHidden(true)
            }
            if !suggestion.explanation.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(suggestion.headline).font(.system(.title2, design: .rounded).bold())
                    if let slot = suggestion.slot {
                    Text("\(slot.start.formatted(date: .omitted, time: .shortened)) – \(slot.end.formatted(date: .omitted, time: .shortened))")
                        .font(.title3.weight(.semibold)).monospacedDigit()
                    Label("15-minute pause · Fits your calendar", systemImage: "checkmark.circle").font(.subheadline)
                    }
                }
                Text(suggestion.explanation).font(.body).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(suggestion.source).font(.caption.weight(.medium))
                    if !suggestion.status.isEmpty { Text(suggestion.status).font(.caption) }
                }.foregroundStyle(.white.opacity(0.88))
                Text("An optional suggestion—not medical advice. AI can be wrong; you make the decision.")
                    .font(.caption).foregroundStyle(.white)
                if suggestion.slot != nil {
                    Button("Review break", systemImage: "arrow.right", action: openReview)
                        .buttonStyle(PulsePrimaryButton(inverted: true))
                } else if !calendar.connected && suggestion.analysis?.heartSignal?.shouldSuggest == true {
                    Button("Connect Calendar to place a break") { connections = true }.buttonStyle(PulsePrimaryButton(inverted: true))
                }
                Button(suggestion.slot == nil ? "Check again" : "Find another time") { Task { await generate() } }
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(.white).disabled(preparing || suggestion.isGenerating)
            } else {
                Text("Is it time\nto take a pause?")
                    .font(.system(.title, design: .rounded).weight(.semibold)).tracking(-0.5)
                Text("Check for repeated rises in your heart rate. Your health signals come first; your calendar helps place a break only when a pattern is flagged.")
                    .font(.body).foregroundStyle(.white.opacity(0.92))
                Button {
                    Task { await generate() }
                } label: {
                    HStack(spacing: 10) {
                        if preparing || suggestion.isGenerating { ProgressView().tint(LowCorTheme.forest) }
                        Text(preparing || suggestion.isGenerating ? "Analyzing your signals…" : "Analyze my signals")
                        if !preparing && !suggestion.isGenerating { Image(systemName: "arrow.right") }
                    }
                }.buttonStyle(PulsePrimaryButton(inverted: true)).disabled(preparing || suggestion.isGenerating)
                Text(suggestion.status.isEmpty ? "A suggestion, not another obligation." : suggestion.status)
                    .font(.caption).foregroundStyle(.white.opacity(0.88))
            }
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white)
        .background(LowCorTheme.forest, in: RoundedRectangle(cornerRadius: 24))
    }

    private func savedCard(_ event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("TIME PROTECTED", systemImage: "checkmark.circle.fill").font(.caption.weight(.semibold)).tracking(1)
            Text("A little space.\nAlready in your day.").font(.system(.title, design: .rounded).bold())
            Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened)) · Private reset")
                .font(.headline)
            Text(demoMode ? "Your break is saved in this demo only. Your real calendar is unchanged." : "Your break is saved to Calendar. Nothing else on your schedule was moved.").font(.subheadline)
            Button("See it in my day", systemImage: "arrow.right") { tab = 1 }.buttonStyle(PulsePrimaryButton())
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(LowCorTheme.forest)
            .background(LowCorTheme.sage, in: RoundedRectangle(cornerRadius: 24))
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The context behind your day").font(.title3.bold()).accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { healthMetric; calendarMetric }
                VStack(spacing: 12) { healthMetric; calendarMetric }
            }
            HStack(alignment: .top, spacing: 16) {
                signalMetric("HRV · SDNN", value: health.metrics.hrvSDNN.map { "\(Int($0.rounded())) ms" } ?? "No data")
                signalMetric("Sleep recorded", value: health.metrics.sleepHours.map { String(format: "%.1f h", $0) } ?? "No data")
            }.pulseCard()
            Button("What do these numbers mean?", systemImage: "info.circle") { showsHealthInfo = true }
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            Text(health.readings.isEmpty
                 ? "No heart-rate readings yet. Connect Health to analyze a pattern; missing data is not a sign that you don’t need a break."
                 : "Heart-rate patterns trigger the check-in. Calendar availability only determines where a suggested pause can fit.")
                .font(.footnote).foregroundStyle(LowCorTheme.secondary)
        }
    }

    private func signalMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(LowCorTheme.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }

    private func analysisCard(_ analysis: PulseBreakAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("What your signals show", systemImage: "text.magnifyingglass").font(.title3.bold())
            if demoMode { Text("Based on fictional demo data").font(.caption.weight(.semibold)).foregroundStyle(LowCorTheme.forest) }
            ForEach(analysis.evidence) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Label(item.title, systemImage: item.symbol).font(.subheadline.weight(.semibold))
                    Text(item.detail).font(.subheadline).foregroundStyle(LowCorTheme.secondary)
                }
            }
            Divider()
            if analysis.heartSignal?.shouldSuggest == true {
                Label(BreakSuggestionStore.elevatedCaution, systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(LowCorTheme.secondary)
                Link("Heart-rate context · American Heart Association", destination: URL(string: "https://www.heart.org/en/health-topics/high-blood-pressure/the-facts-about-high-blood-pressure/all-about-heart-rate-pulse")!)
                    .font(.caption.weight(.semibold)).frame(minHeight: 44)
            }
            Text("Why a pause can help").font(.headline)
            Text("A screen-free pause gives you room to change posture and step away from continuous screen work. Fifteen minutes is an app choice, not a medical prescription or a guaranteed health benefit.")
                .font(.subheadline).foregroundStyle(LowCorTheme.secondary)
            Link("About screen-work breaks · HSE", destination: URL(string: "https://www.hse.gov.uk/msd/dse/work-routine.htm")!)
                .font(.caption.weight(.semibold)).frame(minHeight: 44)
            Label(BreakSuggestionStore.caution, systemImage: "info.circle")
                .font(.footnote).foregroundStyle(LowCorTheme.secondary)
            Button("Understand the metrics and limits") { showsHealthInfo = true }
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }.pulseCard()
    }

    private var healthMetric: some View {
        Button { tab = 2 } label: {
            VStack(alignment: .leading, spacing: 12) {
                Label("Heart rate", systemImage: "heart").font(.subheadline.weight(.medium)).foregroundStyle(LowCorTheme.terracotta)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(health.readings.last.map { "\(Int($0.bpm.rounded()))" } ?? "—")
                        .font(.system(.largeTitle, design: .rounded).bold()).monospacedDigit()
                    Text("BPM").font(.caption.weight(.medium))
                }
                Text(health.readings.last.map { "Latest at \($0.date.formatted(date: .omitted, time: .shortened))" } ?? "View Health")
                    .font(.caption).foregroundStyle(LowCorTheme.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).pulseCard()
        }.buttonStyle(.plain).accessibilityHint("Opens your health readings")
    }

    private var calendarMetric: some View {
        Button { if calendar.connected { tab = 1 } else { connections = true } } label: {
            VStack(alignment: .leading, spacing: 12) {
                Label("Schedule", systemImage: "calendar").font(.subheadline.weight(.medium)).foregroundStyle(LowCorTheme.forest)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(calendar.connected ? "\(upcoming.count)" : "—")
                        .font(.system(.largeTitle, design: .rounded).bold()).monospacedDigit()
                    Text("ahead").font(.caption.weight(.medium))
                }
                Text(calendar.connected ? "See your day" : "Connect calendar").font(.caption).foregroundStyle(LowCorTheme.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).pulseCard()
        }.buttonStyle(.plain).accessibilityHint("Opens your schedule")
    }

    private var agendaPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(happeningNow.isEmpty ? "Coming up" : "Happening now").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("View day") { tab = 1 }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }
            if !calendar.connected {
                Button { connections = true } label: {
                    Label("Connect Calendar to bring your day into view", systemImage: "calendar.badge.plus")
                        .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).pulseCard()
                }.buttonStyle(.plain)
            } else if upcoming.isEmpty && happeningNow.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A little open space.").font(.headline)
                    Text("No more timed events today. Your day is yours to shape.").font(.subheadline).foregroundStyle(LowCorTheme.secondary)
                }.pulseCard()
            } else {
                if !happeningNow.isEmpty {
                    agendaRows(happeningNow, active: true)
                }
                if !upcoming.isEmpty {
                    if !happeningNow.isEmpty {
                        Text("Coming up").font(.title3.bold()).accessibilityAddTraits(.isHeader).padding(.top, 8)
                    }
                    agendaRows(Array(upcoming.prefix(3)), active: false)
                }
            }
        }
    }

    private func agendaRows(_ events: [CalendarEvent], active: Bool) -> some View {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        if index > 0 { Divider().padding(.vertical, 16) }
                        HStack(alignment: .top, spacing: 16) {
                            Text(event.startDate.formatted(date: .omitted, time: .shortened))
                                .font(.caption.weight(.semibold)).foregroundStyle(LowCorTheme.secondary).frame(width: 68, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title).font(.subheadline.weight(.semibold))
                                Text(active ? "Ends at \(event.endDate.formatted(date: .omitted, time: .shortened))" : event.id == activeSavedEventID ? "Your protected break" : "\(max(1, Int(event.endDate.timeIntervalSince(event.startDate) / 60))) min")
                                    .font(.caption).foregroundStyle(LowCorTheme.secondary)
                            }
                            Spacer(minLength: 0)
                            if event.id == activeSavedEventID { Image(systemName: "checkmark.circle.fill").foregroundStyle(LowCorTheme.forest) }
                        }
                    }
                }.pulseCard()
    }

    private func refresh() async {
        calendar.refresh()
        await health.refresh()
        if (suggestion.slot != nil && !calendar.connected) || (suggestion.slot.map { $0.start <= calendar.currentDate } ?? false) { suggestion.clear() }
    }

    private func applyMode() async {
        reviewDraft = nil
        suggestion.clear()
        demoSavedEventID = ""
        let day = demoMode ? PulseDemoDay() : nil
        calendar.setDemo(day)
        health.setDemo(day)
        await refresh()
    }

    private func openReview() {
        guard !preparing, !suggestion.isGenerating, !suggestion.explanation.isEmpty,
              let slot = suggestion.slot else { return }
        reviewDraft = PulseBreakDraft(slot: slot)
    }

    private func generate() async {
        guard !preparing, !suggestion.isGenerating else { return }
        preparing = true
        defer { preparing = false }
        let previousSlot = suggestion.slot
        suggestion.clear()
        calendar.refresh()
        await health.refresh()
        let after = previousSlot.map { max(calendar.currentDate, $0.end) } ?? calendar.currentDate
        let healthSignal = PulseHeartSignal.assess(health.readings, now: calendar.currentDate)
        await suggestion.generate(healthSummary: health.summary, readings: health.readings, metrics: health.metrics,
                                  events: calendar.events, now: calendar.currentDate,
                                  slot: healthSignal.shouldSuggest ? calendar.nextAvailableBreak(now: after) : nil)
    }
}

struct PulsePrimaryButton: ButtonStyle {
    var inverted = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(inverted ? LowCorTheme.forest : .white)
            .background(inverted ? Color.white : LowCorTheme.forest, in: RoundedRectangle(cornerRadius: 14))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
    }
}

extension View {
    func pulseCard() -> some View {
        self.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}
