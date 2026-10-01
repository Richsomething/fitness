import Foundation
import Testing
@testable import MaestroFelix

struct ExerciseSwapTests {
    private static let plan = WorkoutPlan(kind: .strength, title: "Тест", focus: [.chest], exercises: [
        PlannedExercise(exerciseID: "bench-press", sets: 3, repsLow: 8, repsHigh: 12, holdSeconds: 0, restSeconds: 60,
                        calibration: "В прошлый раз было легко — +2 повтора", suggestedWeightKg: 60),
        PlannedExercise(exerciseID: "push-ups", sets: 3, repsLow: 10, repsHigh: 15, holdSeconds: 0, restSeconds: 45),
        PlannedExercise(exerciseID: "plank", sets: 2, repsLow: 0, repsHigh: 0, holdSeconds: 40, restSeconds: 30),
    ])

    // MARK: Alternatives

    @Test("alternatives come from the same muscle group, never the exercise itself or one already in the plan")
    func alternativesShareTheGroup() {
        let options = ExerciseSwaps.alternatives(for: "bench-press", in: Self.plan, limitations: [])
        #expect(!options.isEmpty)
        #expect(options.allSatisfy { $0.group == .chest })
        #expect(!options.contains { $0.id == "bench-press" || $0.id == "push-ups" })
    }

    @Test("a held exercise is swapped for another held one, a counted one for a counted one")
    func alternativesKeepTheKindOfWork() {
        let timed = ExerciseSwaps.alternatives(for: "plank", in: Self.plan, limitations: [])
        #expect(timed.allSatisfy { $0.isTimed })
        let counted = ExerciseSwaps.alternatives(for: "bench-press", in: Self.plan, limitations: [])
        #expect(counted.allSatisfy { !$0.isTimed })
    }

    @Test("an exercise that loads a marked zone is never offered")
    func alternativesAvoidMarkedZones() {
        let options = ExerciseSwaps.alternatives(for: "bench-press", in: Self.plan, limitations: [.shoulders, .elbows, .wrists])
        #expect(options.allSatisfy { $0.loads.isDisjoint(with: [.shoulders, .elbows, .wrists]) })
    }

    // MARK: Applying

    @Test("a swap changes the exercise and keeps the sets, repetitions and rest")
    func applyKeepsTheNumbers() throws {
        let option = try #require(ExerciseSwaps.alternatives(for: "bench-press", in: Self.plan, limitations: []).first)
        let swapped = ExerciseSwaps.apply(["bench-press": option.id], to: Self.plan)
        let first = swapped.exercises[0]
        #expect(first.exerciseID == option.id)
        #expect(first.sets == 3 && first.repsLow == 8 && first.repsHigh == 12 && first.restSeconds == 60)
        #expect(swapped.exercises.map(\.exerciseID).dropFirst() == ["push-ups", "plank"])
    }

    @Test("what was worked out for the old exercise does not follow to the new one")
    func applyClearsTheOldAdvice() throws {
        let option = try #require(ExerciseSwaps.alternatives(for: "bench-press", in: Self.plan, limitations: []).first)
        let first = ExerciseSwaps.apply(["bench-press": option.id], to: Self.plan).exercises[0]
        #expect(first.calibration == nil && first.suggestedWeightKg == nil && first.targetReserve == nil)
    }

    @Test("a swap onto an exercise already in the plan is ignored, as is one for an exercise that is gone")
    func applyIgnoresWhatDoesNotFit() {
        let duplicate = ExerciseSwaps.apply(["bench-press": "push-ups"], to: Self.plan)
        #expect(duplicate == Self.plan)
        let missing = ExerciseSwaps.apply(["lat-pulldown": "seated-row"], to: Self.plan)
        #expect(missing == Self.plan)
    }

    // MARK: Light blocks

    @Test("every light block is offered when nothing is marked")
    func allBlocksPlayableWithoutLimits() {
        #expect(WorkoutPlanner.playableBlocks(for: T.profile()).count == WorkoutPlanner.LightBlock.allCases.count)
    }

    @Test("a light block with nothing left after the marked zones is never offered, and the others hold exercises")
    func emptyBlocksAreNotOffered() {
        let profile = T.profile(limitations: BodyZone.allCases)
        let playable = WorkoutPlanner.playableBlocks(for: profile)
        #expect(playable.allSatisfy { !WorkoutPlanner.light($0, for: profile).exercises.isEmpty })
        let skipped = WorkoutPlanner.LightBlock.allCases.filter { !playable.contains($0) }
        #expect(skipped.allSatisfy { WorkoutPlanner.light($0, for: profile).exercises.isEmpty })
        #expect(!skipped.isEmpty)
    }

    // MARK: In the schedule

    @Test("swaps are kept per slot and survive a round trip through the store")
    func swapsSurviveJSON() throws {
        var state = T.state()
        state.swap("bench-press", to: "incline-db-press", in: T.day("2026-09-28"))
        let decoded = try JSONDecoder().decode(ScheduleState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
        #expect(decoded.swaps["2026-09-28"] == ["bench-press": "incline-db-press"])
    }

    @Test("a schedule written before swaps existed still reads")
    func oldScheduleReads() throws {
        let json = #"{"revisions":[{"from":"2026-09-28","weekdays":[1,3,5]}],"moves":{},"skipped":[],"pauses":[]}"#
        let state = try JSONDecoder().decode(ScheduleState.self, from: Data(json.utf8))
        #expect(state.swaps.isEmpty)
    }

    @Test("putting the original back removes the swap")
    func restoringRemovesTheSwap() {
        var state = T.state()
        state.swap("bench-press", to: "incline-db-press", in: T.day("2026-09-28"))
        state.restore("bench-press", in: T.day("2026-09-28"))
        #expect(state.swaps.isEmpty)
    }

    @Test("a swapped session shows the new exercise and no other session changes")
    func plannerAppliesSwaps() throws {
        let before = SchedulePlanner.sessions(profile: T.profile(), state: T.state(), logs: [], from: T.day("2026-09-28"),
                                              through: T.day("2026-10-04"), today: T.day("2026-09-28"), calendar: T.calendar)
        let first = try #require(before.first)
        let original = first.plan.exercises[0].exerciseID
        let option = try #require(ExerciseSwaps.alternatives(for: original, in: first.plan, limitations: []).first)
        var state = T.state()
        state.swap(original, to: option.id, in: first.key)
        let after = SchedulePlanner.sessions(profile: T.profile(), state: state, logs: [], from: T.day("2026-09-28"),
                                             through: T.day("2026-10-04"), today: T.day("2026-09-28"), calendar: T.calendar)
        #expect(after[0].plan.exercises[0].exerciseID == option.id)
        #expect(after.dropFirst().map(\.plan) == before.dropFirst().map(\.plan))
    }
}
