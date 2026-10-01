import Foundation
import Testing
@testable import MaestroFelix

struct StrengthProgressTests {
    private func log(_ day: String, _ entries: [(String, [SetEntry])]) -> WorkoutLog {
        let end = T.date(day, hour: 19)
        return WorkoutLog(kind: .strength, title: "Тест", startedAt: end.addingTimeInterval(-1800), finishedAt: end,
                          entries: entries.map { id, sets in
                              ExerciseLog(exerciseID: id, setsPlanned: sets.count, setsDone: sets.count, feel: nil, sets: sets)
                          })
    }

    private let bench = "bench-press"

    // MARK: Which exercises

    @Test("exercises are listed by how often they were done, the more recent first among equals")
    func exerciseOrder() {
        let logs = [
            log("2026-09-01", [(bench, [SetEntry(weightKg: 40, reps: 10)]), ("goblet-squat", [SetEntry(weightKg: 20, reps: 10)])]),
            log("2026-09-08", [(bench, [SetEntry(weightKg: 42, reps: 10)])]),
            log("2026-09-15", [("push-ups", [SetEntry(weightKg: nil, reps: 15)]), ("goblet-squat", [SetEntry(weightKg: 22, reps: 10)])]),
        ]
        // Bench and squat were done twice; the squat more recently.
        #expect(StrengthProgress.exercises(in: logs) == ["goblet-squat", bench, "push-ups"])
    }

    @Test("an exercise with only warm-ups has no history to show")
    func warmUpsAreNotHistory() {
        let logs = [log("2026-09-01", [(bench, [SetEntry(weightKg: 20, reps: 10, kind: .warmup)])])]
        #expect(StrengthProgress.exercises(in: logs).isEmpty)
        #expect(StrengthProgress.progress(for: bench, in: logs) == nil)
    }

    // MARK: The series

    @Test("a weighted exercise is followed by the estimated one-repetition maximum, one point a workout")
    func weightedSeries() throws {
        let logs = [
            log("2026-09-08", [(bench, [SetEntry(weightKg: 40, reps: 10), SetEntry(weightKg: 20, reps: 10, kind: .warmup)])]),
            log("2026-09-01", [(bench, [SetEntry(weightKg: 30, reps: 10)])]),
        ]
        let progress = try #require(StrengthProgress.progress(for: bench, in: logs))
        #expect(progress.metric == .estimatedMax)
        #expect(progress.points.map(\.date) == [T.date("2026-09-01", hour: 19), T.date("2026-09-08", hour: 19)])
        #expect(progress.points.map { ($0.value * 10).rounded() / 10 } == [40, 53.3])
        #expect(progress.change.map { ($0 * 10).rounded() / 10 } == 13.3)
        #expect(progress.best?.date == T.date("2026-09-08", hour: 19))
    }

    @Test("work with the body's own weight is followed by the most repetitions in a set")
    func bodyweightSeries() throws {
        let logs = [
            log("2026-09-01", [("push-ups", [SetEntry(weightKg: nil, reps: 12), SetEntry(weightKg: nil, reps: 10)])]),
            log("2026-09-08", [("push-ups", [SetEntry(weightKg: nil, reps: 15)])]),
        ]
        let progress = try #require(StrengthProgress.progress(for: "push-ups", in: logs))
        #expect(progress.metric == .reps)
        #expect(progress.points.map(\.value) == [12, 15])
    }

    @Test("a held exercise is followed by the longest hold")
    func timedSeries() throws {
        let logs = [
            log("2026-09-01", [("plank", [SetEntry(seconds: 30), SetEntry(seconds: 40)])]),
            log("2026-09-08", [("plank", [SetEntry(seconds: 50)])]),
        ]
        let progress = try #require(StrengthProgress.progress(for: "plank", in: logs))
        #expect(progress.metric == .seconds)
        #expect(progress.points.map(\.value) == [40, 50])
    }

    @Test("sets of more than twelve repetitions fall back to the heaviest weight, as they say nothing of a maximum")
    func highRepetitionsUseTheWeight() throws {
        let logs = [log("2026-09-01", [(bench, [SetEntry(weightKg: 25, reps: 20)])])]
        let progress = try #require(StrengthProgress.progress(for: bench, in: logs))
        #expect(progress.points.map(\.value) == [25])
    }

    @Test("one workout gives a point but no change")
    func singlePointHasNoChange() throws {
        let logs = [log("2026-09-01", [(bench, [SetEntry(weightKg: 40, reps: 10)])])]
        let progress = try #require(StrengthProgress.progress(for: bench, in: logs))
        #expect(progress.points.count == 1 && progress.change == nil)
    }

    // MARK: Volume by week

    @Test("volume is added up per week, oldest first, with empty weeks kept at zero")
    func weeklyVolume() {
        let logs = [
            log("2026-09-14", [(bench, [SetEntry(weightKg: 40, reps: 10), SetEntry(weightKg: 40, reps: 10)])]),
            log("2026-09-16", [("goblet-squat", [SetEntry(weightKg: 20, reps: 10)])]),
            log("2026-09-28", [(bench, [SetEntry(weightKg: 50, reps: 8), SetEntry(weightKg: 20, reps: 10, kind: .warmup)])]),
        ]
        let weeks = StrengthProgress.weeklyVolume(in: logs, weeks: 3, endingWith: T.day("2026-09-30"), calendar: T.calendar)
        #expect(weeks.map(\.start) == [T.day("2026-09-14"), T.day("2026-09-21"), T.day("2026-09-28")])
        #expect(weeks.map(\.volumeKg) == [1000, 0, 400])
        #expect(weeks.map(\.sets) == [3, 0, 1])
    }
}
