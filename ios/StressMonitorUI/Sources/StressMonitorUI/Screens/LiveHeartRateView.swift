import SwiftUI
import StressCore

public struct LiveHeartRateView: View {

    @Bindable var model: LiveSessionModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: LiveSessionModel) {
        self._model = Bindable(model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    Wordmark()
                    Text("Live heart rate").displayTitleStyle()
                    statusRow
                }

                readout
                    .frame(maxWidth: .infinity)

                Divider().overlay(DS.Palette.hairline)

                baselineRow

                airPodsCard
                workoutRow

                VStack(spacing: DS.Space.s) {
                    PrimaryButton(model.isCollecting ? "End collection" : "Start collection") {
                        if model.isCollecting {
                            model.endCollection()
                        } else {
                            model.startCollecting()
                        }
                    }
                    Text(model.isCollecting
                         ? "Finishes the active workout."
                         : "Starts a walking workout to collect readings.")
                        .font(.footnote)
                        .foregroundStyle(DS.Palette.inkSecondary)
                }
            }
            .padding(.horizontal, DS.Space.screenMargin)
            .padding(.vertical, DS.Space.l)
        }
        .background(DS.Palette.canvas.ignoresSafeArea())
        .task { model.startCollecting() }
    }

    // MARK: - Pieces

    private var statusRow: some View {
        HStack(spacing: DS.Space.s) {
            Circle()
                .fill(model.isCollecting ? DS.Palette.green : DS.Palette.inkTertiary)
                .frame(width: 10, height: 10)
            Text(model.isCollecting ? "Collecting via HealthKit" : "Collection paused")
                .font(.system(.title3, weight: .regular))
                .foregroundStyle(DS.Palette.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var readout: some View {
        VStack(spacing: DS.Space.xs) {
            Image(systemName: "heart")
                .font(.system(size: 54, weight: .regular))
                .foregroundStyle(DS.Palette.signal)
                .padding(.bottom, DS.Space.s)

            Text("\(model.currentBPM)")
                .readoutStyle(size: 92)
                // The digits cross-fade in place rather than sliding, so a
                // changing number never drags the eye off the value.
                .contentTransition(.numericText())
                .animation(DS.transition(reduceMotion: reduceMotion), value: model.currentBPM)

            Text("BPM")
                .font(.system(.title, weight: .medium))
                .foregroundStyle(DS.Palette.ink)

            Text("Latest reading")
                .font(.system(.body))
                .foregroundStyle(DS.Palette.inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Latest reading \(model.currentBPM) beats per minute")
    }

    private var baselineRow: some View {
        HStack(spacing: 0) {
            statColumn("Session baseline", "\(model.sessionBaselineBPM) BPM")
            Divider()
                .overlay(DS.Palette.hairline)
                .frame(height: 44)
            statColumn(
                "From baseline",
                (model.deltaFromBaseline >= 0 ? "+" : "") + "\(model.deltaFromBaseline) BPM"
            )
        }
    }

    private func statColumn(_ label: String, _ value: String) -> some View {
        VStack(spacing: DS.Space.xs) {
            Text(label)
                .font(.system(.subheadline))
                .foregroundStyle(DS.Palette.inkSecondary)
            Text(value)
                .font(.system(.title2, weight: .semibold).monospacedDigit())
                .foregroundStyle(DS.Palette.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private var airPodsCard: some View {
        HStack(alignment: .top, spacing: DS.Space.l) {
            Image(systemName: "airpods")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(DS.Palette.ink)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("AirPods demo").rowTitleStyle()
                Text("Wear compatible AirPods.\nHealthKit selects the available source.")
                    .rowBodyStyle()
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.l)
        .sageCard()
    }

    private var workoutRow: some View {
        HStack(alignment: .top, spacing: DS.Space.l) {
            Image(systemName: "figure.walk")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(DS.Palette.ink)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(model.isCollecting ? "Walking workout active" : "No active workout")
                    .rowTitleStyle()
                Text("Readings are collected during this session.")
                    .rowBodyStyle()
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    LiveHeartRateView(model: LiveSessionModel())
}
