import SwiftUI

/// What a workout did against the past: its volume next to the last time, and the personal bests it reached.
/// The summary after a workout and the workout's page in the history show the same block.
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
        let change = delta == 0 ? "как в прошлый раз" : "\(delta > 0 ? "+" : "−")\(WorkoutSummaryView.tons(abs(delta))) кг к прошлому разу"
        return HStack(spacing: 12) {
            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.body.weight(.bold))
                .foregroundStyle(FelixTheme.ice)
                .frame(width: 36, height: 36)
                .background(Circle().fill(FelixTheme.cobalt.opacity(0.22)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Объём \(WorkoutSummaryView.tons(comparison.current)) кг").font(.subheadline.weight(.semibold))
                Text(change).font(.footnote).foregroundStyle(FelixTheme.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(CardSurface(radius: 22))
        .accessibilityElement(children: .combine)
    }

    private func recordRow(_ hit: RecordHit) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(FelixTheme.cobalt))
            VStack(alignment: .leading, spacing: 2) {
                Text(ExerciseCatalog.exercise(hit.exerciseID).title).font(.subheadline.weight(.semibold))
                Text(Self.recordText(hit)).font(.footnote).foregroundStyle(FelixTheme.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(CardSurface(radius: 22))
        .accessibilityElement(children: .combine)
    }

    /// "Рабочий вес 65 кг, раньше 60".
    static func recordText(_ hit: RecordHit) -> String {
        func kg(_ value: Double) -> String { WeightFormat.kg((value * 2).rounded() / 2) }
        switch hit.kind {
        case .weight: return "Рабочий вес \(kg(hit.value)) кг, раньше \(kg(hit.previous))"
        case .oneRepMax: return "Расчётный максимум \(kg(hit.value)) кг, раньше \(kg(hit.previous))"
        case .reps: return "\(Int(hit.value)) повторений за подход, раньше \(Int(hit.previous))"
        case .volume: return "Объём \(WorkoutSummaryView.tons(hit.value)) кг, раньше \(WorkoutSummaryView.tons(hit.previous))"
        }
    }
}
