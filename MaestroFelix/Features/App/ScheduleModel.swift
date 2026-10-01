import Foundation
import Observation

/// The schedule as the person shaped it: the days in force over time, moves, skips and pauses.
@MainActor @Observable
final class ScheduleModel {
    private(set) var state = ScheduleState()
    var storageError: String?

    @ObservationIgnored private let store: any DocumentStore
    @ObservationIgnored let calendar: Calendar

    init(store: any DocumentStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        do {
            state = try store.load(ScheduleState.self, key: StoreKey.schedule) ?? ScheduleState()
        } catch {
            storageError = "Не удалось прочитать расписание."
        }
    }

    var hasSchedule: Bool { !state.revisions.isEmpty }

    /// Notes the training days now in force: from today on, or from tomorrow when today's session is
    /// already done. The past keeps the days it had.
    func apply(weekdays: Set<Int>, today: DayKey, todaysSessionDone: Bool) {
        let from = todaysSessionDone ? today.adding(days: 1, calendar: calendar) : today
        commit { $0.record(weekdays: weekdays, from: from) }
    }

    @discardableResult
    func move(_ slot: DayKey, to day: DayKey) -> Bool { commit { $0.move(slot, to: day) } }

    @discardableResult
    func skip(_ slot: DayKey) -> Bool { commit { $0.skip(slot) } }

    @discardableResult
    func unskip(_ slot: DayKey) -> Bool { commit { $0.unskip(slot) } }

    @discardableResult
    func swap(_ exerciseID: String, to replacement: String, in slot: DayKey) -> Bool {
        commit { $0.swap(exerciseID, to: replacement, in: slot) }
    }

    @discardableResult
    func restore(_ exerciseID: String, in slot: DayKey) -> Bool { commit { $0.restore(exerciseID, in: slot) } }

    @discardableResult
    func pause(from: DayKey, until: DayKey) -> Bool { commit { $0.pause(from: from, until: until) } }

    @discardableResult
    func resume(on day: DayKey) -> Bool { commit { $0.resume(on: day, calendar: calendar) } }

    @discardableResult
    private func commit(_ change: (inout ScheduleState) -> Void) -> Bool {
        var updated = state
        change(&updated)
        guard updated != state else { return true }
        do {
            try store.save(updated, key: StoreKey.schedule)
            state = updated
            storageError = nil
            return true
        } catch {
            storageError = "Не удалось сохранить расписание. Попробуй ещё раз."
            return false
        }
    }
}
