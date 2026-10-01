import Foundation

/// One cell of a month grid: the day, whether it belongs to the month shown, and how many workouts ended on it.
struct CalendarDay: Equatable, Identifiable {
    let day: DayKey
    let isInMonth: Bool
    let workouts: Int

    var id: String { day.rawValue }
}

/// The history as a calendar: a month in whole weeks from Monday, so a workout is found by the day it was done.
enum HistoryCalendar {
    static func firstDay(ofMonthContaining day: DayKey, calendar: Calendar) -> DayKey {
        let parts = calendar.dateComponents([.year, .month], from: day.date(calendar: calendar))
        guard let first = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1)) else { return day }
        return DayKey(first, calendar: calendar)
    }

    /// The first day of the month `months` away from the one `day` falls in.
    static func shifted(_ day: DayKey, byMonths months: Int, calendar: Calendar) -> DayKey {
        let first = firstDay(ofMonthContaining: day, calendar: calendar)
        guard let moved = calendar.date(byAdding: .month, value: months, to: first.date(calendar: calendar)) else { return first }
        return DayKey(moved, calendar: calendar)
    }

    /// The weeks of the month `day` falls in, Monday first, with the neighbouring months' days filling the ends.
    static func month(containing day: DayKey, logs: [WorkoutLog], calendar: Calendar) -> [[CalendarDay]] {
        let first = firstDay(ofMonthContaining: day, calendar: calendar)
        let last = shifted(first, byMonths: 1, calendar: calendar).adding(days: -1, calendar: calendar)
        let end = last.weekStart(calendar: calendar).adding(days: 6, calendar: calendar)
        let counts = Dictionary(grouping: logs) { $0.day(calendar: calendar) }.mapValues(\.count)

        var weeks: [[CalendarDay]] = []
        var monday = first.weekStart(calendar: calendar)
        while monday <= end {
            weeks.append((0..<7).map { offset in
                let cell = monday.adding(days: offset, calendar: calendar)
                return CalendarDay(day: cell, isInMonth: cell >= first && cell <= last, workouts: counts[cell] ?? 0)
            })
            monday = monday.adding(days: 7, calendar: calendar)
        }
        return weeks
    }

    /// What ended on `day`, the latest first.
    static func workouts(on day: DayKey, in logs: [WorkoutLog], calendar: Calendar) -> [WorkoutLog] {
        logs.filter { $0.day(calendar: calendar) == day }.sorted { $0.finishedAt > $1.finishedAt }
    }
}
