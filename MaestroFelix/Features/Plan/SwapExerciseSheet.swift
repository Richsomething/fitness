import SwiftUI

/// What to do in place of an exercise of a planned session: the ones that work the same muscles, without load
/// on a zone the person marked. If the exercise was swapped before, the planner's own one is on the list too.
struct SwapExerciseSheet: View {
    let slot: DayKey
    let exerciseID: String
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let session = app.session(forSlot: slot)
        let options = session.map { app.alternatives(for: exerciseID, in: $0) } ?? []
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Замена", color: FelixTheme.ice)
                Text("Что вместо «\(ExerciseCatalog.exercise(exerciseID).title)»?")
                    .font(.felixHeadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Работают те же мышцы. Подходы и повторения остаются, вес подберётся заново.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let session, !options.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(options) { row($0, in: session) }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                Text("Подходящих замен нет: остальные упражнения этой группы уже в занятии или нагружают отмеченные зоны.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(FelixTheme.text)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Color(red: 0.035, green: 0.04, blue: 0.07))
    }

    private func row(_ option: Exercise, in session: PlannedSession) -> some View {
        let isOriginal = app.originalExercise(of: exerciseID, in: session) == option.id
        return Button {
            app.swapExercise(exerciseID, with: option.id, in: session)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                ExerciseBadge(exerciseID: option.id, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                    if isOriginal { Text("Исходное по плану").font(.caption).foregroundStyle(FelixTheme.ice) }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.triangle.2.circlepath").font(.footnote.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(CardSurface(radius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Заменить упражнение")
    }
}
