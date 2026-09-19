import SwiftUI

/// Educational context, deliberately separate from personal medical interpretation.
struct HealthInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Understand your signals.")
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Numbers are context, not a verdict. These adult reference values are not personalized targets or diagnoses.")
                        .foregroundStyle(LowCorTheme.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Your judgment comes first", systemImage: "hand.raised")
                        .font(.headline)
                    Text("AI can be wrong, and Health data can be incomplete. Break suggestions are optional planning ideas—not medical advice. Consider how you feel and decide what works for you.")
                        .font(.subheadline)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LowCorTheme.sage, in: RoundedRectangle(cornerRadius: 20))

                metricCard(
                    title: "Heart rate",
                    symbol: "heart",
                    reference: "BPM · beats per minute",
                    summary: "How often your heart beats. Workday samples include different activities; their average is not your resting heart rate.",
                    details: "A higher reading can accompany movement, standing up, heat or emotions. A lower reading can reflect rest, fitness or medication. A change near a meeting does not prove that the meeting caused it."
                )

                metricCard(
                    title: "Resting heart rate",
                    symbol: "heart.text.clipboard",
                    reference: "60–100 BPM · typical adult resting range",
                    summary: "This range applies while calm, sitting or lying down and feeling well. It is a reference range, not an average or a target for every person.",
                    details: "Below 60 can occur with fitness, sleep or certain medicines. Above 100 at rest can have temporary or medical causes. Discuss persistent changes from your usual rate with a healthcare professional.",
                    sourceTitle: "American Heart Association",
                    sourceURL: "https://www.heart.org/en/health-topics/high-blood-pressure/the-facts-about-high-blood-pressure/all-about-heart-rate-pulse"
                )

                metricCard(
                    title: "Heart rate variability",
                    symbol: "waveform.path.ecg",
                    reference: "HRV · SDNN in milliseconds",
                    summary: "Variation in the time between heartbeats. There is no single normal cutoff for everyone’s short wearable recordings. Compare your own readings under similar conditions.",
                    details: "Lower than your usual HRV can accompany less sleep or other changes; it does not identify the cause. Higher is not automatically better. Age, breathing, posture, recording length and signal quality affect comparisons. Short wearable measurements and 24-hour clinical values are not interchangeable. LowCor reads recorded SDNN—it does not calculate HRV from ordinary BPM samples.",
                    sourceTitle: "Apple HealthKit: HRV / SDNN",
                    sourceURL: "https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn"
                )

                metricCard(
                    title: "Sleep",
                    symbol: "moon.zzz",
                    reference: "7+ hours · recommendation for ages 18–60",
                    summary: "CDC recommends 7–9 hours at ages 61–64 and 7–8 hours at 65+. Sleep quality matters too; these recommendations are not a guarantee of feeling rested.",
                    details: "A shorter recorded night may mean less sleep—or incomplete tracking. Longer recordings do not prove good-quality sleep. LowCor shows sleep recorded in Health, not a diagnosis. Speak with a healthcare professional about recurring sleep problems.",
                    sourceTitle: "CDC: About sleep",
                    sourceURL: "https://www.cdc.gov/sleep/about/index.html"
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("How we use this")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("LowCor looks for repeated elevated heart-rate samples before recommending a pause. Only then does it look for a calendar opening. An open slot by itself never triggers a suggestion. HRV and sleep add context; they cannot prove stress or that a break will change your readings.")
                    DisclosureGroup("How the MVP pattern check works") {
                        Text("The last 30 minutes must contain at least four samples spanning 15 minutes, with no gaps over 10 minutes and a latest sample within 10 minutes. Earlier today must also have at least four samples spanning 15 minutes. At least 80% of recent samples, and their average, must exceed the earlier sample average by both 20 BPM and 25%. These are unvalidated product rules—not clinical thresholds or a reliable stress test. A missing or negative flag does not rule out a health issue.")
                            .font(.footnote).foregroundStyle(LowCorTheme.secondary).padding(.top, 8)
                    }
                    Text("A screen-free pause gives you room to move, stretch or change posture. Short, regular changes of activity can fit into a workday; the right timing depends on your work. Our 15-minute slot is an app choice, not a medical prescription.")
                    Text("Missing values mean unknown, not zero. Demo values are simulated. You always review a break before saving it.")
                    referenceLink("HSE: Work routine and breaks", "https://www.hse.gov.uk/msd/dse/work-routine.htm")
                }
                .font(.subheadline)
                .infoSurface()

                VStack(alignment: .leading, spacing: 12) {
                    Label("Don’t wait for an app", systemImage: "cross.case")
                        .font(.headline)
                    Text("If you have concerning symptoms, seek medical help instead of relying on these suggestions. For chest pain, severe trouble breathing or fainting, seek emergency care.")
                        .font(.subheadline)
                    referenceLink("Heart-rate symptoms: American Heart Association", "https://www.heart.org/en/health-topics/high-blood-pressure/the-facts-about-high-blood-pressure/all-about-heart-rate-pulse")
                }
                .infoSurface()

                VStack(alignment: .leading, spacing: 8) {
                    Text("More about HRV interpretation")
                        .font(.footnote.weight(.semibold))
                    referenceLink("Clinical overview: Cleveland Clinic", "https://my.clevelandclinic.org/health/articles/21773-heart-rate-variability-hrv")
                    referenceLink("Research: HRV metrics and recording context", "https://www.frontiersin.org/journals/public-health/articles/10.3389/fpubh.2017.00258/full")
                    Text("General education for adults. Your clinician can help interpret your individual readings.")
                        .font(.footnote)
                        .foregroundStyle(LowCorTheme.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(LowCorTheme.canvas)
        .foregroundStyle(LowCorTheme.ink)
        .tint(LowCorTheme.forest)
        .navigationTitle("About your signals")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricCard(
        title: String,
        symbol: String,
        reference: String,
        summary: String,
        details: String,
        sourceTitle: String? = nil,
        sourceURL: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(reference)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LowCorTheme.forest)
            Text(summary)
                .font(.subheadline)
            DisclosureGroup("What a change could mean") {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(LowCorTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            .font(.subheadline.weight(.medium))
            if let sourceTitle, let sourceURL {
                referenceLink(sourceTitle, sourceURL)
            }
        }
        .infoSurface()
    }

    @ViewBuilder
    private func referenceLink(_ title: String, _ address: String) -> some View {
        if let url = URL(string: address) {
            Link(destination: url) {
                Label(title, systemImage: "arrow.up.right")
                    .font(.footnote)
                    .frame(minHeight: 44, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

private extension View {
    func infoSurface() -> some View {
        padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}
