import SwiftUI

/// What a workout did against the past: its volume next to the last time, and the personal bests it reached.
/// The summary after a workout and the workout's page in the history show the same block. A number and a small
/// arrow say it; the full sentence is kept for VoiceOver.
struct WorkoutResultsBlock: View {
    let records: [RecordHit]
    let comparison: VolumeComparison?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let comparison { comparisonRow(comparison) }
            if !records.isEmpty {
                Eyebrow("Новые рекорды", color: FelixTheme.ice)
                ForEach(records) { recordRow($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    private func comparisonRow(_ comparison: VolumeComparison) -> some View {
        let delta = comparison.delta
        let spoken = delta == 0 ? "как в прошлый раз" : "\(delta > 0 ? "больше" : "меньше") на \(WorkoutSummaryView.tons(abs(delta))) кг, чем в прошлый раз"
        return HStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.body.weight(.bold))
                .foregroundStyle(FelixTheme.ice)
                .frame(width: 36, height: 36)
                .background(Circle().fill(FelixTheme.cobalt.opacity(0.22)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Объём").font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.secondary)
                Text("\(WorkoutSummaryView.tons(comparison.current)) кг")
                    .font(.felixNumber(24))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            if delta == 0 {
                DeltaPill(text: "0", symbol: "equal")
            } else {
                DeltaPill(text: "\(delta > 0 ? "+" : "−")\(WorkoutSummaryView.tons(abs(delta)))",
                          symbol: delta > 0 ? "arrow.up.right" : "arrow.down.right")
            }
        }
        .padding(14)
        .background(CardSurface(radius: 22))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Объём \(WorkoutSummaryView.tons(comparison.current)) кг, \(spoken)")
    }

    private func recordRow(_ hit: RecordHit) -> some View {
        let title = ExerciseCatalog.exercise(hit.exerciseID).title
        return HStack(spacing: 12) {
            Image(systemName: Self.symbol(for: hit.kind))
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(FelixTheme.cobalt))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(Self.valueText(hit)).font(.footnote.weight(.medium).monospacedDigit()).foregroundStyle(FelixTheme.secondary)
            }
            Spacer(minLength: 8)
            DeltaPill(text: Self.deltaText(hit), symbol: "arrow.up.right")
        }
        .padding(14)
        .background(CardSurface(radius: 22))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(Self.recordText(hit))")
    }

    /// What kind of record it is, as a glyph.
    private static func symbol(for kind: RecordHit.Kind) -> String {
        switch kind {
        case .weight: "scalemass.fill"
        case .oneRepMax: "bolt.fill"
        case .reps: "repeat"
        case .volume: "chart.bar.fill"
        }
    }

    private static func kg(_ value: Double) -> String { WeightFormat.kg((value * 2).rounded() / 2) }

    /// The new best on its own: "65 кг", "≈ 80 кг", "12 повт.", "4 200 кг".
    static func valueText(_ hit: RecordHit) -> String {
        switch hit.kind {
        case .weight: "\(kg(hit.value)) кг"
        case .oneRepMax: "≈ \(kg(hit.value)) кг"
        case .reps: "\(Int(hit.value)) повт."
        case .volume: "\(WorkoutSummaryView.tons(hit.value)) кг"
        }
    }

    /// How far the record moved: "+2,5", "+2", "+300".
    static func deltaText(_ hit: RecordHit) -> String {
        switch hit.kind {
        case .weight, .oneRepMax: "+\(kg(hit.value - hit.previous))"
        case .reps: "+\(Int(hit.value - hit.previous))"
        case .volume: "+\(WorkoutSummaryView.tons(hit.value - hit.previous))"
        }
    }

    /// "Рабочий вес 65 кг, раньше 60": the whole sentence, for VoiceOver.
    static func recordText(_ hit: RecordHit) -> String {
        switch hit.kind {
        case .weight: return "Рабочий вес \(kg(hit.value)) кг, раньше \(kg(hit.previous))"
        case .oneRepMax: return "Расчётный максимум \(kg(hit.value)) кг, раньше \(kg(hit.previous))"
        case .reps: return "\(Int(hit.value)) повторений за подход, раньше \(Int(hit.previous))"
        case .volume: return "Объём \(WorkoutSummaryView.tons(hit.value)) кг, раньше \(WorkoutSummaryView.tons(hit.previous))"
        }
    }
}

/// A small capsule with a direction and a number: how far something moved.
private struct DeltaPill: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(FelixTheme.ice)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(Capsule().fill(FelixTheme.cobalt.opacity(0.22)))
    }
}
