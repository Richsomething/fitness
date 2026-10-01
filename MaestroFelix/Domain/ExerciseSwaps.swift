import Foundation

/// Replacing an exercise of a planned session with another one that works the same muscles. The plan itself is
/// still made by the planner; a swap is the person's change on top of it, kept with the session's slot.
enum ExerciseSwaps {
    /// What can stand in for `exerciseID`: the same muscle group and the same kind of work (held or counted),
    /// not already in the plan, and with no load on a zone the person marked.
    static func alternatives(for exerciseID: String, in plan: WorkoutPlan, limitations: [BodyZone]) -> [Exercise] {
        let original = ExerciseCatalog.exercise(exerciseID)
        let blocked = Set(limitations)
        let present = Set(plan.exercises.map(\.exerciseID))
        return ExerciseCatalog.all.filter {
            $0.group == original.group && $0.isTimed == original.isTimed && !present.contains($0.id)
                && $0.loads.isDisjoint(with: blocked)
        }
    }

    /// The plan with each swapped exercise replaced by its stand-in. Sets, repetitions and rest stay; advice and
    /// weights worked out for the old exercise do not carry over. A swap onto an exercise the plan already has,
    /// or for one it no longer has, is left out.
    static func apply(_ swaps: [String: String], to plan: WorkoutPlan) -> WorkoutPlan {
        guard !swaps.isEmpty else { return plan }
        var taken = Set(plan.exercises.map(\.exerciseID))
        var result = plan
        result.exercises = plan.exercises.map { item in
            guard let replacement = swaps[item.exerciseID], !taken.contains(replacement) else { return item }
            taken.insert(replacement)
            return PlannedExercise(exerciseID: replacement, sets: item.sets, repsLow: item.repsLow, repsHigh: item.repsHigh,
                                   holdSeconds: item.holdSeconds, restSeconds: item.restSeconds)
        }
        return result
    }
}
