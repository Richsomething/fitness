import Foundation

/// What the person chose for reminders. All of it is off until they turn reminders on.
struct ReminderSettings: Codable, Equatable {
    var isEnabled = false
    /// Minutes before the session; 0 means at its start.
    var leadMinutes = 60
    /// Quiet hours as minutes since midnight. A reminder that would land in them is skipped, not delayed.
    var quietStart = 22 * 60
    var quietEnd = 8 * 60
    /// The coach's own words in the notification instead of a neutral sentence.
    var usesPersonalText = false
    /// One gentle note the morning after a missed session, at most one a week.
    var comebackEnabled = false
    /// A notification when the rest between sets ends and the app is not on screen.
    var restAlertEnabled = false

    static let leadOptions = [0, 30, 60, 120]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fresh = ReminderSettings()
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? fresh.isEnabled
        leadMinutes = try container.decodeIfPresent(Int.self, forKey: .leadMinutes) ?? fresh.leadMinutes
        quietStart = try container.decodeIfPresent(Int.self, forKey: .quietStart) ?? fresh.quietStart
        quietEnd = try container.decodeIfPresent(Int.self, forKey: .quietEnd) ?? fresh.quietEnd
        usesPersonalText = try container.decodeIfPresent(Bool.self, forKey: .usesPersonalText) ?? fresh.usesPersonalText
        comebackEnabled = try container.decodeIfPresent(Bool.self, forKey: .comebackEnabled) ?? fresh.comebackEnabled
        restAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .restAlertEnabled) ?? fresh.restAlertEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, leadMinutes, quietStart, quietEnd, usesPersonalText, comebackEnabled, restAlertEnabled
    }

    func isQuiet(_ date: Date, calendar: Calendar = .current) -> Bool {
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        if quietStart == quietEnd { return false }
        if quietStart < quietEnd { return minutes >= quietStart && minutes < quietEnd }
        return minutes >= quietStart || minutes < quietEnd
    }

    /// "За час", "За 30 минут", "В момент начала".
    static func leadText(_ minutes: Int) -> String {
        switch minutes {
        case 0: "В момент начала"
        case 30: "За 30 минут"
        case 60: "За час"
        case 120: "За 2 часа"
        default: "За \(minutes) мин"
        }
    }
}

struct ReminderRequest: Equatable, Identifiable {
    enum Kind: String { case lead, comeback }

    let slot: DayKey
    let kind: Kind
    let fireDate: Date
    let title: String
    let body: String

    var id: String { Self.identifier(slot: slot, kind: kind) }

    /// A request is named by its slot and kind, so a move, a completion or a switch-off finds it again.
    static func identifier(slot: DayKey, kind: Kind) -> String { "session.\(slot.rawValue).\(kind.rawValue)" }
}

/// The words a notification may use. Never the weight, the goal or the limitations: these can show
/// on a locked screen.
struct ReminderTexts: Equatable {
    var coachName: String?
    var upcoming: String?
    var missed: String?

    static let neutralTitle = "Maestro Felix"
}

enum ReminderPlanner {
    /// How far ahead requests are made, and the most kept at once; iOS holds 64 per app.
    static let horizonDays = 14
    static let maxRequests = 20
    static let comebackHour = 10

    /// The notifications that should be waiting: one per upcoming planned session, `leadMinutes`
    /// before it, and — if asked — one note the morning after the first open session of a week.
    /// `comebackSent` holds the week starts that already had one delivered.
    static func requests(slots: [PlannedSlot], settings: ReminderSettings, startHour: Int, startMinute: Int, now: Date,
                         texts: ReminderTexts, comebackSent: Set<String> = [], calendar: Calendar = .current) -> [ReminderRequest] {
        guard settings.isEnabled else { return [] }
        let today = DayKey(now, calendar: calendar)
        let last = today.adding(days: horizonDays, calendar: calendar)
        let upcoming = slots.filter { $0.status == .planned && $0.day >= today && $0.day <= last }
        var found: [ReminderRequest] = []
        for slot in upcoming {
            let start = slot.day.at(hour: startHour, minute: startMinute, calendar: calendar)
            let fire = start.addingTimeInterval(-Double(settings.leadMinutes) * 60)
            guard fire > now, !settings.isQuiet(fire, calendar: calendar) else { continue }
            found.append(lead(slot.slot, fire: fire, settings: settings, texts: texts))
        }
        if settings.comebackEnabled {
            found += comebacks(upcoming, settings: settings, now: now, texts: texts, sent: comebackSent, calendar: calendar)
        }
        return Array(found.sorted { $0.fireDate < $1.fireDate }.prefix(maxRequests))
    }

    private static func lead(_ slot: DayKey, fire: Date, settings: ReminderSettings, texts: ReminderTexts) -> ReminderRequest {
        if settings.usesPersonalText, let body = texts.upcoming {
            return ReminderRequest(slot: slot, kind: .lead, fireDate: fire, title: texts.coachName ?? ReminderTexts.neutralTitle, body: body)
        }
        let body: String
        switch settings.leadMinutes {
        case 0: body = "Пора на тренировку."
        case 60: body = "Тренировка через час."
        case 120: body = "Тренировка через 2 часа."
        default: body = "Тренировка через \(settings.leadMinutes) минут."
        }
        return ReminderRequest(slot: slot, kind: .lead, fireDate: fire, title: ReminderTexts.neutralTitle, body: body)
    }

    /// For each week, the earliest session still open gets a note the next morning; it goes away with
    /// the session when it is done, and the next open one of the week takes over.
    private static func comebacks(_ upcoming: [PlannedSlot], settings: ReminderSettings, now: Date, texts: ReminderTexts,
                                  sent: Set<String>, calendar: Calendar) -> [ReminderRequest] {
        let byWeek = Dictionary(grouping: upcoming) { $0.day.weekStart(calendar: calendar) }
        return byWeek.compactMap { week, slots -> ReminderRequest? in
            guard !sent.contains(week.rawValue), let first = slots.min(by: { $0.day < $1.day }) else { return nil }
            let fire = first.day.adding(days: 1, calendar: calendar).at(hour: comebackHour, minute: 0, calendar: calendar)
            guard fire > now, !settings.isQuiet(fire, calendar: calendar) else { return nil }
            if settings.usesPersonalText, let body = texts.missed {
                return ReminderRequest(slot: first.slot, kind: .comeback, fireDate: fire, title: texts.coachName ?? ReminderTexts.neutralTitle, body: body)
            }
            return ReminderRequest(slot: first.slot, kind: .comeback, fireDate: fire, title: ReminderTexts.neutralTitle,
                                   body: "Не получилось — ничего страшного. Ждём на следующем занятии.")
        }
    }
}
