import Foundation

/// A muscle group a training day works.
enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, arms, legs, glutes, core, mobility, cardio
    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: "Грудь"
        case .back: "Спина"
        case .shoulders: "Плечи"
        case .arms: "Руки"
        case .legs: "Ноги"
        case .glutes: "Ягодицы"
        case .core: "Пресс"
        case .mobility: "Мобильность"
        case .cardio: "Кардио"
        }
    }
}

/// One exercise of the catalog. `loads` are the body zones it puts real load on; an exercise that
/// loads a zone the person marked is replaced when a plan is made.
struct Exercise: Identifiable, Hashable {
    let id: String
    let title: String
    let group: MuscleGroup
    let symbol: String
    let loads: Set<BodyZone>
    /// Held or done for time (a plank, a cardio block) rather than counted in repetitions.
    var isTimed = false
}

/// An exercise as it stands in a day's plan.
struct PlannedExercise: Codable, Identifiable, Equatable {
    var id: String { exerciseID }
    let exerciseID: String
    var sets: Int
    var repsLow: Int
    var repsHigh: Int
    /// Target time of one set, for timed exercises.
    var holdSeconds: Int
    var restSeconds: Int
    /// Why the numbers moved since last time, from the person's own rating; nil when they did not.
    var calibration: String?
    var suggestedWeightKg: Double?
    var targetReserve: Int?
    var loadBlocked: Bool?

    var exercise: Exercise { ExerciseCatalog.exercise(exerciseID) }

    var targetText: String {
        if exercise.isTimed {
            let hold = holdSeconds >= 120 ? "\(holdSeconds / 60) мин" : "\(holdSeconds) с"
            return sets == 1 ? hold : "\(sets) × \(hold)"
        }
        return "\(sets) × \(repsLow)–\(repsHigh)"
    }
}

/// What kind of day it is.
enum WorkoutKind: String, Codable {
    case strength, cardio, light
}

struct WorkoutPlan: Codable, Equatable, Identifiable {
    var id: String { "\(kind.rawValue)-\(title)" }
    let kind: WorkoutKind
    let title: String
    let focus: [MuscleGroup]
    var exercises: [PlannedExercise]
    /// Zones whose exercises were swapped for others; shown so the person sees they were taken into account.
    var avoidedZones: [BodyZone] = []

    /// A rough length: working time plus rest, rounded to five minutes.
    var estimatedMinutes: Int {
        let seconds = exercises.reduce(0) { total, item in
            let work = item.exercise.isTimed ? item.holdSeconds : 45
            return total + item.sets * work + max(item.sets - 1, 0) * item.restSeconds
        }
        return max(5, Int((Double(seconds) / 60 / 5).rounded()) * 5)
    }
}

/// How an exercise felt, rated at the end of a workout. It calibrates the next plans.
enum ExerciseFeel: Int, Codable, CaseIterable, Identifiable {
    case easy = 1, fine, hard, limit
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .easy: "Легко"
        case .fine: "В самый раз"
        case .hard: "Тяжело"
        case .limit: "На пределе"
        }
    }
}

/// What a set was for. Only ordinary sets, to failure and drop sets count toward the planned sets and
/// the volume; a warm-up is written down but stays outside both.
enum SetKind: String, Codable, CaseIterable, Identifiable {
    case normal, warmup, failure, dropSet
    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Рабочий"
        case .warmup: "Разминка"
        case .failure: "До отказа"
        case .dropSet: "Дроп-сет"
        }
    }

    /// Said after the numbers in a summary; nil for an ordinary set.
    var tag: String? {
        switch self {
        case .normal: nil
        case .warmup: "разминка"
        case .failure: "до отказа"
        case .dropSet: "дроп-сет"
        }
    }
}

/// One set as it was done: the weight and repetitions, or the seconds held for a timed exercise.
/// A field is nil when it does not apply (no weight for bodyweight work).
struct SetEntry: Codable, Equatable, Identifiable {
    var id = UUID()
    var weightKg: Double?
    var reps: Int?
    var seconds: Int?
    var kind: SetKind = .normal

    /// Weight times repetitions; zero without either, and for a warm-up.
    var volumeKg: Double { kind == .warmup ? 0 : (weightKg ?? 0) * Double(reps ?? 0) }

    /// "60 кг × 10", "12 повторений" or "40 с", with the kind after them when it is not an ordinary set.
    var summary: String {
        let numbers = numbersText
        guard let tag = kind.tag else { return numbers }
        return "\(numbers) · \(tag)"
    }

    /// The summary for a row titled by `rowTitles`: a warm-up row is already named "Разминка", so its tag is left off.
    var rowSummary: String { kind == .warmup ? numbersText : summary }

    private var numbersText: String {
        if let seconds { return "\(seconds) с" }
        let count = reps ?? 0
        guard let weightKg, weightKg > 0 else {
            return "\(count) \(RussianPlural.form(count, one: "повторение", few: "повторения", many: "повторений"))"
        }
        return "\(WeightFormat.kg(weightKg)) кг × \(count)"
    }
}

extension Array where Element == SetEntry {
    /// A name for each row of a list of sets: "Подход 1, 2…" counting only the working sets, and "Разминка"
    /// for a warm-up, so the numbers match the "3 из 3" shown beside them.
    func rowTitles(noun: String) -> [String] {
        var working = 0
        return map { entry in
            guard entry.kind != .warmup else { return "Разминка" }
            working += 1
            return "\(noun) \(working)"
        }
    }
}

extension SetEntry {
    private enum CodingKeys: String, CodingKey { case id, weightKg, reps, seconds, kind }

    /// A set written before kinds existed reads as an ordinary one.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        seconds = try container.decodeIfPresent(Int.self, forKey: .seconds)
        kind = try container.decodeIfPresent(SetKind.self, forKey: .kind) ?? .normal
    }
}

/// How a day counts what was done: sets for strength work, blocks for cardio, where each block is
/// one stretch of time.
struct SetWords {
    /// "Подходов" or "Блоков", before a count.
    let progress: String
    private let one: String
    private let few: String
    private let many: String

    static let sets = SetWords(progress: "Подходов", one: "подход", few: "подхода", many: "подходов")
    static let blocks = SetWords(progress: "Блоков", one: "блок", few: "блока", many: "блоков")

    func form(_ count: Int) -> String { RussianPlural.form(count, one: one, few: few, many: many) }
}

extension WorkoutKind {
    var setWords: SetWords { self == .cardio ? .blocks : .sets }
}

enum WeightFormat {
    /// "60" or "62,5".
    static func kg(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}

struct ExerciseLog: Codable, Equatable, Identifiable {
    var id: String { exerciseID }
    let exerciseID: String
    var setsPlanned: Int
    var setsDone: Int
    var feel: ExerciseFeel?
    /// What was done, set by set; empty in logs made before sets were recorded.
    var sets: [SetEntry] = []
    var feedback: ExerciseFeedback?

    private enum CodingKeys: String, CodingKey { case exerciseID, setsPlanned, setsDone, feel, sets, feedback }

    init(exerciseID: String, setsPlanned: Int, setsDone: Int, feel: ExerciseFeel?, sets: [SetEntry] = [], feedback: ExerciseFeedback? = nil) {
        self.exerciseID = exerciseID
        self.setsPlanned = setsPlanned
        self.setsDone = setsDone
        self.feel = feel
        self.sets = sets
        self.feedback = feedback
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseID = try container.decode(String.self, forKey: .exerciseID)
        setsPlanned = try container.decode(Int.self, forKey: .setsPlanned)
        setsDone = try container.decode(Int.self, forKey: .setsDone)
        feel = try container.decodeIfPresent(ExerciseFeel.self, forKey: .feel)
        sets = try container.decodeIfPresent([SetEntry].self, forKey: .sets) ?? []
        feedback = try container.decodeIfPresent(ExerciseFeedback.self, forKey: .feedback)
    }
}

struct WorkoutLog: Codable, Equatable, Identifiable {
    var id = UUID()
    let kind: WorkoutKind
    let title: String
    let startedAt: Date
    let finishedAt: Date
    var entries: [ExerciseLog]
    /// The planned slot this workout completed; nil for rest-day activity and for logs made before slots existed.
    var sessionKey: DayKey?
    /// The sets the plan called for, exercises never started included; nil in older logs.
    var plannedSets: Int?
    /// The exercises the plan held, in order, those never started included; nil in older logs.
    var plannedExerciseIDs: [String]?

    private enum CodingKeys: String, CodingKey {
        case id, kind, title, startedAt, finishedAt, entries, sessionKey, plannedSets, plannedExerciseIDs
    }

    init(id: UUID = UUID(), kind: WorkoutKind, title: String, startedAt: Date, finishedAt: Date, entries: [ExerciseLog],
         sessionKey: DayKey? = nil, plannedSets: Int? = nil, plannedExerciseIDs: [String]? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.entries = entries
        self.sessionKey = sessionKey
        self.plannedSets = plannedSets
        self.plannedExerciseIDs = plannedExerciseIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(WorkoutKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        finishedAt = try container.decode(Date.self, forKey: .finishedAt)
        entries = try container.decode([ExerciseLog].self, forKey: .entries)
        sessionKey = try container.decodeIfPresent(DayKey.self, forKey: .sessionKey)
        plannedSets = try container.decodeIfPresent(Int.self, forKey: .plannedSets)
        plannedExerciseIDs = try container.decodeIfPresent([String].self, forKey: .plannedExerciseIDs)
    }

    var setsDone: Int { entries.reduce(0) { $0 + $1.setsDone } }
    var setsPlanned: Int { max(plannedSets ?? entries.reduce(0) { $0 + $1.setsPlanned }, setsDone) }
    /// Finished before every planned set was done; counted as done all the same, since the person ended it.
    var isPartial: Bool { setsDone < setsPlanned }
    var volumeKg: Double { entries.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.volumeKg } } }
    var minutes: Int { max(1, Int(finishedAt.timeIntervalSince(startedAt) / 60)) }
    func day(calendar: Calendar = .current) -> DayKey { DayKey(finishedAt, calendar: calendar) }
}

// MARK: - Catalog

enum ExerciseCatalog {
    static func exercise(_ id: String) -> Exercise {
        byID[id] ?? Exercise(id: id, title: id, group: .core, symbol: "figure.strengthtraining.functional", loads: [])
    }

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static let all: [Exercise] = [
        // Chest
        Exercise(id: "bench-press", title: "Жим штанги лёжа", group: .chest, symbol: "figure.strengthtraining.traditional",
                 loads: [.shoulders, .elbows, .wrists]),
        Exercise(id: "incline-db-press", title: "Жим гантелей на наклонной", group: .chest,
                 symbol: "figure.strengthtraining.traditional", loads: [.shoulders, .elbows]),
        Exercise(id: "machine-press", title: "Жим в тренажёре", group: .chest, symbol: "dumbbell.fill", loads: [.elbows]),
        Exercise(id: "push-ups", title: "Отжимания", group: .chest, symbol: "figure.core.training",
                 loads: [.shoulders, .elbows, .wrists]),
        Exercise(id: "cable-fly", title: "Сведения в кроссовере", group: .chest, symbol: "figure.mixed.cardio", loads: [.shoulders]),
        // Shoulders
        Exercise(id: "db-shoulder-press", title: "Жим гантелей сидя", group: .shoulders,
                 symbol: "figure.strengthtraining.traditional", loads: [.shoulders, .elbows]),
        Exercise(id: "lateral-raise", title: "Махи в стороны", group: .shoulders, symbol: "figure.arms.open", loads: [.shoulders]),
        Exercise(id: "face-pull", title: "Тяга к лицу", group: .shoulders, symbol: "figure.rower", loads: [.elbows]),
        Exercise(id: "rear-delt-fly", title: "Разведения в наклоне", group: .shoulders, symbol: "figure.arms.open",
                 loads: [.lowerBack]),
        // Back
        Exercise(id: "lat-pulldown", title: "Тяга верхнего блока", group: .back, symbol: "figure.climbing",
                 loads: [.shoulders, .elbows]),
        Exercise(id: "pull-ups", title: "Подтягивания", group: .back, symbol: "figure.climbing",
                 loads: [.shoulders, .elbows, .wrists]),
        Exercise(id: "seated-row", title: "Тяга горизонтального блока", group: .back, symbol: "figure.rower", loads: [.elbows]),
        Exercise(id: "db-row", title: "Тяга гантели в наклоне", group: .back, symbol: "figure.strengthtraining.functional",
                 loads: [.lowerBack, .elbows]),
        Exercise(id: "machine-row", title: "Тяга в тренажёре с упором", group: .back, symbol: "figure.rower", loads: []),
        Exercise(id: "back-extension", title: "Гиперэкстензия", group: .back, symbol: "figure.flexibility", loads: [.lowerBack]),
        Exercise(id: "deadlift", title: "Становая тяга классическая", group: .back, symbol: "figure.strengthtraining.traditional",
                 loads: [.lowerBack, .hips, .knees, .wrists]),
        // Arms
        Exercise(id: "barbell-curl", title: "Подъём штанги на бицепс", group: .arms, symbol: "dumbbell.fill",
                 loads: [.elbows, .wrists]),
        Exercise(id: "hammer-curl", title: "Молотки с гантелями", group: .arms, symbol: "dumbbell.fill", loads: [.elbows]),
        Exercise(id: "cable-curl", title: "Сгибания на блоке", group: .arms, symbol: "dumbbell.fill", loads: [.elbows]),
        Exercise(id: "triceps-pushdown", title: "Разгибания на блоке", group: .arms, symbol: "dumbbell.fill", loads: [.elbows]),
        Exercise(id: "overhead-extension", title: "Разгибания из-за головы", group: .arms, symbol: "dumbbell.fill",
                 loads: [.elbows, .shoulders]),
        Exercise(id: "dips", title: "Отжимания на брусьях", group: .arms, symbol: "figure.strengthtraining.functional",
                 loads: [.shoulders, .elbows, .wrists]),
        // Legs
        Exercise(id: "back-squat", title: "Приседания со штангой", group: .legs, symbol: "figure.strengthtraining.traditional",
                 loads: [.knees, .hips, .lowerBack, .ankles]),
        Exercise(id: "leg-press", title: "Жим ногами", group: .legs, symbol: "figure.strengthtraining.functional",
                 loads: [.knees, .hips]),
        Exercise(id: "goblet-squat", title: "Гоблет-присед", group: .legs, symbol: "figure.strengthtraining.functional",
                 loads: [.knees, .hips]),
        Exercise(id: "romanian-deadlift", title: "Румынская тяга", group: .legs, symbol: "figure.strengthtraining.traditional",
                 loads: [.lowerBack, .hips]),
        Exercise(id: "lunges", title: "Выпады", group: .legs, symbol: "figure.walk", loads: [.knees, .hips, .ankles]),
        Exercise(id: "leg-curl", title: "Сгибания ног в тренажёре", group: .legs, symbol: "figure.cooldown", loads: [.knees]),
        Exercise(id: "leg-extension", title: "Разгибания ног в тренажёре", group: .legs, symbol: "figure.cooldown",
                 loads: [.knees]),
        Exercise(id: "calf-raise", title: "Подъёмы на носки", group: .legs, symbol: "figure.step.training", loads: [.ankles]),
        // Glutes
        Exercise(id: "hip-thrust", title: "Ягодичный мост со штангой", group: .glutes, symbol: "figure.core.training",
                 loads: [.hips]),
        Exercise(id: "glute-bridge", title: "Ягодичный мост", group: .glutes, symbol: "figure.core.training", loads: []),
        Exercise(id: "cable-kickback", title: "Отведения ноги на блоке", group: .glutes, symbol: "figure.kickboxing",
                 loads: [.hips]),
        // Core
        Exercise(id: "crunch", title: "Скручивания", group: .core, symbol: "figure.core.training", loads: [.neck]),
        Exercise(id: "reverse-crunch", title: "Обратные скручивания", group: .core, symbol: "figure.core.training",
                 loads: [.lowerBack]),
        Exercise(id: "hanging-leg-raise", title: "Подъёмы ног в висе", group: .core, symbol: "figure.climbing",
                 loads: [.shoulders, .wrists, .hips]),
        Exercise(id: "plank", title: "Планка", group: .core, symbol: "figure.core.training", loads: [.shoulders, .wrists],
                 isTimed: true),
        Exercise(id: "side-plank", title: "Боковая планка", group: .core, symbol: "figure.core.training", loads: [.shoulders],
                 isTimed: true),
        Exercise(id: "bicycle", title: "Велосипед", group: .core, symbol: "figure.core.training", loads: [.neck]),
        Exercise(id: "dead-bug", title: "Мёртвый жук", group: .core, symbol: "figure.core.training", loads: []),
        Exercise(id: "bird-dog", title: "Птица-собака", group: .core, symbol: "figure.cross.training", loads: []),
        // Mobility
        Exercise(id: "cat-cow", title: "Кошка-корова", group: .mobility, symbol: "figure.yoga", loads: [], isTimed: true),
        Exercise(id: "hip-opener", title: "Раскрытие тазобедренных", group: .mobility, symbol: "figure.flexibility", loads: [],
                 isTimed: true),
        Exercise(id: "thoracic-rotation", title: "Ротации грудного отдела", group: .mobility, symbol: "figure.yoga", loads: [],
                 isTimed: true),
        Exercise(id: "hamstring-stretch", title: "Растяжка задней поверхности", group: .mobility, symbol: "figure.flexibility",
                 loads: [], isTimed: true),
        // Cardio
        Exercise(id: "incline-walk", title: "Ходьба в горку", group: .cardio, symbol: "figure.walk", loads: [.ankles],
                 isTimed: true),
        Exercise(id: "bike", title: "Велотренажёр", group: .cardio, symbol: "figure.indoor.cycle", loads: [.knees], isTimed: true),
        Exercise(id: "elliptical", title: "Эллипс", group: .cardio, symbol: "figure.elliptical", loads: [.knees], isTimed: true),
        Exercise(id: "rower", title: "Гребной тренажёр", group: .cardio, symbol: "figure.rower",
                 loads: [.lowerBack, .knees], isTimed: true),
        Exercise(id: "easy-walk", title: "Спокойная ходьба", group: .cardio, symbol: "figure.walk", loads: [], isTimed: true),
    ]
}
