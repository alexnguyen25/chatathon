import SwiftUI

private struct ExampleMoment: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let bpm: Int
    let isAvailable: Bool
}

struct ExampleDayView: View {
    @State private var isReviewingSuggestion = false
    @State private var isSaved = false

    private let moments = [
        ExampleMoment(time: "9 AM", title: "Planning", bpm: 72, isAvailable: false),
        ExampleMoment(time: "10 AM", title: "Focus", bpm: 76, isAvailable: false),
        ExampleMoment(time: "11 AM", title: "Design review", bpm: 84, isAvailable: false),
        ExampleMoment(time: "12 PM", title: "Available", bpm: 92, isAvailable: true),
        ExampleMoment(time: "1 PM", title: "Lunch", bpm: 78, isAvailable: false),
        ExampleMoment(time: "2 PM", title: "Deep work", bpm: 74, isAvailable: false),
        ExampleMoment(time: "3 PM", title: "Team sync", bpm: 81, isAvailable: false),
        ExampleMoment(time: "4 PM", title: "Wrap-up", bpm: 73, isAvailable: false),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("LowCor", systemImage: "waveform.path.ecg")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(LowCorTheme.ink)
                        .tint(LowCorTheme.forest)

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your day").font(.system(size: 42, weight: .bold, design: .rounded))
                            Text("Mon, Sep 21").font(.title3).foregroundStyle(LowCorTheme.secondary)
                        }
                        Spacer()
                        Text("Sample data")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(LowCorTheme.forest)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(LowCorTheme.sage, in: Capsule())
                    }

                    HStack {
                        Text("Time").frame(width: 54, alignment: .leading)
                        Text("Calendar")
                        Spacer()
                        Text("Heart rate\n(BPM)").multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline.weight(.medium))

                    VStack(spacing: 0) {
                        ForEach(moments) { moment in
                            ExampleTimelineRow(moment: moment, isSaved: isSaved)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "cup.and.saucer").font(.title).foregroundStyle(LowCorTheme.ink)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isSaved ? "Break added to example day" : "Make room for a break")
                                    .font(.title3.weight(.semibold))
                                Text("12:00–12:15 PM · Free in your calendar")
                                    .foregroundStyle(LowCorTheme.secondary)
                            }
                        }
                        Button(isSaved ? "Review example event" : "Review suggestion") { isReviewingSuggestion = true }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(LowCorTheme.forest, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white).font(.headline)
                    }
                    .padding(18)
                    .background(LowCorTheme.sage, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(24)
            }
            .background(LowCorTheme.canvas)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $isReviewingSuggestion) {
                SuggestionReviewView(isSaved: $isSaved)
            }
        }
    }
}

private struct ExampleTimelineRow: View {
    let moment: ExampleMoment
    let isSaved: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(moment.time).font(.footnote).foregroundStyle(LowCorTheme.secondary)
                .frame(width: 54, alignment: .leading)
            RoundedRectangle(cornerRadius: 12)
                .fill(moment.isAvailable ? Color.clear : LowCorTheme.sage)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(moment.isAvailable ? LowCorTheme.forest : Color.clear, style: StrokeStyle(lineWidth: 1.5, dash: moment.isAvailable ? [5, 4] : []))
                }
                .overlay(alignment: .leading) {
                    Text(moment.isAvailable && isSaved ? "Private reset · 12:00–12:15" : moment.title)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                }
                .frame(height: 54)
            VStack(spacing: 2) {
                Circle().fill(LowCorTheme.terracotta).frame(width: 9, height: 9)
                Text("\(moment.bpm)").font(.footnote.monospacedDigit()).foregroundStyle(LowCorTheme.secondary)
            }
            .frame(width: 34)
        }
        .padding(.vertical, 4)
    }
}

private struct SuggestionReviewView: View {
    @Binding var isSaved: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Review calendar event").font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 16) {
                Label("Private reset", systemImage: "cup.and.saucer").font(.title3.weight(.semibold))
                Divider()
                LabeledContent("Date", value: "Monday, Sep 21")
                LabeledContent("Time", value: "12:00–12:15 PM")
                LabeledContent("Destination", value: "Example day")
            }
            .padding(20)
            .background(LowCorTheme.sage, in: RoundedRectangle(cornerRadius: 16))
            Text("This is a sample-only confirmation. It never writes to your real calendar.")
                .font(.footnote).foregroundStyle(LowCorTheme.secondary)
            Spacer()
            Button("Add to example day") { isSaved = true; dismiss() }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(LowCorTheme.forest, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white).font(.headline)
        }
        .padding(24)
        .background(LowCorTheme.canvas)
        .navigationTitle("Suggestion")
        .navigationBarTitleDisplayMode(.inline)
    }
}
