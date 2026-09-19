import SwiftUI
import EventKit

struct PulseBreakDraft: Identifiable {
    let id = UUID()
    let slot: DateInterval
}

struct PulseConnectionsView: View {
    @ObservedObject var health: TodayHealthStore
    @ObservedObject var calendar: CalendarStore
    @Binding var demoMode: Bool
    var canChangeMode: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var connectingCalendar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "link").font(.largeTitle).foregroundStyle(LowCorTheme.forest).accessibilityHidden(true)
                    Text("Your day,\nbrought together.").font(.system(.largeTitle, design: .rounded).bold())
                    Text("Two connections. One clearer picture of when to pause.").foregroundStyle(LowCorTheme.secondary)
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Explore a demo day", isOn: $demoMode).font(.headline).disabled(!canChangeMode)
                        Text("A fictional meeting-heavy day with simulated heart-rate readings. Try the full flow without changing Health or Calendar.")
                            .font(.subheadline).foregroundStyle(LowCorTheme.secondary)
                    }.pulseCard()
                    if !demoMode {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Apple Health", systemImage: "heart").font(.title3.bold()).foregroundStyle(LowCorTheme.terracotta)
                        Text("Read heart rate, HRV, resting heart rate, and recorded sleep from Health. Available data depends on your devices and permissions—not a stress score.").font(.subheadline)
                        if !health.readings.isEmpty {
                            Label("\(health.readings.count) readings available today", systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(LowCorTheme.forest)
                        }
                        Button(health.isLoading ? "Reading Health…" : health.readings.isEmpty ? "Connect Health" : "Review Health access") {
                            Task { await health.requestAccessAndLoad() }
                        }.buttonStyle(PulsePrimaryButton()).disabled(health.isLoading)
                        Text(health.status).font(.caption).foregroundStyle(LowCorTheme.secondary)
                    }.pulseCard()
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Apple Calendar", systemImage: "calendar").font(.title3.bold()).foregroundStyle(LowCorTheme.forest)
                        Text("Find an open slot across your calendars. Add a break only after you review it.").font(.subheadline)
                        if calendar.connected {
                            Label("Connected · \(calendar.events.count) events today", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(LowCorTheme.forest)
                        } else {
                            Button(connectingCalendar ? "Connecting…" : "Connect Calendar") {
                                connectingCalendar = true
                                Task { await calendar.requestAccessAndLoadToday(); connectingCalendar = false }
                            }.buttonStyle(PulsePrimaryButton()).disabled(connectingCalendar)
                            Text(calendar.status).font(.caption).foregroundStyle(LowCorTheme.secondary)
                        }
                    }.pulseCard()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Private by design", systemImage: "lock.shield").font(.headline)
                        Text("AI runs on your iPhone when Apple Intelligence is available. Health details never appear in saved calendar events. You can change permissions in Settings.")
                            .font(.subheadline).foregroundStyle(LowCorTheme.secondary)
                        Button("Open app settings", systemImage: "arrow.up.right") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    }
                }.frame(maxWidth: 640).padding(24).frame(maxWidth: .infinity)
            }.background(LowCorTheme.canvas).foregroundStyle(LowCorTheme.ink)
                .navigationTitle("Connections").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.frame(minHeight: 44) } }
                .safeAreaInset(edge: .bottom) {
                    Button("Back to my day") { dismiss() }.buttonStyle(PulsePrimaryButton())
                        .padding(24).background(LowCorTheme.canvas)
                }
        }.tint(LowCorTheme.forest).preferredColorScheme(.light)
    }
}

struct PulseBreakReviewView: View {
    @ObservedObject var calendar: CalendarStore
    let slot: DateInterval
    let onSaved: (String) -> Void
    let onShowDay: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCalendar = ""
    @State private var error: String?
    @State private var saving = false
    @State private var saved = false
    @State private var destination = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: saved ? "checkmark.circle.fill" : "cup.and.saucer")
                        .font(.system(size: 44)).foregroundStyle(LowCorTheme.forest).accessibilityHidden(true)
                    Text(saved ? "A little room.\nNow reserved." : "Make this\nmoment yours.")
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text(saved ? "Your break is in \(destination). Here’s where it fits." : calendar.isDemo ? "Demo only. Nothing will be added to your real calendar." : "A 15-minute pause, with everything else left as it is.")
                        .foregroundStyle(LowCorTheme.secondary)
                    VStack(alignment: .leading, spacing: 20) {
                        Label("Private reset", systemImage: "leaf").font(.title2.bold())
                        Text(slot.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.subheadline)
                        Text("\(slot.start.formatted(date: .omitted, time: .shortened)) – \(slot.end.formatted(date: .omitted, time: .shortened))")
                            .font(.title2.weight(.semibold)).monospacedDigit()
                        if !saved {
                            Divider()
                            if calendar.isDemo {
                                Label("Demo calendar · this app only", systemImage: "flask").font(.subheadline)
                            } else if calendar.writableCalendars.isEmpty {
                                Text("No writable calendars available. Add a calendar in the Calendar app, then try again.")
                                    .font(.subheadline).foregroundStyle(LowCorTheme.terracotta)
                            } else {
                                Picker("Save to", selection: $selectedCalendar) {
                                    ForEach(calendar.writableCalendars, id: \.calendarIdentifier) { item in
                                        Text(item.title).tag(item.calendarIdentifier)
                                    }
                                }.frame(minHeight: 44)
                            }
                        } else {
                            Label("Added to \(destination)", systemImage: "checkmark.circle").font(.subheadline)
                        }
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(LowCorTheme.sage, in: RoundedRectangle(cornerRadius: 20))
                    neighborContext
                    if let error {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Couldn't add this break", systemImage: "exclamationmark.circle").font(.headline)
                            Text(error).font(.subheadline)
                            Button("Back to suggestion") { dismiss() }.frame(minHeight: 44)
                        }.foregroundStyle(LowCorTheme.terracotta).pulseCard()
                    }
                    if !saved {
                        Label(BreakSuggestionStore.elevatedCaution, systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(LowCorTheme.secondary)
                        Label(BreakSuggestionStore.caution, systemImage: "info.circle")
                            .font(.footnote).foregroundStyle(LowCorTheme.secondary)
                        Label("Only the break title and time are shared with your calendar—not your health readings or AI explanation.", systemImage: "lock.shield")
                            .font(.footnote).foregroundStyle(LowCorTheme.secondary)
                    }
                }.frame(maxWidth: 640).padding(24).frame(maxWidth: .infinity)
            }.background(LowCorTheme.canvas).foregroundStyle(LowCorTheme.ink)
                .navigationTitle(saved ? "Time protected" : "Review break").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(saved ? "Done" : "Cancel") { dismiss() }.frame(minHeight: 44) } }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        if saved { onShowDay(); dismiss() } else { save() }
                    } label: {
                        HStack {
                            if saving { ProgressView().tint(.white) }
                            Text(saved ? "See it in my day" : saving ? "Adding…" : calendar.isDemo ? "Add to demo day" : "Add to calendar")
                            Image(systemName: saved ? "arrow.right" : "plus")
                        }
                    }.buttonStyle(PulsePrimaryButton()).disabled(saving || (!saved && selectedCalendar.isEmpty))
                        .padding(24).background(LowCorTheme.canvas)
                }
                .onAppear { selectedCalendar = calendar.defaultCalendarID ?? "" }
                .sensoryFeedback(.success, trigger: saved)
        }.tint(LowCorTheme.forest).preferredColorScheme(.light)
    }

    private var neighborContext: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("IN YOUR DAY").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(LowCorTheme.secondary)
            if let before = calendar.events.filter({ !$0.isAllDay && $0.endDate <= slot.start }).last {
                neighbor(before.title, time: before.endDate, suffix: "ends")
            }
            HStack(spacing: 12) {
                Image(systemName: saved ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(LowCorTheme.forest)
                Text("15 minutes for yourself").font(.subheadline.weight(.semibold))
            }.padding(.vertical, 8)
            if let next = calendar.events.first(where: { !$0.isAllDay && $0.startDate >= slot.end }) {
                neighbor(next.title, time: next.startDate, suffix: "starts")
            } else {
                Text("No timed events after this break today.").font(.subheadline).foregroundStyle(LowCorTheme.secondary)
            }
        }.pulseCard()
    }

    private func neighbor(_ title: String, time: Date, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.medium))
            Text("\(suffix.capitalized) at \(time.formatted(date: .omitted, time: .shortened))")
                .font(.caption).foregroundStyle(LowCorTheme.secondary)
        }
    }

    private func save() {
        guard !saving, !saved else { return }
        saving = true
        error = nil
        do {
            destination = calendar.isDemo ? "Demo calendar" : calendar.writableCalendars.first { $0.calendarIdentifier == selectedCalendar }?.title ?? "Calendar"
            let id = try calendar.saveBreak(start: slot.start, end: slot.end, calendarID: selectedCalendar)
            saved = true
            onSaved(id)
        } catch { self.error = error.localizedDescription }
        saving = false
    }
}
