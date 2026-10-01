import Foundation
import Observation

/// Where a workout in progress stands.
enum SessionPhase: Equatable, Codable {
    /// The exercise list.
    case overview
    /// A set under way since `since`.
    case working(index: Int, since: Date)
    /// Rest after a set until `until`; `length` is the full rest, for the ring.
    case resting(index: Int, until: Date, length: TimeInterval)
    /// A timed set on hold; `elapsed` is what had run when it was stopped.
    case paused(index: Int, elapsed: TimeInterval)
    /// All sets of an exercise done.
    case exerciseDone(index: Int)
    /// Rating the exercises at the end.
    case rating

    /// The exercise the phase is about, if any.
    var exerciseIndex: Int? {
        switch self {
        case let .working(index, _), let .resting(index, _, _), let .paused(index, _), let .exerciseDone(index): index
        case .overview, .rating: nil
        }
    }
}

/// A workout in progress written down whole, so it can go on after the app is closed or evicted.
struct SessionSnapshot: Codable, Equatable {
    var id: UUID
    var plan: WorkoutPlan
    var slot: DayKey?
    var startedAt: Date
    var sets: [[SetEntry]]
    var phase: SessionPhase
    var feels: [String: ExerciseFeel]
    var feedbacks: [String: ExerciseFeedback]?

    /// The sets done so far that count toward the plan: warm-ups are left out, like in the planned total.
    var workingSetsDone: Int { sets.reduce(0) { $0 + $1.filter { $0.kind != .warmup }.count } }

    /// Whether the snapshot still fits its plan. One that does not is dropped rather than shown wrong.
    var isConsistent: Bool {
        guard sets.count == plan.exercises.count else { return false }
        return phase.exerciseIndex.map { plan.exercises.indices.contains($0) } ?? true
    }
}

/// One workout in progress. Timers are dates, not counters, so they stay right if the app sleeps;
/// every change reports itself through `onChange`, which is how the workout gets written down.
@MainActor @Observable
final class WorkoutSession: Identifiable {
    let id: UUID
    let plan: WorkoutPlan
    /// The planned slot this workout is for; nil for rest-day activity.
    let slot: DayKey?
    let startedAt: Date
    private(set) var sets: [[SetEntry]]
    private(set) var phase: SessionPhase
    private(set) var feels: [String: ExerciseFeel]
    private(set) var feedbacks: [String: ExerciseFeedback] = [:]
    /// The sets of the last time each exercise was done, to prefill inputs and show "last time".
    @ObservationIgnored private let history: [String: [SetEntry]]
    @ObservationIgnored var onChange: (() -> Void)?

    init(plan: WorkoutPlan, slot: DayKey? = nil, history: [String: [SetEntry]] = [:], startedAt: Date = .now, id: UUID = UUID()) {
        self.id = id
        self.plan = plan
        self.slot = slot
        self.startedAt = startedAt
        self.history = history
        sets = Array(repeating: [], count: plan.exercises.count)
        phase = .overview
        feels = [:]
    }

    convenience init?(snapshot: SessionSnapshot, history: [String: [SetEntry]] = [:]) {
        guard snapshot.isConsistent else { return nil }
        self.init(plan: snapshot.plan, slot: snapshot.slot, history: history, startedAt: snapshot.startedAt, id: snapshot.id)
        sets = snapshot.sets
        phase = snapshot.phase
        feels = snapshot.feels
        feedbacks = snapshot.feedbacks ?? [:]
    }

    func snapshot() -> SessionSnapshot {
        SessionSnapshot(id: id, plan: plan, slot: slot, startedAt: startedAt, sets: sets, phase: phase, feels: feels, feedbacks: feedbacks)
    }

    /// Sets done per exercise, the planned kind only: a warm-up is written down but is not one of them.
    var setsDone: [Int] { sets.map(Self.workingCount) }
    var totalSets: Int { plan.exercises.reduce(0) { $0 + $1.sets } }
    var completedSets: Int { setsDone.reduce(0, +) }
    var isComplete: Bool { completedSets >= totalSets }
    var hasProgress: Bool { sets.contains { !$0.isEmpty } }
    /// Exercises with every set done.
    var exercisesDone: Int { plan.exercises.indices.filter(isDone).count }

    func isDone(_ index: Int) -> Bool { Self.workingCount(sets[index]) >= plan.exercises[index].sets }

    private static func workingCount(_ sets: [SetEntry]) -> Int { sets.filter { $0.kind != .warmup }.count }

    /// The next exercise with sets left, after `index` first and then from the top.
    func nextExercise(after index: Int) -> Int? {
        let order = Array(plan.exercises.indices[(index + 1)...]) + Array(plan.exercises.indices[...index])
        return order.first { !isDone($0) }
    }

    // MARK: Last time

    /// The set to offer next for an exercise: the one just done, else the same set last time, else the
    /// plan's own numbers. Weight shows only for exercises that take one.
    func suggestion(for index: Int) -> SetEntry {
        let item = plan.exercises[index]
        let past = workingHistory(item.exerciseID)
        let done = sets[index].filter { $0.kind != .warmup }
        let reference = done.last ?? (past.indices.contains(done.count) ? past[done.count] : past.last)
        if item.exercise.isTimed { return SetEntry(seconds: reference?.seconds ?? item.holdSeconds) }
        let takesWeight = ExerciseCatalog.info(item.exerciseID).usesWeight
        let weight = item.loadBlocked == true ? 0 : (done.last?.weightKg ?? (item.targetReserve != nil ? item.suggestedWeightKg ?? 0 : reference?.weightKg ?? 0))
        let reps = done.last?.reps ?? (item.targetReserve != nil ? item.repsHigh : reference?.reps ?? item.repsHigh)
        return SetEntry(weightKg: takesWeight ? weight : nil, reps: reps)
    }

    /// What was done last time, warm-ups left out: they say nothing about the working numbers.
    private func workingHistory(_ exerciseID: String) -> [SetEntry] {
        (history[exerciseID] ?? []).filter { $0.kind != .warmup }
    }

    /// "Прошлый раз: 60 кг × 10, 60 кг × 9", or nil when the exercise is new.
    func previousText(for index: Int) -> String? {
        let past = workingHistory(plan.exercises[index].exerciseID)
        guard !past.isEmpty else { return nil }
        let first = Array(past.prefix(4))
        return "Прошлый раз: \(Self.pastLine(first))\(past.count > 4 ? "…" : "")"
    }

    /// Plain repetitions read "17, 18, 18 повторений" (the word said once); anything else keeps a phrase per set.
    private static func pastLine(_ sets: [SetEntry]) -> String {
        let bareCounts = sets.allSatisfy { $0.kind == .normal && $0.seconds == nil && ($0.weightKg ?? 0) == 0 }
        guard bareCounts, let last = sets.last?.reps else { return sets.map(\.summary).joined(separator: ", ") }
        let counts = sets.map { String($0.reps ?? 0) }.joined(separator: ", ")
        return "\(counts) \(RussianPlural.form(last, one: "повторение", few: "повторения", many: "повторений"))"
    }

    // MARK: Flow

    /// Starts the next set of an exercise; a finished exercise just shows as done.
    func start(_ index: Int) {
        phase = isDone(index) ? .exerciseDone(index: index) : .working(index: index, since: .now)
        changed()
    }

    /// Records the set under way and moves to rest, to the next set, or to "exercise done".
    func finishSet(_ entry: SetEntry) {
        guard case let .working(index, _) = phase else { return }
        sets[index].append(entry)
        let item = plan.exercises[index]
        if entry.kind == .warmup {
            // A warm-up is not a planned set: no rest, the working sets go on.
            phase = .working(index: index, since: .now)
        } else if isDone(index) {
            phase = .exerciseDone(index: index)
        } else if item.restSeconds > 0 {
            let length = TimeInterval(item.restSeconds)
            phase = .resting(index: index, until: .now.addingTimeInterval(length), length: length)
        } else {
            phase = .working(index: index, since: .now)
        }
        changed()
    }

    func addRest(_ seconds: TimeInterval) {
        guard case let .resting(index, until, length) = phase else { return }
        phase = .resting(index: index, until: until.addingTimeInterval(seconds), length: length + seconds)
        changed()
    }

    /// Ends the rest now and starts the next set.
    func startNextSet() {
        guard case let .resting(index, _, _) = phase else { return }
        phase = .working(index: index, since: .now)
        changed()
    }

    /// Holds a timed set where it is: the clock stops until `resume`.
    func pause(at now: Date = .now) {
        guard case let .working(index, since) = phase, plan.exercises[index].exercise.isTimed else { return }
        phase = .paused(index: index, elapsed: max(0, now.timeIntervalSince(since)))
        changed()
    }

    /// Goes on from the held time, as if the set had not stopped.
    func resume(at now: Date = .now) {
        guard case let .paused(index, elapsed) = phase else { return }
        phase = .working(index: index, since: now.addingTimeInterval(-elapsed))
        changed()
    }

    /// Leaves an exercise without writing anything down and goes to the next one with sets left; with none
    /// left, back to the list. Sets already done stay.
    func skip(_ index: Int) {
        if let next = nextExercise(after: index), next != index { start(next) } else { showOverview() }
    }

    /// Changes a set already done, keeping its place and identity.
    func updateSet(_ index: Int, at position: Int, to entry: SetEntry) {
        guard sets.indices.contains(index), sets[index].indices.contains(position) else { return }
        var updated = entry
        updated.id = sets[index][position].id
        sets[index][position] = updated
        changed()
    }

    /// Takes a set out. An exercise that is no longer done goes back to working.
    func deleteSet(_ index: Int, at position: Int) {
        guard sets.indices.contains(index), sets[index].indices.contains(position) else { return }
        sets[index].remove(at: position)
        if case .exerciseDone(index) = phase, !isDone(index) { phase = .working(index: index, since: .now) }
        changed()
    }

    /// Back to the list; a set under way is dropped, sets done stay.
    func showOverview() {
        phase = .overview
        changed()
    }

    func beginRating() {
        phase = .rating
        changed()
    }

    // MARK: Rating and result

    /// "В самый раз" unless the person said otherwise.
    func feel(for exerciseID: String) -> ExerciseFeel { feels[exerciseID] ?? .fine }

    func rate(_ exerciseID: String, _ feel: ExerciseFeel) {
        feels[exerciseID] = feel
        changed()
    }

    func setFeedback(_ exerciseID: String, _ feedback: ExerciseFeedback) {
        feedbacks[exerciseID] = feedback
        changed()
    }

    /// The finished workout. Its id is the session's, so saving the same session twice is one workout.
    func log(finishedAt date: Date = .now) -> WorkoutLog {
        let entries = plan.exercises.indices.filter { !sets[$0].isEmpty }.map { index in
            let item = plan.exercises[index]
            return ExerciseLog(exerciseID: item.exerciseID, setsPlanned: item.sets, setsDone: setsDone[index],
                               feel: feels[item.exerciseID] ?? (item.targetReserve == nil ? .fine : nil), sets: sets[index], feedback: feedbacks[item.exerciseID])
        }
        return WorkoutLog(id: id, kind: plan.kind, title: plan.title, startedAt: startedAt, finishedAt: date, entries: entries,
                          sessionKey: slot, plannedSets: totalSets, plannedExerciseIDs: plan.exercises.map(\.exerciseID))
    }

    private func changed() { onChange?() }
}
