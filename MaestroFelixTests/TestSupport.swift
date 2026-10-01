import Foundation
@testable import MaestroFelix

/// Shared fixtures. Every test runs on one calendar — Gregorian, UTC, weeks from Monday — so the
/// results do not depend on the machine's region or time zone.
///
/// Reference days: 2026-09-28 is a Monday, so 09-30 is a Wednesday and 10-02 a Friday.
enum T {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    static func day(_ text: String) -> DayKey { DayKey(rawValue: text)! }

    static func date(_ text: String, hour: Int = 12, minute: Int = 0) -> Date {
        day(text).at(hour: hour, minute: minute, calendar: calendar)
    }

    static func profile(weekdays: Set<Int> = [1, 3, 5], goal: TrainingGoal = .maintenance,
                        experience: TrainingExperience = .regular, limitations: [BodyZone] = []) -> OnboardingDraft {
        var draft = OnboardingDraft()
        draft.gender = .male
        draft.heightText = "180"
        draft.weightText = "80"
        draft.limitationsReviewed = true
        draft.weekdays = weekdays
        draft.goal = goal
        draft.experience = experience
        draft.startHour = 18
        draft.limitations = limitations.map { BodyLimitation(zone: $0) }
        return draft
    }

    static func state(weekdays: Set<Int> = [1, 3, 5], from: String = "2026-09-28") -> ScheduleState {
        var state = ScheduleState()
        state.record(weekdays: weekdays, from: day(from))
        return state
    }

    static func log(kind: WorkoutKind = .strength, slot: String? = nil, finished: String, hour: Int = 19,
                    sets: Int = 3) -> WorkoutLog {
        let end = date(finished, hour: hour)
        return WorkoutLog(kind: kind, title: "Тест", startedAt: end.addingTimeInterval(-3000), finishedAt: end,
                          entries: [ExerciseLog(exerciseID: "bench-press", setsPlanned: sets, setsDone: sets, feel: nil)],
                          sessionKey: slot.map(day), plannedSets: sets)
    }

    static func slots(_ state: ScheduleState, logs: [WorkoutLog] = [], from: String, through: String, today: String) -> [PlannedSlot] {
        SchedulePlanner.slots(state: state, logs: logs, from: day(from), through: day(through), today: day(today), calendar: calendar)
    }
}
