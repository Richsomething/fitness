import SwiftUI

/// One finished workout in a list: its name, when, how long, how much.
struct WorkoutLogRow: View {
    let log: WorkoutLog
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        NavigationLink { WorkoutDetailView(log: log) } label: {
            HStack(spacing: 12) {
                Image(systemName: log.kind == .strength ? "checkmark.circle.fill" : "figure.walk.circle.fill")
                    .font(.title3)
                    .foregroundStyle(log.kind == .strength ? FelixTheme.ice : FelixTheme.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(log.title).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                    Text(detail).font(.footnote).foregroundStyle(FelixTheme.secondary).multilineTextAlignment(.leading)
                    // What was actually done: two exercises by name and a count of the rest.
                    if let names = log.exerciseSummary {
                        Text(names).font(.caption).foregroundStyle(FelixTheme.tertiary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
            }
            .foregroundStyle(FelixTheme.text)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let day = log.day(calendar: app.calendar)
        var parts = [TrainingCalendar.shortDateText(day), "\(log.minutes) мин"]
        parts.append("\(log.setsDone) \(log.kind.setWords.form(log.setsDone))")
        if log.volumeKg > 0 { parts.append("\(WorkoutSummaryView.tons(log.volumeKg)) кг") }
        if log.kind != .strength { parts.append("вне плана") } else if log.isPartial { parts.append("частично") }
        return parts.joined(separator: " · ")
    }
}

/// Every finished workout, week by week, with what the week called for next to what was done.
struct HistoryListView: View {
    @Environment(AppCoordinator.self) private var app
    @State private var mode = Mode.list

    private enum Mode: Hashable { case list, calendar }

    var body: some View {
        let weeks = app.historyWeeks()
        return ScreenScaffold(glow: UnitPoint(x: 0.1, y: 0)) {
            VStack(alignment: .leading, spacing: 18) {
                Text("История").font(.felixTitle)
                if weeks.isEmpty {
                    EmptyHint(symbol: "figure.strengthtraining.traditional", text: "Пока нет завершённых тренировок.")
                } else {
                    GlassSegmented(options: [(Mode.list, "Список"), (Mode.calendar, "Календарь")], selection: $mode)
                    switch mode {
                    case .list: ForEach(weeks) { week in weekBlock(week) }
                    case .calendar: HistoryCalendarView()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func weekBlock(_ week: HistoryWeek) -> some View {
        let end = week.start.adding(days: 6, calendar: app.calendar)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("\(TrainingCalendar.shortDateText(week.start)) – \(TrainingCalendar.shortDateText(end))", color: FelixTheme.ice)
                Spacer()
                if week.planned > 0 {
                    Text("План: \(week.planned) · выполнено: \(week.done)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(FelixTheme.secondary)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(week.logs.enumerated()), id: \.element.id) { offset, log in
                    if offset > 0 { FelixDivider() }
                    WorkoutLogRow(log: log).padding(.horizontal, 16)
                }
            }
            .background(CardSurface(radius: 24))
        }
    }
}

/// A finished workout in full: the numbers, and every exercise set by set with how it felt.
struct WorkoutDetailView: View {
    let log: WorkoutLog
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDelete = false
    @State private var deleteFailed = false

    var body: some View {
        let records = PersonalRecords.hits(in: log, before: app.workouts.logs)
        let comparison = PersonalRecords.volumeComparison(in: log, before: app.workouts.logs)
        return ScreenScaffold(glow: UnitPoint(x: 0.9, y: 0)) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Eyebrow(whenText, color: FelixTheme.ice)
                        Spacer(minLength: 8)
                        actionsMenu
                    }
                    Text(log.title).font(.felixTitle).fixedSize(horizontal: false, vertical: true)
                    if log.isPartial { partialNote }
                }
                HStack(spacing: 10) {
                    tile("\(log.minutes)", "мин")
                    tile("\(log.setsDone)", log.kind.setWords.form(log.setsDone))
                    if log.volumeKg > 0 { tile(WorkoutSummaryView.tons(log.volumeKg), "объём, кг") }
                }
                if comparison != nil || !records.isEmpty { WorkoutResultsBlock(records: records, comparison: comparison) }
                ForEach(log.entries) { entry in exerciseCard(entry) }
                if deleteFailed { FelixInlineIssue(text: app.workouts.storageError ?? "Не удалось удалить тренировку.") }
            }
        }
        .environment(\.bodyBuild, BodyFigure.Build(app.profile?.gender))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("Удалить тренировку?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                if app.deleteWorkout(log) { dismiss() } else { deleteFailed = true }
            }
            Button("Оставить", role: .cancel) {}
        } message: {
            Text("Исчезнет из истории и серии. Вернуть нельзя.")
        }
    }

    /// Repeat it as it was, or take it out of the history.
    private var actionsMenu: some View {
        Menu {
            if let plan = log.repeatPlan {
                Button { app.start(plan, slot: nil) } label: { Label("Повторить тренировку", systemImage: "arrow.counterclockwise") }
            }
            Button(role: .destructive) { confirmsDelete = true } label: { Label("Удалить", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(FelixTheme.text)
                .frame(width: 44, height: 44)
                .felixGlass(in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel("Действия с тренировкой")
    }

    /// Cut short: how far it got, and which exercises were never started.
    private var partialNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Частично: \(log.setsDone) из \(log.setsPlanned) \(log.kind.setWords.form(log.setsPlanned))", systemImage: "circle.lefthalf.filled")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FelixTheme.ice)
            if !log.untouchedExerciseIDs.isEmpty {
                Text("Не начато: \(log.untouchedExerciseIDs.map { ExerciseCatalog.exercise($0).title }.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var whenText: String {
        let day = log.day(calendar: app.calendar)
        let name = OnboardingDraft.fullWeekdayNames[day.isoWeekday(calendar: app.calendar) - 1]
        return "\(name), \(TrainingCalendar.dateText(day)) · \(log.finishedAt.formatted(date: .omitted, time: .shortened))"
    }

    private func tile(_ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.felixNumber(26)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(unit).font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 78)
        .background(CardSurface(radius: 20))
        .accessibilityElement(children: .combine)
    }

    private func exerciseCard(_ entry: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ExerciseBadge(exerciseID: entry.exerciseID, size: 40)
                Text(ExerciseCatalog.exercise(entry.exerciseID).title).font(.headline).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let feel = entry.feel, feel != .fine {
                    InfoPill(text: feel.title)
                }
            }
            if let before = PersonalRecords.previousEntry(of: entry.exerciseID, before: log, in: app.workouts.logs), let top = before.topSet {
                Text("Прошлый раз: \(top.summary)").font(.footnote).foregroundStyle(FelixTheme.tertiary)
            }
            if entry.sets.isEmpty {
                Text("\(entry.setsDone) из \(entry.setsPlanned) подходов")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
            } else {
                let titles = entry.sets.rowTitles(noun: "Подход")
                VStack(spacing: 6) {
                    ForEach(Array(entry.sets.enumerated()), id: \.element.id) { offset, set in
                        HStack {
                            Text(titles[offset]).foregroundStyle(FelixTheme.secondary)
                            Spacer()
                            Text(set.rowSummary).monospacedDigit()
                        }
                        .font(.subheadline)
                    }
                }
                if entry.setsDone < entry.setsPlanned {
                    Text("Сделано \(entry.setsDone) из \(entry.setsPlanned)").font(.footnote).foregroundStyle(FelixTheme.ice)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface(radius: 24))
    }
}
