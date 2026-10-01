import FelixGlass
import SwiftUI

/// How to do an exercise: which muscles it works, on the front and back of the same drawing the
/// health map uses, and three cues on technique.
struct ExerciseTechniqueSheet: View {
    let exerciseID: String
    @Environment(\.bodyBuild) private var build
    @Environment(\.dismiss) private var dismiss

    private var exercise: Exercise { ExerciseCatalog.exercise(exerciseID) }
    private var info: ExerciseInfo { ExerciseCatalog.info(exerciseID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                figures
                muscleList
                tips
                Text("Общие подсказки, не медицинская рекомендация. Появилась боль — остановись.")
                    .font(.footnote)
                    .foregroundStyle(FelixTheme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                FelixPrimaryButton(title: "Понятно", systemImage: "checkmark") { dismiss() }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .foregroundStyle(FelixTheme.text)
        .glassSheet(detents: [.large])
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ExerciseBadge(exerciseID: exerciseID, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(exercise.group.title, color: FelixTheme.ice)
                Text(exercise.title)
                    .font(.felixHeadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            // A way to close that does not need a gesture, within reach of the thumb at the top.
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .felixGlass(in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("Закрыть")
        }
    }

    /// Only the sides that have a lit muscle: a dim empty silhouette beside the real one says nothing and costs half the card.
    private var figures: some View {
        let sides: [(String, BodyFigure.Facing, [String])] = [("Спереди", .front, info.front), ("Сзади", .back, info.back)]
            .filter { !$0.2.isEmpty }
        let shown = sides.isEmpty ? [("Спереди", BodyFigure.Facing.front, info.front)] : sides
        return HStack(spacing: 12) {
            ForEach(shown, id: \.0) { figure($0.0, facing: $0.1, muscles: $0.2) }
        }
        .padding(16)
        .background(CardSurface(radius: 28))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Работают мышцы: \(muscleTitles.joined(separator: ", "))")
    }

    private func figure(_ caption: String, facing: BodyFigure.Facing, muscles: [String]) -> some View {
        VStack(spacing: 8) {
            MuscleHighlightView(muscles: muscles, facing: facing, build: build)
                .frame(height: 210)
            Eyebrow(caption, color: FelixTheme.ice)
        }
        .frame(maxWidth: .infinity)
    }

    private var muscleTitles: [String] {
        var seen = Set<String>()
        return (info.front + info.back).map(MuscleNames.title).filter { seen.insert($0).inserted }
    }

    private var muscleList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Работают")
            FlowLayout(spacing: 8) {
                ForEach(muscleTitles, id: \.self) { title in
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FelixTheme.ice)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Capsule().fill(FelixTheme.cobalt.opacity(0.22)))
                }
            }
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Как делать")
            ForEach(Array(info.tips.enumerated()), id: \.offset) { offset, tip in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(offset + 1)")
                        .font(.felixNumber(20))
                        .foregroundStyle(FelixTheme.ice)
                        .frame(width: 24)
                    Text(tip)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
