import Foundation
import os
import UserNotifications

enum NotificationAuthorization: Equatable {
    case notDetermined, denied, allowed
}

enum RestAlert {
    static let identifier = "rest.end"
}

/// What the app asks of the system's notifications. A protocol, so the planning around it can be
/// tested without a device.
@MainActor
protocol NotificationScheduling {
    func authorization() async -> NotificationAuthorization
    /// Asks the system and says whether notifications are now allowed.
    func requestAuthorization() async -> Bool
    /// Makes the pending session reminders exactly `requests`.
    func replaceSessionReminders(with requests: [ReminderRequest]) async
    /// Weeks (by their Monday) that already had a comeback note delivered and still on the shelf.
    func deliveredComebackWeeks(calendar: Calendar) async -> Set<String>
    func scheduleRestEnd(at date: Date) async
    func cancelRestEnd() async
    /// Every pending and delivered notification of the app.
    func removeEverything() async
}

@MainActor
final class SystemNotificationScheduler: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()
    // Only the kind of operation and the system's error code: no times, texts or names.
    private let log = Logger(subsystem: "com.maestrofelix.app", category: "notifications")

    func authorization() async -> NotificationAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorized, .provisional, .ephemeral: .allowed
        case .denied: .denied
        @unknown default: .denied
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            log.error("authorization request failed: \((error as NSError).code)")
            return false
        }
    }

    func replaceSessionReminders(with requests: [ReminderRequest]) async {
        let wanted = Set(requests.map(\.id))
        let stale = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix("session.") && !wanted.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for request in requests {
            do {
                try await center.add(notification(for: request))
            } catch {
                log.error("scheduling a reminder failed: \((error as NSError).code)")
            }
        }
    }

    func deliveredComebackWeeks(calendar: Calendar) async -> Set<String> {
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
        // "session.2026-10-02.comeback" → the slot in the middle.
        let slots = delivered.filter { $0.hasPrefix("session.") && $0.hasSuffix(".comeback") }
            .compactMap { DayKey(rawValue: String($0.dropFirst("session.".count).dropLast(".comeback".count))) }
        return Set(slots.map { $0.weekStart(calendar: calendar).rawValue })
    }

    func scheduleRestEnd(at date: Date) async {
        center.removePendingNotificationRequests(withIdentifiers: [RestAlert.identifier])
        let seconds = date.timeIntervalSinceNow
        guard seconds > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Отдых закончился"
        content.body = "Пора на следующий подход."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: RestAlert.identifier, content: content, trigger: trigger))
        } catch {
            log.error("scheduling the rest alert failed: \((error as NSError).code)")
        }
    }

    func cancelRestEnd() async {
        center.removePendingNotificationRequests(withIdentifiers: [RestAlert.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [RestAlert.identifier])
    }

    func removeEverything() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func notification(for request: ReminderRequest) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.threadIdentifier = "sessions"
        content.userInfo = ["slot": request.slot.rawValue]
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireDate)
        return UNNotificationRequest(identifier: request.id, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
    }
}
