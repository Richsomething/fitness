import Foundation

/// How the coach speaks. The tone changes the words only — never the exercises or the load.
enum CoachTone: String, Codable, CaseIterable, Identifiable {
    case calm, energetic, focused
    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "Спокойный"
        case .energetic: "Энергичный"
        case .focused: "Собранный"
        }
    }
}

/// A virtual coach the person picks: a name, a tone and a look. The look is a placeholder emblem until
/// the characters are drawn; a coach is never presented as a live person.
struct CoachPersona: Identifiable, Equatable {
    let id: String
    let name: String
    let tone: CoachTone
    let symbol: String
    let blurb: String
}

enum CoachEvent: String, Codable, CaseIterable {
    case welcome, upcomingWorkout, restDay, sessionCompleted, missedSession, returnAfterPause
}

/// What a line may mention. Nothing about the body, the weight or the health.
struct CoachContext: Equatable {
    var name: String?
    /// The next session as it reads after "Следующая тренировка —": "завтра", "в пятницу".
    var nextDay: String?
}

struct CoachState: Codable, Equatable {
    var personaID = CoachCatalog.personas[0].id

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        personaID = try container.decodeIfPresent(String.self, forKey: .personaID) ?? CoachCatalog.personas[0].id
    }

    private enum CodingKeys: String, CodingKey { case personaID }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

enum CoachCatalog {
    static let personas = [
        CoachPersona(id: "vera", name: "Вера", tone: .calm, symbol: "leaf.fill", blurb: "Идём шаг за шагом, в твоём темпе."),
        CoachPersona(id: "max", name: "Макс", tone: .energetic, symbol: "bolt.fill", blurb: "Подбадриваю и зову вперёд."),
        CoachPersona(id: "yan", name: "Ян", tone: .focused, symbol: "scope", blurb: "Коротко и по делу."),
    ]

    static func persona(_ id: String?) -> CoachPersona {
        personas.first { $0.id == id } ?? personas[0]
    }

    /// A line for `event`. `{, name}` becomes ", Имя" or nothing; a line that needs `{next}` is left
    /// out when there is no next session. `seed` picks among the rest; `avoiding` is skipped when
    /// there is another choice.
    static func line(for event: CoachEvent, persona: CoachPersona, context: CoachContext, seed: Int,
                     avoiding: String? = nil) -> String {
        let usable = templates(for: event, tone: persona.tone)
            .filter { context.nextDay != nil || !$0.contains("{next}") }
            .map { render($0, context: context) }
        let fresh = usable.filter { $0 != avoiding }
        let pool = fresh.isEmpty ? usable : fresh
        return pool[abs(seed) % max(pool.count, 1)]
    }

    private static func render(_ template: String, context: CoachContext) -> String {
        let name = context.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        return template
            .replacingOccurrences(of: "{, name}", with: name.map { ", \($0)" } ?? "")
            .replacingOccurrences(of: "{next}", with: context.nextDay ?? "")
    }

    static func templates(for event: CoachEvent, tone: CoachTone) -> [String] {
        switch (tone, event) {
        case (.calm, .welcome):
            ["Привет{, name}. Идём по плану, шаг за шагом.", "Рад тебя видеть{, name}. Начнём спокойно.", "Всё готово. Двигаемся в своём темпе."]
        case (.calm, .upcomingWorkout):
            ["Сегодня идём по плану, шаг за шагом.", "Тренировка ждёт — без спешки, в своём темпе.", "Разомнись и начинай, когда будешь готов."]
        case (.calm, .restDay):
            ["Сегодня отдых по плану. Следующая тренировка — {next}.", "Восстановление — тоже часть плана.",
             "День отдыха. Хочется подвигаться — есть лёгкий вариант."]
        case (.calm, .sessionCompleted):
            ["Хорошая работа. Теперь можно отдохнуть.", "Тренировка позади. Спасибо, что пришёл{, name}.", "Готово. Каждое занятие складывается в ритм."]
        case (.calm, .missedSession):
            ["Ничего страшного. План можно продолжить в любой момент.", "Бывает. Вернёмся к плану, когда будет удобно.",
             "Пропуск — не проблема. Ждём тебя на следующем занятии."]
        case (.calm, .returnAfterPause):
            ["С возвращением{, name}. Начнём мягко.", "Рад, что ты снова здесь. Без спешки.",
             "Пауза закончилась. Продолжаем с того места, где остановились."]

        case (.energetic, .welcome):
            ["Привет{, name}! Готов двигаться?", "Ты здесь — уже отлично! Погнали?", "Так, посмотрим, что у нас сегодня!"]
        case (.energetic, .upcomingWorkout):
            ["Твоя тренировка уже ждёт. Начнём?", "Время действовать! План готов.", "Сегодня твой день. Жми «Начать»!"]
        case (.energetic, .restDay):
            ["Сегодня заслуженный отдых! Дальше — {next}.", "Отдыхаем и набираемся сил!", "День отдыха! А хочешь размяться — есть лёгкий блок."]
        case (.energetic, .sessionCompleted):
            ["Есть! Ещё одна тренировка в копилке!", "Отличная работа{, name}! Так держать!", "Сделано! Ты молодец."]
        case (.energetic, .missedSession):
            ["Не беда! Следующая тренировка — твоя.", "Бывает! Главное — вернуться.", "Всё впереди. Ждём тебя на следующем занятии!"]
        case (.energetic, .returnAfterPause):
            ["Ты вернулся{, name}! Отлично, снова в деле.", "С возвращением! Разгоняемся потихоньку.", "Пауза позади — поехали!"]

        case (.focused, .welcome):
            ["План готов. Начинаем.", "Всё на месте{, name}. Приступаем.", "Профиль загружен. Готов к работе."]
        case (.focused, .upcomingWorkout):
            ["План готов. Начинаем с первого блока.", "Сегодня по плану тренировка. Приступай.", "Всё подготовлено. Первое упражнение ждёт."]
        case (.focused, .restDay):
            ["Сегодня отдых по плану. Следующее занятие — {next}.", "Отдых. Восстановление запланировано.", "День без тренировки. Лёгкий блок — по желанию."]
        case (.focused, .sessionCompleted):
            ["Занятие выполнено. Записано.", "Блок закрыт. Хорошая работа{, name}.", "Тренировка завершена. Результат сохранён."]
        case (.focused, .missedSession):
            ["Занятие пропущено. Продолжаем по плану.", "Пропуск учтён. Следующее занятие — по расписанию.", "Возвращаемся к плану на следующем занятии."]
        case (.focused, .returnAfterPause):
            ["Пауза завершена. Возвращаемся к плану.", "Расписание снова активно{, name}.", "Продолжаем с текущего занятия."]
        }
    }
}
