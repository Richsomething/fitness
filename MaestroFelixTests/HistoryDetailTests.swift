import Foundation
import Testing
@testable import MaestroFelix

@MainActor
struct HistoryDetailTests {
    private func entry(_ id: String, _ sets: [SetEntry], planned: Int? = nil) -> ExerciseLog {
        ExerciseLog(exerciseID: id, setsPlanned: planned ?? sets.count, setsDone: sets.count, feel: nil, sets: sets)
    }

    private func log(_ day: String, _ entries: [ExerciseLog], planned: [String]? = nil) -> WorkoutLog {
        let end = T.date(day, hour: 19)
        return WorkoutLog(kind: .strength, title: "Тест", startedAt: end.addingTimeInterval(-1800), finishedAt: end,
                          entries: entries, plannedExerciseIDs: planned)
    }

    // MARK: What was left undone

    @Test("a log remembers the exercises the plan held, so those never started can be named")
    func untouchedExercises() {
        let workout = log("2026-09-30", [entry("bench-press", [SetEntry(weightKg: 40, reps: 10)])],
                          planned: ["bench-press", "push-ups", "plank"])
        #expect(workout.untouchedExerciseIDs == ["push-ups", "plank"])
    }

    @Test("an older log, written without them, names none as untouched")
    func oldLogsNameNone() throws {
        let json = """
        [{"id":"6F1B0F0E-0B6B-4B7B-9E0B-0A1D6C3A9F11","kind":"strength","title":"Тест","startedAt":780000000,
          "finishedAt":780003000,"entries":[]}]
        """
        let logs = try JSONDecoder().decode([WorkoutLog].self, from: Data(json.utf8))
        #expect(logs[0].plannedExerciseIDs == nil && logs[0].untouchedExerciseIDs.isEmpty)
    }

    @Test("a finished session writes the plan's exercises into its log")
    func sessionLogCarriesThePlan() {
        let plan = WorkoutPlan(kind: .strength, title: "Тест", focus: [.chest], exercises: [
            PlannedExercise(exerciseID: "bench-press", sets: 3, repsLow: 8, repsHigh: 12, holdSeconds: 0, restSeconds: 60),
            PlannedExercise(exerciseID: "push-ups", sets: 2, repsLow: 10, repsHigh: 15, holdSeconds: 0, restSeconds: 0),
        ])
        let session = WorkoutSession(plan: plan, slot: nil, history: [:], startedAt: T.date("2026-09-30", hour: 18))
        session.start(0)
        session.finishSet(SetEntry(weightKg: 40, reps: 10))
        let finished = session.log(finishedAt: T.date("2026-09-30", hour: 19))
        #expect(finished.plannedExerciseIDs == ["bench-press", "push-ups"])
        #expect(finished.untouchedExerciseIDs == ["push-ups"])
    }

    // MARK: Row text

    @Test("the first exercises are named, the rest counted")
    func exerciseSummary() {
        let sets = [SetEntry(weightKg: 20, reps: 10)]
        let three = log("2026-09-30", [entry("bench-press", sets), entry("goblet-squat", sets), entry("lat-pulldown", sets)])
        #expect(three.exerciseSummary == "\(ExerciseCatalog.exercise("bench-press").title), \(ExerciseCatalog.exercise("goblet-squat").title) и ещё 1")
        let one = log("2026-09-30", [entry("bench-press", sets)])
        #expect(one.exerciseSummary == ExerciseCatalog.exercise("bench-press").title)
        #expect(log("2026-09-30", []).exerciseSummary == nil)
    }

    @Test("an exercise with warm-ups only is not named as done")
    func summaryIgnoresWarmUps() {
        let workout = log("2026-09-30", [entry("bench-press", [SetEntry(weightKg: 20, reps: 10, kind: .warmup)])])
        #expect(workout.exerciseSummary == nil)
    }

    // MARK: Actions

    @Test("a deleted workout is gone for good, and an unknown one is nothing to do")
    func deletingRemovesTheLog() throws {
        let base = try SwiftDataProfileRepository.inMemory()
        let model = WorkoutModel(store: base)
        let first = log("2026-09-10", [entry("bench-press", [SetEntry(weightKg: 30, reps: 10)])])
        let second = log("2026-09-12", [entry("bench-press", [SetEntry(weightKg: 32, reps: 10)])])
        #expect(model.save(first) && model.save(second))
        #expect(model.delete(first.id))
        #expect(model.logs.map(\.id) == [second.id])
        #expect(WorkoutModel(store: base).logs.map(\.id) == [second.id], "and it stays gone after a restart")
        #expect(model.delete(UUID()))
    }

    @Test("a failed delete changes nothing and says so")
    func aFailedDeleteChangesNothing() throws {
        let store = FlakyStore(base: try SwiftDataProfileRepository.inMemory())
        let model = WorkoutModel(store: store)
        let first = log("2026-09-10", [entry("bench-press", [SetEntry(weightKg: 30, reps: 10)])])
        #expect(model.save(first))
        store.failingSaves = [StoreKey.workoutLogs]
        #expect(!model.delete(first.id))
        #expect(model.logs.count == 1 && model.storageError != nil)
    }

    @Test("deleting the workout that closed a session opens that session again")
    func deletingReopensTheSlot() throws {
        let h = try Harness.make()
        let slot = T.day("2026-09-30")
        let done = T.log(slot: "2026-09-30", finished: "2026-09-30")
        #expect(h.app.workouts.save(done))
        h.app.refreshStats()
        #expect(h.app.slots(from: slot, through: slot).first?.status.isDone == true)
        #expect(h.app.deleteWorkout(done))
        #expect(h.app.slots(from: slot, through: slot).first?.status.isDone == false)
        #expect(h.app.progress.stats.doneSessions == 0)
    }

    @Test("a workout can be repeated: the same exercises, the sets and repetitions it was done with")
    func repeatPlan() throws {
        let workout = WorkoutLog(kind: .strength, title: "Грудь", startedAt: T.date("2026-09-30", hour: 18),
                                 finishedAt: T.date("2026-09-30", hour: 19), entries: [
                                    entry("bench-press", [SetEntry(weightKg: 40, reps: 8), SetEntry(weightKg: 40, reps: 10),
                                                          SetEntry(weightKg: 20, reps: 12, kind: .warmup)], planned: 4),
                                    entry("plank", [SetEntry(seconds: 45)]),
                                 ])
        let plan = try #require(workout.repeatPlan)
        #expect(plan.title == "Грудь" && plan.kind == .strength)
        #expect(plan.exercises.map(\.exerciseID) == ["bench-press", "plank"])
        let bench = plan.exercises[0]
        #expect(bench.sets == 4 && bench.repsLow == 8 && bench.repsHigh == 10)
        #expect(plan.exercises[1].holdSeconds == 45)
        #expect(plan.focus == [.chest, .core])
    }

    @Test("a log with nothing done has nothing to repeat")
    func emptyLogCannotBeRepeated() {
        #expect(log("2026-09-30", []).repeatPlan == nil)
    }

    // MARK: Comparing with the last time

    @Test("the top set is the heaviest working one, then the one with most repetitions")
    func topSet() {
        let sets = [SetEntry(weightKg: 20, reps: 15, kind: .warmup), SetEntry(weightKg: 40, reps: 8),
                    SetEntry(weightKg: 40, reps: 10), SetEntry(weightKg: 35, reps: 12)]
        #expect(entry("bench-press", sets).topSet == SetEntry(id: sets[2].id, weightKg: 40, reps: 10))
        #expect(entry("bench-press", []).topSet == nil)
    }

    @Test("the previous result is the last earlier workout with working sets of that exercise")
    func previousEntry() throws {
        let old = log("2026-09-01", [entry("bench-press", [SetEntry(weightKg: 30, reps: 10)])])
        let last = log("2026-09-10", [entry("bench-press", [SetEntry(weightKg: 35, reps: 10)])])
        let warmUpOnly = log("2026-09-15", [entry("bench-press", [SetEntry(weightKg: 20, reps: 10, kind: .warmup)])])
        let now = log("2026-09-20", [entry("bench-press", [SetEntry(weightKg: 40, reps: 10)])])
        let found = try #require(PersonalRecords.previousEntry(of: "bench-press", before: now, in: [old, last, warmUpOnly, now]))
        #expect(found.topSet?.weightKg == 35)
        #expect(PersonalRecords.previousEntry(of: "plank", before: now, in: [old, last, now]) == nil)
        #expect(PersonalRecords.previousEntry(of: "bench-press", before: old, in: [old, last, now]) == nil)
    }
}
