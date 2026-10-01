import Foundation
import Testing
@testable import MaestroFelix

struct WorkoutDomainTests {
    // MARK: Log format

    @Test("logs written before sets and slots existed still read")
    func legacyLogDecodes() throws {
        let json = """
        [{"id":"6F1B0F0E-0B6B-4B7B-9E0B-0A1D6C3A9F11","kind":"strength","title":"Спина и бицепс",
          "startedAt":780000000,"finishedAt":780003000,
          "entries":[{"exerciseID":"pull-ups","setsPlanned":3,"setsDone":2,"feel":2}]}]
        """
        let logs = try JSONDecoder().decode([WorkoutLog].self, from: Data(json.utf8))
        #expect(logs.count == 1)
        #expect(logs[0].sessionKey == nil && logs[0].plannedSets == nil)
        #expect(logs[0].entries[0].sets.isEmpty && logs[0].entries[0].feel == .fine)
        #expect(logs[0].setsDone == 2 && logs[0].setsPlanned == 3 && logs[0].isPartial)
    }

    @Test("the note about spared zones names a few and counts the rest")
    func sparedZonesNoteIsShort() {
        let zones: [BodyZone] = [.shoulders, .elbows, .wrists, .lowerBack, .hips]
        let names = zones.map { $0.title.lowercased() }
        #expect(AvoidedNote.text(for: Array(zones.prefix(1))) == "Обошли нагрузку на: \(names[0])")
        #expect(AvoidedNote.text(for: Array(zones.prefix(3))) == "Обошли нагрузку на: \(names[0]), \(names[1]), \(names[2])")
        #expect(AvoidedNote.text(for: zones) == "Обошли нагрузку на: \(names[0]), \(names[1]) и ещё 3")
    }

    @Test("a title done more than once is said once, with how many times")
    func repeatedTitlesAreCounted() {
        #expect(ActivityText.list(["Ягодицы и кор", "Ягодицы и кор", "Кардио"]) == "Ягодицы и кор ×2, Кардио")
        #expect(ActivityText.list(["Кардио"]) == "Кардио")
        #expect(ActivityText.list([]) == "")
    }

    @Test func newLogsKeepSetsAndSlotThroughJSON() throws {
        let sets = [SetEntry(weightKg: 60, reps: 10), SetEntry(weightKg: 62.5, reps: 8)]
        let log = WorkoutLog(kind: .strength, title: "Грудь", startedAt: T.date("2026-09-30", hour: 18),
                             finishedAt: T.date("2026-09-30", hour: 19),
                             entries: [ExerciseLog(exerciseID: "bench-press", setsPlanned: 3, setsDone: 2, feel: .hard, sets: sets)],
                             sessionKey: T.day("2026-09-30"), plannedSets: 6)
        let decoded = try JSONDecoder().decode(WorkoutLog.self, from: JSONEncoder().encode(log))
        #expect(decoded == log)
        #expect(decoded.volumeKg == 60 * 10 + 62.5 * 8)
        #expect(decoded.minutes == 60)
    }

    @Test("a workout ended early counts as partial but still as done")
    func partialWorkouts() {
        let full = T.log(slot: "2026-09-30", finished: "2026-09-30", sets: 3)
        #expect(!full.isPartial)
        var early = full
        early.entries[0].setsDone = 1
        early.plannedSets = 6
        #expect(early.isPartial && early.setsDone == 1 && early.setsPlanned == 6)
    }

    @Test func setsReadAsPlainRussian() {
        #expect(SetEntry(weightKg: 60, reps: 10).summary == "60 кг × 10")
        #expect(SetEntry(weightKg: 62.5, reps: 8).summary == "62,5 кг × 8")
        #expect(SetEntry(weightKg: nil, reps: 12).summary == "12 повторений")
        #expect(SetEntry(weightKg: 0, reps: 1).summary == "1 повторение")
        #expect(SetEntry(weightKg: nil, reps: 3).summary == "3 повторения")
        #expect(SetEntry(seconds: 40).summary == "40 с")
    }

    // MARK: Body weight

    @Test("one weighing a day: the later one replaces the earlier")
    func oneWeighingPerDay() {
        var entries = WeightHistory.adding(80, on: T.date("2026-09-28", hour: 8), to: [], calendar: T.calendar)
        entries = WeightHistory.adding(79, on: T.date("2026-09-29", hour: 8), to: entries, calendar: T.calendar)
        entries = WeightHistory.adding(78.5, on: T.date("2026-09-29", hour: 20), to: entries, calendar: T.calendar)
        #expect(entries.map(\.kg) == [80, 78.5])
    }

    @Test func weighingsStayInDateOrder() {
        var entries = WeightHistory.adding(79, on: T.date("2026-09-29"), to: [], calendar: T.calendar)
        entries = WeightHistory.adding(80, on: T.date("2026-09-28"), to: entries, calendar: T.calendar)
        #expect(entries.map(\.kg) == [80, 79])
    }

    @Test("the trend smooths the weighings: it starts at the first and moves only part of the way to each next one")
    func trendSmoothsTheWeighings() {
        let entries = [(80.0, "2026-09-01"), (82.0, "2026-09-02"), (80.0, "2026-09-03"), (80.0, "2026-09-04")]
            .map { WeightEntry(date: T.date($0.1), kg: $0.0) }
        let trend = WeightHistory.trend(entries)
        #expect(trend.count == 4 && trend.map(\.date) == entries.map(\.date))
        #expect(trend[0].kg == 80)
        #expect(trend[1].kg > 80 && trend[1].kg < 82, "a jump is only partly followed")
        #expect(abs(trend[1].kg - 80.6) < 0.001)
        #expect(trend[3].kg < trend[1].kg, "and the trend comes back when the weight does")
        #expect(WeightHistory.trend([]).isEmpty)
    }

    @Test func changeNeedsTwoWeighingsAndIsWrittenWithoutJudgement() {
        #expect(WeightHistory.change([]) == nil)
        #expect(WeightHistory.change([WeightEntry(date: T.date("2026-09-28"), kg: 80)]) == nil)
        let two = [WeightEntry(date: T.date("2026-09-28"), kg: 80), WeightEntry(date: T.date("2026-09-30"), kg: 78.5)]
        #expect(WeightHistory.change(two) == -1.5)
        #expect(WeightHistory.changeText(-1.5) == "−1,5 кг")
        #expect(WeightHistory.changeText(2) == "+2 кг")
        #expect(WeightHistory.changeText(0) == "0 кг")
    }

    // MARK: Planner

    @Test func aRestDayHasNoPlan() {
        #expect(WorkoutPlanner.plan(for: T.profile(), on: T.date("2026-09-29"), calendar: T.calendar) == nil)
        #expect(WorkoutPlanner.plan(for: T.profile(), on: T.date("2026-09-30"), calendar: T.calendar) != nil)
    }

    @Test("days in force can differ from the profile's current days")
    func explicitDaysOverrideTheProfile() {
        let plan = WorkoutPlanner.plan(for: T.profile(weekdays: [1]), weekdays: [3], on: T.date("2026-09-30"), calendar: T.calendar)
        #expect(plan?.title == "Всё тело")
        #expect(WorkoutPlanner.plan(for: T.profile(weekdays: [1]), on: T.date("2026-09-30"), calendar: T.calendar) == nil)
    }

    @Test(arguments: [(1, "Всё тело"), (2, "Верх тела"), (3, "Грудь, плечи, трицепс"), (4, "Верх тела"), (5, "Грудь, плечи, трицепс")])
    func splitFollowsTheNumberOfDays(count: Int, firstTitle: String) {
        let days = Set(Array(1...7).prefix(count))
        let plan = WorkoutPlanner.plan(for: T.profile(weekdays: days), on: T.date("2026-09-28"), calendar: T.calendar)
        #expect(plan?.title == firstTitle)
    }

    @Test func markedZonesKeepTheirLoadOutOfThePlan() {
        let blocked: Set<BodyZone> = [.knees, .shoulders]
        for date in ["2026-09-28", "2026-09-30", "2026-10-02"] {
            let plan = WorkoutPlanner.plan(for: T.profile(limitations: Array(blocked)), on: T.date(date), calendar: T.calendar)
            for item in plan?.exercises ?? [] {
                #expect(item.exercise.loads.isDisjoint(with: blocked), "\(item.exerciseID) loads a marked zone")
            }
        }
    }

    @Test("a day the marked zones leave thin is filled with safe exercises instead of staying at one")
    func thinDaysAreToppedUp() throws {
        let blocked: Set<BodyZone> = [.shoulders, .elbows, .wrists, .lowerBack]
        // Wednesday of a three-day week is the pull day, which most of these zones close.
        let plan = try #require(WorkoutPlanner.plan(for: T.profile(limitations: Array(blocked)), on: T.date("2026-09-30"),
                                                    calendar: T.calendar))
        #expect(plan.exercises.count == 5)
        #expect(Set(plan.exercises.map(\.exerciseID)).count == plan.exercises.count)
        for item in plan.exercises { #expect(item.exercise.loads.isDisjoint(with: blocked), "\(item.exerciseID) loads a marked zone") }
        #expect(plan.focus.count > 2, "the added groups are named in the plan")
    }

    @Test func aDayWithNothingMarkedKeepsItsTemplate() throws {
        let plan = try #require(WorkoutPlanner.plan(for: T.profile(), on: T.date("2026-09-30"), calendar: T.calendar))
        #expect(plan.exercises.count == 5)
        #expect(plan.focus == [.back, .arms])
        #expect(plan.avoidedZones.isEmpty)
    }

    @Test("an exercise rated easy adds repetitions next time, one at the limit takes some away")
    func ratingCalibratesTheNextPlan() throws {
        let base = try #require(WorkoutPlanner.plan(for: T.profile(), on: T.date("2026-09-28"), calendar: T.calendar))
        let target = try #require(base.exercises.first { !$0.exercise.isTimed })
        func adjusted(_ feel: ExerciseFeel) throws -> PlannedExercise {
            let log = WorkoutLog(kind: .strength, title: "x", startedAt: T.date("2026-09-21"), finishedAt: T.date("2026-09-21"),
                                 entries: [ExerciseLog(exerciseID: target.exerciseID, setsPlanned: 3, setsDone: 3, feel: feel)])
            let plan = try #require(WorkoutPlanner.plan(for: T.profile(), on: T.date("2026-09-28"), logs: [log], calendar: T.calendar))
            return try #require(plan.exercises.first { $0.exerciseID == target.exerciseID })
        }
        #expect(try adjusted(.easy).repsLow == target.repsLow + 2)
        #expect(try adjusted(.limit).repsLow < target.repsLow)
        #expect(try adjusted(.fine) == target)
    }

    // MARK: Exercise catalog

    @Test func everyExerciseIsDescribed() {
        for exercise in ExerciseCatalog.all {
            let info = ExerciseCatalog.info(exercise.id)
            #expect(info.tips.count == 3, "\(exercise.id) needs three tips")
            #expect(!(info.front.isEmpty && info.back.isEmpty), "\(exercise.id) trains nothing on the drawing")
        }
    }

    @Test("every muscle an exercise names exists on the drawings")
    func musclesExistInTheArt() {
        func names(_ facing: BodyFigure.Facing) -> Set<String> {
            let art = BodyFigure.anatomy(facing: facing, build: .male).art
            return Set(art.muscles.map { $0.image.replacingOccurrences(of: "\(art.image)-", with: "") })
        }
        let front = names(.front), back = names(.back)
        #expect(front.count == 16 && back.count == 16)
        for exercise in ExerciseCatalog.all {
            let info = ExerciseCatalog.info(exercise.id)
            for muscle in info.front { #expect(front.contains(muscle), "\(exercise.id): no front muscle \(muscle)") }
            for muscle in info.back { #expect(back.contains(muscle), "\(exercise.id): no back muscle \(muscle)") }
        }
    }

    @Test func timedExercisesTakeNoWeight() {
        for exercise in ExerciseCatalog.all where exercise.isTimed {
            #expect(!ExerciseCatalog.info(exercise.id).usesWeight)
        }
    }
}
