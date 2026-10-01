import SwiftUI

/// One planned session: what it holds and what can be done with it — start it today, move it, skip it,
/// bring a skipped one back, or open the result of a finished one.
struct SessionDetailView: View {
    let slot: DayKey
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var moving = false
    @State private var confirmsSkip = false
    @State private var technique: TechniqueTarget?
    @State private var swapping: TechniqueTarget?

    private struct TechniqueTarget: Identifiable {
        let id: String
    }

    var body: some View {
        let session = app.session(forSlot: slot)
        return ScreenScaffold(glow: UnitPoint(x: 0.9, y: 0)) {
            if let session {
                content(session)
            } else {
                Text("Это занятие больше не в плане.")
                    .foregroundStyle(FelixTheme.secondary)
            }
        }
        // The actions stay in view above the tab bar instead of waiting at the end of the list.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let session { actionBar(session) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $technique) { ExerciseTechniqueSheet(exerciseID: $0.id) }
        .sheet(item: $swapping) { SwapExerciseSheet(slot: slot, exerciseID: $0.id) }
    }

    private func content(_ session: PlannedSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(whenText(session), color: FelixTheme.ice)
                Text(session.plan.title).font(.felixTitle).fixedSize(horizontal: false, vertical: true)
                // State and size are text; only the muscle groups are pills, so each kind of fact looks like itself.
                HStack(spacing: 8) {
                    Label(session.status.title, systemImage: session.status.symbol)
                        .foregroundStyle(session.status.color)
                    Text("·").foregroundStyle(FelixTheme.tertiary)
                    Text(sizeText(session)).foregroundStyle(FelixTheme.secondary)
                }
                .font(.subheadline.weight(.semibold))
                FlowLayout(spacing: 6) {
                    ForEach(session.plan.focus) { InfoPill(text: $0.title) }
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(session.plan.exercises.enumerated()), id: \.element.id) { offset, item in
                    if offset > 0 { FelixDivider() }
                    exerciseRow(item, in: session)
                }
            }
            .background(CardSurface(radius: 24))
            if !session.plan.avoidedZones.isEmpty { AvoidedNote(zones: session.plan.avoidedZones) }
            notes(session)
            StarterPlanNote()
        }
        .sheet(isPresented: $moving) { MoveSessionSheet(session: session) }
        .confirmationDialog("Пропустить тренировку?", isPresented: $confirmsSkip, titleVisibility: .visible) {
            Button("Пропустить", role: .destructive) { app.skip(session.key) }
            Button("Не пропускать", role: .cancel) {}
        } message: {
            Text("Не пойдёт в серию. Можно вернуть.")
        }
    }

    /// "5 упражнений · ≈ 20 мин".
    private func sizeText(_ session: PlannedSession) -> String {
        let count = session.plan.exercises.count
        let exercises = "\(count) \(RussianPlural.form(count, one: "упражнение", few: "упражнения", many: "упражнений"))"
        return "\(exercises) · ≈ \(session.plan.estimatedMinutes) мин"
    }

    private func whenText(_ session: PlannedSession) -> String {
        let name = OnboardingDraft.fullWeekdayNames[session.day.isoWeekday(calendar: app.calendar) - 1]
        let time = TrainingCalendar.clock(hour: app.profile?.startHour ?? 18, minute: app.profile?.startMinute ?? 0)
        return "\(name), \(TrainingCalendar.dateText(session.day)) · \(time)"
    }

    private func exerciseRow(_ item: PlannedExercise, in session: PlannedSession) -> some View {
        HStack(spacing: 0) {
            Button { technique = TechniqueTarget(id: item.exerciseID) } label: {
                HStack(spacing: 12) {
                    ExerciseBadge(exerciseID: item.exerciseID, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.exercise.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                        if app.originalExercise(of: item.exerciseID, in: session) != nil {
                            Text("Заменено вами").font(.caption).foregroundStyle(FelixTheme.ice)
                        }
                        if let calibration = item.calibration {
                            Text(calibration).font(.caption).foregroundStyle(FelixTheme.ice)
                        }
                        if let last = app.lastTimeText(for: item.exerciseID) {
                            Text("Прошлый раз: \(last)").font(.caption).foregroundStyle(FelixTheme.tertiary)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(item.targetText).font(.subheadline.monospacedDigit()).foregroundStyle(FelixTheme.secondary)
                }
                .foregroundStyle(FelixTheme.text)
                .padding(.leading, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Как делать упражнение")
            rowMenu(item, in: session)
        }
    }

    /// How to do the exercise, and for an open session also swapping it or putting the planner's own back.
    private func rowMenu(_ item: PlannedExercise, in session: PlannedSession) -> some View {
        Menu {
            Button { technique = TechniqueTarget(id: item.exerciseID) } label: { Label("Как делать", systemImage: "info.circle") }
            if session.status == .planned {
                Button { swapping = TechniqueTarget(id: item.exerciseID) } label: {
                    Label("Заменить упражнение", systemImage: "arrow.triangle.2.circlepath")
                }
                if let original = app.originalExercise(of: item.exerciseID, in: session) {
                    Button { app.swapExercise(item.exerciseID, with: original, in: session) } label: {
                        Label("Вернуть исходное", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FelixTheme.tertiary)
                .frame(width: 48, height: 60)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Действия с упражнением «\(item.exercise.title)»")
    }

    /// The one thing to do with the session, pinned at the bottom: start it today, otherwise move it, with
    /// the rest in a menu.
    @ViewBuilder private func actionBar(_ session: PlannedSession) -> some View {
        switch session.status {
        case .planned:
            let isToday = session.day == app.today
            HStack(spacing: 10) {
                if isToday {
                    FelixPrimaryButton(title: "Начать тренировку", systemImage: "play.fill") { start(session) }
                } else {
                    FelixSecondaryButton(title: "Перенести", systemImage: "calendar.badge.clock") { moving = true }
                }
                Menu {
                    if isToday {
                        Button { moving = true } label: { Label("Перенести", systemImage: "calendar.badge.clock") }
                    } else {
                        Button { start(session) } label: { Label("Начать раньше", systemImage: "play") }
                    }
                    Button(role: .destructive) { confirmsSkip = true } label: { Label("Пропустить", systemImage: "forward") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(FelixTheme.text)
                        .frame(width: 54, height: 54)
                        .felixGlass(in: Circle())
                        .contentShape(Circle())
                }
                .accessibilityLabel("Другие действия")
            }
            .pinnedActions()
        case let .done(id):
            if let log = app.workouts.logs.first(where: { $0.id == id }) {
                NavigationLink { WorkoutDetailView(log: log) } label: {
                    Text("Посмотреть результат")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .felixGlass(in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .pinnedActions()
            }
        case .skipped:
            FelixSecondaryButton(title: "Вернуть в план", systemImage: "arrow.uturn.backward") { app.unskip(session.key) }
                .pinnedActions()
        case .missed, .paused:
            EmptyView()
        }
    }

    /// What a session cannot be used for, said where the actions would be.
    @ViewBuilder private func notes(_ session: PlannedSession) -> some View {
        switch session.status {
        case .missed: note("Занятие прошло, перенести нельзя.")
        case .paused: note("На паузе: пропусков нет.")
        default: EmptyView()
        }
    }

    private func start(_ session: PlannedSession) {
        app.start(session.plan, slot: session.key)
        dismiss()
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(FelixTheme.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
