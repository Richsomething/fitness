import Foundation
import Testing
@testable import MaestroFelix

struct WeekOverviewTests {
    private static let today = T.day("2026-10-01")

    private func session(_ day: String, _ status: SessionStatus, title: String = "Тренировка",
                         focus: [MuscleGroup] = [.chest], exercises: [(String, Int)]) -> PlannedSession {
        let plan = WorkoutPlan(kind: .strength, title: title, focus: focus, exercises: exercises.map { id, sets in
            PlannedExercise(exerciseID: id, sets: sets, repsLow: 8, repsHigh: 12, holdSeconds: 0, restSeconds: 60)
        })
        return PlannedSession(slot: PlannedSlot(slot: T.day(day), day: T.day(day), status: status), plan: plan)
    }

    @Test("progress counts the finished sessions and names the next open one")
    func progressAndNext() {
        let sessions = [
            session("2026-09-30", .done(UUID()), exercises: [("bench-press", 3)]),
            session("2026-10-02", .planned, title: "Ноги", focus: [.legs], exercises: [("goblet-squat", 3)]),
            session("2026-10-04", .planned, title: "Спина", focus: [.back], exercises: [("lat-pulldown", 3)]),
        ]
        let overview = WeekOverview(sessions: sessions, today: Self.today)
        #expect(overview.sessionCount == 3 && overview.doneCount == 1)
        #expect(overview.next?.plan.title == "Ноги")
    }

    @Test("a session of an earlier day is never the next one")
    func nextSkipsThePast() {
        let sessions = [session("2026-09-29", .planned, exercises: [("bench-press", 3)])]
        #expect(WeekOverview(sessions: sessions, today: Self.today).next == nil)
    }

    @Test("load adds up planned sets per muscle group, most loaded first")
    func loadBySets() {
        let sessions = [
            session("2026-10-02", .planned, exercises: [("bench-press", 3), ("goblet-squat", 4)]),
            session("2026-10-04", .planned, exercises: [("bench-press", 2), ("lat-pulldown", 3)]),
        ]
        let loads = WeekOverview(sessions: sessions, today: Self.today).loads
        #expect(loads.map(\.group) == [.chest, .legs, .back])
        #expect(loads.map(\.plannedSets) == [5, 4, 3])
    }

    @Test("sets of a finished session count as done, the rest as still to do")
    func doneSets() {
        let sessions = [
            session("2026-09-30", .done(UUID()), exercises: [("bench-press", 3)]),
            session("2026-10-02", .planned, exercises: [("bench-press", 2)]),
        ]
        let chest = WeekOverview(sessions: sessions, today: Self.today).loads.first { $0.group == .chest }
        #expect(chest?.plannedSets == 5 && chest?.doneSets == 3)
    }

    @Test("a skipped or missed session adds no load: it is not going to happen")
    func closedSessionsAddNothing() {
        let sessions = [
            session("2026-09-29", .missed, exercises: [("bench-press", 3)]),
            session("2026-10-02", .skipped, exercises: [("goblet-squat", 3)]),
        ]
        #expect(WeekOverview(sessions: sessions, today: Self.today).loads.isEmpty)
    }

    @Test("groups of the body the week does not touch are named")
    func untouchedGroups() {
        let sessions = [session("2026-10-02", .planned, exercises: [("bench-press", 3), ("hip-thrust", 3), ("plank", 2)])]
        let untouched = WeekOverview(sessions: sessions, today: Self.today).untouched
        #expect(untouched == [.back, .shoulders, .arms, .legs])
    }

    @Test("the legend lists each state once, in the order it first appears")
    func legendStatesAreDistinct() {
        let states: [SessionStatus] = [.done(UUID()), .planned, .done(UUID()), .skipped, .planned]
        #expect(StatusLegend.distinct(states).map(\.title) == ["Выполнена", "Запланирована", "Пропущена"])
    }

    @Test("an empty week has no next session and every body group untouched")
    func emptyWeek() {
        let overview = WeekOverview(sessions: [], today: Self.today)
        #expect(overview.sessionCount == 0 && overview.doneCount == 0 && overview.next == nil)
        #expect(overview.untouched == WeekOverview.bodyGroups)
    }
}
