import Foundation

enum ProfileGender: String, CaseIterable, Codable, Identifiable {
    // `undisclosed` is no longer offered; it stays so drafts saved earlier still decode.
    case female, male, undisclosed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .female: "Женщина"
        case .male: "Мужчина"
        case .undisclosed: "Не хочу указывать"
        }
    }
}

enum TrainingGoal: String, CaseIterable, Codable, Identifiable {
    case fatLoss, muscleGain, maintenance
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fatLoss: "Сушка"
        case .muscleGain: "Набор мышц"
        case .maintenance: "Поддержание формы"
        }
    }
    var detail: String {
        switch self {
        case .fatLoss: "Сделать акцент на составе тела"
        case .muscleGain: "Развивать силу и мышечную массу"
        case .maintenance: "Заниматься регулярно и сохранять форму"
        }
    }
}

/// Training experience from easiest to hardest; `allCases` is that order. Raw values of the first
/// three are stored in older drafts and stay unchanged.
enum TrainingExperience: String, CaseIterable, Codable, Identifiable {
    case beginner, returning, occasional, regular, advanced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .beginner: "Начинаю с нуля"
        case .returning: "Возвращаюсь после перерыва"
        case .occasional: "Тренируюсь время от времени"
        case .regular: "Уже занимаюсь регулярно"
        case .advanced: "Опытный атлет"
        }
    }
}

enum BodyZone: String, CaseIterable, Codable, Identifiable {
    case neck, shoulders, elbows, wrists, upperBack, lowerBack, hips, knees, ankles
    var id: String { rawValue }
    var title: String {
        switch self {
        case .neck: "Шея"
        case .shoulders: "Плечи"
        case .elbows: "Локти"
        case .wrists: "Кисти и запястья"
        case .upperBack: "Верх спины"
        case .lowerBack: "Поясница"
        case .hips: "Таз и бёдра"
        case .knees: "Колени"
        case .ankles: "Голеностоп и стопы"
        }
    }
}

enum LimitationKind: String, CaseIterable, Codable, Identifiable {
    case pastInjury, currentDiscomfort, movementRestriction
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pastInjury: "Травма в прошлом"
        case .currentDiscomfort: "Дискомфорт сейчас"
        case .movementRestriction: "Ограничение движения"
        }
    }
}

enum BodySide: String, CaseIterable, Codable, Identifiable {
    case unspecified, left, right, both
    var id: String { rawValue }
    var title: String {
        switch self {
        case .unspecified: "Не указана"
        case .left: "Слева"
        case .right: "Справа"
        case .both: "С обеих сторон"
        }
    }
}

struct BodyLimitation: Codable, Identifiable, Equatable {
    var id = UUID()
    var zone: BodyZone
    var side: BodySide = .unspecified
    var kind: LimitationKind = .pastInjury
    // nil means no rating supplied, not zero symptoms or medical clearance.
    var discomfortLevel: Int?
    var avoidMovements = ""
    var notes = ""
}

enum OnboardingStep: Int, CaseIterable, Codable, Identifiable {
    case introduction, body, goal, preferences, schedule, limitations, review
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .introduction: "Начнём с тебя"
        case .body: "О тебе"
        case .goal: "К чему идём?"
        case .preferences: "Твой уровень"
        case .schedule: "Твои дни"
        case .limitations: "Что важно учесть?"
        case .review: "Твой профиль"
        }
    }
    var subtitle: String {
        switch self {
        case .introduction: "Соберём профиль, чтобы будущий план подходил твоей жизни."
        case .body: "Эти данные можно изменить позже."
        case .goal: "Выбери главный ориентир. Он может меняться вместе с тобой."
        case .preferences: "Опыт, время и пожелания помогут подготовить подходящий план."
        case .schedule: "Выбери столько дней, сколько раз хочешь ходить в зал."
        case .limitations: "Отметь травмы и ограничения, которые нужно учитывать при подборе упражнений."
        case .review: "Проверь профиль перед сохранением. К любому шагу можно вернуться."
        }
    }
}

struct OnboardingDraft: Codable, Equatable {
    var schemaVersion = 1
    var profileID = UUID()
    var step: OnboardingStep = .introduction
    var name = ""
    var gender: ProfileGender?
    var heightText = ""
    var weightText = ""
    var goal: TrainingGoal?
    var experience: TrainingExperience?
    var durationMinutes = 60
    var wishes = ""
    var visitsPerWeek: Int { weekdays.count }
    // ISO weekdays: Monday = 1, Sunday = 7; deliberately independent of Calendar.weekday.
    var weekdays: Set<Int> = []
    var startHour = 18
    var startMinute = 0
    var limitationsReviewed = false
    var limitations: [BodyLimitation] = []

    static let weekdayNames = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    static let fullWeekdayNames = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]

    var height: Double? { Self.number(heightText) }
    var weight: Double? { Self.number(weightText) }
    var timeLabel: String { String(format: "%02d:%02d", startHour, startMinute) }
    var daysLabel: String { weekdays.sorted().map { Self.weekdayNames[$0 - 1] }.joined(separator: ", ") }

    static func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }

    func validationMessage(for step: OnboardingStep) -> String? {
        switch step {
        case .introduction:
            return nil
        case .body:
            guard gender == .female || gender == .male else { return "Выбери пол." }
            guard let height, height.isFinite, (80...250).contains(height) else {
                return "Укажи рост от 80 до 250 см. Это диапазон ввода, а не оценка здоровья."
            }
            guard let weight, weight.isFinite, (20...400).contains(weight) else {
                return "Укажи вес от 20 до 400 кг. Это диапазон ввода, а не оценка здоровья."
            }
        case .goal:
            if goal == nil { return "Выбери свою основную цель." }
        case .preferences:
            if experience == nil { return "Укажи свой опыт занятий." }
        case .schedule:
            if weekdays.isEmpty { return "Выбери хотя бы один день." }
        case .limitations:
            if !limitationsReviewed { return "Отметь ограничения или выбери «Нет известных ограничений»." }
        case .review:
            for earlier in OnboardingStep.allCases where earlier != .review {
                if let issue = validationMessage(for: earlier) { return issue }
            }
        }
        return nil
    }
}

struct LocalProfile: Codable {
    var schemaVersion = 1
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var details: OnboardingDraft
}
