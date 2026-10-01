import Foundation
import Testing
@testable import MaestroFelix

enum InjectedFailure: Error {
    case injected
}

/// A system notification centre that remembers what it was asked and answers like a real one: the
/// first request for permission is the only time it is granted or refused.
@MainActor
final class FakeScheduler: NotificationScheduling {
    var status = NotificationAuthorization.notDetermined
    /// What the person answers when asked.
    var grants = true
    var deliveredWeeks: Set<String> = []
    private(set) var permissionRequests = 0
    private(set) var pending: [ReminderRequest] = []
    private(set) var restAlert: Date?
    private(set) var removedEverything = false

    func authorization() async -> NotificationAuthorization { status }

    func requestAuthorization() async -> Bool {
        permissionRequests += 1
        status = grants ? .allowed : .denied
        return grants
    }

    func replaceSessionReminders(with requests: [ReminderRequest]) async { pending = requests }

    func deliveredComebackWeeks(calendar: Calendar) async -> Set<String> { deliveredWeeks }

    func scheduleRestEnd(at date: Date) async { restAlert = date }

    func cancelRestEnd() async { restAlert = nil }

    func removeEverything() async {
        pending = []
        restAlert = nil
        removedEverything = true
    }
}

/// A store that can be told to fail on certain keys, to see how the app carries on.
@MainActor
final class FlakyStore: DocumentStore {
    let base: SwiftDataProfileRepository
    var failingSaves: Set<String> = []
    var failingLoads: Set<String> = []

    init(base: SwiftDataProfileRepository) { self.base = base }

    func load<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        if failingLoads.contains(key) { throw InjectedFailure.injected }
        return try base.load(type, key: key)
    }

    func save<T: Encodable>(_ value: T, key: String) throws {
        if failingSaves.contains(key) { throw InjectedFailure.injected }
        try base.save(value, key: key)
    }

    func remove(key: String) throws { try base.remove(key: key) }

    func removeAll() throws { try base.removeAll() }
}

/// A clock the test moves by hand.
final class TestClock: @unchecked Sendable {
    var now: Date

    init(_ now: Date) { self.now = now }
}

/// The whole app in memory: a signed-up profile, a fake notification centre, a clock that stands on
/// Wednesday 2026-09-30 at noon unless told otherwise.
@MainActor
struct Harness {
    let base: SwiftDataProfileRepository
    let store: FlakyStore
    let scheduler: FakeScheduler
    let clock: TestClock
    let app: AppCoordinator

    var now: Date { clock.now }

    static func make(profile: OnboardingDraft? = T.profile(), now: Date = T.date("2026-09-30")) throws -> Harness {
        let base = try SwiftDataProfileRepository.inMemory()
        if let profile { _ = try base.complete(profile, existing: nil) }
        return try assemble(base: base, now: now)
    }

    /// Opens the same data again, as after the app was closed and started.
    static func reopen(_ old: Harness, now: Date? = nil) throws -> Harness {
        try assemble(base: old.base, now: now ?? old.now)
    }

    private static func assemble(base: SwiftDataProfileRepository, now: Date) throws -> Harness {
        let store = FlakyStore(base: base)
        let scheduler = FakeScheduler()
        let clock = TestClock(now)
        let onboarding = try OnboardingModel(repository: base)
        let app = AppCoordinator(store: store, onboarding: onboarding, scheduler: scheduler, calendar: T.calendar,
                                 clock: { clock.now })
        return Harness(base: base, store: store, scheduler: scheduler, clock: clock, app: app)
    }

    /// A planned session of the day, found by its slot.
    func session(_ slot: String) throws -> PlannedSession {
        try #require(app.session(forSlot: T.day(slot)))
    }
}
