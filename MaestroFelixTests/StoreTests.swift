import Foundation
import Testing
@testable import MaestroFelix

@MainActor
struct StoreTests {
    @Test func documentsRoundTripAndAreOverwritten() throws {
        let store = try SwiftDataProfileRepository.inMemory()
        #expect(try store.load([WeightEntry].self, key: StoreKey.weights) == nil)
        let first = [WeightEntry(date: T.date("2026-09-28"), kg: 80)]
        try store.save(first, key: StoreKey.weights)
        #expect(try store.load([WeightEntry].self, key: StoreKey.weights) == first)
        let second = first + [WeightEntry(date: T.date("2026-09-29"), kg: 79)]
        try store.save(second, key: StoreKey.weights)
        #expect(try store.load([WeightEntry].self, key: StoreKey.weights) == second)
    }

    @Test func removingOneKeyLeavesTheOthers() throws {
        let store = try SwiftDataProfileRepository.inMemory()
        try store.save(CoachState(), key: StoreKey.coach)
        try store.save(ReminderSettings(), key: StoreKey.reminders)
        try store.remove(key: StoreKey.coach)
        #expect(try store.load(CoachState.self, key: StoreKey.coach) == nil)
        #expect(try store.load(ReminderSettings.self, key: StoreKey.reminders) != nil)
        try store.remove(key: "never-written")
    }

    @Test func removeAllEmptiesEverything() throws {
        let store = try SwiftDataProfileRepository.inMemory()
        _ = try store.complete(T.profile(), existing: nil)
        try store.save(ScheduleState(), key: StoreKey.schedule)
        try store.removeAll()
        #expect(try store.loadProfile() == nil && store.loadDraft() == nil)
        #expect(try store.load(ScheduleState.self, key: StoreKey.schedule) == nil)
    }

    @Test("a document of the wrong shape throws instead of reading as empty")
    func wrongShapeThrows() throws {
        let store = try SwiftDataProfileRepository.inMemory()
        try store.save("not a list of weighings", key: StoreKey.weights)
        #expect(throws: DecodingError.self) { try store.load([WeightEntry].self, key: StoreKey.weights) }
    }

    @Test func theDraftBecomesTheProfileOnCompletion() throws {
        let store = try SwiftDataProfileRepository.inMemory()
        var draft = T.profile()
        draft.name = "Аня"
        try store.saveDraft(draft)
        #expect(try store.loadDraft()?.name == "Аня" && store.loadProfile() == nil)
        let profile = try store.complete(draft, existing: nil)
        #expect(try store.loadDraft() == nil && store.loadProfile()?.id == profile.id)
        let later = try store.complete(draft, existing: profile)
        #expect(later.id == profile.id && later.createdAt == profile.createdAt)
    }

    @Test func twoStoresInMemoryAreSeparate() throws {
        let one = try SwiftDataProfileRepository.inMemory()
        let two = try SwiftDataProfileRepository.inMemory()
        try one.save(CoachState(), key: StoreKey.coach)
        #expect(try two.load(CoachState.self, key: StoreKey.coach) == nil)
    }
}

@MainActor
struct SmallModelTests {
    // MARK: Weight

    @Test func weightRefusesWhatTheProfileRefuses() throws {
        let h = try Harness.make(profile: nil)
        let model = WeightModel(store: h.store, calendar: T.calendar)
        #expect(!model.add(10) && !model.add(500) && !model.add(.nan) && !model.add(.infinity))
        #expect(model.add(80, on: T.date("2026-09-28")) && model.add(79, on: T.date("2026-09-28", hour: 20)))
        #expect(model.entries.map(\.kg) == [79], "the later weighing of the day replaced the earlier")
        #expect(model.change == nil)
        #expect(model.add(78, on: T.date("2026-09-30")) && model.change == -1)
    }

    @Test func aFailedWeightSaveChangesNothing() throws {
        let h = try Harness.make(profile: nil)
        let model = WeightModel(store: h.store, calendar: T.calendar)
        model.add(80)
        h.store.failingSaves = [StoreKey.weights]
        #expect(!model.add(70, on: T.date("2026-10-05")))
        #expect(model.entries.map(\.kg) == [80] && model.storageError != nil)
    }

    // MARK: Coach

    @Test func theChosenCoachIsRemembered() throws {
        let h = try Harness.make(profile: nil)
        let model = CoachModel(store: h.store)
        #expect(model.persona.id == "vera")
        #expect(model.select("yan") && CoachModel(store: h.store).persona.id == "yan")
        #expect(model.select("nobody") && model.persona.id == "vera", "an unknown coach falls back to the first")
    }

    @Test func aFailedCoachSaveKeepsTheOldCoach() throws {
        let h = try Harness.make(profile: nil)
        let model = CoachModel(store: h.store)
        h.store.failingSaves = [StoreKey.coach]
        #expect(!model.select("max") && model.persona.id == "vera" && model.storageError != nil)
    }

    // MARK: Achievements

    @Test("an unlocked achievement stays unlocked across reopening, and is not offered again")
    func achievementsPersist() throws {
        let h = try Harness.make(profile: nil)
        let model = ProgressModel(store: h.store)
        var stats = TrainingStats()
        stats.workouts = 1
        model.update(stats)
        #expect(model.unlock(at: T.date("2026-09-30")) == [.firstWorkout])
        #expect(model.unlock(at: T.date("2026-10-01")).isEmpty)
        let reopened = ProgressModel(store: h.store)
        #expect(reopened.achievements.has(.firstWorkout))
        reopened.update(stats)
        #expect(reopened.unlock(at: T.date("2026-10-02")).isEmpty)
    }

    @Test func anAchievementThatCouldNotBeSavedIsNotMarkedAsGiven() throws {
        let h = try Harness.make(profile: nil)
        let model = ProgressModel(store: h.store)
        var stats = TrainingStats()
        stats.workouts = 1
        model.update(stats)
        h.store.failingSaves = [StoreKey.achievements]
        #expect(model.unlock(at: T.date("2026-09-30")).isEmpty && !model.achievements.has(.firstWorkout))
        h.store.failingSaves = []
        #expect(model.unlock(at: T.date("2026-09-30")) == [.firstWorkout], "it is given when saving works again")
    }

    // MARK: Schedule

    @Test func aFailedScheduleSaveKeepsTheOldSchedule() throws {
        let h = try Harness.make(profile: nil)
        let model = ScheduleModel(store: h.store, calendar: T.calendar)
        model.apply(weekdays: [1, 3, 5], today: T.day("2026-09-30"), todaysSessionDone: false)
        h.store.failingSaves = [StoreKey.schedule]
        #expect(!model.skip(T.day("2026-10-02")))
        #expect(model.state.skipped.isEmpty && model.storageError != nil)
    }

    @Test func theScheduleSurvivesReopening() throws {
        let h = try Harness.make(profile: nil)
        let model = ScheduleModel(store: h.store, calendar: T.calendar)
        model.apply(weekdays: [2, 4], today: T.day("2026-09-30"), todaysSessionDone: true)
        model.pause(from: T.day("2026-10-05"), until: T.day("2026-10-06"))
        let reopened = ScheduleModel(store: h.store, calendar: T.calendar)
        #expect(reopened.state == model.state)
        #expect(reopened.state.revisions.first?.from == T.day("2026-10-01"), "a session done today starts the change tomorrow")
    }

    // MARK: Reminders

    @Test func reminderSettingsPersistAndAFailedSaveChangesNothing() throws {
        let h = try Harness.make(profile: nil)
        let model = RemindersModel(store: h.store, scheduler: FakeScheduler())
        #expect(model.update { $0.leadMinutes = 30 })
        #expect(RemindersModel(store: h.store, scheduler: FakeScheduler()).settings.leadMinutes == 30)
        h.store.failingSaves = [StoreKey.reminders]
        #expect(!model.update { $0.leadMinutes = 120 })
        #expect(model.settings.leadMinutes == 30 && model.storageError != nil)
    }
}
