import Foundation

/// A calendar day written "yyyy-MM-dd". It names a planned slot for good — moving a session changes its
/// day, not its slot — and keeps the schedule independent of the time of day and of daylight saving.
struct DayKey: RawRepresentable, Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let rawValue: String

    init?(rawValue: String) {
        let parts = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ Int($0) != nil }) else { return nil }
        self.rawValue = rawValue
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        rawValue = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(rawValue: text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a day: \(text)"))
        }
        self = key
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.rawValue < rhs.rawValue }

    var description: String { rawValue }

    /// The start of this day.
    func date(calendar: Calendar = .current) -> Date {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? .distantPast
    }

    /// The moment on this day at `hour:minute`.
    func at(hour: Int, minute: Int, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date(calendar: calendar)) ?? date(calendar: calendar)
    }

    func adding(days: Int, calendar: Calendar = .current) -> DayKey {
        DayKey(calendar.date(byAdding: .day, value: days, to: date(calendar: calendar)) ?? date(calendar: calendar),
               calendar: calendar)
    }

    /// Whole days from this day to `other`; negative when `other` is earlier.
    func days(to other: DayKey, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: date(calendar: calendar), to: other.date(calendar: calendar)).day ?? 0
    }

    /// A number that grows by one a day, to pick among lines by the day.
    func ordinal(calendar: Calendar = .current) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date(calendar: calendar)) ?? 0
    }

    /// Monday = 1 … Sunday = 7, whatever the region's first weekday is.
    func isoWeekday(calendar: Calendar = .current) -> Int {
        TrainingCalendar.isoWeekday(date(calendar: calendar), calendar: calendar)
    }

    /// The Monday of this day's week.
    func weekStart(calendar: Calendar = .current) -> DayKey {
        adding(days: 1 - isoWeekday(calendar: calendar), calendar: calendar)
    }

    /// The seven days of this day's week, Monday first.
    func weekDays(calendar: Calendar = .current) -> [DayKey] {
        let monday = weekStart(calendar: calendar)
        return (0..<7).map { monday.adding(days: $0, calendar: calendar) }
    }
}
