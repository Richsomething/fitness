import Foundation
import Testing
@testable import MaestroFelix

@MainActor
struct SetKindTests {
    private static let plan = WorkoutPlan(kind: .strength, title: "Тест", focus: [.chest], exercises: [
        PlannedExercise(exerciseID: "bench-press", sets: 3, repsLow: 8, repsHigh: 12, holdSeconds: 0, restSeconds: 60),
    ])

    private func session(history: [String: [SetEntry]] = [:]) -> WorkoutSession {
        WorkoutSession(plan: Self.plan, slot: T.day("2026-09-30"), history: history, startedAt: T.date("2026-09-30", hour: 18))
    }

    @Test func aSetIsAnOrdinaryOneUnlessMarked() {
        #expect(SetEntry(weightKg: 40, reps: 10).kind == .normal)
        #expect(SetKind.allCases.map(\.title) == ["Рабочий", "Разминка", "До отказа", "Дроп-сет"])
    }

    @Test func aWarmUpAddsNoVolume() {
        #expect(SetEntry(weightKg: 20, reps: 10, kind: .warmup).volumeKg == 0)
        #expect(SetEntry(weightKg: 20, reps: 10, kind: .dropSet).volumeKg == 200)
    }

    @Test func theSummaryNamesAnUnusualSet() {
        #expect(SetEntry(weightKg: 20, reps: 10, kind: .warmup).summary == "20 кг × 10 · разминка")
        #expect(SetEntry(weightKg: 20, reps: 10).summary == "20 кг × 10")
    }

    @Test("an unfinished workout counts its working sets, not the warm-ups")
    func theResumeCountSkipsWarmUps() {
        let sets = [[SetEntry(weightKg: 20, reps: 10, kind: .warmup), SetEntry(weightKg: 40, reps: 10), SetEntry(weightKg: 40, reps: 9)]]
        let snapshot = SessionSnapshot(id: UUID(), plan: Self.plan, slot: nil, startedAt: T.date("2026-09-30", hour: 18),
                                       sets: sets, phase: .exerciseDone(index: 0), feels: [:])
        #expect(snapshot.workingSetsDone == 2)
    }

    @Test("a row already titled as a warm-up does not say it again")
    func rowSummaryDropsTheWarmUpTag() {
        #expect(SetEntry(weightKg: 20, reps: 10, kind: .warmup).rowSummary == "20 кг × 10")
        #expect(SetEntry(weightKg: 20, reps: 8, kind: .failure).rowSummary == "20 кг × 8 · до отказа")
        #expect(SetEntry(weightKg: 20, reps: 8).rowSummary == "20 кг × 8")
    }

    @Test("rows count only the working sets, and a warm-up is named, not numbered")
    func rowTitlesSkipWarmUpsInTheCount() {
        let sets = [SetEntry(weightKg: 20, reps: 10, kind: .warmup), SetEntry(weightKg: 40, reps: 10),
                    SetEntry(weightKg: 40, reps: 8, kind: .failure), SetEntry(weightKg: 20, reps: 12, kind: .warmup)]
        #expect(sets.rowTitles(noun: "Подход") == ["Разминка", "Подход 1", "Подход 2", "Разминка"])
        #expect([SetEntry]().rowTitles(noun: "Подход").isEmpty)
    }

    @Test("a log written before kinds existed reads as ordinary sets")
    func oldSetsDecodeAsOrdinary() throws {
        let json = #"{"id":"6B6E3C52-0F5B-4C0B-9C47-6F9B7B5A0001","weightKg":50,"reps":8}"#
        let entry = try JSONDecoder().decode(SetEntry.self, from: Data(json.utf8))
        #expect(entry.kind == .normal && entry.weightKg == 50 && entry.reps == 8)
    }

    @Test("a warm-up is not one of the planned sets, and it needs no rest")
    func warmUpsStayOutOfThePlannedSets() {
        let running = session()
        running.start(0)
        running.finishSet(SetEntry(weightKg: 20, reps: 10, kind: .warmup))
        #expect(running.completedSets == 0)
        #expect(!running.isDone(0))
        guard case .working(0, _) = running.phase else { Issue.record("expected the next set at once"); return }
        for _ in 0..<3 {
            running.finishSet(SetEntry(weightKg: 50, reps: 10))
            if case .resting = running.phase { running.startNextSet() }
        }
        #expect(running.isDone(0))
        #expect(running.completedSets == 3)
        #expect(running.sets[0].count == 4)
    }

    @Test func theLogCountsWorkingSetsAndKeepsEveryOne() {
        let running = session()
        running.start(0)
        running.finishSet(SetEntry(weightKg: 20, reps: 10, kind: .warmup))
        running.finishSet(SetEntry(weightKg: 50, reps: 10))
        let log = running.log(finishedAt: T.date("2026-09-30", hour: 19))
        #expect(log.setsDone == 1)
        #expect(log.entries[0].sets.count == 2)
        #expect(log.volumeKg == 500)
    }

    @Test func afterAWarmUpTheWorkingNumbersComeFromLastTime() {
        let running = session(history: ["bench-press": [SetEntry(weightKg: 60, reps: 10)]])
        running.start(0)
        running.finishSet(SetEntry(weightKg: 20, reps: 10, kind: .warmup))
        #expect(running.suggestion(for: 0).weightKg == 60)
    }
}
