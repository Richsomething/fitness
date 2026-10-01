import Foundation
import Testing
@testable import MaestroFelix

struct ProgressTests {
    // Monday/Wednesday/Friday from 09-14. Sessions: 14 16 18 | 21 23 25 | 28 30 10-02. "Today" is Friday 10-02.
    private let state = T.state(from: "2026-09-14")

    private func done(_ days: [String]) -> [WorkoutLog] {
        days.map { T.log(slot: $0, finished: $0) }
    }

    private func stats(_ state: ScheduleState, _ logs: [WorkoutLog], today: String = "2026-10-02") -> TrainingStats {
        ProgressCalculator.stats(state: state, logs: logs, today: T.day(today), calendar: T.calendar)
    }

    // MARK: Streak

    @Test("done sessions add up, a missed one resets, today's open one changes nothing")
    func streakAcrossAMiss() {
        let logs = done(["2026-09-14", "2026-09-16", "2026-09-18", "2026-09-23", "2026-09-25", "2026-09-28", "2026-09-30"])
        let result = stats(state, logs)
        #expect(result.streak == 4)
        #expect(result.bestStreak == 4)
    }

    @Test func todaysSessionExtendsTheStreakOnceDone() {
        let logs = done(["2026-09-28", "2026-09-30", "2026-10-02"])
        #expect(stats(state, logs).streak == 3)
    }

    @Test("days off never break the streak")
    func restDaysAreNeutral() {
        let logs = done(["2026-09-14", "2026-09-16", "2026-09-18", "2026-09-21", "2026-09-23", "2026-09-25", "2026-09-28", "2026-09-30"])
        #expect(stats(state, logs).streak == 8)
    }

    @Test func aSkippedSessionBreaksTheStreak() {
        var skipped = state
        skipped.skip(T.day("2026-09-30"))
        let logs = done(["2026-09-14", "2026-09-16", "2026-09-18", "2026-09-21", "2026-09-23", "2026-09-25", "2026-09-28"])
        let result = stats(skipped, logs)
        #expect(result.streak == 0)
        #expect(result.bestStreak == 7)
    }

    @Test("a pause freezes the streak instead of breaking it")
    func pauseFreezes() {
        var held = state
        held.pause(from: T.day("2026-09-19"), until: T.day("2026-09-22"))
        let logs = done(["2026-09-14", "2026-09-16", "2026-09-18", "2026-09-23", "2026-09-25", "2026-09-28", "2026-09-30"])
        #expect(stats(held, logs).streak == 7)
    }

    @Test func aMovedSessionKeepsTheObligation() {
        var moved = state
        moved.move(T.day("2026-09-30"), to: T.day("2026-10-01"))
        let logs = done(["2026-09-28", "2026-09-30"])
        // Done for its slot and counted on its new day: nothing was missed.
        #expect(stats(moved, logs, today: "2026-10-01").streak == 2)
    }

    @Test func aLateReturnDoesNotEraseARecordedMiss() {
        let logs = done(["2026-09-14", "2026-09-16", "2026-09-18", "2026-09-23"])
        let result = stats(state, logs, today: "2026-09-24")
        // The 21st was missed; finishing the 23rd restarts the count from one.
        #expect(result.streak == 1)
        #expect(result.bestStreak == 3)
    }

    // MARK: Weeks

    @Test func aWeekIsFullWhenEverySessionIsDone() {
        let logs = done(["2026-09-14", "2026-09-16", "2026-09-18", "2026-09-21", "2026-09-23"])
        let result = stats(state, logs)
        #expect(result.fullWeeks == 1)
        #expect(result.week?.planned == 3)
    }

    @Test func aHeldDayCallsForNoSession() {
        var held = state
        held.pause(from: T.day("2026-09-25"), until: T.day("2026-09-25"))
        let logs = done(["2026-09-21", "2026-09-23"])
        let weeks = ProgressCalculator.weeks(in: T.slots(held, logs: logs, from: "2026-09-21", through: "2026-09-27", today: "2026-10-02"),
                                             calendar: T.calendar)
        #expect(weeks.map(\.planned) == [2])
        #expect(weeks.first?.isComplete == true)
    }

    @Test func aWeekWithNothingPlannedIsNeverFull() {
        #expect(WeekProgress(start: T.day("2026-09-28"), planned: 0, done: 0).isComplete == false)
    }

    @Test func currentWeekProgressCountsPlannedAndDone() {
        let logs = done(["2026-09-28"])
        #expect(stats(state, logs, today: "2026-09-30").week == WeekProgress(start: T.day("2026-09-28"), planned: 3, done: 1))
    }

    @Test func statsCountEveryWorkoutIncludingRestDayActivity() {
        let logs = done(["2026-09-28"]) + [T.log(kind: .cardio, finished: "2026-09-29")]
        let result = stats(state, logs, today: "2026-09-30")
        #expect(result.workouts == 2)
        #expect(result.doneSessions == 1)
    }

    // MARK: Achievements

    @Test func achievementsAreMetByTheStats() {
        var first = TrainingStats()
        #expect(AchievementRules.newlyMet(stats: first, state: AchievementsState()).isEmpty)
        first.workouts = 1
        #expect(AchievementRules.newlyMet(stats: first, state: AchievementsState()) == [.firstWorkout])
        first.doneSessions = 3
        first.fullWeeks = 1
        #expect(Set(AchievementRules.newlyMet(stats: first, state: AchievementsState())) == Set(AchievementID.allCases))
    }

    @Test("a locked achievement says how far along it is and how much is left")
    func achievementProgress() {
        var stats = TrainingStats()
        stats.workouts = 0
        stats.doneSessions = 2
        stats.fullWeeks = 0
        #expect(AchievementRules.progress(.firstWorkout, stats: stats) == AchievementProgress(current: 0, goal: 1))
        #expect(AchievementRules.progress(.threeInPlan, stats: stats) == AchievementProgress(current: 2, goal: 3))
        #expect(AchievementRules.progress(.threeInPlan, stats: stats).remaining == 1)
        #expect(AchievementRules.progress(.firstFullWeek, stats: stats).fraction == 0)
    }

    @Test("progress never runs past its goal")
    func achievementProgressIsCapped() {
        var stats = TrainingStats()
        stats.doneSessions = 40
        let progress = AchievementRules.progress(.threeInPlan, stats: stats)
        #expect(progress.current == 3 && progress.remaining == 0 && progress.fraction == 1)
    }

    @Test("an achievement is issued once: what is unlocked is never offered again")
    func issuingIsIdempotent() {
        var stats = TrainingStats()
        stats.workouts = 5
        var unlocked = AchievementsState()
        for id in AchievementRules.newlyMet(stats: stats, state: unlocked) { unlocked.unlocked[id.rawValue] = T.date("2026-10-02") }
        #expect(unlocked.has(.firstWorkout))
        #expect(AchievementRules.newlyMet(stats: stats, state: unlocked).isEmpty)
    }

    @Test("cutting the plan later cannot hand out a full week for the weeks already lived")
    func laterScheduleCutsDoNotRewriteHistory() {
        var cut = state
        cut.record(weekdays: [1], from: T.day("2026-10-05"))
        let logs = done(["2026-09-14", "2026-09-16"])
        // The week of 09-14 still called for three sessions, so it is not full.
        #expect(stats(cut, logs, today: "2026-10-06").fullWeeks == 0)
    }

    // MARK: History

    @Test func historyPutsPlanNextToFactNewestWeekFirst() {
        let logs = done(["2026-09-14", "2026-09-16"]) + [T.log(kind: .light, finished: "2026-09-21", hour: 8)] + done(["2026-09-23"])
        let slots = T.slots(state, logs: logs, from: "2026-09-14", through: "2026-09-27", today: "2026-10-02")
        let weeks = HistoryBuilder.weeks(logs: logs, slots: slots, calendar: T.calendar)
        #expect(weeks.map(\.start.rawValue) == ["2026-09-21", "2026-09-14"])
        #expect(weeks[0].planned == 3 && weeks[0].done == 1 && weeks[0].logs.count == 2)
        #expect(weeks[1].planned == 3 && weeks[1].done == 2)
    }

    @Test func historyOmitsWeeksWithNothingDone() {
        let slots = T.slots(state, from: "2026-09-14", through: "2026-09-27", today: "2026-10-02")
        #expect(HistoryBuilder.weeks(logs: [], slots: slots, calendar: T.calendar).isEmpty)
    }
}
