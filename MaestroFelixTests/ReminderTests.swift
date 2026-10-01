import Foundation
import Testing
@testable import MaestroFelix

struct ReminderTests {
    private let state = T.state()
    private var settings: ReminderSettings {
        var settings = ReminderSettings()
        settings.isEnabled = true
        return settings
    }
    private let texts = ReminderTexts(coachName: "Вера", upcoming: "План на сегодня готов. Увидимся в зале?",
                                      missed: "Ничего страшного. План можно продолжить в любой момент.")

    private func requests(_ settings: ReminderSettings, state: ScheduleState? = nil, logs: [WorkoutLog] = [],
                          now: Date = T.date("2026-09-30", hour: 8), startHour: Int = 18, sent: Set<String> = []) -> [ReminderRequest] {
        let today = DayKey(now, calendar: T.calendar)
        let slots = SchedulePlanner.slots(state: state ?? self.state, logs: logs, from: today,
                                          through: today.adding(days: 21, calendar: T.calendar), today: today, calendar: T.calendar)
        return ReminderPlanner.requests(slots: slots, settings: settings, startHour: startHour, startMinute: 0, now: now,
                                        texts: texts, comebackSent: sent, calendar: T.calendar)
    }

    @Test func nothingIsScheduledUntilRemindersAreOn() {
        #expect(requests(ReminderSettings()).isEmpty)
    }

    @Test("one reminder per upcoming session, an hour before it")
    func leadReminders() {
        let found = requests(settings)
        #expect(found.first?.fireDate == T.date("2026-09-30", hour: 17))
        #expect(found.first?.slot.rawValue == "2026-09-30")
        #expect(Array(found.map(\.slot.rawValue).prefix(3)) == ["2026-09-30", "2026-10-02", "2026-10-05"])
        #expect(found.allSatisfy { $0.kind == .lead })
    }

    @Test func aReminderAlreadyInThePastIsNotMade() {
        let found = requests(settings, now: T.date("2026-09-30", hour: 17, minute: 30))
        #expect(found.first?.slot.rawValue == "2026-10-02")
    }

    @Test("a reminder that falls in quiet hours is skipped, not moved")
    func quietHoursSkip() {
        // A session at 08:00 with a lead of an hour would ring at 07:00, inside 22:00–08:00: no reminder at all.
        #expect(requests(settings, startHour: 8).isEmpty)
        var atStart = settings
        atStart.leadMinutes = 0
        #expect(requests(atStart, startHour: 8).isEmpty == false)
    }

    @Test func quietHoursCrossMidnight() {
        let quiet = ReminderSettings()
        #expect(quiet.isQuiet(T.date("2026-09-30", hour: 23), calendar: T.calendar))
        #expect(quiet.isQuiet(T.date("2026-09-30", hour: 3), calendar: T.calendar))
        #expect(quiet.isQuiet(T.date("2026-09-30", hour: 7, minute: 59), calendar: T.calendar))
        #expect(!quiet.isQuiet(T.date("2026-09-30", hour: 8), calendar: T.calendar))
        #expect(!quiet.isQuiet(T.date("2026-09-30", hour: 21, minute: 59), calendar: T.calendar))
        var none = quiet
        none.quietEnd = none.quietStart
        #expect(!none.isQuiet(T.date("2026-09-30", hour: 23), calendar: T.calendar))
    }

    @Test func doneSkippedAndHeldSessionsGetNoReminder() {
        var changed = state
        changed.skip(T.day("2026-10-02"))
        let logs = [T.log(slot: "2026-09-30", finished: "2026-09-30", hour: 7)]
        let found = requests(settings, state: changed, logs: logs)
        #expect(found.allSatisfy { $0.slot.rawValue != "2026-09-30" && $0.slot.rawValue != "2026-10-02" })
        var held = state
        held.pause(from: T.day("2026-09-30"), until: T.day("2026-10-04"))
        #expect(requests(settings, state: held).allSatisfy { $0.slot.rawValue >= "2026-10-05" })
    }

    @Test("a moved session is reminded on its new day, under the same request name")
    func movedSessionMovesItsReminder() {
        var moved = state
        moved.move(T.day("2026-10-02"), to: T.day("2026-10-03"))
        let request = requests(settings, state: moved).first { $0.slot.rawValue == "2026-10-02" }
        #expect(request?.fireDate == T.date("2026-10-03", hour: 17))
        #expect(request?.id == "session.2026-10-02.lead")
    }

    @Test func requestsStayWithinTheHorizonAndTheLimit() {
        let found = requests(settings, state: T.state(weekdays: Set(1...7)))
        #expect(found.count <= ReminderPlanner.maxRequests)
        let horizon = T.day("2026-09-30").adding(days: ReminderPlanner.horizonDays, calendar: T.calendar)
        #expect(found.allSatisfy { $0.slot <= horizon })
    }

    @Test("neutral text says nothing about the person; personal text is the coach's line")
    func notificationWording() {
        let neutral = requests(settings).first
        #expect(neutral?.title == "Maestro Felix")
        #expect(neutral?.body == "Тренировка через час.")
        var personal = settings
        personal.usesPersonalText = true
        let coach = requests(personal).first
        #expect(coach?.title == "Вера")
        #expect(coach?.body == texts.upcoming)
    }

    @Test func leadWordsFollowTheChosenLead() {
        var lead = settings
        lead.leadMinutes = 0
        #expect(requests(lead).first?.body == "Пора на тренировку.")
        lead.leadMinutes = 30
        #expect(requests(lead).first?.body == "Тренировка через 30 минут.")
    }

    // MARK: Comeback

    @Test("the comeback note comes the morning after the first open session of a week, once a week")
    func oneComebackPerWeek() {
        var comeback = settings
        comeback.comebackEnabled = true
        let notes = requests(comeback).filter { $0.kind == .comeback }
        #expect(notes.first?.slot.rawValue == "2026-09-30")
        #expect(notes.first?.fireDate == T.date("2026-10-01", hour: 10))
        let weeks = notes.map { $0.slot.weekStart(calendar: T.calendar) }
        #expect(Set(weeks).count == weeks.count)
    }

    @Test func aWeekThatAlreadyHadOneGetsNoMore() {
        var comeback = settings
        comeback.comebackEnabled = true
        let notes = requests(comeback, sent: ["2026-09-28"]).filter { $0.kind == .comeback }
        #expect(notes.allSatisfy { $0.slot.weekStart(calendar: T.calendar).rawValue != "2026-09-28" })
    }

    @Test func doingTheSessionHandsTheNoteToTheNextOpenOne() {
        var comeback = settings
        comeback.comebackEnabled = true
        let logs = [T.log(slot: "2026-09-30", finished: "2026-09-30", hour: 7)]
        let notes = requests(comeback, logs: logs).filter { $0.kind == .comeback }
        #expect(notes.first?.slot.rawValue == "2026-10-02")
    }

    @Test func settingsReadOldDataAndKeepEverythingOffByDefault() throws {
        let decoded = try JSONDecoder().decode(ReminderSettings.self, from: Data(#"{"isEnabled":true}"#.utf8))
        #expect(decoded.isEnabled)
        #expect(decoded.leadMinutes == 60 && decoded.comebackEnabled == false && decoded.restAlertEnabled == false)
        let fresh = ReminderSettings()
        #expect(!fresh.isEnabled && !fresh.usesPersonalText && !fresh.comebackEnabled && !fresh.restAlertEnabled)
    }
}
