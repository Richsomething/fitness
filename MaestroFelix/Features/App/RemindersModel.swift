import Foundation
import Observation

/// Reminder settings, the system's permission, and keeping the pending notifications in step with the plan.
@MainActor @Observable
final class RemindersModel {
    private(set) var settings = ReminderSettings()
    private(set) var authorization: NotificationAuthorization = .notDetermined
    var storageError: String?

    @ObservationIgnored private let store: any DocumentStore
    @ObservationIgnored private let scheduler: any NotificationScheduling

    init(store: any DocumentStore, scheduler: any NotificationScheduling) {
        self.store = store
        self.scheduler = scheduler
        do {
            settings = try store.load(ReminderSettings.self, key: StoreKey.reminders) ?? ReminderSettings()
        } catch {
            storageError = "Не удалось прочитать настройки напоминаний."
        }
    }

    func refreshAuthorization() async {
        authorization = await scheduler.authorization()
    }

    /// "Напоминать о тренировках". The system is asked only now, after this deliberate action; if the
    /// answer is no, the switch stays off and `authorization` says why.
    @discardableResult
    func setEnabled(_ on: Bool) async -> Bool {
        if on, !(await ensurePermission()) { return false }
        return update { $0.isEnabled = on }
    }

    /// The bell during rest: the same permission, asked for at that deliberate tap.
    @discardableResult
    func setRestAlert(_ on: Bool) async -> Bool {
        if on, !(await ensurePermission()) { return false }
        return update { $0.restAlertEnabled = on }
    }

    @discardableResult
    func update(_ change: (inout ReminderSettings) -> Void) -> Bool {
        var updated = settings
        change(&updated)
        guard updated != settings else { return true }
        do {
            try store.save(updated, key: StoreKey.reminders)
            settings = updated
            storageError = nil
            return true
        } catch {
            storageError = "Не удалось сохранить настройки напоминаний."
            return false
        }
    }

    /// Makes the pending notifications exactly the ones the plan calls for now.
    func reconcile(slots: [PlannedSlot], startHour: Int, startMinute: Int, texts: ReminderTexts, now: Date,
                   calendar: Calendar = .current) async {
        await refreshAuthorization()
        guard settings.isEnabled, authorization == .allowed else {
            await scheduler.replaceSessionReminders(with: [])
            return
        }
        let sent = await scheduler.deliveredComebackWeeks(calendar: calendar)
        let requests = ReminderPlanner.requests(slots: slots, settings: settings, startHour: startHour, startMinute: startMinute,
                                                now: now, texts: texts, comebackSent: sent, calendar: calendar)
        await scheduler.replaceSessionReminders(with: requests)
    }

    private func ensurePermission() async -> Bool {
        await refreshAuthorization()
        if authorization == .notDetermined {
            _ = await scheduler.requestAuthorization()
            await refreshAuthorization()
        }
        return authorization == .allowed
    }
}
