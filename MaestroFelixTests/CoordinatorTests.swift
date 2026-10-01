import Foundation
import Testing
@testable import MaestroFelix

/// The app as the person meets it: sign-up done, then days passing, workouts done, the schedule
/// changed. Everything runs against an in-memory store and a fake notification centre.
@MainActor
struct CoordinatorTests {
    private let weekday = Set([1, 3, 5])

    private func startToday(_ h: Harness) throws -> WorkoutSession {
        let planned = try h.session("2026-09-30")
        h.app.start(planned.plan, slot: planned.key)
        return try #require(h.app.activeSession)
    }

    /// Does one set of the first exercise.
    private func doASet(_ session: WorkoutSession, weight: Double = 40, reps: Int = 10) {
        session.start(0)
        session.finishSet(SetEntry(weightKg: weight, reps: reps))
    }

    // MARK: Opening

    @Test("a profile from before schedules existed gets one from today, and its weight becomes the first weighing")
    func profileWithoutAScheduleIsMigrated() throws {
        let h = try Harness.make()
        #expect(h.app.schedule.state.revisions == [ScheduleRevision(from: T.day("2026-09-30"), weekdays: weekday)])
        #expect(h.app.weights.entries.map(\.kg) == [80])
        guard case let .training(session) = h.app.todayState else { Issue.record("expected a training day"); return }
        #expect(session.plan.title == "Спина и бицепс")
    }

    @Test func reopeningKeepsTheScheduleAndAddsNothing() throws {
        let h = try Harness.make()
        let reopened = try Harness.reopen(h)
        #expect(reopened.app.schedule.state == h.app.schedule.state)
        #expect(reopened.app.weights.entries.count == 1)
    }

    @Test func beforeSignUpThereIsNothingToShow() throws {
        let h = try Harness.make(profile: nil)
        #expect(h.app.profile == nil && h.app.sessions(from: T.day("2026-09-30"), through: T.day("2026-10-06")).isEmpty)
    }

    // MARK: Editing the profile

    @Test("new days replace the plan from today, when today's session is not done")
    func editingTheDaysAppliesFromToday() throws {
        let h = try Harness.make()
        let onboarding = h.app.onboarding
        onboarding.edit(.schedule)
        onboarding.draft.weekdays = [2, 4]
        onboarding.advance()
        onboarding.advance()
        #expect(h.app.schedule.state.revisions == [ScheduleRevision(from: T.day("2026-09-30"), weekdays: [2, 4])])
        guard case .rest = h.app.todayState else { Issue.record("Wednesday is a rest day now"); return }
    }

    @Test("with today's session done, new days start tomorrow and today stays as lived")
    func editingAfterTodaysWorkoutKeepsToday() throws {
        let h = try Harness.make()
        let running = try startToday(h)
        doASet(running)
        _ = try #require(h.app.finish(running))
        let onboarding = h.app.onboarding
        onboarding.edit(.schedule)
        onboarding.draft.weekdays = [2, 4]
        onboarding.advance()
        onboarding.advance()
        #expect(h.app.schedule.state.revisions.map(\.from.rawValue) == ["2026-09-30", "2026-10-01"])
        guard case .trainingDone = h.app.todayState else { Issue.record("today stays done"); return }
    }

    @Test func aNewWeightInTheProfileJoinsTheWeighings() throws {
        let h = try Harness.make()
        let onboarding = h.app.onboarding
        onboarding.edit(.body)
        onboarding.draft.weightText = "78,5"
        onboarding.advance()
        onboarding.advance()
        #expect(h.app.weights.entries.map(\.kg) == [78.5])
    }

    // MARK: Workout

    @Test("a workout is written down as it goes, saved once, and moves the numbers and the achievements")
    func aWorkoutFromStartToFinish() throws {
        let h = try Harness.make()
        let running = try startToday(h)
        doASet(running)
        #expect(h.app.workouts.resumable?.id == running.id, "written down after every change")

        let summary = try #require(h.app.finish(running))
        #expect(summary.log.sessionKey == T.day("2026-09-30") && summary.log.setsDone == 1)
        #expect(summary.newAchievements == [.firstWorkout])
        #expect(summary.streak == 1 && summary.nextSessionText == "в пятницу")
        #expect(h.app.workouts.logs.count == 1 && h.app.workouts.resumable == nil)
        #expect(h.app.progress.stats.workouts == 1 && h.app.progress.stats.week?.done == 1)
        guard case .trainingDone = h.app.todayState else { Issue.record("expected done"); return }

        let again = try #require(h.app.finish(running))
        #expect(again.newAchievements.isEmpty && h.app.workouts.logs.count == 1, "the same workout is never counted twice")
    }

    @Test func leavingWithoutSavingForgetsTheWorkout() throws {
        let h = try Harness.make()
        let running = try startToday(h)
        doASet(running)
        h.app.cancel(running)
        #expect(h.app.activeSession == nil && h.app.workouts.resumable == nil && h.app.workouts.logs.isEmpty)
        guard case .training = h.app.todayState else { Issue.record("the session is still to do"); return }
    }

    @Test("after the app is closed the workout is found, and goes on from the same set")
    func aWorkoutSurvivesTheAppBeingClosed() throws {
        let h = try Harness.make()
        let running = try startToday(h)
        doASet(running)
        let reopened = try Harness.reopen(h, now: h.now.addingTimeInterval(90))
        #expect(reopened.app.workouts.resumable?.id == running.id && reopened.app.activeSession == nil)
        reopened.app.resume()
        let resumed = try #require(reopened.app.activeSession)
        #expect(resumed.id == running.id && resumed.completedSets == 1)
        guard case .resting = resumed.phase else { Issue.record("expected rest"); return }
        reopened.app.discardResumable()
        #expect(reopened.app.workouts.resumable == nil)
    }

    @Test("starting a session whose workout is already begun goes on with it instead of replacing it")
    func startingAgainResumes() throws {
        let h = try Harness.make()
        let running = try startToday(h)
        doASet(running)
        let reopened = try Harness.reopen(h)
        let planned = try reopened.session("2026-09-30")
        reopened.app.start(planned.plan, slot: planned.key)
        let resumed = try #require(reopened.app.activeSession)
        #expect(resumed.id == running.id && resumed.completedSets == 1)
        // A different session, or rest-day activity, is a new workout and replaces the old record.
        reopened.app.cancel(resumed)
        reopened.app.start(planned.plan, slot: nil)
        #expect(reopened.app.activeSession?.id != running.id)
    }

    @Test func aWorkoutThatCannotBeSavedStaysOpen() throws {
        let h = try Harness.make()
        let running = try startToday(h)
        doASet(running)
        h.store.failingSaves = [StoreKey.workoutLogs]
        #expect(h.app.finish(running) == nil)
        #expect(h.app.workouts.logs.isEmpty && h.app.workouts.resumable != nil && h.app.workouts.storageError != nil)
        h.store.failingSaves = []
        #expect(h.app.finish(running) != nil && h.app.workouts.logs.count == 1)
    }

    @Test func onlyOneWorkoutRunsAtATime() throws {
        let h = try Harness.make()
        let first = try startToday(h)
        let planned = try h.session("2026-09-30")
        h.app.start(planned.plan, slot: planned.key)
        #expect(h.app.activeSession?.id == first.id)
    }

    @Test("a light block on a training day leaves the day's session still to do")
    func restDayActivityDoesNotCountAsTheSession() throws {
        let h = try Harness.make()
        h.app.start(WorkoutPlanner.light(.core, for: T.profile()), slot: nil)
        let block = try #require(h.app.activeSession)
        doASet(block, weight: 0, reps: 12)
        _ = try #require(h.app.finish(block))
        guard case .training = h.app.todayState else { Issue.record("the planned session must still be there"); return }
        #expect(h.app.progress.stats.doneSessions == 0 && h.app.progress.stats.workouts == 1)
    }

    // MARK: Changing the schedule

    @Test func skippingAndBringingBackASession() throws {
        let h = try Harness.make()
        let planned = try h.session("2026-09-30")
        h.app.skip(planned.key)
        guard case .skipped = h.app.todayState else { Issue.record("expected skipped"); return }
        h.app.unskip(planned.key)
        guard case .training = h.app.todayState else { Issue.record("expected training"); return }
    }

    @Test func movingASessionToAFreeDayAndNotToABusyOne() throws {
        let h = try Harness.make()
        let planned = try h.session("2026-09-30")
        h.app.move(planned, to: T.day("2026-10-02"))
        #expect(h.app.schedule.state.moves.isEmpty, "Friday already holds a session")
        h.app.move(planned, to: T.day("2026-10-01"))
        guard case let .rest(next, movedTo, _) = h.app.todayState else { Issue.record("expected rest"); return }
        #expect(movedTo == T.day("2026-10-01") && next?.day == T.day("2026-10-01") && next?.key == planned.key)
        #expect(h.app.movableDays(for: try h.session("2026-09-30")).contains(T.day("2026-09-30")), "it can come back to its own day")
    }

    @Test func aFinishedSessionCannotBeMoved() throws {
        let h = try Harness.make()
        let running = try startToday(h)
        doASet(running)
        _ = try #require(h.app.finish(running))
        let done = try h.session("2026-09-30")
        #expect(h.app.movableDays(for: done).isEmpty)
        h.app.move(done, to: T.day("2026-10-01"))
        #expect(h.app.schedule.state.moves.isEmpty)
    }

    @Test func aPauseHoldsTheDaysAndEndsOnRequest() throws {
        let h = try Harness.make()
        h.app.pause(until: T.day("2026-10-04"))
        guard case let .paused(until, next) = h.app.todayState else { Issue.record("expected paused"); return }
        #expect(until == T.day("2026-10-04") && next?.day == T.day("2026-10-05"))
        #expect(h.app.currentPause != nil)
        h.app.resumeSchedule()
        #expect(h.app.currentPause == nil)
        guard case .training = h.app.todayState else { Issue.record("expected training again"); return }
    }

    // MARK: The coach

    @Test func theCoachFitsTheDay() throws {
        let h = try Harness.make()
        #expect(h.app.coachEvent(for: h.app.todayState) == .welcome, "the first day of the plan")

        let running = try startToday(h)
        doASet(running)
        _ = try #require(h.app.finish(running))
        #expect(h.app.coachEvent(for: h.app.todayState) == .sessionCompleted)

        h.clock.now = T.date("2026-10-01")
        h.app.becameActive()
        #expect(h.app.coachEvent(for: h.app.todayState) == .restDay)

        // Friday passes without a workout: Saturday's word is gentle, and never about blame.
        h.clock.now = T.date("2026-10-03")
        h.app.becameActive()
        #expect(h.app.coachEvent(for: h.app.todayState) == .missedSession)
        #expect(h.app.progress.stats.streak == 0)
    }

    @Test func comingBackFromAPauseIsNoticed() throws {
        let h = try Harness.make()
        h.app.pause(until: T.day("2026-10-01"))
        h.clock.now = T.date("2026-10-02")
        h.app.becameActive()
        guard case .training = h.app.todayState else { Issue.record("Friday is a training day"); return }
        #expect(h.app.coachEvent(for: h.app.todayState) == .returnAfterPause)
    }

    @Test func theCoachCanBeChangedWithoutTouchingThePlan() throws {
        let h = try Harness.make()
        let before = h.app.todayState
        #expect(h.app.coach.select("max") && h.app.coach.persona.name == "Макс")
        #expect(h.app.todayState == before)
        #expect(try Harness.reopen(h).app.coach.persona.id == "max")
    }

    // MARK: Reminders

    @Test("reminders ask permission once, at the deliberate tap, and then keep the week scheduled")
    func turningRemindersOn() async throws {
        let h = try Harness.make()
        #expect(await h.app.reminders.setEnabled(true))
        #expect(h.scheduler.permissionRequests == 1)
        h.app.scheduleReconcile()
        await h.app.settle()
        #expect(h.scheduler.pending.first?.slot == T.day("2026-09-30"))
        #expect(h.scheduler.pending.first?.fireDate == T.date("2026-09-30", hour: 17))
        _ = await h.app.reminders.setEnabled(true)
        #expect(h.scheduler.permissionRequests == 1)
    }

    @Test func aRefusalLeavesRemindersOffAndSchedulesNothing() async throws {
        let h = try Harness.make()
        h.scheduler.grants = false
        #expect(await h.app.reminders.setEnabled(true) == false)
        #expect(h.app.reminders.settings.isEnabled == false && h.app.reminders.authorization == .denied)
        h.app.scheduleReconcile()
        await h.app.settle()
        #expect(h.scheduler.pending.isEmpty)
    }

    @Test func permissionTakenAwayInSettingsStopsTheReminders() async throws {
        let h = try Harness.make()
        _ = await h.app.reminders.setEnabled(true)
        h.app.scheduleReconcile()
        await h.app.settle()
        #expect(!h.scheduler.pending.isEmpty)
        h.scheduler.status = .denied
        h.app.becameActive()
        await h.app.settle()
        #expect(h.scheduler.pending.isEmpty)
    }

    @Test("what is done, moved or paused changes the waiting reminders with it")
    func remindersFollowThePlan() async throws {
        let h = try Harness.make()
        _ = await h.app.reminders.setEnabled(true)
        h.app.scheduleReconcile()
        await h.app.settle()
        #expect(h.scheduler.pending.map(\.slot.rawValue).prefix(2) == ["2026-09-30", "2026-10-02"])

        let friday = try h.session("2026-10-02")
        h.app.move(friday, to: T.day("2026-10-03"))
        await h.app.settle()
        #expect(h.scheduler.pending.first { $0.slot == T.day("2026-10-02") }?.fireDate == T.date("2026-10-03", hour: 17))

        let running = try startToday(h)
        doASet(running)
        _ = try #require(h.app.finish(running))
        await h.app.settle()
        #expect(h.scheduler.pending.allSatisfy { $0.slot != T.day("2026-09-30") })

        h.app.pause(until: T.day("2026-10-11"))
        await h.app.settle()
        #expect(!h.scheduler.pending.isEmpty)
        #expect(h.scheduler.pending.allSatisfy { $0.slot >= T.day("2026-10-12") }, "only sessions after the pause keep a reminder")
    }

    @Test func personalWordsUseTheCoachsLineWithoutAnythingAboutThePerson() async throws {
        let h = try Harness.make()
        _ = await h.app.reminders.setEnabled(true)
        h.app.reminders.update { $0.usesPersonalText = true }
        h.app.scheduleReconcile()
        await h.app.settle()
        let request = try #require(h.scheduler.pending.first)
        #expect(request.title == "Вера")
        #expect(CoachCatalog.templates(for: .upcomingWorkout, tone: .calm).contains(request.body))
        #expect(!request.body.contains("80") && !request.body.contains("Салават"))
    }

    @Test("a rest alert is armed for the end of the rest and cleared when the rest ends early")
    func restAlert() async throws {
        let h = try Harness.make()
        #expect(await h.app.reminders.setRestAlert(true))
        let running = try startToday(h)
        doASet(running)
        await h.app.settle()
        guard case let .resting(_, until, _) = running.phase else { Issue.record("expected rest"); return }
        #expect(h.scheduler.restAlert == until)
        running.startNextSet()
        await h.app.settle()
        #expect(h.scheduler.restAlert == nil)
    }

    @Test func noRestAlertUnlessAskedFor() async throws {
        let h = try Harness.make()
        let running = try startToday(h)
        doASet(running)
        await h.app.settle()
        #expect(h.scheduler.restAlert == nil && h.scheduler.permissionRequests == 0)
    }

    // MARK: Weight

    @Test func recordingWeightUpdatesTheProfileToo() throws {
        let h = try Harness.make()
        #expect(h.app.recordWeight(79.5))
        #expect(h.app.weights.latest?.kg == 79.5 && h.app.profile?.weight == 79.5)
        #expect(!h.app.recordWeight(10) && !h.app.recordWeight(.nan))
        #expect(h.app.weights.entries.count == 1, "the second weighing of the day replaced the first")
    }

    @Test("a weighing for an earlier day joins the history but leaves the profile's weight alone")
    func aPastWeighingKeepsTheProfileWeight() throws {
        let h = try Harness.make()
        #expect(h.app.recordWeight(79.5))
        #expect(h.app.recordWeight(81, on: h.app.now.addingTimeInterval(-86_400)))
        #expect(h.app.weights.entries.map(\.kg) == [81, 79.5])
        #expect(h.app.profile?.weight == 79.5)
    }

    // MARK: Data

    @Test("the export is one JSON file with everything in it")
    func exportFile() throws {
        let h = try Harness.make()
        let running = try startToday(h)
        doASet(running)
        _ = try #require(h.app.finish(running))
        let url = try h.app.exportFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(ExportBundle.self, from: Data(contentsOf: url))
        #expect(bundle.format == "maestro-felix-export" && bundle.version == 1)
        #expect(bundle.workouts.count == 1 && bundle.workouts[0].entries[0].sets.count == 1)
        #expect(bundle.weights.map(\.kg) == [80] && bundle.profile?.details.weekdays == weekday)
        #expect(bundle.schedule.revisions.count == 1 && bundle.achievements.has(.firstWorkout))
    }

    @Test("erasing everything clears the data and the notifications, then the app starts over")
    func eraseEverything() async throws {
        let h = try Harness.make()
        _ = await h.app.reminders.setEnabled(true)
        let running = try startToday(h)
        doASet(running)
        _ = try #require(h.app.finish(running))
        var restarted = false
        h.app.onErase = { restarted = true }
        await h.app.eraseEverything()
        #expect(restarted && h.scheduler.removedEverything)
        #expect(try h.base.loadProfile() == nil && h.base.loadDraft() == nil)
        #expect(try h.base.load([WorkoutLog].self, key: StoreKey.workoutLogs) == nil)
        #expect(try Harness.reopen(h).app.profile == nil)
    }

    // MARK: History

    @Test func historyShowsPlanNextToWhatWasDone() throws {
        let h = try Harness.make()
        let running = try startToday(h)
        doASet(running)
        _ = try #require(h.app.finish(running))
        let weeks = h.app.historyWeeks()
        #expect(weeks.count == 1 && weeks[0].start == T.day("2026-09-28"))
        #expect(weeks[0].done == 1 && weeks[0].planned == 2 && weeks[0].logs.count == 1)
    }
}
