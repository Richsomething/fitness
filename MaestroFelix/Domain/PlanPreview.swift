import Foundation

/// What the person is about to get, said before the profile is saved and again once it is: the training days of
/// the week and the first session, made by the same planner that will make it for real.
struct PlanPreview: Equatable, Identifiable {
    struct FirstSession: Equatable {
        let day: DayKey
        let hour: Int
        let minute: Int
        let title: String
        let exerciseCount: Int
        let minutes: Int
    }

    /// ISO weekdays, Monday = 1, in order.
    let weekdays: [Int]
    /// The next training time after now; nil when the planner has nothing for that day.
    let first: FirstSession?

    var id: String { weekdays.map(String.init).joined() }
    var weekdayNames: [String] { weekdays.map { OnboardingDraft.weekdayNames[$0 - 1] } }

    static func make(from draft: OnboardingDraft, now: Date, calendar: Calendar) -> PlanPreview? {
        guard !draft.weekdays.isEmpty else { return nil }
        let start = TrainingCalendar.nextSession(weekdays: draft.weekdays, hour: draft.startHour, minute: draft.startMinute,
                                                 after: now, calendar: calendar)
        let first = start.flatMap { date -> FirstSession? in
            guard let plan = WorkoutPlanner.plan(for: draft, weekdays: draft.weekdays, on: date, calendar: calendar) else { return nil }
            return FirstSession(day: DayKey(date, calendar: calendar), hour: draft.startHour, minute: draft.startMinute,
                                title: plan.title, exerciseCount: plan.exercises.count, minutes: plan.estimatedMinutes)
        }
        return PlanPreview(weekdays: draft.weekdays.sorted(), first: first)
    }
}
