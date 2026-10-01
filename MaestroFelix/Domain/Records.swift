import Foundation

/// A personal best reached in a workout.
struct RecordHit: Equatable, Identifiable {
    enum Kind: String {
        /// The heaviest working weight.
        case weight
        /// The estimated one-repetition maximum.
        case oneRepMax
        /// The most repetitions in one set, for work with the body's own weight.
        case reps
        /// The most volume of one exercise in one workout.
        case volume
    }

    let exerciseID: String
    let kind: Kind
    let value: Double
    let previous: Double

    var id: String { "\(exerciseID)-\(kind.rawValue)" }
}

/// Total volume of the exercises that were done before, now against then.
struct VolumeComparison: Equatable {
    let current: Double
    let previous: Double
    var delta: Double { current - previous }
}

/// Bests and comparisons drawn from the history. Warm-ups are never counted, and the first time an
/// exercise is done there is nothing to beat, so it is not called a record.
enum PersonalRecords {
    /// The estimated heaviest single repetition from a set (Epley). Sets over twelve repetitions are
    /// too far from a maximum to say anything.
    static func oneRepMax(_ set: SetEntry) -> Double? {
        guard let weight = set.weightKg, weight > 0, let reps = set.reps, (1...12).contains(reps) else { return nil }
        return weight * Double(30 + reps) / 30
    }

    /// At most one record per exercise, the first that applies of: weight, estimated maximum, repetitions,
    /// volume.
    static func hits(in log: WorkoutLog, before logs: [WorkoutLog]) -> [RecordHit] {
        let earlier = logs.filter { $0.id != log.id && $0.finishedAt < log.finishedAt }
        return log.entries.compactMap { entry in
            let now = working(entry.sets)
            let past = earlier.flatMap { $0.entries.filter { $0.exerciseID == entry.exerciseID } }
            let pastSets = past.flatMap { working($0.sets) }
            guard !now.isEmpty, !pastSets.isEmpty else { return nil }

            if let hit = beaten(.weight, entry.exerciseID, now: best(now.compactMap(\.weightKg).filter { $0 > 0 }),
                                past: best(pastSets.compactMap(\.weightKg).filter { $0 > 0 })) { return hit }
            if let hit = beaten(.oneRepMax, entry.exerciseID, now: best(now.compactMap(oneRepMax)),
                                past: best(pastSets.compactMap(oneRepMax))) { return hit }
            let bodyweight: ([SetEntry]) -> [Double] = { $0.filter { ($0.weightKg ?? 0) == 0 }.compactMap { $0.reps.map(Double.init) } }
            if let hit = beaten(.reps, entry.exerciseID, now: best(bodyweight(now)), past: best(bodyweight(pastSets))) { return hit }
            return beaten(.volume, entry.exerciseID, now: volume(now), past: best(past.map { volume(working($0.sets)) }))
        }
    }

    /// How the exercise went the last time before `log` that it had working sets; nil when it is new.
    static func previousEntry(of exerciseID: String, before log: WorkoutLog, in logs: [WorkoutLog]) -> ExerciseLog? {
        logs.filter { $0.id != log.id && $0.finishedAt < log.finishedAt }
            .sorted { $0.finishedAt > $1.finishedAt }
            .lazy
            .compactMap { $0.entries.first { $0.exerciseID == exerciseID && !working($0.sets).isEmpty } }
            .first
    }

    /// Volume of the exercises this workout shares with earlier ones, against the last time each was done.
    static func volumeComparison(in log: WorkoutLog, before logs: [WorkoutLog]) -> VolumeComparison? {
        let earlier = logs.filter { $0.id != log.id && $0.finishedAt < log.finishedAt }.sorted { $0.finishedAt > $1.finishedAt }
        var current = 0.0
        var previous = 0.0
        for entry in log.entries {
            let last = earlier.lazy.compactMap { $0.entries.first { $0.exerciseID == entry.exerciseID && !working($0.sets).isEmpty } }.first
            guard let last else { continue }
            current += volume(working(entry.sets))
            previous += volume(working(last.sets))
        }
        return previous > 0 ? VolumeComparison(current: current, previous: previous) : nil
    }

    private static func working(_ sets: [SetEntry]) -> [SetEntry] { sets.filter { $0.kind != .warmup } }
    private static func volume(_ sets: [SetEntry]) -> Double { sets.reduce(0) { $0 + $1.volumeKg } }
    private static func best(_ values: [Double]) -> Double? { values.max() }

    private static func beaten(_ kind: RecordHit.Kind, _ id: String, now: Double?, past: Double?) -> RecordHit? {
        guard let now, let past, now > past else { return nil }
        return RecordHit(exerciseID: id, kind: kind, value: now, previous: past)
    }
}
