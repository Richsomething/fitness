import Foundation

/// Makes the day's plan from the profile. The training days of the week are split by how many there
/// are (one: full body; two: upper and lower; three: push, pull, legs; and so on); goal and level set
/// sets, repetitions and rest; exercises that load a marked zone give way to the next candidate for
/// the slot; and the person's rating of an exercise last time moves its repetitions. Rest days offer a
/// cardio session or a short light block. Everything is a plain rule on the person's own answers — not
/// a medical assessment.
enum WorkoutPlanner {
    // MARK: Days

    /// The plan for `date`, or nil when it is not a training day. `weekdays` are the training days in
    /// force on that date; without them the profile's current days are used.
    static func plan(for profile: OnboardingDraft, weekdays: Set<Int>? = nil, on date: Date = .now, logs: [WorkoutLog] = [],
                     calendar: Calendar = .current) -> WorkoutPlan? {
        let weekday = TrainingCalendar.isoWeekday(date, calendar: calendar)
        let days = (weekdays ?? profile.weekdays).sorted()
        guard let index = days.firstIndex(of: weekday) else { return nil }
        let split = Self.split(days.count)
        let template = split[index % split.count]
        // Alternate candidates week to week, so the same day does not repeat exactly.
        let variant = calendar.component(.weekOfYear, from: date) % 2
        return build(template, variant: variant, profile: profile, logs: logs)
    }

    /// A cardio session for a rest day.
    static func cardio(for profile: OnboardingDraft, seed: Int, logs: [WorkoutLog] = []) -> WorkoutPlan {
        let main = ["incline-walk", "bike", "elliptical", "rower"]
        let blocked = blockedZones(profile)
        let options = main.filter { ExerciseCatalog.exercise($0).loads.isDisjoint(with: blocked) }
        let chosen = options.isEmpty ? "easy-walk" : options[abs(seed) % options.count]
        let level = profile.experience.flatMap { TrainingExperience.allCases.firstIndex(of: $0) } ?? 1
        let minutes = [15, 15, 20, 25, 30][min(level, 4)]
        let exercises = [
            timed("easy-walk", seconds: 5 * 60),
            timed(chosen, seconds: minutes * 60),
            timed("hamstring-stretch", seconds: 60),
        ]
        return WorkoutPlan(kind: .cardio, title: "Кардио", focus: [.cardio], exercises: exercises,
                           avoidedZones: avoided(options: main, blocked: blocked))
    }

    enum LightBlock: String, CaseIterable, Identifiable {
        case core, arms, mobility, glutes
        var id: String { rawValue }

        var title: String {
            switch self {
            case .core: "Пресс"
            case .arms: "Руки"
            case .mobility: "Мобильность"
            case .glutes: "Ягодицы и кор"
            }
        }

        var symbol: String {
            switch self {
            case .core: "figure.core.training"
            case .arms: "dumbbell.fill"
            case .mobility: "figure.yoga"
            case .glutes: "figure.strengthtraining.functional"
            }
        }

        fileprivate var slots: [[String]] {
            switch self {
            case .core: [["crunch", "dead-bug"], ["reverse-crunch", "bird-dog"], ["plank", "dead-bug"], ["bicycle", "side-plank"]]
            case .arms: [["hammer-curl", "cable-curl"], ["triceps-pushdown", "overhead-extension"],
                         ["cable-curl", "barbell-curl"], ["overhead-extension", "triceps-pushdown"]]
            case .mobility: [["cat-cow"], ["thoracic-rotation"], ["hip-opener"], ["hamstring-stretch"]]
            case .glutes: [["glute-bridge"], ["cable-kickback", "bird-dog"], ["side-plank", "dead-bug"], ["bird-dog"]]
            }
        }
    }

    /// A short light session for a rest day: 3 sets of 12–15, or holds for mobility.
    static func light(_ block: LightBlock, for profile: OnboardingDraft, logs: [WorkoutLog] = []) -> WorkoutPlan {
        let blocked = blockedZones(profile)
        var used = Set<String>()
        var avoidedZones = Set<BodyZone>()
        var exercises: [PlannedExercise] = []
        for slot in block.slots {
            guard let pick = pick(slot, variant: 0, blocked: blocked, used: used, avoided: &avoidedZones) else { continue }
            used.insert(pick)
            let item = ExerciseCatalog.exercise(pick).isTimed
                ? timed(pick, seconds: block == .mobility ? 60 : 30, sets: block == .mobility ? 2 : 3, rest: 30)
                : PlannedExercise(exerciseID: pick, sets: 3, repsLow: 12, repsHigh: 15, holdSeconds: 0, restSeconds: 45)
            exercises.append(calibrated(item, logs: logs))
        }
        return WorkoutPlan(kind: .light, title: block.title, focus: [], exercises: exercises,
                           avoidedZones: BodyZone.allCases.filter(avoidedZones.contains))
    }

    // MARK: Split

    private struct DayTemplate {
        let title: String
        let focus: [MuscleGroup]
        /// Candidates for each slot, in order of preference.
        let slots: [[String]]
    }

    private static let push = DayTemplate(title: "Грудь, плечи, трицепс", focus: [.chest, .shoulders, .arms], slots: [
        ["bench-press", "machine-press", "push-ups"], ["incline-db-press", "machine-press", "cable-fly"],
        ["db-shoulder-press", "lateral-raise"], ["lateral-raise", "face-pull"],
        ["triceps-pushdown", "overhead-extension"], ["cable-fly", "dips", "machine-press"],
    ])
    private static let pull = DayTemplate(title: "Спина и бицепс", focus: [.back, .arms], slots: [
        ["lat-pulldown", "pull-ups", "machine-row"], ["seated-row", "machine-row"], ["db-row", "machine-row", "seated-row"],
        ["face-pull", "rear-delt-fly"], ["barbell-curl", "cable-curl"], ["hammer-curl", "cable-curl"],
    ])
    private static let legs = DayTemplate(title: "Ноги и пресс", focus: [.legs, .glutes, .core], slots: [
        ["back-squat", "leg-press", "goblet-squat", "glute-bridge"], ["romanian-deadlift", "hip-thrust", "glute-bridge"],
        ["lunges", "leg-press", "leg-curl"], ["leg-curl", "leg-extension", "glute-bridge"],
        ["calf-raise", "cable-kickback"], ["plank", "dead-bug", "crunch"],
    ])
    private static let upper = DayTemplate(title: "Верх тела", focus: [.chest, .back, .shoulders, .arms], slots: [
        ["bench-press", "incline-db-press", "machine-press"], ["lat-pulldown", "pull-ups", "machine-row"],
        ["db-shoulder-press", "lateral-raise"], ["seated-row", "machine-row"],
        ["barbell-curl", "hammer-curl"], ["triceps-pushdown", "overhead-extension"],
    ])
    private static let lower = DayTemplate(title: "Низ тела", focus: [.legs, .glutes, .core], slots: [
        ["leg-press", "back-squat", "goblet-squat", "glute-bridge"], ["hip-thrust", "romanian-deadlift", "glute-bridge"],
        ["leg-curl", "leg-extension"], ["lunges", "cable-kickback", "glute-bridge"],
        ["calf-raise"], ["dead-bug", "plank", "reverse-crunch"],
    ])
    private static let full = DayTemplate(title: "Всё тело", focus: [.legs, .chest, .back, .core], slots: [
        ["goblet-squat", "leg-press", "glute-bridge"], ["bench-press", "machine-press", "push-ups"],
        ["lat-pulldown", "seated-row", "machine-row"], ["db-shoulder-press", "lateral-raise"],
        ["romanian-deadlift", "hip-thrust", "glute-bridge"], ["plank", "dead-bug"],
    ])

    private static func split(_ days: Int) -> [DayTemplate] {
        switch days {
        case 1: [full]
        case 2: [upper, lower]
        case 3: [push, pull, legs]
        case 4: [upper, lower, upper, lower]
        case 5: [push, pull, legs, upper, lower]
        default: [push, pull, legs, push, pull, legs, full]
        }
    }

    /// Provisional class × goal rules. The coordinator only applies these after preparation.
    static func classPlan(_ original: WorkoutPlan, profile: OnboardingDraft,
                          trainingClass: TrainingClass) -> WorkoutPlan {
        guard original.kind == .strength else { return original }
        var plan = original
        if trainingClass == .powerlifting {
            let chest = original.focus.contains(.chest)
            let legs = original.focus.contains(.legs)
            let template: DayTemplate
            if chest && legs {
                template = DayTemplate(title: "Присед и жим", focus: [.legs, .chest, .back, .core], slots: [
                    ["back-squat", "leg-press", "glute-bridge"], ["bench-press", "machine-press", "push-ups"],
                    ["deadlift", "hip-thrust", "glute-bridge"], ["seated-row", "machine-row"],
                    ["triceps-pushdown", "cable-curl"], ["dead-bug", "plank"]])
            } else if chest {
                template = DayTemplate(title: "Жим и подсобные", focus: [.chest, .back, .arms], slots: [
                    ["bench-press", "machine-press", "push-ups"], ["seated-row", "machine-row"],
                    ["incline-db-press", "cable-fly"], ["triceps-pushdown", "overhead-extension"],
                    ["face-pull", "rear-delt-fly"], ["dead-bug", "plank"]])
            } else if legs {
                template = DayTemplate(title: "Присед и подсобные", focus: [.legs, .glutes, .core], slots: [
                    ["back-squat", "leg-press", "glute-bridge"], ["deadlift", "hip-thrust", "glute-bridge"],
                    ["leg-curl", "leg-extension"], ["seated-row", "machine-row"],
                    ["dead-bug", "plank"], ["calf-raise"]])
            } else {
                template = DayTemplate(title: "Становая и подсобные", focus: [.back, .legs, .arms, .core], slots: [
                    ["deadlift", "hip-thrust", "glute-bridge"], ["seated-row", "machine-row"],
                    ["lat-pulldown", "machine-row"], ["leg-curl", "glute-bridge"],
                    ["hammer-curl", "cable-curl"], ["dead-bug", "plank"]])
            }
            // Keep the competition movement stable; marked zones still trigger substitutions.
            plan = build(template, variant: 0, profile: profile, logs: [])
        }
        let lowerVolume = profile.goal != .muscleGain
        let novice = profile.experience == .beginner || profile.experience == .returning
        let sets = novice ? 2 : (lowerVolume ? 3 : 4)
        for index in plan.exercises.indices {
            var item = plan.exercises[index]
            item.sets = sets
            if !item.exercise.isTimed {
                let main = ["bench-press", "back-squat", "deadlift"].contains(item.exerciseID)
                let compound = main || ["incline-db-press", "machine-press", "leg-press", "goblet-squat",
                                       "romanian-deadlift", "hip-thrust", "lat-pulldown", "seated-row",
                                       "machine-row", "db-row", "db-shoulder-press"].contains(item.exerciseID)
                let range: ClosedRange<Int> = trainingClass == .powerlifting && main ? 3...5
                    : compound ? 8...12 : 10...15
                item.repsLow = range.lowerBound
                item.repsHigh = range.upperBound
                item.restSeconds = trainingClass == .powerlifting && main ? 180 : (compound ? 120 : 90)
            }
            plan.exercises[index] = item
        }
        return WorkoutPlan(kind: plan.kind, title: trainingClass.title + " · " + plan.title,
                           focus: plan.focus, exercises: plan.exercises, avoidedZones: plan.avoidedZones)
    }

    // MARK: Building

    private static func build(_ template: DayTemplate, variant: Int, profile: OnboardingDraft, logs: [WorkoutLog]) -> WorkoutPlan {
        let dose = Dose(goal: profile.goal, experience: profile.experience)
        let blocked = blockedZones(profile)
        var used = Set<String>()
        var avoidedZones = Set<BodyZone>()
        var ids: [String] = []
        // Slots are tried until the day is full, so a slot the marked zones close gives way to a later one.
        for slot in template.slots where ids.count < dose.exerciseCount {
            guard let pick = pick(slot, variant: variant, blocked: blocked, used: used, avoided: &avoidedZones) else { continue }
            used.insert(pick)
            ids.append(pick)
        }
        var focus = template.focus
        if ids.count < dose.exerciseCount {
            let extra = topUp(focus: template.focus, blocked: blocked, used: used, count: dose.exerciseCount - ids.count)
            ids += extra
            for group in extra.map({ ExerciseCatalog.exercise($0).group }) where !focus.contains(group) { focus.append(group) }
        }
        let exercises = ids.map { id in
            let item = ExerciseCatalog.exercise(id).isTimed
                ? timed(id, seconds: 40, sets: dose.sets, rest: 45)
                : PlannedExercise(exerciseID: id, sets: dose.sets, repsLow: dose.reps.lowerBound, repsHigh: dose.reps.upperBound,
                                  holdSeconds: 0, restSeconds: dose.rest)
            return calibrated(item, logs: logs)
        }
        return WorkoutPlan(kind: .strength, title: template.title, focus: focus, exercises: exercises,
                           avoidedZones: BodyZone.allCases.filter(avoidedZones.contains))
    }

    /// Exercises to fill a day the marked zones left thin: none that loads a marked zone, first from
    /// the day's own muscle groups, then from core, glutes and mobility, then legs.
    private static func topUp(focus: [MuscleGroup], blocked: Set<BodyZone>, used: Set<String>, count: Int) -> [String] {
        let support: [MuscleGroup] = [.core, .glutes, .mobility, .legs]
        var picks: [String] = []
        for group in focus + support.filter({ !focus.contains($0) }) {
            for exercise in ExerciseCatalog.all where exercise.group == group && !used.contains(exercise.id)
                && !picks.contains(exercise.id) && exercise.loads.isDisjoint(with: blocked) {
                picks.append(exercise.id)
                if picks.count == count { return picks }
            }
        }
        return picks
    }

    /// The first candidate (rotated by `variant`) that loads no marked zone and is not already in the day.
    private static func pick(_ candidates: [String], variant: Int, blocked: Set<BodyZone>, used: Set<String>,
                             avoided: inout Set<BodyZone>) -> String? {
        let shift = candidates.count > 1 ? variant % candidates.count : 0
        let ordered = Array(candidates[shift...] + candidates[..<shift])
        for id in ordered where !used.contains(id) {
            let conflict = ExerciseCatalog.exercise(id).loads.intersection(blocked)
            if conflict.isEmpty { return id }
            avoided.formUnion(conflict)
        }
        return nil
    }

    private static func blockedZones(_ profile: OnboardingDraft) -> Set<BodyZone> {
        Set(profile.limitations.map(\.zone))
    }

    private static func avoided(options: [String], blocked: Set<BodyZone>) -> [BodyZone] {
        let hit = options.reduce(into: Set<BodyZone>()) { $0.formUnion(ExerciseCatalog.exercise($1).loads.intersection(blocked)) }
        return BodyZone.allCases.filter(hit.contains)
    }

    private static func timed(_ id: String, seconds: Int, sets: Int = 1, rest: Int = 0) -> PlannedExercise {
        PlannedExercise(exerciseID: id, sets: sets, repsLow: 0, repsHigh: 0, holdSeconds: seconds, restSeconds: rest)
    }

    /// Moves the numbers by the last rating of this exercise: easy adds, at the limit takes away.
    private static func calibrated(_ item: PlannedExercise, logs: [WorkoutLog]) -> PlannedExercise {
        let last = logs.sorted { $0.finishedAt > $1.finishedAt }
            .lazy.compactMap { $0.entries.first { $0.exerciseID == item.exerciseID }?.feel }.first
        guard let last else { return item }
        var adjusted = item
        switch (last, item.exercise.isTimed) {
        case (.easy, false):
            adjusted.repsLow += 2
            adjusted.repsHigh += 2
            adjusted.calibration = "В прошлый раз было легко — +2 повтора"
        case (.easy, true):
            adjusted.holdSeconds += 10
            adjusted.calibration = "В прошлый раз было легко — +10 с"
        case (.limit, false):
            adjusted.sets = max(2, item.sets - 1)
            adjusted.repsLow = max(4, item.repsLow - 2)
            adjusted.repsHigh = max(6, item.repsHigh - 2)
            adjusted.calibration = "В прошлый раз на пределе — чуть легче"
        case (.limit, true):
            adjusted.holdSeconds = max(15, item.holdSeconds - 10)
            adjusted.calibration = "В прошлый раз на пределе — чуть короче"
        default:
            break
        }
        return adjusted
    }
}

/// Sets, repetitions and rest from the goal, and how many exercises from the level.
private struct Dose {
    let sets: Int
    let reps: ClosedRange<Int>
    let rest: Int
    let exerciseCount: Int

    init(goal: TrainingGoal?, experience: TrainingExperience?) {
        let level = experience.flatMap { TrainingExperience.allCases.firstIndex(of: $0) } ?? 1
        var sets: Int
        switch goal {
        case .muscleGain:
            (sets, reps, rest) = (4, 8...12, 90)
        case .fatLoss:
            (sets, reps, rest) = (3, 12...15, 45)
        case .maintenance, nil:
            (sets, reps, rest) = (3, 10...12, 60)
        }
        // Fewer sets while starting or coming back, one more for the experienced.
        if level <= 1 { sets = max(2, sets - 1) }
        if level == 4 { sets += 1 }
        self.sets = sets
        exerciseCount = [4, 4, 5, 5, 6][min(level, 4)]
    }
}
