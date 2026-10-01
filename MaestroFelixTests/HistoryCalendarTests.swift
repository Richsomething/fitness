import Foundation
import Testing
@testable import MaestroFelix

struct HistoryCalendarTests {
    private func log(_ day: String, hour: Int = 19) -> WorkoutLog {
        let end = T.date(day, hour: hour)
        return WorkoutLog(kind: .strength, title: "Тест", startedAt: end.addingTimeInterval(-1800), finishedAt: end, entries: [])
    }

    @Test("a month is laid out in whole weeks from Monday, the days of its neighbours filling the ends")
    func monthGrid() {
        // October 2026 starts on a Thursday and ends on a Saturday.
        let weeks = HistoryCalendar.month(containing: T.day("2026-10-15"), logs: [], calendar: T.calendar)
        #expect(weeks.count == 5 && weeks.allSatisfy { $0.count == 7 })
        #expect(weeks[0][0].day == T.day("2026-09-28") && !weeks[0][0].isInMonth)
        #expect(weeks[0][3].day == T.day("2026-10-01") && weeks[0][3].isInMonth)
        #expect(weeks[4][6].day == T.day("2026-11-01") && !weeks[4][6].isInMonth)
        #expect(weeks.flatMap { $0 }.filter(\.isInMonth).count == 31)
    }

    @Test("a month that fits exactly in four weeks has four rows")
    func shortMonth() {
        // February 2027 starts on a Monday and has 28 days.
        let weeks = HistoryCalendar.month(containing: T.day("2027-02-10"), logs: [], calendar: T.calendar)
        #expect(weeks.count == 4 && weeks.flatMap { $0 }.allSatisfy(\.isInMonth))
    }

    @Test("each day counts the workouts finished on it")
    func workoutCounts() {
        let logs = [log("2026-10-02"), log("2026-10-02", hour: 21), log("2026-10-05"), log("2026-09-30")]
        let days = HistoryCalendar.month(containing: T.day("2026-10-15"), logs: logs, calendar: T.calendar).flatMap { $0 }
        func count(_ day: String) -> Int { days.first { $0.day == T.day(day) }?.workouts ?? -1 }
        #expect(count("2026-10-02") == 2 && count("2026-10-05") == 1 && count("2026-10-03") == 0)
        #expect(count("2026-09-30") == 1, "a day of the previous month shown in the grid is counted too")
    }

    @Test("moving by months lands on the first day of the month, over the turn of the year too")
    func shiftingMonths() {
        #expect(HistoryCalendar.shifted(T.day("2026-10-15"), byMonths: -1, calendar: T.calendar) == T.day("2026-09-01"))
        #expect(HistoryCalendar.shifted(T.day("2026-12-31"), byMonths: 1, calendar: T.calendar) == T.day("2027-01-01"))
        #expect(HistoryCalendar.shifted(T.day("2026-01-20"), byMonths: -1, calendar: T.calendar) == T.day("2025-12-01"))
        #expect(HistoryCalendar.shifted(T.day("2026-10-15"), byMonths: 0, calendar: T.calendar) == T.day("2026-10-01"))
    }

    @Test("a day's workouts are listed latest first")
    func dayWorkouts() {
        let early = log("2026-10-02", hour: 8), late = log("2026-10-02", hour: 20)
        let found = HistoryCalendar.workouts(on: T.day("2026-10-02"), in: [early, log("2026-10-03"), late], calendar: T.calendar)
        #expect(found.map(\.id) == [late.id, early.id])
    }
}
