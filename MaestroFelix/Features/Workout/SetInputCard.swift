import FelixGlass
import SwiftUI

/// The set under way: what it was last time, the weight and repetitions to record (already filled in,
/// so a set as planned is one tap), and what kind of set it is. A weight that has never been set asks
/// for one instead of offering zero.
struct SetInputCard: View {
    let usesWeight: Bool
    let repsRange: ClosedRange<Int>
    @Binding var weight: Double
    @Binding var reps: Int
    @Binding var kind: SetKind
    @Binding var step: Double
    let previous: String?

    /// Starting points for a weight not yet chosen. They are only a quick way to type a number, not advice.
    private static let quickWeights: [Double] = [10, 20, 30, 40, 50]
    private static let steps: [(value: Double, title: String)] = [(1, "1"), (2.5, "2,5"), (5, "5")]

    var body: some View {
        VStack(spacing: 16) {
            if let previous {
                Label(previous, systemImage: "clock.arrow.circlepath")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(FelixTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 12) {
                if usesWeight {
                    NumberStepper(title: "Вес", value: $weight, step: step, range: 0...500, unit: "кг", fractionDigits: 1)
                }
                NumberStepper(title: "Повторы", value: repsAsDouble, step: 1, range: 1...200, unit: "цель \(repsRange.lowerBound)–\(repsRange.upperBound)")
            }
            if usesWeight && weight == 0 { weightPrompt }
            if usesWeight { stepChoice }
            GlassSegmented(options: SetKind.allCases.map { ($0, $0.title) }, selection: $kind, compact: true)
                .accessibilityLabel("Тип подхода")
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(CardSurface(radius: 28, highlighted: true))
    }

    private var weightPrompt: some View {
        VStack(spacing: 8) {
            Text("Какой вес берёшь?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FelixTheme.ice)
            HStack(spacing: 8) {
                ForEach(Self.quickWeights, id: \.self) { value in
                    Button { weight = value } label: {
                        Text(WeightFormat.kg(value))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(WeightFormat.kg(value)) килограммов")
                }
            }
        }
    }

    private var stepChoice: some View {
        HStack(spacing: 12) {
            Text("Шаг веса, кг")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FelixTheme.secondary)
            GlassSegmented(options: Self.steps, selection: $step, compact: true)
        }
    }

    private var repsAsDouble: Binding<Double> {
        Binding { Double(reps) } set: { reps = Int($0.rounded()) }
    }
}

/// Changes or removes a set already done.
struct SetEditSheet: View {
    let exerciseTitle: String
    let number: Int
    let isTimed: Bool
    let usesWeight: Bool
    let initial: SetEntry
    let onSave: (SetEntry) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weight = 0.0
    @State private var reps = 1.0
    @State private var seconds = 1.0
    @State private var kind = SetKind.normal

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Подход \(number)", color: FelixTheme.ice)
                Text(exerciseTitle).font(.felixHeadline).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 12) {
                if isTimed {
                    NumberStepper(title: "Время", value: $seconds, step: 5, range: 1...3600, unit: "секунд")
                } else {
                    if usesWeight { NumberStepper(title: "Вес", value: $weight, step: 2.5, range: 0...500, unit: "кг", fractionDigits: 1) }
                    NumberStepper(title: "Повторы", value: $reps, step: 1, range: 1...200, unit: "раз")
                }
            }
            if !isTimed {
                GlassSegmented(options: SetKind.allCases.map { ($0, $0.title) }, selection: $kind, compact: true)
                    .accessibilityLabel("Тип подхода")
            }
            VStack(spacing: 6) {
                FelixPrimaryButton(title: "Сохранить", systemImage: "checkmark") {
                    onSave(isTimed ? SetEntry(seconds: Int(seconds))
                                   : SetEntry(weightKg: usesWeight ? weight : nil, reps: Int(reps), kind: kind))
                    dismiss()
                }
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Text("Удалить подход").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                }
                .foregroundStyle(FelixTheme.critical)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(FelixTheme.text)
        .glassSheet(detents: [.medium])
        .onAppear {
            weight = initial.weightKg ?? 0
            reps = Double(initial.reps ?? 1)
            seconds = Double(initial.seconds ?? 1)
            kind = initial.kind
        }
    }
}
