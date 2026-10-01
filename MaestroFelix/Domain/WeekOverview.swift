import Foundation

/// How much of a muscle group a week asks for, in planned sets, and how much of that is already done.
struct GroupLoad: Equatable, Identifiable {
    let group: MuscleGroup
    let plannedSets: Int
    let doneSets: Int

    var id: String { group.rawValue }
}

/// A week seen from above: how many of its sessions are done, what comes next, and how the sets are spread
/// over the body, so the plan shows whether the whole body gets its turn within the week.
struct WeekOverview: Equatable {
    /// The groups a week is expected to cover; cardio and mobility are not part of that count.
    static let bodyGroups: [MuscleGroup] = [.chest, .back, .shoulders, .arms, .legs, .glutes, .core]

    let sessionCount: Int
    let doneCount: Int
    /// The first open session from `today` on.
    let next: PlannedSession?
    /// Groups with sets in the week, the most loaded first.
    let loads: [GroupLoad]
    /// Body groups with no sets in the week.
    let untouched: [MuscleGroup]

    init(sessions: [PlannedSession], today: DayKey) {
        sessionCount = sessions.count
        doneCount = sessions.filter { $0.status.isDone }.count
        next = sessions.filter { $0.status == .planned && $0.day >= today }.min { $0.day < $1.day }

        // A skipped, missed or paused session is not going to happen, so it adds no load.
        var planned: [MuscleGroup: Int] = [:]
        var done: [MuscleGroup: Int] = [:]
        for session in sessions where session.status == .planned || session.status.isDone {
            for item in session.plan.exercises {
                planned[item.exercise.group, default: 0] += item.sets
                if session.status.isDone { done[item.exercise.group, default: 0] += item.sets }
            }
        }
        let position = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.enumerated().map { ($1, $0) })
        loads = planned
            .sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : position[lhs.key, default: 0] < position[rhs.key, default: 0]
            }
            .map { GroupLoad(group: $0.key, plannedSets: $0.value, doneSets: done[$0.key] ?? 0) }
        untouched = Self.bodyGroups.filter { planned[$0] == nil }
    }
}
