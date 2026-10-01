import Foundation
import Testing
@testable import MaestroFelix

struct ScheduleTests {
    // Monday 09-28 … Sunday 10-04. Training on Monday, Wednesday, Friday; "today" is Wednesday 09-30.
    private let state = T.state()

    private func week(_ state: ScheduleState, logs: [WorkoutLog] = [], today: String = "2026-09-30") -> [PlannedSlot] {
        T.slots(state, logs: logs, from: "2026-09-28", through: "2026-10-04", today: today)
    }

    @Test func plansTheChosenDaysOfAWeek() {
        let slots = week(state)
        #expect(slots.map(\.day.rawValue) == ["2026-09-28", "2026-09-30", "2026-10-02"])
        #expect(slots.map(\.status) == [.missed, .planned, .planned])
    }

    @Test("days before the schedule began are not planned")
    func nothingBeforeTheFirstRevision() {
        let slots = T.slots(state, from: "2026-09-14", through: "2026-09-27", today: "2026-09-30")
        #expect(slots.isEmpty)
    }

    @Test func aWorkoutLoggedForASlotCompletesIt() {
        let log = T.log(slot: "2026-09-28", finished: "2026-09-28")
        #expect(week(state, logs: [log]).first?.status == .done(log.id))
    }

    @Test("a workout from before slots existed counts for the session on the day it was finished")
    func legacyWorkoutCompletesItsDay() {
        let log = T.log(finished: "2026-09-30")
        #expect(week(state, logs: [log])[1].status == .done(log.id))
    }

    @Test("rest-day cardio or a light block never completes a planned session")
    func restDayActivityDoesNotCompleteASession() {
        let logs = [T.log(kind: .cardio, finished: "2026-09-30"), T.log(kind: .light, finished: "2026-09-30")]
        #expect(week(state, logs: logs)[1].status == .planned)
    }

    @Test func aMovedSessionKeepsItsSlot() throws {
        var moved = state
        moved.move(T.day("2026-10-02"), to: T.day("2026-10-03"))
        let slot = try #require(T.slots(moved, from: "2026-10-03", through: "2026-10-03", today: "2026-09-30").first)
        #expect(slot.slot.rawValue == "2026-10-02")
        #expect(slot.day.rawValue == "2026-10-03")
        #expect(slot.isMoved)
        #expect(slot.status == .planned)
        #expect(T.slots(moved, from: "2026-10-02", through: "2026-10-02", today: "2026-09-30").isEmpty)
    }

    @Test func movingBackToTheSlotRemovesTheMove() {
        var moved = state
        moved.move(T.day("2026-10-02"), to: T.day("2026-10-03"))
        moved.move(T.day("2026-10-02"), to: T.day("2026-10-02"))
        #expect(moved.moves.isEmpty)
    }

    @Test func aSessionMovedFromLastWeekShowsInThisOne() {
        var moved = state
        moved.move(T.day("2026-09-28"), to: T.day("2026-10-06"))
        let slots = T.slots(moved, from: "2026-10-05", through: "2026-10-11", today: "2026-09-29")
        #expect(slots.contains { $0.slot.rawValue == "2026-09-28" && $0.day.rawValue == "2026-10-06" })
    }

    @Test func skippingMarksTheSessionSkipped() {
        var skipped = state
        skipped.skip(T.day("2026-10-02"))
        #expect(week(skipped)[2].status == .skipped)
        skipped.unskip(T.day("2026-10-02"))
        #expect(week(skipped)[2].status == .planned)
    }

    @Test("a pause turns would-be misses into held days")
    func pauseHoldsDays() {
        var held = state
        held.pause(from: T.day("2026-09-28"), until: T.day("2026-10-04"))
        #expect(week(held, today: "2026-10-05").map(\.status) == [.paused, .paused, .paused])
    }

    @Test func aDoneSessionStaysDoneUnderAPause() {
        var held = state
        held.pause(from: T.day("2026-09-28"), until: T.day("2026-10-04"))
        let log = T.log(slot: "2026-09-28", finished: "2026-09-28")
        #expect(week(held, logs: [log], today: "2026-10-05").first?.status == .done(log.id))
    }

    @Test func resumingEndsThePauseTheDayBefore() {
        var held = state
        held.pause(from: T.day("2026-09-28"), until: T.day("2026-10-04"))
        held.resume(on: T.day("2026-10-01"), calendar: T.calendar)
        #expect(held.pauses == [SchedulePause(from: T.day("2026-09-28"), until: T.day("2026-09-30"))])
        held.resume(on: T.day("2026-09-28"), calendar: T.calendar)
        #expect(held.pauses.isEmpty)
    }

    // MARK: Revisions

    @Test("changing the days leaves the past as it was")
    func newDaysApplyFromTheirDayOn() {
        var changed = state
        changed.record(weekdays: [2, 4], from: T.day("2026-10-05"))
        #expect(changed.revisions.count == 2)
        let before = T.slots(changed, from: "2026-09-28", through: "2026-10-04", today: "2026-10-05")
        #expect(before.map(\.day.rawValue) == ["2026-09-28", "2026-09-30", "2026-10-02"])
        let after = T.slots(changed, from: "2026-10-05", through: "2026-10-11", today: "2026-10-05")
        #expect(after.map(\.day.rawValue) == ["2026-10-06", "2026-10-08"])
    }

    @Test func recordingTheDaysAlreadyInForceAddsNothing() {
        var same = state
        same.record(weekdays: [1, 3, 5], from: T.day("2026-10-05"))
        #expect(same.revisions.count == 1)
    }

    @Test("a change that has not started yet is replaced, and undone by writing the old days")
    func pendingChangeIsReplaced() {
        var changed = state
        changed.record(weekdays: [2, 4], from: T.day("2026-10-05"))
        changed.record(weekdays: [1, 2], from: T.day("2026-10-05"))
        #expect(changed.revisions.count == 2)
        #expect(changed.revisions.last?.weekdays == [1, 2])
        changed.record(weekdays: [1, 3, 5], from: T.day("2026-10-05"))
        #expect(changed.revisions.count == 1)
    }

    @Test func emptyDaysAreNeverRecorded() {
        var same = state
        same.record(weekdays: [], from: T.day("2026-10-05"))
        #expect(same == state)
    }

    // MARK: Plans

    @Test("the split follows the number of days, in day order")
    func sessionsCarryTheirPlans() {
        let sessions = SchedulePlanner.sessions(profile: T.profile(), state: state, logs: [], from: T.day("2026-09-28"),
                                                through: T.day("2026-10-04"), today: T.day("2026-09-30"), calendar: T.calendar)
        #expect(sessions.map(\.plan.title) == ["Грудь, плечи, трицепс", "Спина и бицепс", "Ноги и пресс"])
    }

    @Test("a session keeps the content of its slot when it is moved")
    func movedSessionKeepsItsPlan() {
        var moved = state
        moved.move(T.day("2026-10-02"), to: T.day("2026-10-03"))
        let sessions = SchedulePlanner.sessions(profile: T.profile(), state: moved, logs: [], from: T.day("2026-10-03"),
                                                through: T.day("2026-10-03"), today: T.day("2026-09-30"), calendar: T.calendar)
        #expect(sessions.map(\.plan.title) == ["Ноги и пресс"])
    }

    @Test func daysOfARevisionSplitByThatRevision() {
        var changed = state
        changed.record(weekdays: [2, 4], from: T.day("2026-10-05"))
        let sessions = SchedulePlanner.sessions(profile: T.profile(), state: changed, logs: [], from: T.day("2026-10-05"),
                                                through: T.day("2026-10-11"), today: T.day("2026-10-05"), calendar: T.calendar)
        #expect(sessions.map(\.plan.title) == ["Верх тела", "Низ тела"])
    }

    // MARK: Today

    private func resolve(_ state: ScheduleState, logs: [WorkoutLog] = [], today: String = "2026-09-30") -> TodayState {
        let sessions = SchedulePlanner.sessions(profile: T.profile(), state: state, logs: logs, from: T.day(today),
                                                through: T.day(today).adding(days: 14, calendar: T.calendar),
                                                today: T.day(today), calendar: T.calendar)
        return TodayResolver.resolve(sessions: sessions, state: state, logs: logs, today: T.day(today), calendar: T.calendar)
    }

    @Test func aTrainingDayStartsTraining() {
        guard case let .training(session) = resolve(state) else { Issue.record("expected training"); return }
        #expect(session.plan.title == "Спина и бицепс")
    }

    @Test func aFinishedSessionShowsAsDone() {
        let log = T.log(slot: "2026-09-30", finished: "2026-09-30")
        guard case let .trainingDone(_, done) = resolve(state, logs: [log]) else { Issue.record("expected done"); return }
        #expect(done.id == log.id)
    }

    @Test("a light block on a training day does not hide the session")
    func lightBlockKeepsTheSessionAvailable() {
        guard case .training = resolve(state, logs: [T.log(kind: .light, finished: "2026-09-30")]) else {
            Issue.record("the planned session must still be there"); return
        }
    }

    @Test func aRestDayKnowsTheNextSessionAndTheDayDoneSoFar() {
        let activity = T.log(kind: .cardio, finished: "2026-09-29")
        guard case let .rest(next, movedTo, done) = resolve(state, logs: [activity], today: "2026-09-29") else {
            Issue.record("expected rest"); return
        }
        #expect(next?.day.rawValue == "2026-09-30")
        #expect(movedTo == nil)
        #expect(done.map(\.id) == [activity.id])
    }

    @Test func aSessionMovedAwayLeavesARestDayThatSaysWhere() {
        var moved = state
        moved.move(T.day("2026-09-30"), to: T.day("2026-10-01"))
        guard case let .rest(next, movedTo, _) = resolve(moved) else { Issue.record("expected rest"); return }
        #expect(movedTo?.rawValue == "2026-10-01")
        #expect(next?.day.rawValue == "2026-10-01")
    }

    @Test func aSkippedSessionIsNamedAsSkipped() {
        var skipped = state
        skipped.skip(T.day("2026-09-30"))
        guard case .skipped = resolve(skipped) else { Issue.record("expected skipped"); return }
    }

    @Test func aPauseWinsOverThePlan() {
        var held = state
        held.pause(from: T.day("2026-09-30"), until: T.day("2026-10-06"))
        guard case let .paused(until, _) = resolve(held) else { Issue.record("expected paused"); return }
        #expect(until.rawValue == "2026-10-06")
    }

    // MARK: Moving

    private func movable(_ slot: String, state: ScheduleState? = nil, logs: [WorkoutLog] = [], today: String = "2026-09-30") -> [String] {
        let all = T.slots(state ?? self.state, logs: logs, from: today, through: "2026-10-14", today: today)
        guard let target = all.first(where: { $0.slot.rawValue == slot }) else { return [] }
        return SchedulePlanner.movableDays(for: target, among: all, today: T.day(today), calendar: T.calendar).map(\.rawValue)
    }

    @Test("a session may move to any free day from today to two weeks ahead, and not onto another session")
    func movableDaysAreTheFreeOnes() {
        #expect(movable("2026-09-30") == ["2026-10-01", "2026-10-03", "2026-10-04", "2026-10-06", "2026-10-08", "2026-10-10",
                                          "2026-10-11", "2026-10-13"])
    }

    @Test func aMovedSessionCanGoBackToItsOwnDay() {
        var moved = state
        moved.move(T.day("2026-10-02"), to: T.day("2026-10-03"))
        let days = movable("2026-10-02", state: moved)
        #expect(days.contains("2026-10-02") && !days.contains("2026-10-03"))
    }

    @Test("a done, missed, skipped or held session cannot be moved")
    func onlyAnOpenSessionMoves() {
        #expect(movable("2026-09-30", logs: [T.log(slot: "2026-09-30", finished: "2026-09-30")]).isEmpty)
        #expect(movable("2026-09-28", today: "2026-09-30").isEmpty, "Monday is over")
        var skipped = state
        skipped.skip(T.day("2026-10-02"))
        #expect(movable("2026-10-02", state: skipped).isEmpty)
        var held = state
        held.pause(from: T.day("2026-09-30"), until: T.day("2026-10-04"))
        #expect(movable("2026-10-02", state: held).isEmpty)
    }

    // MARK: Storage

    @Test func scheduleStateSurvivesJSONAndReadsOldDataWithMissingFields() throws {
        var full = state
        full.move(T.day("2026-10-02"), to: T.day("2026-10-03"))
        full.skip(T.day("2026-09-28"))
        full.pause(from: T.day("2026-10-05"), until: T.day("2026-10-06"))
        let decoded = try JSONDecoder().decode(ScheduleState.self, from: JSONEncoder().encode(full))
        #expect(decoded == full)
        #expect(try JSONDecoder().decode(ScheduleState.self, from: Data("{}".utf8)) == ScheduleState())
    }
}
