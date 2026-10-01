import Foundation

extension ExerciseLog {
    /// The best working set of the exercise: the heaviest, then the one with most repetitions, then the longest hold.
    var topSet: SetEntry? {
        sets.filter { $0.kind != .warmup }
            .max { ($0.weightKg ?? 0, $0.reps ?? 0, $0.seconds ?? 0) < ($1.weightKg ?? 0, $1.reps ?? 0, $1.seconds ?? 0) }
    }
}

extension WorkoutLog {
    /// A plan to do this workout again: the exercises that were done, with the sets they were planned for and the range of
    /// repetitions or the hold they were done with. Nil when nothing was done.
    var repeatPlan: WorkoutPlan? {
        let items = entries.filter { $0.sets.contains { $0.kind != .warmup } }.map { entry -> PlannedExercise in
            let working = entry.sets.filter { $0.kind != .warmup }
            let reps = working.compactMap(\.reps)
            let low = reps.min() ?? 8
            return PlannedExercise(exerciseID: entry.exerciseID, sets: max(entry.setsPlanned, working.count), repsLow: low,
                                   repsHigh: max(reps.max() ?? low, low), holdSeconds: working.compactMap(\.seconds).max() ?? 0,
                                   restSeconds: 60)
        }
        guard !items.isEmpty else { return nil }
        var focus: [MuscleGroup] = []
        for item in items where !focus.contains(item.exercise.group) { focus.append(item.exercise.group) }
        return WorkoutPlan(kind: kind, title: title, focus: focus, exercises: items)
    }

    /// Exercises the plan held that were never started, in plan order; empty for a log made before plans were kept.
    var untouchedExerciseIDs: [String] {
        let started = Set(entries.map(\.exerciseID))
        return (plannedExerciseIDs ?? []).filter { !started.contains($0) }
    }

    /// The exercises with working sets, named for a list row: the first two, the rest counted.
    var exerciseSummary: String? {
        let names = entries.filter { $0.sets.contains { $0.kind != .warmup } }.map { ExerciseCatalog.exercise($0.exerciseID).title }
        switch names.count {
        case 0: return nil
        case 1, 2: return names.joined(separator: ", ")
        default: return "\(names[0]), \(names[1]) и ещё \(names.count - 2)"
        }
    }
}
