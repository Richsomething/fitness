import Foundation
import Testing
@testable import MaestroFelix

struct AdaptiveTrainingTests {
    @Test func invalidInputsDoNotProduceLoads() {
        #expect(AdaptiveTraining.estimatedMaximum(weight: .nan, reps: 2, reserve: 0) == nil)
        #expect(AdaptiveTraining.estimatedMaximum(weight: 100, reps: 10, reserve: 5) == nil)
        #expect(AdaptiveTraining.workingWeight(maximum: 100, reps: 10, reserve: 2, increment: 0) == nil)
        #expect(AdaptiveTraining.estimatedMaximum(weight: 100, reps: 1, reserve: 0) == 100)
    }

    @Test func estimatedLoadHasReserveAndRoundsDown() {
        let maximum = AdaptiveTraining.estimatedMaximum(weight: 100, reps: 2, reserve: 0)!
        let load = AdaptiveTraining.workingWeight(maximum: maximum, reps: 10, reserve: 2)!
        #expect(load == 70)
        #expect(load < 80)
    }

    @Test func easyWithoutExplicitReserveCannotRaiseLoad() {
        let entry = ExerciseLog(exerciseID: "bench-press", setsPlanned: 2, setsDone: 2, feel: .easy,
                                sets: [SetEntry(weightKg: 50, reps: 10), SetEntry(weightKg: 50, reps: 10)])
        #expect(AdaptiveTraining.correction(for: entry, target: 8, plannedSets: 2, upperTarget: 10) == 1)
        var explicit = entry
        explicit.feedback = ExerciseFeedback(reserve: 4)
        #expect(AdaptiveTraining.correction(for: explicit, target: 8, plannedSets: 2, upperTarget: 10) > 1)
        explicit.sets[1].reps = 8
        #expect(AdaptiveTraining.correction(for: explicit, target: 8, plannedSets: 2, upperTarget: 10) == 1)
    }

    @Test func temporaryFatigueAndDiscomfortHaveDifferentActions() {
        var entry = ExerciseLog(exerciseID: "bench-press", setsPlanned: 1, setsDone: 1, feel: .hard,
                                sets: [SetEntry(weightKg: 50, reps: 10)],
                                feedback: ExerciseFeedback(reserve: 1, reason: .fatigue))
        #expect(AdaptiveTraining.correction(for: entry, target: 10, plannedSets: 1) == 0.9)
        entry.feedback?.reason = .discomfort
        #expect(AdaptiveTraining.correction(for: entry, target: 10, plannedSets: 1) == 0)
    }

    @Test func fourteenDaysAloneDoNotOpenAssessment() {
        let start = T.date("2026-09-01")
        let now = T.date("2026-09-15")
        let state = AdaptiveTrainingState(route: .preparation, startedAt: start)
        #expect(!AdaptiveTraining.isPrepared(state, logs: [], now: now, calendar: T.calendar))
        let entry = ExerciseLog(exerciseID: "bench-press", setsPlanned: 1, setsDone: 1, feel: .fine,
                                sets: [SetEntry(weightKg: 20, reps: 10)])
        let logs = (0..<4).map { day in
            WorkoutLog(kind: .strength, title: "Подготовка", startedAt: start,
                       finishedAt: start.addingTimeInterval(Double(day + 1) * 86400), entries: [entry], plannedSets: 1)
        }
        #expect(AdaptiveTraining.isPrepared(state, logs: logs, now: now, calendar: T.calendar))
        #expect(!AdaptiveTraining.isPrepared(state, logs: logs, now: start.addingTimeInterval(7 * 86400), calendar: T.calendar))
        #expect(!AdaptiveTraining.isPrepared(state, logs: Array(repeating: logs[0], count: 4), now: now, calendar: T.calendar))
        let partial = logs.map { log in var copy = log; copy.plannedSets = 2; return copy }
        #expect(!AdaptiveTraining.isPrepared(state, logs: partial, now: now, calendar: T.calendar))
    }

    @Test func unknownWeightIsNotInventedAndPreparationReducesVolume() {
        let now = T.date("2026-09-28")
        let original = WorkoutPlan(kind: .strength, title: "Тест", focus: [.chest], exercises: [
            PlannedExercise(exerciseID: "bench-press", sets: 5, repsLow: 4, repsHigh: 6, holdSeconds: 0, restSeconds: 60)
        ])
        let state = AdaptiveTrainingState(route: .preparation, startedAt: now)
        let result = AdaptiveTraining.plan(original, state: state, logs: [], now: now)
        #expect(result.exercises[0].sets == 2)
        #expect(result.exercises[0].suggestedWeightKg == nil)
        #expect(result.exercises[0].targetReserve == 3)
    }

    @Test func olderEvidenceDoesNotOverrideANewerEnteredResult() {
        let now = T.date("2026-09-28")
        let result = StrengthResult(exerciseID: "bench-press", weightKg: 100, reps: 2, reserve: 0, measuredAt: now)
        let state = AdaptiveTrainingState(route: .knownResults, startedAt: now, results: [result])
        let entry = ExerciseLog(exerciseID: "bench-press", setsPlanned: 1, setsDone: 1, feel: .fine,
                                sets: [SetEntry(weightKg: 30, reps: 10)])
        let log = WorkoutLog(kind: .strength, title: "Раньше", startedAt: now.addingTimeInterval(-86400),
                             finishedAt: now.addingTimeInterval(-86400), entries: [entry])
        let plan = WorkoutPlan(kind: .strength, title: "Тест", focus: [.chest], exercises: [
            PlannedExercise(exerciseID: "bench-press", sets: 3, repsLow: 8, repsHigh: 10, holdSeconds: 0, restSeconds: 90)
        ])
        #expect(AdaptiveTraining.plan(plan, state: state, logs: [log], now: now).exercises[0].suggestedWeightKg == 70)
    }

    @Test func oldPlansAndFeedbacklessLogsStillDecode() throws {
        let decoder = JSONDecoder()
        let item = try decoder.decode(PlannedExercise.self, from: Data(#"{"exerciseID":"bench-press","sets":3,"repsLow":8,"repsHigh":10,"holdSeconds":0,"restSeconds":90}"#.utf8))
        #expect(item.suggestedWeightKg == nil)
        let entry = try decoder.decode(ExerciseLog.self, from: Data(#"{"exerciseID":"bench-press","setsPlanned":3,"setsDone":0}"#.utf8))
        #expect(entry.feedback == nil)
    }

    private func preparationLogs(start: Date) -> [WorkoutLog] {
        (1...4).map { day in
            WorkoutLog(kind: .strength, title: "Подготовка", startedAt: start,
                       finishedAt: start.addingTimeInterval(Double(day) * 86400), entries: [
                        ExerciseLog(exerciseID: "bench-press", setsPlanned: 1, setsDone: 1, feel: .fine,
                                    sets: [SetEntry(weightKg: 20, reps: 10)])], plannedSets: 1)
        }
    }

    @Test @MainActor func classSelectionRequiresPreparationAndPersists() throws {
        let store = try SwiftDataProfileRepository.inMemory()
        let model = AdaptiveTrainingModel(store: store)
        let start = T.date("2026-09-01")
        let logs = preparationLogs(start: start)
        #expect(model.choose(.knownResults, now: start))
        #expect(!model.chooseClass(.powerlifting, logs: logs, now: T.date("2026-09-08"), calendar: T.calendar))
        #expect(!model.chooseClass(.powerlifting, logs: [], now: T.date("2026-09-15"), calendar: T.calendar))
        #expect(model.chooseClass(.powerlifting, logs: logs, now: T.date("2026-09-15"), calendar: T.calendar))
        #expect(AdaptiveTrainingModel(store: store).state.trainingClass == .powerlifting)
    }

    @Test func classesChangeEmphasisAndGoalsChangeVolume() throws {
        let date = T.date("2026-09-28")
        let profile = T.profile(goal: .muscleGain)
        let base = try #require(WorkoutPlanner.plan(for: profile, on: date, calendar: T.calendar))
        let body = WorkoutPlanner.classPlan(base, profile: profile, trainingClass: .bodybuilding)
        let power = WorkoutPlanner.classPlan(base, profile: profile, trainingClass: .powerlifting)
        let bench = try #require(power.exercises.first { $0.exerciseID == "bench-press" })
        #expect(bench.repsHigh == 5 && bench.restSeconds == 180 && bench.sets == 4)
        let bodyBench = try #require(body.exercises.first { $0.exerciseID == "bench-press" })
        #expect(bodyBench.repsHigh == 12 && bodyBench.restSeconds == 120)
        var cutProfile = profile
        cutProfile.goal = .fatLoss
        let cut = WorkoutPlanner.classPlan(base, profile: cutProfile, trainingClass: .powerlifting)
        #expect(cut.exercises.first?.sets == 3)
        #expect(cut.exercises.first?.repsHigh == 5)
        #expect(cut.exercises.allSatisfy { $0.repsHigh <= 15 })
        let pull = try #require(WorkoutPlanner.plan(for: profile, on: T.date("2026-09-30"), calendar: T.calendar))
        #expect(WorkoutPlanner.classPlan(pull, profile: profile, trainingClass: .powerlifting).exercises.first?.exerciseID == "deadlift")
        let limited = T.profile(limitations: [.lowerBack, .knees])
        let replacement = WorkoutPlanner.classPlan(pull, profile: limited, trainingClass: .powerlifting)
        #expect(replacement.exercises.allSatisfy { $0.exercise.loads.isDisjoint(with: [.lowerBack, .knees]) })
    }

    @Test func classLoadsUseNewTargetsAndCannotActivateEarly() throws {
        let start = T.date("2026-09-01")
        let now = T.date("2026-09-28")
        let profile = T.profile()
        let base = try #require(WorkoutPlanner.plan(for: profile, on: now, calendar: T.calendar))
        var state = AdaptiveTrainingState(route: .knownResults, startedAt: start, results: [
            StrengthResult(exerciseID: "bench-press", weightKg: 100, reps: 2, reserve: 0, measuredAt: now)
        ], trainingClass: .powerlifting)
        let logs = preparationLogs(start: start)
        let power = AdaptiveTraining.plan(base, state: state, logs: logs, now: now, calendar: T.calendar, profile: profile)
        state.trainingClass = .bodybuilding
        let body = AdaptiveTraining.plan(base, state: state, logs: logs, now: now, calendar: T.calendar, profile: profile)
        let powerLoad = try #require(power.exercises.first { $0.exerciseID == "bench-press" }?.suggestedWeightKg)
        let bodyLoad = try #require(body.exercises.first { $0.exerciseID == "bench-press" }?.suggestedWeightKg)
        #expect(powerLoad > bodyLoad)
        let early = AdaptiveTraining.plan(base, state: state, logs: [], now: now, calendar: T.calendar, profile: profile)
        #expect(early.title == base.title)
        var cut = profile
        cut.goal = .fatLoss
        #expect(AdaptiveTraining.plan(base, state: state, logs: logs, now: now, calendar: T.calendar, profile: cut).exercises.first?.targetReserve == 3)
    }

    @Test func oldAdaptiveStateHasNoImplicitClass() throws {
        let state = try JSONDecoder().decode(AdaptiveTrainingState.self,
                                            from: Data(#"{"version":1,"results":[]}"#.utf8))
        #expect(state.trainingClass == nil)
    }
}
