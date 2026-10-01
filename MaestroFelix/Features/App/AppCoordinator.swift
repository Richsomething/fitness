import Foundation
import Observation

enum AppTab: Hashable {
    case today, plan, progress, profile
}

/// What the person sees when a workout is saved.
struct FinishSummary: Equatable {
    let log: WorkoutLog
    let streak: Int
    let newAchievements: [AchievementID]
    /// Personal bests this workout reached.
    var records: [RecordHit] = []
    /// Volume against the last time the same exercises were done; nil when none were done before.
    var comparison: VolumeComparison?
    let coach: CoachPersona
    let coachLine: String
    let nextSessionText: String?
}

/// The app's state as one: the models for each kind of data, and what happens across them when
/// something changes — a workout is saved, a session moved, the profile edited. Views ask it for
/// what to show and tell it what the person did.
@MainActor @Observable
final class AppCoordinator {
    let onboarding: OnboardingModel
    let workouts: WorkoutModel
    let schedule: ScheduleModel
    let weights: WeightModel
    let coach: CoachModel
    let reminders: RemindersModel
    let progress: ProgressModel
    let adaptiveTraining: AdaptiveTrainingModel

    var activeSession: WorkoutSession?
    var selectedTab: AppTab = .today
    var dataError: String?
    private(set) var today: DayKey
    /// Called after everything was erased, so the app can start over.
    @ObservationIgnored var onErase: (() -> Void)?

    @ObservationIgnored private let store: any DocumentStore
    @ObservationIgnored private let scheduler: any NotificationScheduling
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var reminderTask: Task<Void, Never>?
    @ObservationIgnored private var restAlertTask: Task<Void, Never>?

    init(store: any DocumentStore, onboarding: OnboardingModel, scheduler: any NotificationScheduling,
         calendar: Calendar = .current, clock: @escaping () -> Date = { .now }) {
        self.store = store
        self.onboarding = onboarding
        self.scheduler = scheduler
        self.calendar = calendar
        self.clock = clock
        adaptiveTraining = AdaptiveTrainingModel(store: store)
        workouts = WorkoutModel(store: store)
        schedule = ScheduleModel(store: store, calendar: calendar)
        weights = WeightModel(store: store, calendar: calendar)
        coach = CoachModel(store: store)
        reminders = RemindersModel(store: store, scheduler: scheduler)
        progress = ProgressModel(store: store)
        today = DayKey(clock(), calendar: calendar)
        onboarding.onProfileSaved = { [weak self] profile in self?.profileSaved(profile) }
        ensureScheduleAndWeight()
        refreshStats()
    }

    var now: Date { clock() }
    var profile: OnboardingDraft? { onboarding.profile?.details }

    /// Waits for reminder and rest-alert work in flight; tests use it to see the outcome.
    func settle() async {
        await reminderTask?.value
        await restAlertTask?.value
    }

    // MARK: Plan

    func slots(from: DayKey, through: DayKey) -> [PlannedSlot] {
        SchedulePlanner.slots(state: schedule.state, logs: workouts.logs, from: from, through: through, today: today, calendar: calendar)
    }

    func sessions(from: DayKey, through: DayKey) -> [PlannedSession] {
        guard let profile else { return [] }
        let base = SchedulePlanner.sessions(profile: profile, state: schedule.state,
                                            logs: adaptiveTraining.state.route == nil ? workouts.logs : [],
                                            from: from, through: through, today: today, calendar: calendar)
        // Completion state still comes from the real history; adapting a plan must not reopen a finished slot.
        let actual = slots(from: from, through: through)
        return base.map { session in
            let slot = actual.first { $0.slot == session.key } ?? session.slot
            guard slot.status == .planned, slot.day >= today else { return PlannedSession(slot: slot, plan: session.plan) }
            let plan = AdaptiveTraining.plan(session.plan, state: adaptiveTraining.state, logs: workouts.logs,
                                             now: now, calendar: calendar, profile: profile)
            return PlannedSession(slot: slot, plan: plan)
        }
    }

    /// The seven days around `day`, Monday first, with their sessions.
    func week(of day: DayKey) -> (days: [DayKey], sessions: [PlannedSession]) {
        let days = day.weekDays(calendar: calendar)
        return (days, sessions(from: days[0], through: days[6]))
    }

    var todayState: TodayState {
        let upcoming = sessions(from: today, through: today.adding(days: SchedulePlanner.moveHorizonDays, calendar: calendar))
        return TodayResolver.resolve(sessions: upcoming, state: schedule.state, logs: workouts.logs, today: today, calendar: calendar)
    }

    /// A planned session found by its slot, wherever it now falls; nil when the slot no longer holds one.
    func session(forSlot slot: DayKey) -> PlannedSession? {
        let day = schedule.state.day(of: slot)
        return sessions(from: day, through: day).first { $0.key == slot }
    }

    /// The days a session can move to.
    func movableDays(for session: PlannedSession) -> [DayKey] {
        let horizon = today.adding(days: SchedulePlanner.moveHorizonDays, calendar: calendar)
        return SchedulePlanner.movableDays(for: session.slot, among: slots(from: today, through: horizon), today: today,
                                           calendar: calendar)
    }

    func historyWeeks() -> [HistoryWeek] {
        let firstPlan = schedule.state.revisions.first?.from ?? today
        let firstLog = workouts.logs.map { $0.day(calendar: calendar) }.min() ?? today
        // Through the end of this week, so the current week shows what it calls for in full.
        let all = slots(from: min(firstPlan, firstLog), through: today.weekDays(calendar: calendar)[6])
        return HistoryBuilder.weeks(logs: workouts.logs, slots: all, calendar: calendar)
    }

    /// The best working set of the last time an exercise was done, as a short line; nil for a new exercise.
    func lastTimeText(for exerciseID: String) -> String? {
        guard let sets = workouts.lastSets(for: [exerciseID])[exerciseID] else { return nil }
        let top = sets.filter { $0.kind != .warmup }.max { ($0.weightKg ?? 0, $0.reps ?? 0) < ($1.weightKg ?? 0, $1.reps ?? 0) }
        return top?.summary
    }

    // MARK: Coach

    /// The coach's words for an event, chosen by the day (or by the workout count for a finished workout).
    func coachLine(for event: CoachEvent) -> String {
        let index = CoachEvent.allCases.firstIndex(of: event) ?? 0
        let seed = event == .sessionCompleted ? workouts.logs.count : today.ordinal(calendar: calendar) + index
        return coach.line(for: event, context: CoachContext(name: profile?.name, nextDay: nextSessionPhrase()), seed: seed)
    }

    func coachEvent(for state: TodayState) -> CoachEvent {
        let recentMiss = slots(from: today.adding(days: -2, calendar: calendar), through: today.adding(days: -1, calendar: calendar))
            .contains { $0.status == .missed }
        let justResumed = schedule.state.pauses.contains { $0.until == today.adding(days: -1, calendar: calendar) }
        switch state {
        case .trainingDone: return .sessionCompleted
        case .skipped: return .missedSession
        case .paused: return .restDay
        case .training:
            if workouts.logs.isEmpty, schedule.state.revisions.first?.from == today { return .welcome }
            if justResumed { return .returnAfterPause }
            return recentMiss ? .missedSession : .upcomingWorkout
        case .rest:
            if justResumed { return .returnAfterPause }
            return recentMiss ? .missedSession : .restDay
        }
    }

    private func nextSessionPhrase() -> String? {
        let upcoming = slots(from: today, through: today.adding(days: SchedulePlanner.moveHorizonDays, calendar: calendar))
        guard let next = upcoming.first(where: { $0.day > today && $0.status == .planned }) else { return nil }
        return TrainingCalendar.dayPhrase(next.day, today: today, calendar: calendar)
    }

    // MARK: Workout

    func start(_ plan: WorkoutPlan, slot: DayKey?) {
        guard activeSession == nil else { return }
        // A workout already begun for this session goes on; it is not thrown away by a second start.
        if let slot, workouts.resumable?.slot == slot {
            resume()
            return
        }
        let session = workouts.makeSession(plan: plan, slot: slot, startedAt: now)
        attach(session)
        activeSession = session
    }

    /// Goes on with the workout that was under way when the app went away.
    func resume() {
        guard activeSession == nil, let session = workouts.restore() else { return }
        attach(session)
        activeSession = session
    }

    /// Removes a finished workout. The session it closed is open again; streak and week are counted anew.
    @discardableResult
    func deleteWorkout(_ log: WorkoutLog) -> Bool {
        guard workouts.delete(log.id) else { return false }
        scheduleChanged()
        return true
    }

    /// Drops the unfinished workout without saving it.
    func discardResumable() {
        workouts.discardSnapshot()
        cancelRestAlert()
    }

    /// Saves the workout and works out what it changed. Nil when storage fails; the session stays open.
    func finish(_ session: WorkoutSession) -> FinishSummary? {
        let log = session.log(finishedAt: now)
        guard workouts.save(log) else { return nil }
        session.onChange = nil
        workouts.discardSnapshot()
        cancelRestAlert()
        refreshStats()
        let unlocked = progress.unlock(at: now)
        scheduleReconcile()
        return FinishSummary(log: log, streak: progress.stats.streak, newAchievements: unlocked,
                             records: PersonalRecords.hits(in: log, before: workouts.logs),
                             comparison: PersonalRecords.volumeComparison(in: log, before: workouts.logs),
                             coach: coach.persona, coachLine: coachLine(for: .sessionCompleted), nextSessionText: nextSessionPhrase())
    }

    /// Leaves the workout without saving.
    func cancel(_ session: WorkoutSession) {
        session.onChange = nil
        workouts.discardSnapshot()
        cancelRestAlert()
        activeSession = nil
    }

    private func attach(_ session: WorkoutSession) {
        session.onChange = { [weak self, weak session] in
            guard let self, let session else { return }
            self.sessionChanged(session)
        }
        sessionChanged(session)
    }

    /// Arms or clears the rest alert after the setting changed in the middle of a rest.
    func syncRestAlert(for session: WorkoutSession) { sessionChanged(session) }

    private func sessionChanged(_ session: WorkoutSession) {
        workouts.persist(session)
        let deadline: Date? = if case let .resting(_, until, _) = session.phase { until } else { nil }
        chainRestAlert(deadline: reminders.settings.restAlertEnabled ? deadline : nil)
    }

    private func cancelRestAlert() { chainRestAlert(deadline: nil) }

    /// One rest alert at a time, in the order asked for.
    private func chainRestAlert(deadline: Date?) {
        let previous = restAlertTask
        restAlertTask = Task { [scheduler] in
            await previous?.value
            if let deadline { await scheduler.scheduleRestEnd(at: deadline) } else { await scheduler.cancelRestEnd() }
        }
    }

    // MARK: Changing the schedule

    func skip(_ slot: DayKey) { if schedule.skip(slot) { scheduleChanged() } }

    func unskip(_ slot: DayKey) { if schedule.unskip(slot) { scheduleChanged() } }

    func move(_ session: PlannedSession, to day: DayKey) {
        guard movableDays(for: session).contains(day) else { return }
        if schedule.move(session.key, to: day) { scheduleChanged() }
    }

    func pause(until day: DayKey) { if schedule.pause(from: today, until: day) { scheduleChanged() } }

    func resumeSchedule() { if schedule.resume(on: today) { scheduleChanged() } }

    var currentPause: SchedulePause? { schedule.state.pause(covering: today) }

    // MARK: Swapping an exercise

    /// Exercises that can take the place of one in a session.
    func alternatives(for exerciseID: String, in session: PlannedSession) -> [Exercise] {
        ExerciseSwaps.alternatives(for: exerciseID, in: session.plan, limitations: (profile?.limitations ?? []).map(\.zone))
    }

    /// The planner's exercise behind what the session shows now, when the person swapped it.
    func originalExercise(of shownID: String, in session: PlannedSession) -> String? {
        schedule.state.swaps[session.key.rawValue]?.first { $0.value == shownID }?.key
    }

    /// Puts `replacement` where the session shows `shownID`; choosing the planner's own exercise puts it back.
    func swapExercise(_ shownID: String, with replacement: String, in session: PlannedSession) {
        guard session.status == .planned else { return }
        let original = originalExercise(of: shownID, in: session) ?? shownID
        let saved = replacement == original
            ? schedule.restore(original, in: session.key)
            : schedule.swap(original, to: replacement, in: session.key)
        if saved { scheduleChanged() }
    }

    private func scheduleChanged() {
        refreshStats()
        scheduleReconcile()
    }

    // MARK: Profile and weight

    private func profileSaved(_ saved: LocalProfile) {
        let doneToday = workouts.logs.contains { $0.kind == .strength && $0.day(calendar: calendar) == today }
        schedule.apply(weekdays: saved.details.weekdays, today: today, todaysSessionDone: doneToday)
        seedWeight(from: saved.details)
        scheduleChanged()
    }

    /// A schedule and a first weighing for a profile that had none, as after an update.
    private func ensureScheduleAndWeight() {
        guard let profile else { return }
        if !schedule.hasSchedule { schedule.apply(weekdays: profile.weekdays, today: today, todaysSessionDone: false) }
        if weights.entries.isEmpty { seedWeight(from: profile) }
    }

    /// The profile's weight joins the weighings when it differs from the latest one.
    private func seedWeight(from details: OnboardingDraft) {
        guard let kg = details.weight, weights.latest?.kg != kg else { return }
        weights.add(kg, on: now)
    }

    /// Records a weighing for `date` (today when not given). The profile's weight follows only when this is the latest
    /// weighing, so adding a forgotten earlier one does not roll the profile back.
    @discardableResult
    func recordWeight(_ kg: Double, on date: Date? = nil) -> Bool {
        let day = date ?? now
        guard weights.add(kg, on: day) else { return false }
        if let latest = weights.latest, calendar.isDate(latest.date, inSameDayAs: day) { onboarding.applyWeight(kg) }
        return true
    }

    // MARK: Foreground

    func becameActive() {
        today = DayKey(now, calendar: calendar)
        refreshStats()
        scheduleReconcile()
    }

    func refreshStats() {
        progress.update(ProgressCalculator.stats(state: schedule.state, logs: workouts.logs, today: today, calendar: calendar))
    }

    // MARK: Reminders

    func scheduleReconcile() {
        let previous = reminderTask
        reminderTask = Task { [weak self] in
            await previous?.value
            await self?.reconcileReminders()
        }
    }

    private func reconcileReminders() async {
        guard let profile else { return }
        let horizon = today.adding(days: ReminderPlanner.horizonDays + 1, calendar: calendar)
        let texts = ReminderTexts(coachName: coach.persona.name, upcoming: coachLine(for: .upcomingWorkout),
                                  missed: coachLine(for: .missedSession))
        await reminders.reconcile(slots: slots(from: today, through: horizon), startHour: profile.startHour,
                                  startMinute: profile.startMinute, texts: texts, now: now, calendar: calendar)
    }

    // MARK: Data

    /// The person's data as a JSON file in the temporary folder, ready to share.
    func exportFile() throws -> URL {
        let bundle = ExportBundle(exportedAt: now, profile: onboarding.profile, workouts: workouts.logs, weights: weights.entries,
                                  schedule: schedule.state, achievements: progress.achievements, coach: coach.state,
                                  reminders: reminders.settings, adaptiveTraining: adaptiveTraining.state)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("maestro-felix-\(today.rawValue).json")
        try bundle.jsonData().write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Everything: stored data, drafts, pending and delivered notifications. Then the app starts over.
    func eraseEverything() async {
        do {
            try store.removeAll()
        } catch {
            dataError = "Не удалось удалить данные. Ничего не изменилось."
            return
        }
        reminderTask?.cancel()
        await scheduler.removeEverything()
        dataError = nil
        onErase?()
    }
}
