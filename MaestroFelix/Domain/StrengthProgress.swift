import Foundation

/// One workout's result for one exercise, reduced to the number a progress chart draws.
struct ExercisePoint: Equatable, Identifiable {
    let workoutID: UUID
    let date: Date
    let value: Double

    var id: UUID { workoutID }
}

/// How one exercise has gone over the workouts it was done in.
struct ExerciseProgress: Equatable {
    /// What the number means. Weighted work is followed by the estimated one-repetition maximum, work with the
    /// body's own weight by the most repetitions in a set, held work by the longest hold.
    enum Metric: Equatable {
        case estimatedMax, reps, seconds

        var unit: String {
            switch self {
            case .estimatedMax: "кг"
            case .reps: "повт."
            case .seconds: "с"
            }
        }

        var title: String {
            switch self {
            case .estimatedMax: "Расчётный максимум"
            case .reps: "Повторений в подходе"
            case .seconds: "Удержание"
            }
        }
    }

    let exerciseID: String
    let metric: Metric
    /// Oldest first, one a workout.
    let points: [ExercisePoint]

    /// The highest point; the earlier one when two are level, as that is when it was first reached.
    var best: ExercisePoint? {
        points.reduce(nil as ExercisePoint?) { best, point in
            guard let best else { return point }
            return point.value > best.value ? point : best
        }
    }

    /// Latest minus first; nil with fewer than two workouts.
    var change: Double? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }
        return last.value - first.value
    }
}

/// A week's training in sets and kilograms lifted.
struct WeekVolume: Equatable, Identifiable {
    let start: DayKey
    let volumeKg: Double
    let sets: Int

    var id: String { start.rawValue }
}

/// Strength progress drawn from the log of sets: warm-ups are left out everywhere, and an exercise with nothing but
/// warm-ups has no history.
enum StrengthProgress {
    /// Exercises with at least one working set, the most often done first, the more recently done first among equals.
    static func exercises(in logs: [WorkoutLog]) -> [String] {
        var count: [String: Int] = [:]
        var latest: [String: Date] = [:]
        for log in logs {
            for entry in log.entries where !working(entry.sets).isEmpty {
                count[entry.exerciseID, default: 0] += 1
                latest[entry.exerciseID] = max(latest[entry.exerciseID] ?? .distantPast, log.finishedAt)
            }
        }
        return count.keys.sorted { lhs, rhs in
            if count[lhs] != count[rhs] { return count[lhs, default: 0] > count[rhs, default: 0] }
            if latest[lhs] != latest[rhs] { return latest[lhs, default: .distantPast] > latest[rhs, default: .distantPast] }
            return lhs < rhs
        }
    }

    static func progress(for exerciseID: String, in logs: [WorkoutLog]) -> ExerciseProgress? {
        let history = logs.sorted { $0.finishedAt < $1.finishedAt }.compactMap { log -> (UUID, Date, [SetEntry])? in
            let sets = log.entries.filter { $0.exerciseID == exerciseID }.flatMap { working($0.sets) }
            return sets.isEmpty ? nil : (log.id, log.finishedAt, sets)
        }
        guard !history.isEmpty else { return nil }

        let metric: ExerciseProgress.Metric
        if ExerciseCatalog.exercise(exerciseID).isTimed {
            metric = .seconds
        } else if history.contains(where: { $0.2.contains { ($0.weightKg ?? 0) > 0 } }) {
            metric = .estimatedMax
        } else {
            metric = .reps
        }

        let points = history.compactMap { id, date, sets -> ExercisePoint? in
            value(metric, sets).map { ExercisePoint(workoutID: id, date: date, value: $0) }
        }
        return points.isEmpty ? nil : ExerciseProgress(exerciseID: exerciseID, metric: metric, points: points)
    }

    /// The last `weeks` weeks up to the one `endingWith` falls in, oldest first; a week without training stays at zero.
    static func weeklyVolume(in logs: [WorkoutLog], weeks: Int, endingWith day: DayKey, calendar: Calendar = .current) -> [WeekVolume] {
        let last = day.weekStart(calendar: calendar)
        let starts = (0..<max(weeks, 0)).reversed().map { last.adding(days: -7 * $0, calendar: calendar) }
        let byWeek = Dictionary(grouping: logs) { $0.day(calendar: calendar).weekStart(calendar: calendar) }
        return starts.map { start in
            let sets = (byWeek[start] ?? []).flatMap(\.entries).flatMap { working($0.sets) }
            return WeekVolume(start: start, volumeKg: sets.reduce(0) { $0 + $1.volumeKg }, sets: sets.count)
        }
    }

    // MARK: Pieces

    private static func working(_ sets: [SetEntry]) -> [SetEntry] { sets.filter { $0.kind != .warmup } }

    /// A workout's number for the metric: the best of its sets.
    private static func value(_ metric: ExerciseProgress.Metric, _ sets: [SetEntry]) -> Double? {
        switch metric {
        case .seconds:
            return sets.compactMap(\.seconds).max().map(Double.init)
        case .reps:
            return sets.compactMap(\.reps).max().map(Double.init)
        case .estimatedMax:
            // Sets of many repetitions say little of a maximum; then the heaviest weight stands in.
            if let estimate = sets.compactMap(PersonalRecords.oneRepMax).max() { return estimate }
            return sets.compactMap(\.weightKg).filter { $0 > 0 }.max()
        }
    }
}
