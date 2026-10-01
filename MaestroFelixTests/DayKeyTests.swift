import Foundation
import Testing
@testable import MaestroFelix

struct DayKeyTests {
    @Test("a day survives a JSON round trip as a plain string")
    func codableRoundTrip() throws {
        let data = try JSONEncoder().encode([T.day("2026-09-30")])
        #expect(String(data: data, encoding: .utf8) == #"["2026-09-30"]"#)
        #expect(try JSONDecoder().decode([DayKey].self, from: data) == [T.day("2026-09-30")])
    }

    @Test("text that is not a day is refused", arguments: ["2026-9-30", "2026/09/30", "today", "", "2026-09", "2026-09-3x"])
    func rejectsMalformedText(text: String) {
        #expect(DayKey(rawValue: text) == nil)
    }

    @Test("a broken day in stored data fails to decode instead of becoming a wrong day")
    func decodingBrokenDayThrows() {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([DayKey].self, from: Data(#"["soon"]"#.utf8)) }
    }

    @Test func addsDaysAcrossMonthAndYear() {
        #expect(T.day("2026-09-30").adding(days: 1, calendar: T.calendar) == T.day("2026-10-01"))
        #expect(T.day("2026-12-31").adding(days: 1, calendar: T.calendar) == T.day("2027-01-01"))
        #expect(T.day("2026-03-01").adding(days: -1, calendar: T.calendar) == T.day("2026-02-28"))
    }

    @Test func weekStartsOnMondayWhateverTheRegion() {
        let wednesday = T.day("2026-09-30")
        #expect(wednesday.isoWeekday(calendar: T.calendar) == 3)
        #expect(wednesday.weekStart(calendar: T.calendar) == T.day("2026-09-28"))
        #expect(T.day("2026-10-04").weekStart(calendar: T.calendar) == T.day("2026-09-28"))
        #expect(T.day("2026-10-05").weekStart(calendar: T.calendar) == T.day("2026-10-05"))
        #expect(wednesday.weekDays(calendar: T.calendar).map(\.rawValue).first == "2026-09-28")
        #expect(wednesday.weekDays(calendar: T.calendar).count == 7)
    }

    @Test func countsDaysBetween() {
        #expect(T.day("2026-09-28").days(to: T.day("2026-10-05"), calendar: T.calendar) == 7)
        #expect(T.day("2026-10-05").days(to: T.day("2026-09-28"), calendar: T.calendar) == -7)
    }

    @Test func daysOrderAsTimeDoes() {
        #expect(T.day("2026-09-30") < T.day("2026-10-01"))
        #expect(T.day("2026-12-31") < T.day("2027-01-01"))
    }

    @Test("the greeting follows the hour of the day", arguments: [(5, "Доброе утро"), (11, "Доброе утро"), (12, "Добрый день"),
                                                                  (17, "Добрый день"), (18, "Добрый вечер"), (22, "Добрый вечер"),
                                                                  (23, "Доброй ночи"), (0, "Доброй ночи"), (4, "Доброй ночи")])
    func greetingFollowsTheHour(hour: Int, expected: String) {
        #expect(Greeting.text(hour: hour) == expected)
    }

    @Test func shortDatesAndDayNumbers() {
        #expect(TrainingCalendar.shortDateText(T.day("2026-10-01")) == "1 окт")
        #expect(TrainingCalendar.shortDateText(T.day("2026-05-31")) == "31 мая")
        #expect(TrainingCalendar.dayNumber(T.day("2026-10-01")) == 1)
        #expect(T.day("2026-10-01").ordinal(calendar: T.calendar) == T.day("2026-09-30").ordinal(calendar: T.calendar) + 1)
    }

    @Test("the month a day falls in reads as a heading")
    func monthAndYear() {
        #expect(TrainingCalendar.monthYearText(T.day("2026-10-01")) == "Октябрь 2026")
        #expect(TrainingCalendar.monthYearText(T.day("2027-01-31")) == "Январь 2027")
    }

    @Test func russianPhrasesForDays() {
        let today = T.day("2026-09-30")
        #expect(TrainingCalendar.dayPhrase(today, today: today, calendar: T.calendar) == "сегодня")
        #expect(TrainingCalendar.dayPhrase(T.day("2026-10-01"), today: today, calendar: T.calendar) == "завтра")
        #expect(TrainingCalendar.dayPhrase(T.day("2026-10-02"), today: today, calendar: T.calendar) == "в пятницу")
        #expect(TrainingCalendar.dayPhrase(T.day("2026-10-06"), today: today, calendar: T.calendar) == "во вторник")
        #expect(TrainingCalendar.dateText(T.day("2026-09-30")) == "30 сентября")
    }
}
