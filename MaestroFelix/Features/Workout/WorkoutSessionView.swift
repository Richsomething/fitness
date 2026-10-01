import SwiftUI

/// A workout from start to result: the exercise list, the runner for the exercise under way, the
/// rating of how each felt, and the summary. It can be minimised at any point and resumed later.
struct WorkoutSessionView: View {
    let session: WorkoutSession
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsExit = false
    @State private var confirmsDiscard = false
    @State private var summary: FinishSummary?
    @State private var saveError: String?

    var body: some View {
        ZStack {
            FelixBackground()
            AmbientGlow(anchor: UnitPoint(x: 0.5, y: 0))
            content
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .animation(.smooth(duration: 0.35), value: session.phase)
        .foregroundStyle(FelixTheme.text)
        .environment(\.bodyBuild, BodyFigure.Build(app.profile?.gender))
        .confirmationDialog("Закончить тренировку?", isPresented: $confirmsExit, titleVisibility: .visible) {
            Button("Свернуть — продолжу позже") { dismiss() }
            Button("Завершить и оценить") { session.beginRating() }
            Button("Выйти без сохранения", role: .destructive) {
                guard session.hasProgress else { discard(); return }
                // Sets would be lost, so it is asked once more, after this dialog has closed.
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    confirmsDiscard = true
                }
            }
            Button("Продолжить", role: .cancel) {}
        } message: {
            Text("\(words.progress): \(session.completedSets) из \(session.totalSets)")
        }
        .confirmationDialog("Удалить без сохранения?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Удалить без сохранения", role: .destructive) { discard() }
            Button("Вернуться к тренировке", role: .cancel) {}
        } message: {
            Text("Записанное (\(session.completedSets) из \(session.totalSets)) пропадёт.")
        }
    }

    private func discard() {
        app.cancel(session)
        dismiss()
    }

    private var words: SetWords { session.plan.kind.setWords }

    @ViewBuilder private var content: some View {
        if let summary {
            WorkoutSummaryView(summary: summary) {
                app.activeSession = nil
                dismiss()
            }
        } else {
            switch session.phase {
            case .overview:
                overview
            case .working, .resting, .paused, .exerciseDone:
                if let index = session.phase.exerciseIndex {
                    ExerciseRunnerView(session: session, index: index) { session.beginRating() }
                }
            case .rating:
                WorkoutRatingView(session: session, error: saveError ?? app.workouts.storageError) { save() }
            }
        }
    }

    private func save() {
        if let result = app.finish(session) {
            saveError = nil
            summary = result
        } else {
            saveError = "Тренировку не удалось сохранить. Попробуй ещё раз."
        }
    }

    // MARK: Overview

    private var overview: some View {
        VStack(spacing: 0) {
            HStack {
                FelixIconButton(systemImage: "xmark", label: "Закрыть тренировку") {
                    if session.hasProgress { confirmsExit = true } else { closeEmpty() }
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Label(ExerciseRunnerView.clock(timeline.date.timeIntervalSince(session.startedAt)), systemImage: "stopwatch")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(FelixTheme.ice)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .felixGlass(in: Capsule(), interactive: false)
                }
            }
            .padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(kindLabel, color: FelixTheme.ice)
                        Text(session.plan.title)
                            .font(.felixTitle)
                            .fixedSize(horizontal: false, vertical: true)
                        progressBar
                    }
                    .padding(.bottom, 8)
                    ForEach(Array(session.plan.exercises.enumerated()), id: \.element.id) { index, item in
                        exerciseRow(index, item)
                    }
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
            overviewAction
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .entranceScope("session-\(session.id.uuidString)")
    }

    /// The exercise to do next: the first with sets left.
    private var nextIndex: Int? { session.plan.exercises.indices.first { !session.isDone($0) } }

    /// One clear next step: start or go on, or finish when everything is done.
    @ViewBuilder private var overviewAction: some View {
        VStack(spacing: 4) {
            if session.isComplete || nextIndex == nil {
                FelixPrimaryButton(title: "Завершить и оценить", systemImage: "flag.checkered") { session.beginRating() }
            } else if let next = nextIndex {
                FelixPrimaryButton(title: session.hasProgress ? "Продолжить" : "Начать тренировку", systemImage: "play.fill") {
                    session.start(next)
                }
                if session.hasProgress {
                    Button { session.beginRating() } label: {
                        Text("Завершить досрочно")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FelixTheme.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
        }
    }

    /// An untouched workout has nothing to keep, so closing it forgets it.
    private func closeEmpty() {
        app.cancel(session)
        dismiss()
    }

    private var kindLabel: String {
        switch session.plan.kind {
        case .strength: "Тренировка"
        case .cardio: "День отдыха · кардио"
        case .light: "День отдыха · лёгкий блок"
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [FelixTheme.ice, FelixTheme.cobalt], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * Double(session.completedSets) / Double(max(session.totalSets, 1)))
                }
            }
            .frame(height: 10)
            HStack {
                // Cardio is one block per exercise, so one count says it all.
                if session.plan.kind != .cardio {
                    Text("Упражнений: \(session.exercisesDone) из \(session.plan.exercises.count)")
                    Spacer()
                }
                Text("\(words.progress): \(session.completedSets) из \(session.totalSets)")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(FelixTheme.secondary)
            .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private func exerciseRow(_ index: Int, _ item: PlannedExercise) -> some View {
        let done = session.isDone(index)
        let isNext = index == nextIndex
        return Button { session.start(index) } label: {
            HStack(spacing: 14) {
                ZStack {
                    ExerciseBadge(exerciseID: item.exerciseID, size: 48)
                    if done {
                        Circle().fill(FelixTheme.cobalt.opacity(0.9))
                        Image(systemName: "checkmark").font(.title3.weight(.bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.exercise.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    Text(rowDetail(item))
                        .font(.subheadline)
                        .foregroundStyle(FelixTheme.secondary)
                    if let calibration = item.calibration {
                        Label(calibration, systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FelixTheme.ice)
                    }
                    if item.sets > 1 {
                        let setsDone = min(session.setsDone[index], item.sets)
                        HStack(spacing: 4) {
                            ForEach(0..<item.sets, id: \.self) { set in
                                Capsule()
                                    .fill(set < setsDone ? FelixTheme.cobalt : Color.white.opacity(0.12))
                                    .frame(width: 18, height: 4)
                            }
                            // The dashes alone do not say what they count.
                            Text("\(setsDone) из \(item.sets)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(FelixTheme.tertiary)
                                .padding(.leading, 4)
                        }
                        .padding(.top, 2)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(words.progress): \(setsDone) из \(item.sets)")
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: done ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(done ? FelixTheme.ice : FelixTheme.cobalt)
            }
            .foregroundStyle(FelixTheme.text)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardSurface(radius: 24, highlighted: isNext))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint(done ? "Упражнение выполнено" : "Начать подход")
    }

    private func rowDetail(_ item: PlannedExercise) -> String {
        guard item.sets > 1, item.restSeconds > 0 else { return item.targetText }
        return "\(item.targetText) · отдых \(item.restSeconds) с"
    }
}
