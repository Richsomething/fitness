import SwiftUI

/// The card for today's session, in whichever state the day is.
struct TodayStateCard: View {
    let state: TodayState
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        switch state {
        case let .training(session):
            TrainingCard(session: session)
        case let .trainingDone(session, log):
            DoneCard(session: session, log: log)
        case let .skipped(session):
            SkippedCard(session: session)
        case let .paused(until, next):
            PausedCard(until: until, next: next)
        case let .rest(next, movedTo, activity):
            RestDayCard(next: next, movedTo: movedTo, activity: activity)
        }
    }
}

/// What a session holds, shown as lines: a badge of the muscles, the name in full, how it went last time,
/// the target.
struct ExerciseLine: View {
    let item: PlannedExercise
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        HStack(spacing: 12) {
            ExerciseBadge(exerciseID: item.exerciseID, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.exercise.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let last = app.lastTimeText(for: item.exerciseID) {
                    // The clock says "last time"; the words are for VoiceOver.
                    Label(last, systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(FelixTheme.tertiary)
                        .accessibilityLabel("Прошлый раз: \(last)")
                }
            }
            Spacer(minLength: 8)
            Text(item.targetText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(FelixTheme.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A short note that zones the person marked were kept out of the plan.
struct AvoidedNote: View {
    let zones: [BodyZone]

    /// A few zones by name, the rest counted: the full list is long and repeats on every screen.
    static func text(for zones: [BodyZone]) -> String {
        let names = zones.map { $0.title.lowercased() }
        let shown = names.count <= 3 ? names.joined(separator: ", ") : "\(names[0]), \(names[1]) и ещё \(names.count - 2)"
        return "Обошли нагрузку на: \(shown)"
    }

    var body: some View {
        Label(Self.text(for: zones), systemImage: "shield.lefthalf.filled")
            .font(.footnote.weight(.medium))
            .foregroundStyle(FelixTheme.ice)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct InfoPill: View {
    let text: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(FelixTheme.ice)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .felixGlass(in: Capsule(), interactive: false, tint: FelixTheme.cobalt.opacity(0.28))
    }
}

// MARK: - Training

private struct TrainingCard: View {
    let session: PlannedSession
    @Environment(AppCoordinator.self) private var app
    @State private var moving = false
    @State private var confirmsSkip = false

    var body: some View {
        // The start button is pinned at the bottom of the screen (see TodayScreen), so it never waits below the fold.
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(session.isMoved ? "Сегодня · перенесена" : "Сегодня", color: FelixTheme.ice)
                Text(session.plan.title)
                    .font(.felixHeadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(meta).font(.subheadline).foregroundStyle(FelixTheme.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(session.plan.exercises) { ExerciseLine(item: $0) }
            }
            if !session.plan.avoidedZones.isEmpty { AvoidedNote(zones: session.plan.avoidedZones) }
            actions
            StarterPlanNote()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HeroCardBackground())
        .sheet(isPresented: $moving) { MoveSessionSheet(session: session) }
        .confirmationDialog("Пропустить тренировку?", isPresented: $confirmsSkip, titleVisibility: .visible) {
            Button("Пропустить", role: .destructive) { app.skip(session.key) }
            Button("Не пропускать", role: .cancel) {}
        } message: {
            Text("Не пойдёт в серию. Можно вернуть.")
        }
    }

    /// "5 упражнений · ≈ 20 мин".
    private var meta: String {
        let count = session.plan.exercises.count
        let exercises = "\(count) \(RussianPlural.form(count, one: "упражнение", few: "упражнения", many: "упражнений"))"
        return "\(exercises) · ≈ \(session.plan.estimatedMinutes) мин"
    }

    /// What else can be done with today's session, said in words and kept quieter than the start button.
    private var actions: some View {
        HStack(spacing: 24) {
            Button { moving = true } label: { Label("Перенести", systemImage: "calendar.badge.clock") }
            Button { confirmsSkip = true } label: { Label("Пропустить", systemImage: "forward.end") }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(FelixTheme.secondary)
        .labelStyle(.titleAndIcon)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

// MARK: - Done, skipped, paused

private struct DoneCard: View {
    let session: PlannedSession
    let log: WorkoutLog

    var body: some View {
        NavigationLink {
            WorkoutDetailView(log: log)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient(colors: [.white, FelixTheme.ice], startPoint: .top, endPoint: .bottom))
                    .symbolEffect(.bounce, options: .nonRepeating)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Сегодня · сделано", color: FelixTheme.ice)
                    Text(session.plan.title).font(.felixHeadline).multilineTextAlignment(.leading)
                    Text("\(log.setsDone) \(RussianPlural.form(log.setsDone, one: "подход", few: "подхода", many: "подходов")) · \(log.minutes) мин")
                        .font(.subheadline)
                        .foregroundStyle(FelixTheme.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
            }
            .foregroundStyle(FelixTheme.text)
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HeroCardBackground())
            .contentShape(RoundedRectangle(cornerRadius: FelixTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Открыть результат")
    }
}

private struct SkippedCard: View {
    let session: PlannedSession
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Сегодня · пропущена", color: FelixTheme.ice)
            Text(session.plan.title).font(.felixHeadline).fixedSize(horizontal: false, vertical: true)
            Text("Занятие пропущено. Его можно вернуть в план.")
                .font(.subheadline)
                .foregroundStyle(FelixTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            FelixSecondaryButton(title: "Вернуть в план", systemImage: "arrow.uturn.backward") { app.unskip(session.key) }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
    }
}

private struct PausedCard: View {
    let until: DayKey
    let next: PlannedSession?
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Пауза", color: FelixTheme.ice)
            Text("До \(TrainingCalendar.dateText(until))").font(.felixHeadline)
            Text("На паузе: пропусков и напоминаний нет.")
                .font(.subheadline)
                .foregroundStyle(FelixTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            FelixSecondaryButton(title: "Снять паузу", systemImage: "play.fill") { app.resumeSchedule() }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
    }
}
