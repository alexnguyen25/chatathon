import SwiftUI

private struct ExampleMoment: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let detail: String
    let bpm: Int?
}

struct ExampleDayView: View {
    @State private var isReviewingSuggestion = false
    @State private var isSaved = false

    private let moments = [
        ExampleMoment(time: "9:00", title: "Planning", detail: "Calendar", bpm: 72),
        ExampleMoment(time: "10:00", title: "Focus", detail: "Calendar", bpm: 76),
        ExampleMoment(time: "11:00", title: "Design Review", detail: "Calendar · synthetic change begins", bpm: 84),
        ExampleMoment(time: "11:30", title: "Design Review", detail: "Synthetic observation", bpm: 91),
        ExampleMoment(time: "12:00", title: "Available", detail: "30-minute open calendar slot", bpm: 88),
        ExampleMoment(time: "12:30", title: "Lunch", detail: "Calendar", bpm: 76),
        ExampleMoment(time: "13:00", title: "Deep Work", detail: "Calendar", bpm: 73),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Example day")
                        .font(.largeTitle.bold())
                    Text("A clearly labeled synthetic showcase. It never replaces your live Health data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    GroupBox("Monday · September 21") {
                        VStack(spacing: 0) {
                            ForEach(moments) { moment in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(moment.time)
                                        .font(.footnote.monospacedDigit())
                                        .frame(width: 42, alignment: .leading)
                                        .foregroundStyle(.secondary)
                                    Circle()
                                        .fill(moment.title == "Available" ? Color.green : Color(red: 0.65, green: 0.33, blue: 0.26))
                                        .frame(width: 10, height: 10)
                                        .padding(.top, 5)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(moment.title).font(.body.weight(.medium))
                                            Spacer()
                                            if let bpm = moment.bpm { Text("\(bpm) BPM").font(.footnote.monospacedDigit()) }
                                        }
                                        Text(moment.detail).font(.footnote).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 10)
                            }
                        }
                    }

                    GroupBox("Planning prompt") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Synthetic observation", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                            Text("Readings changed during Design Review. A 30-minute opening appears before Lunch.")
                            Text("Consider protecting 12:00–12:15 as a private reset before afternoon work.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button(isSaved ? "Added to example day" : "Review suggestion") {
                                isReviewingSuggestion = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.14, green: 0.36, blue: 0.27))
                        }
                    }
                }
                .padding()
            }
            .navigationDestination(isPresented: $isReviewingSuggestion) {
                SuggestionReviewView(isSaved: $isSaved)
            }
        }
    }
}

private struct SuggestionReviewView: View {
    @Binding var isSaved: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Private reset") {
                LabeledContent("Date", value: "Monday, Sep 21")
                LabeledContent("Time", value: "12:00–12:15")
                LabeledContent("Calendar", value: "Example day only")
            }
            Section {
                Text("This screen does not write to your real calendar. It demonstrates the review-before-save flow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Add to example day") {
                    isSaved = true
                    dismiss()
                }
            }
        }
        .navigationTitle("Review suggestion")
    }
}
