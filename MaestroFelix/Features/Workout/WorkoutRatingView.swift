import SwiftUI

/// At the end: how each exercise felt. Everything starts at "В самый раз", so only what stood out needs
/// a tap; the ratings calibrate the next plans. The way back to the workout stays open until it is saved.
struct WorkoutRatingView: View {
    let session: WorkoutSession
    let error: String?
    let onSave: () -> Void
    @Environment(AppCoordinator.self) private var app
    private var appUsesAdaptive: Bool { app.adaptiveTraining.state.route != nil }

    private var done: [Int] {
        session.plan.exercises.indices.filter { !session.sets[$0].isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { withAnimation(.smooth) { session.showOverview() } } label: {
                    Label("К тренировке", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FelixTheme.ice)
                        .frame(minHeight: 44)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Как прошло?", color: FelixTheme.ice)
                        Text("Всё в самый раз?")
                            .font(.felixTitle)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Отметь каждое упражнение: уточним нагрузку.")
                            .font(.subheadline)
                            .foregroundStyle(FelixTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 8)
                    ForEach(done, id: \.self) { row($0) }
                    if done.isEmpty {
                        Text("Ни одного подхода — оценивать пока нечего.")
                            .foregroundStyle(FelixTheme.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 8) {
                if let error { FelixInlineIssue(text: error) }
                FelixPrimaryButton(title: "Сохранить тренировку", systemImage: "checkmark", action: onSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .entranceScope("rating-\(session.id.uuidString)")
        .sensoryFeedback(.selection, trigger: session.feels)
    }

    private func row(_ index: Int) -> some View {
        let item = session.plan.exercises[index]
        let feedback = session.feedbacks[item.exerciseID] ?? ExerciseFeedback()
        let feel = Binding { session.feel(for: item.exerciseID) } set: { session.rate(item.exerciseID, $0) }
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                ExerciseBadge(exerciseID: item.exerciseID, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.exercise.title)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail(index, item))
                        .font(.footnote)
                        .foregroundStyle(FelixTheme.secondary)
                }
                Spacer(minLength: 0)
            }
            GlassSegmented(options: ExerciseFeel.allCases.map { ($0, $0.title) }, selection: feel, compact: true, tight: true)
                .accessibilityLabel("Оценка: \(item.exercise.title)")
            if appUsesAdaptive {
                Picker("Запас в последнем рабочем подходе", selection: Binding<Int>(
                    get: { feedback.reserve ?? -1 },
                    set: { session.setFeedback(item.exerciseID, ExerciseFeedback(reserve: $0 < 0 ? nil : $0, reason: feedback.reason)) })) {
                    Text("Не знаю").tag(-1)
                    ForEach(0...5, id: \.self) { Text("\($0) повторов").tag($0) }
                }
                Picker("Контекст упражнения", selection: Binding(
                    get: { feedback.reason },
                    set: { session.setFeedback(item.exerciseID, ExerciseFeedback(reserve: feedback.reserve, reason: $0)) })) {
                    ForEach(TrainingAdjustmentReason.allCases) { Text($0.title).tag($0) }
                }
            }
        }
        .padding(14)
        .background(CardSurface(radius: 22))
    }

    /// "3 подхода", or what a single stretch of time came to.
    private func detail(_ index: Int, _ item: PlannedExercise) -> String {
        if item.sets == 1, let only = session.sets[index].first { return only.summary }
        let count = session.setsDone[index]
        return "\(count) \(session.plan.kind.setWords.form(count))"
    }
}
