import Foundation

/// How a week went: the sessions it called for (a held day calls for none) and the ones done.
struct WeekProgress: Equatable, Identifiable {
    let start: DayKey
    let planned: Int
    let done: Int

    var id: String { start.rawValue }
    var isComplete: Bool { planned > 0 && done == planned }
}

struct TrainingStats: Equatable {
    /// Planned sessions done in a row; a day off changes nothing, a closed day without a session breaks it.
    var streak = 0
    var bestStreak = 0
    var doneSessions = 0
    var fullWeeks = 0
    /// Every finished workout, rest-day activity included.
    var workouts = 0
    var week: WeekProgress?
}

enum ProgressCalculator {
    /// Streak over slots up to `today`. Done adds one; a skipped or missed session resets; a held one
    /// and today's still-open one leave it alone.
    static func streak(in slots: [PlannedSlot], today: DayKey) -> (current: Int, best: Int) {
        var current = 0
        var best = 0
        for slot in slots.sorted(by: { ($0.day, $0.slot) < ($1.day, $1.slot) }) where slot.day <= today {
            switch slot.status {
            case .done:
                current += 1
                best = max(best, current)
            case .skipped, .missed:
                current = 0
            case .paused, .planned:
                break
            }
        }
        return (current, best)
    }

    static func weeks(in slots: [PlannedSlot], calendar: Calendar = .current) -> [WeekProgress] {
        let grouped = Dictionary(grouping: slots) { $0.day.weekStart(calendar: calendar) }
        return grouped.map { start, group in
            let due = group.filter { $0.status != .paused }
            return WeekProgress(start: start, planned: due.count, done: due.filter { $0.status.isDone }.count)
        }
        .sorted { $0.start < $1.start }
    }

    static func stats(state: ScheduleState, logs: [WorkoutLog], today: DayKey, calendar: Calendar = .current) -> TrainingStats {
        let weekEnd = today.weekStart(calendar: calendar).adding(days: 6, calendar: calendar)
        let first = state.revisions.first?.from ?? today
        let slots = SchedulePlanner.slots(state: state, logs: logs, from: min(first, today), through: weekEnd, today: today,
                                          calendar: calendar)
        let run = streak(in: slots, today: today)
        let weeks = weeks(in: slots, calendar: calendar)
        var stats = TrainingStats()
        stats.streak = run.current
        stats.bestStreak = run.best
        stats.doneSessions = slots.filter { $0.status.isDone }.count
        stats.fullWeeks = weeks.filter(\.isComplete).count
        stats.workouts = logs.count
        stats.week = weeks.first { $0.start == today.weekStart(calendar: calendar) }
        return stats
    }
}

// MARK: - Achievements

enum AchievementID: String, Codable, CaseIterable, Sendable {
    case firstWorkout, threeInPlan, firstFullWeek

    var title: String {
        switch self {
        case .firstWorkout: "Первая тренировка"
        case .threeInPlan: "Три по плану"
        case .firstFullWeek: "Полная неделя"
        }
    }

    var detail: String {
        switch self {
        case .firstWorkout: "Завершил первое занятие"
        case .threeInPlan: "Выполнил три плановых занятия"
        case .firstFullWeek: "Выполнил весь план недели"
        }
    }

    var symbol: String {
        switch self {
        case .firstWorkout: "flag.checkered"
        case .threeInPlan: "3.circle.fill"
        case .firstFullWeek: "calendar.badge.checkmark"
        }
    }
}

/// What was unlocked and when. Issuing is idempotent: an achievement already here is never issued again.
struct AchievementsState: Codable, Equatable {
    /// The rules' version at the time of writing, so a later change to a condition can be told apart.
    var version = AchievementRules.version
    var unlocked: [String: Date] = [:]

    func has(_ id: AchievementID) -> Bool { unlocked[id.rawValue] != nil }
}

/// How far along an achievement is: what is done toward what it takes.
struct AchievementProgress: Equatable {
    let current: Int
    let goal: Int

    init(current: Int, goal: Int) {
        self.goal = goal
        self.current = min(max(current, 0), goal)
    }

    var remaining: Int { goal - current }
    var fraction: Double { goal == 0 ? 1 : Double(current) / Double(goal) }
}

enum AchievementRules {
    static let version = 1

    /// What each achievement takes; `isMet` says it is reached when progress is whole.
    static func progress(_ id: AchievementID, stats: TrainingStats) -> AchievementProgress {
        switch id {
        case .firstWorkout: AchievementProgress(current: stats.workouts, goal: 1)
        case .threeInPlan: AchievementProgress(current: stats.doneSessions, goal: 3)
        case .firstFullWeek: AchievementProgress(current: stats.fullWeeks, goal: 1)
        }
    }

    static func isMet(_ id: AchievementID, stats: TrainingStats) -> Bool {
        switch id {
        case .firstWorkout: stats.workouts >= 1
        case .threeInPlan: stats.doneSessions >= 3
        case .firstFullWeek: stats.fullWeeks >= 1
        }
    }

    /// Achievements the stats meet that are not yet unlocked.
    static func newlyMet(stats: TrainingStats, state: AchievementsState) -> [AchievementID] {
        AchievementID.allCases.filter { isMet($0, stats: stats) && !state.has($0) }
    }
}

// MARK: - History

/// A week of the history: what it called for next to what was done, with every workout finished in it.
struct HistoryWeek: Equatable, Identifiable {
    let start: DayKey
    let planned: Int
    let done: Int
    let logs: [WorkoutLog]

    var id: String { start.rawValue }
}

enum HistoryBuilder {
    /// Weeks newest first, each with its workouts newest first. A week with a workout but no plan
    /// (before a schedule existed) shows the workouts alone.
    static func weeks(logs: [WorkoutLog], slots: [PlannedSlot], calendar: Calendar = .current) -> [HistoryWeek] {
        let progress = Dictionary(uniqueKeysWithValues: ProgressCalculator.weeks(in: slots, calendar: calendar).map { ($0.start, $0) })
        let byWeek = Dictionary(grouping: logs) { $0.day(calendar: calendar).weekStart(calendar: calendar) }
        return Set(progress.keys).union(byWeek.keys)
            .compactMap { start -> HistoryWeek? in
                let entries = (byWeek[start] ?? []).sorted { $0.finishedAt > $1.finishedAt }
                guard !entries.isEmpty else { return nil }
                return HistoryWeek(start: start, planned: progress[start]?.planned ?? 0, done: progress[start]?.done ?? 0, logs: entries)
            }
            .sorted { $0.start > $1.start }
    }
}
