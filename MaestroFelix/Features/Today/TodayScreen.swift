import SwiftUI

/// The first tab: what is on today. A greeting, the coach's word, one card for the day's session —
/// or the rest — and the week at a glance. Nothing else competes with the day's one action.
struct TodayScreen: View {
    @Environment(AppCoordinator.self) private var app
    @State private var confirmsDiscard = false

    var body: some View {
        let state = app.todayState
        return NavigationStack {
            ScreenScaffold {
                VStack(alignment: .leading, spacing: 14) {
                    header.entrance(0)
                    // Only until a way is chosen; after that "Подбор нагрузки" lives in the profile.
                    if app.adaptiveTraining.state.route == nil {
                        NavigationLink {
                            TrainingStartView()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("С чего начнём?").font(.headline)
                                Text("Записать результаты, подготовиться или оценить силу позже")
                                    .font(.subheadline).foregroundStyle(FelixTheme.secondary)
                            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(CardSurface(radius: 22))
                        }.buttonStyle(PressableStyle())
                    }
                    if let saved = app.workouts.resumable, app.activeSession == nil {
                        ResumeBanner(snapshot: saved, onResume: { app.resume() }, onDiscard: { confirmsDiscard = true })
                            .entrance(1)
                    }
                    // The day's own card comes first; the coach's line is a note under it, not a card above it.
                    TodayStateCard(state: state).entrance(2)
                    CoachCard(persona: app.coach.persona, line: app.coachLine(for: app.coachEvent(for: state)),
                              event: app.coachEvent(for: state), actionTitle: action(for: state)?.title, action: action(for: state)?.run)
                        .entrance(3)
                    WeekStrip(week: app.week(of: app.today), today: app.today, progress: app.progress.stats.week,
                              streak: app.progress.stats.streak)
                        .entrance(4)
                }
                .entranceScope("today")
            }
            // The day's one action stays in view whatever the length of the list above it.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if case let .training(session) = state {
                    FelixPrimaryButton(title: "Начать тренировку", systemImage: "play.fill") {
                        app.start(session.plan, slot: session.key)
                    }
                    .pinnedActions()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .confirmationDialog("Отменить незавершённую тренировку?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Отменить без сохранения", role: .destructive) { app.discardResumable() }
            Button("Оставить", role: .cancel) {}
        } message: {
            Text("Сделанные подходы не сохранятся.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(dateLine, color: FelixTheme.ice)
            // One line at the card-title size: the greeting is a hello, not the screen's main subject.
            Text(greeting)
                .font(.felixHeadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dateLine: String {
        let weekday = OnboardingDraft.fullWeekdayNames[app.today.isoWeekday(calendar: app.calendar) - 1]
        return "\(weekday), \(TrainingCalendar.dateText(app.today))"
    }

    private var greeting: String {
        let hour = app.calendar.component(.hour, from: app.now)
        let name = app.profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? Greeting.text(hour: hour) : "\(Greeting.text(hour: hour)), \(name)"
    }

    private struct CardAction {
        let title: String
        let run: () -> Void
    }

    /// The one thing the coach offers next to their line, if the day has one.
    private func action(for state: TodayState) -> CardAction? {
        switch state {
        case .training: nil
        case .trainingDone: nil
        case .skipped: nil
        case .paused: CardAction(title: "Снять паузу") { app.resumeSchedule() }
        // No "open the plan" link: the Plan tab is one tap away at the bottom.
        case .rest: nil
        }
    }
}

/// A workout left unfinished: go on with it, or let it go.
struct ResumeBanner: View {
    let snapshot: SessionSnapshot
    let onResume: () -> Void
    let onDiscard: () -> Void

    private var done: Int { snapshot.workingSetsDone }
    private var total: Int { snapshot.plan.exercises.reduce(0) { $0 + $1.sets } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Незавершённая тренировка", color: FelixTheme.ice)
                Text(snapshot.plan.title).font(.headline)
                Text("Подходов: \(done) из \(total) · начата в \(snapshot.startedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
            }
            HStack(spacing: 10) {
                FelixPrimaryButton(title: "Продолжить", systemImage: "play.fill", action: onResume)
                Button(action: onDiscard) {
                    Text("Отменить")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FelixTheme.secondary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 56)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface(radius: 24, highlighted: true))
    }
}
