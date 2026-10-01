import Foundation
import Testing
@testable import MaestroFelix

@MainActor
struct SessionTests {
    // Bench press takes a weight, a plank is held, push-ups use the body and need no rest.
    private static let plan = WorkoutPlan(kind: .strength, title: "Тест", focus: [.chest], exercises: [
        PlannedExercise(exerciseID: "bench-press", sets: 3, repsLow: 8, repsHigh: 12, holdSeconds: 0, restSeconds: 60),
        PlannedExercise(exerciseID: "plank", sets: 2, repsLow: 0, repsHigh: 0, holdSeconds: 40, restSeconds: 30),
        PlannedExercise(exerciseID: "push-ups", sets: 2, repsLow: 10, repsHigh: 15, holdSeconds: 0, restSeconds: 0),
    ])

    private func session(history: [String: [SetEntry]] = [:], slot: DayKey? = T.day("2026-09-30")) -> WorkoutSession {
        WorkoutSession(plan: Self.plan, slot: slot, history: history, startedAt: T.date("2026-09-30", hour: 18))
    }

    // MARK: Numbers offered

    @Test func aNewExerciseOffersThePlansOwnNumbers() {
        let running = session()
        let first = running.suggestion(for: 0)
        #expect(first.weightKg == 0 && first.reps == 12)
        #expect(running.suggestion(for: 1).seconds == 40)
        let bodyweight = running.suggestion(for: 2)
        #expect(bodyweight.weightKg == nil && bodyweight.reps == 15)
    }

    @Test func afterASetTheSameNumbersAreOffered() {
        let running = session()
        running.start(0)
        running.finishSet(SetEntry(weightKg: 50, reps: 9))
        let next = running.suggestion(for: 0)
        #expect(next.weightKg == 50 && next.reps == 9)
    }

    @Test("last time fills in the first set, and says what it was")
    func lastTimeFillsTheFirstSet() {
        let past = [SetEntry(weightKg: 60, reps: 10), SetEntry(weightKg: 60, reps: 9), SetEntry(weightKg: 57.5, reps: 8)]
        let running = session(history: ["bench-press": past])
        #expect(running.suggestion(for: 0).weightKg == 60 && running.suggestion(for: 0).reps == 10)
        #expect(running.previousText(for: 0) == "Прошлый раз: 60 кг × 10, 60 кг × 9, 57,5 кг × 8")
        #expect(running.previousText(for: 2) == nil)
    }

    @Test func aLongHistoryIsShortened() {
        let past = (1...6).map { SetEntry(weightKg: 20, reps: $0) }
        #expect(session(history: ["bench-press": past]).previousText(for: 0)?.hasSuffix("…") == true)
    }

    @Test("sets with no weight are listed as bare counts, said once")
    func bodyweightHistoryIsListedCompactly() {
        let past = [17, 18, 18].map { SetEntry(weightKg: nil, reps: $0) }
        #expect(session(history: ["push-ups": past]).previousText(for: 2) == "Прошлый раз: 17, 18, 18 повторений")
        let single = [SetEntry(weightKg: nil, reps: 1)]
        #expect(session(history: ["push-ups": single]).previousText(for: 2) == "Прошлый раз: 1 повторение")
    }

    @Test func bodyweightHistoryNeverInventsAWeight() {
        let running = session(history: ["push-ups": [SetEntry(weightKg: 20, reps: 12)]])
        #expect(running.suggestion(for: 2).weightKg == nil)
        #expect(running.suggestion(for: 2).reps == 12)
    }

    // MARK: Flow

    @Test func restFollowsASetAndTheLastSetEndsTheExercise() {
        let running = session()
        running.start(0)
        running.finishSet(SetEntry(weightKg: 40, reps: 10))
        guard case let .resting(index, until, length) = running.phase else { Issue.record("expected rest"); return }
        #expect(index == 0 && length == 60 && until > .now)
        running.startNextSet()
        guard case .working = running.phase else { Issue.record("expected working"); return }
        running.finishSet(SetEntry(weightKg: 40, reps: 10))
        running.startNextSet()
        running.finishSet(SetEntry(weightKg: 40, reps: 9))
        #expect(running.phase == .exerciseDone(index: 0))
        #expect(running.isDone(0) && running.completedSets == 3)
    }

    @Test func noRestMeansTheNextSetStartsAtOnce() {
        let running = session()
        running.start(2)
        running.finishSet(SetEntry(reps: 12))
        guard case .working(2, _) = running.phase else { Issue.record("expected the next set"); return }
    }

    @Test func extraRestLengthensTheCountdown() {
        let running = session()
        running.start(0)
        running.finishSet(SetEntry(weightKg: 40, reps: 10))
        guard case let .resting(_, before, lengthBefore) = running.phase else { Issue.record("expected rest"); return }
        running.addRest(15)
        guard case let .resting(_, after, lengthAfter) = running.phase else { Issue.record("expected rest"); return }
        #expect(after.timeIntervalSince(before) == 15 && lengthAfter == lengthBefore + 15)
    }

    @Test func finishingASetOutsideASetChangesNothing() {
        let running = session()
        running.finishSet(SetEntry(reps: 5))
        #expect(running.completedSets == 0 && running.phase == .overview)
    }

    @Test func theNextExerciseIsTheNextOneWithSetsLeft() {
        let running = session()
        #expect(running.nextExercise(after: 0) == 1)
        running.start(1)
        running.finishSet(SetEntry(seconds: 40))
        running.startNextSet()
        running.finishSet(SetEntry(seconds: 41))
        #expect(running.isDone(1))
        #expect(running.nextExercise(after: 0) == 2)
        #expect(running.nextExercise(after: 2) == 0)
    }

    // MARK: Editing

    @Test func aSetCanBeChangedKeepingItsPlaceAndIdentity() {
        let running = session()
        running.start(0)
        running.finishSet(SetEntry(weightKg: 40, reps: 10))
        let id = running.sets[0][0].id
        running.updateSet(0, at: 0, to: SetEntry(weightKg: 42.5, reps: 8))
        #expect(running.sets[0][0].id == id)
        #expect(running.sets[0][0].weightKg == 42.5 && running.sets[0][0].reps == 8)
        running.updateSet(0, at: 5, to: SetEntry(reps: 1))
        #expect(running.completedSets == 1)
    }

    @Test func takingASetOutBringsAFinishedExerciseBackToWork() {
        let running = session()
        running.start(2)
        running.finishSet(SetEntry(reps: 12))
        running.finishSet(SetEntry(reps: 11))
        #expect(running.phase == .exerciseDone(index: 2))
        running.deleteSet(2, at: 0)
        #expect(running.completedSets == 1)
        guard case .working(2, _) = running.phase else { Issue.record("expected working again"); return }
    }

    // MARK: Writing down

    @Test("every change is reported, so the workout can be written down as it goes")
    func changesAreReported() {
        let running = session()
        var reports = 0
        running.onChange = { reports += 1 }
        running.start(0)
        running.finishSet(SetEntry(weightKg: 40, reps: 10))
        running.addRest(15)
        running.startNextSet()
        running.rate("bench-press", .hard)
        running.showOverview()
        #expect(reports == 6)
    }

    @Test func aSnapshotBringsTheWorkoutBackExactly() throws {
        let running = session()
        running.start(0)
        running.finishSet(SetEntry(weightKg: 40, reps: 10))
        running.rate("bench-press", .hard)
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: JSONEncoder().encode(running.snapshot()))
        let restored = try #require(WorkoutSession(snapshot: decoded))
        #expect(restored.id == running.id && restored.slot == running.slot && restored.startedAt == running.startedAt)
        #expect(restored.sets == running.sets && restored.phase == running.phase && restored.feels == running.feels)
    }

    @Test("a snapshot that no longer fits its plan is refused rather than shown wrong")
    func inconsistentSnapshotsAreRefused() {
        var snapshot = session().snapshot()
        #expect(snapshot.isConsistent)
        snapshot.sets.removeLast()
        #expect(!snapshot.isConsistent && WorkoutSession(snapshot: snapshot) == nil)
        var outOfRange = session().snapshot()
        outOfRange.phase = .working(index: 9, since: .now)
        #expect(!outOfRange.isConsistent)
    }

    // MARK: Result

    @Test("the log carries the slot, the planned sets, and 'В самый раз' unless said otherwise")
    func logIsBuiltFromTheSession() {
        let running = session()
        running.start(0)
        running.finishSet(SetEntry(weightKg: 40, reps: 10))
        running.start(1)
        running.finishSet(SetEntry(seconds: 42))
        running.rate("plank", .limit)
        let log = running.log(finishedAt: T.date("2026-09-30", hour: 19))
        #expect(log.id == running.id && log.sessionKey == T.day("2026-09-30") && log.plannedSets == 7)
        #expect(log.entries.map(\.exerciseID) == ["bench-press", "plank"])
        #expect(log.entries.map(\.feel) == [.fine, .limit])
        #expect(log.setsDone == 2 && log.isPartial && log.volumeKg == 400)
    }

    @Test func restDayActivityHasNoSlot() {
        #expect(session(slot: nil).log().sessionKey == nil)
    }
}

@MainActor
struct WorkoutModelTests {
    private func log(_ id: String, day: String, sets: [SetEntry] = [SetEntry(weightKg: 40, reps: 10)]) -> WorkoutLog {
        var entry = T.log(finished: day)
        entry.entries = [ExerciseLog(exerciseID: "bench-press", setsPlanned: 3, setsDone: sets.count, feel: nil, sets: sets)]
        return WorkoutLog(id: UUID(uuidString: id)!, kind: .strength, title: "Тест", startedAt: entry.startedAt,
                          finishedAt: entry.finishedAt, entries: entry.entries)
    }

    private static let first = "00000000-0000-0000-0000-000000000001"
    private static let second = "00000000-0000-0000-0000-000000000002"

    @Test func theSameWorkoutSavedTwiceStaysOne() throws {
        let h = try Harness.make()
        let model = h.app.workouts
        let one = log(Self.first, day: "2026-09-29")
        #expect(model.save(one) && model.save(one))
        #expect(model.logs.count == 1)
    }

    @Test func lastTimeComesFromTheNewestWorkoutThatRecordedSets() throws {
        let h = try Harness.make()
        let model = h.app.workouts
        model.save(log(Self.first, day: "2026-09-20", sets: [SetEntry(weightKg: 30, reps: 10)]))
        model.save(log(Self.second, day: "2026-09-27", sets: [SetEntry(weightKg: 35, reps: 8)]))
        // A workout made before sets were recorded has none to offer.
        model.save(log("00000000-0000-0000-0000-000000000003", day: "2026-09-29", sets: []))
        #expect(model.lastSets(for: ["bench-press"])["bench-press"]?.first?.weightKg == 35)
        #expect(model.lastSets(for: ["plank"]).isEmpty)
    }

    @Test func aFailedSaveKeepsTheLogsAndSaysSo() throws {
        let h = try Harness.make()
        h.store.failingSaves = [StoreKey.workoutLogs]
        #expect(!h.app.workouts.save(log(Self.first, day: "2026-09-29")))
        #expect(h.app.workouts.logs.isEmpty && h.app.workouts.storageError != nil)
    }

    @Test("a history that cannot be read is left untouched, new workouts are kept apart, and they rejoin it later")
    func unreadableHistoryIsNeverOverwritten() throws {
        let h = try Harness.make()
        try h.base.save([log(Self.first, day: "2026-09-27")], key: StoreKey.workoutLogs)

        h.store.failingLoads = [StoreKey.workoutLogs]
        let broken = WorkoutModel(store: h.store)
        #expect(broken.logs.isEmpty && broken.storageError != nil)
        #expect(broken.save(log(Self.second, day: "2026-09-29")))
        #expect(try h.base.load([WorkoutLog].self, key: StoreKey.workoutLogs)?.count == 1, "the main record was not overwritten")
        #expect(try h.base.load([WorkoutLog].self, key: WorkoutModel.recoveredKey)?.count == 1)

        h.store.failingLoads = []
        let healed = WorkoutModel(store: h.store)
        #expect(healed.logs.map(\.id.uuidString) == [Self.first, Self.second])
        #expect(try h.base.load([WorkoutLog].self, key: StoreKey.workoutLogs)?.count == 2)
        #expect(try h.base.load([WorkoutLog].self, key: WorkoutModel.recoveredKey) == nil)
    }

    @Test func aWorkoutInProgressSurvivesReopening() throws {
        let h = try Harness.make()
        let running = h.app.workouts.makeSession(plan: SessionTests_plan, slot: T.day("2026-09-30"))
        running.start(0)
        running.finishSet(SetEntry(weightKg: 40, reps: 10))
        h.app.workouts.persist(running)
        let reopened = WorkoutModel(store: h.store)
        #expect(reopened.resumable?.id == running.id)
        #expect(reopened.restore()?.completedSets == 1)
        reopened.discardSnapshot()
        #expect(reopened.resumable == nil && WorkoutModel(store: h.store).resumable == nil)
    }

    @Test func aStoredWorkoutThatNoLongerFitsIsDroppedAtOpening() throws {
        let h = try Harness.make()
        var snapshot = WorkoutSession(plan: SessionTests_plan).snapshot()
        snapshot.sets = []
        try h.base.save(snapshot, key: StoreKey.activeSession)
        #expect(WorkoutModel(store: h.store).resumable == nil)
        #expect(try h.base.load(SessionSnapshot.self, key: StoreKey.activeSession) == nil)
    }
}

private let SessionTests_plan = WorkoutPlan(kind: .strength, title: "Тест", focus: [.chest], exercises: [
    PlannedExercise(exerciseID: "bench-press", sets: 3, repsLow: 8, repsHigh: 12, holdSeconds: 0, restSeconds: 60),
    PlannedExercise(exerciseID: "plank", sets: 2, repsLow: 0, repsHigh: 0, holdSeconds: 40, restSeconds: 30),
])
