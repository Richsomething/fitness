import Foundation

enum TrainingCalendar {
    /// The next start time on a selected ISO weekday (Monday = 1) after `now`.
    static func nextSession(weekdays: Set<Int>, hour: Int, minute: Int,
                            after now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard !weekdays.isEmpty else { return nil }
        let today = calendar.startOfDay(for: now)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(isoWeekday(day, calendar: calendar)),
                  let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  start > now else { continue }
            return start
        }
        return nil
    }

    static func isoWeekday(_ date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    /// "Сегодня", "Завтра" or the weekday's name.
    static func dayText(_ date: Date, calendar: Calendar = .current, now: Date = .now) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Сегодня" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Завтра"
        }
        return OnboardingDraft.fullWeekdayNames[isoWeekday(date, calendar: calendar) - 1]
    }

    /// The day as it reads in a sentence: "сегодня", "завтра", "в пятницу".
    static func dayPhrase(_ day: DayKey, today: DayKey, calendar: Calendar = .current) -> String {
        switch today.days(to: day, calendar: calendar) {
        case 0: return "сегодня"
        case 1: return "завтра"
        default:
            let weekday = day.isoWeekday(calendar: calendar)
            return "\(weekday == 2 ? "во" : "в") \(accusativeWeekdays[weekday - 1])"
        }
    }

    private static let accusativeWeekdays = ["понедельник", "вторник", "среду", "четверг", "пятницу", "субботу", "воскресенье"]

    /// "30 сентября", the month in the genitive.
    static func dateText(_ day: DayKey) -> String {
        let parts = day.rawValue.split(separator: "-").compactMap { Int($0) }
        return "\(parts[2]) \(months[parts[1] - 1])"
    }

    private static let months = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября",
                                 "октября", "ноября", "декабря"]

    /// "1 окт", the month shortened.
    static func shortDateText(_ day: DayKey) -> String {
        let parts = day.rawValue.split(separator: "-").compactMap { Int($0) }
        return "\(parts[2]) \(shortMonths[parts[1] - 1])"
    }

    /// "Октябрь 2026", the month a day falls in, for a heading.
    static func monthYearText(_ day: DayKey) -> String {
        let parts = day.rawValue.split(separator: "-").compactMap { Int($0) }
        return "\(headingMonths[parts[1] - 1]) \(parts[0])"
    }

    private static let headingMonths = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь",
                                        "Октябрь", "Ноябрь", "Декабрь"]

    /// The day of the month, without a leading zero.
    static func dayNumber(_ day: DayKey) -> Int {
        Int(day.rawValue.suffix(2)) ?? 0
    }

    private static let shortMonths = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]

    /// A clock reading such as "18:00".
    static func clock(hour: Int, minute: Int) -> String { String(format: "%02d:%02d", hour, minute) }
}

enum Greeting {
    /// A greeting for the hour of the day, from 0 to 23.
    static func text(hour: Int) -> String {
        switch hour {
        case 5..<12: "Доброе утро"
        case 12..<18: "Добрый день"
        case 18..<23: "Добрый вечер"
        default: "Доброй ночи"
        }
    }
}

enum RussianPlural {
    static func trainings(_ count: Int) -> String {
        form(count, one: "тренировка", few: "тренировки", many: "тренировок")
    }

    static func form(_ count: Int, one: String, few: String, many: String) -> String {
        if (11...14).contains(count % 100) { return many }
        switch count % 10 {
        case 1: return one
        case 2...4: return few
        default: return many
        }
    }
}
