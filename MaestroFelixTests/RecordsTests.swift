import Foundation
import Testing
@testable import MaestroFelix

struct RecordsTests {
    private func log(_ day: String, _ id: String = "bench-press", sets: [SetEntry]) -> WorkoutLog {
        let end = T.date(day, hour: 19)
        return WorkoutLog(kind: .strength, title: "Тест", startedAt: end.addingTimeInterval(-1800), finishedAt: end,
                          entries: [ExerciseLog(exerciseID: id, setsPlanned: sets.count, setsDone: sets.count, feel: nil, sets: sets)])
    }

    @Test func theEstimatedOneRepMaxFollowsEpley() {
        #expect(PersonalRecords.oneRepMax(SetEntry(weightKg: 60, reps: 10)) == 80)
        #expect(PersonalRecords.oneRepMax(SetEntry(weightKg: 100, reps: 1)).map { ($0 * 10).rounded() / 10 } == 103.3)
        #expect(PersonalRecords.oneRepMax(SetEntry(weightKg: 20, reps: 30)) == nil)
        #expect(PersonalRecords.oneRepMax(SetEntry(reps: 12)) == nil)
    }

    @Test func theFirstTimeIsNotARecord() {
        let first = log("2026-09-30", sets: [SetEntry(weightKg: 60, reps: 10)])
        #expect(PersonalRecords.hits(in: first, before: []).isEmpty)
    }

    @Test func aHeavierWorkingWeightIsARecord() {
        let past = log("2026-09-28", sets: [SetEntry(weightKg: 60, reps: 10)])
        let now = log("2026-09-30", sets: [SetEntry(weightKg: 65, reps: 8)])
        let hits = PersonalRecords.hits(in: now, before: [past])
        #expect(hits == [RecordHit(exerciseID: "bench-press", kind: .weight, value: 65, previous: 60)])
    }

    @Test("one exercise gets one record: the weight, else the estimated max, else reps, else volume")
    func oneRecordPerExercise() {
        let past = log("2026-09-28", sets: [SetEntry(weightKg: 60, reps: 8)])
        // Same top weight, more repetitions: the estimated one-rep max moved, the weight did not.
        let now = log("2026-09-30", sets: [SetEntry(weightKg: 60, reps: 10)])
        let hits = PersonalRecords.hits(in: now, before: [past])
        #expect(hits.count == 1 && hits[0].kind == .oneRepMax)
        // The same sets again: nothing new.
        #expect(PersonalRecords.hits(in: log("2026-10-01", sets: [SetEntry(weightKg: 60, reps: 8)]), before: [past]).isEmpty)
    }

    @Test func moreRepetitionsOfTheBodyAreARecord() {
        let past = log("2026-09-28", "push-ups", sets: [SetEntry(reps: 12), SetEntry(reps: 10)])
        let now = log("2026-09-30", "push-ups", sets: [SetEntry(reps: 14)])
        #expect(PersonalRecords.hits(in: now, before: [past]) == [RecordHit(exerciseID: "push-ups", kind: .reps, value: 14, previous: 12)])
    }

    @Test func warmUpsNeverMakeARecord() {
        let past = log("2026-09-28", sets: [SetEntry(weightKg: 60, reps: 10)])
        let now = log("2026-09-30", sets: [SetEntry(weightKg: 100, reps: 5, kind: .warmup), SetEntry(weightKg: 60, reps: 10)])
        #expect(PersonalRecords.hits(in: now, before: [past]).isEmpty)
    }

    @Test func onlyEarlierWorkoutsCount() {
        let earlier = log("2026-09-28", sets: [SetEntry(weightKg: 60, reps: 10)])
        let later = log("2026-10-05", sets: [SetEntry(weightKg: 90, reps: 10)])
        let now = log("2026-09-30", sets: [SetEntry(weightKg: 62.5, reps: 10)])
        #expect(PersonalRecords.hits(in: now, before: [earlier, later, now]).map(\.previous) == [60])
    }

    @Test func volumeIsComparedOnlyOnExercisesDoneBefore() {
        let past = log("2026-09-28", sets: [SetEntry(weightKg: 50, reps: 10), SetEntry(weightKg: 50, reps: 10)])
        var now = log("2026-09-30", sets: [SetEntry(weightKg: 50, reps: 10), SetEntry(weightKg: 50, reps: 10), SetEntry(weightKg: 50, reps: 10)])
        now.entries.append(ExerciseLog(exerciseID: "squat-new", setsPlanned: 1, setsDone: 1, feel: nil, sets: [SetEntry(weightKg: 100, reps: 10)]))
        #expect(PersonalRecords.volumeComparison(in: now, before: [past]) == VolumeComparison(current: 1500, previous: 1000))
        #expect(PersonalRecords.volumeComparison(in: now, before: []) == nil)
    }

    // MARK: Shown as a number and an arrow

    @Test("a record is shown as its new value and how far it moved") @MainActor
    func recordsAreShownAsValueAndDelta() {
        let weight = RecordHit(exerciseID: "bench-press", kind: .weight, value: 62.5, previous: 60)
        #expect(WorkoutResultsBlock.valueText(weight) == "62,5 кг" && WorkoutResultsBlock.deltaText(weight) == "+2,5")
        let max = RecordHit(exerciseID: "bench-press", kind: .oneRepMax, value: 80, previous: 77.5)
        #expect(WorkoutResultsBlock.valueText(max) == "≈ 80 кг" && WorkoutResultsBlock.deltaText(max) == "+2,5")
        let reps = RecordHit(exerciseID: "push-ups", kind: .reps, value: 18, previous: 15)
        #expect(WorkoutResultsBlock.valueText(reps) == "18 повт." && WorkoutResultsBlock.deltaText(reps) == "+3")
        let volume = RecordHit(exerciseID: "bench-press", kind: .volume, value: 4500, previous: 4200)
        #expect(WorkoutResultsBlock.valueText(volume) == "\(WorkoutSummaryView.tons(4500)) кг")
        #expect(WorkoutResultsBlock.deltaText(volume) == "+\(WorkoutSummaryView.tons(300))")
    }

    @Test("the full sentence stays for VoiceOver") @MainActor
    func theSpokenSentenceIsKept() {
        let hit = RecordHit(exerciseID: "bench-press", kind: .weight, value: 65, previous: 60)
        #expect(WorkoutResultsBlock.recordText(hit) == "Рабочий вес 65 кг, раньше 60")
    }
}
