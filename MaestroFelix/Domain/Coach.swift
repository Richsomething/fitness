import Foundation

/// How the coach speaks. The tone changes the words only — never the exercises or the load.
enum CoachTone: String, Codable, CaseIterable, Identifiable {
    case calm, energetic, focused, supportive
    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "Спокойный"
        case .energetic: "Энергичный"
        case .focused: "Собранный"
        case .supportive: "Заботливый"
        }
    }
}

/// An original virtual character with a specialty and a distinct speaking style.
struct CoachPersona: Identifiable, Equatable {
    let id: String
    let name: String
    let tone: CoachTone
    let symbol: String
    let blurb: String
    let specialty: String
    let approach: String
    var portrait: String { "coach-" + id + "-expressions" }
    var selectionLine: String {
        switch tone {
        case .calm: "Договорились. Каждый повтор — под контролем. Начинаем."
        case .energetic: "Теперь работаем жёстче. По твоему плану — с моим огнём!"
        case .focused: "Любопытно. Проверим, на что ты способен. Результаты запишем."
        case .supportive: "Ну что, напарник? Я рядом. Дойдём в твоём темпе."
        }
    }
}

enum CoachEvent: String, Codable, CaseIterable {
    case welcome, upcomingWorkout, restDay, sessionCompleted, missedSession, returnAfterPause
}

/// Fixed frames in each bundled 3 × 2 expression sheet. No image generation at runtime.
enum CoachEmotion: Int, CaseIterable, Identifiable {
    case neutral, focused, encouraging, proud, supportive, relaxed
    var id: Int { rawValue }
    var column: Int { rawValue % 3 }
    var row: Int { rawValue / 3 }
    var title: String {
        switch self {
        case .neutral: "Знакомство"
        case .focused: "Концентрация"
        case .encouraging: "Вперёд"
        case .proud: "Результат"
        case .supportive: "Поддержка"
        case .relaxed: "Отдых"
        }
    }
    static func forEvent(_ event: CoachEvent) -> Self {
        switch event {
        case .welcome: .neutral
        case .upcomingWorkout: .focused
        case .sessionCompleted: .proud
        case .missedSession: .supportive
        case .returnAfterPause: .encouraging
        case .restDay: .relaxed
        }
    }
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
        CoachPersona(id: "vera", name: "Вера", tone: .calm, symbol: "leaf.fill", blurb: "Точность важнее спешки.", specialty: "Техника и контроль", approach: "Внимательная и спокойная. Помогает сосредоточиться на движении и ровном темпе."),
        CoachPersona(id: "max", name: "Макс", tone: .energetic, symbol: "bolt.fill", blurb: "Сильнее с каждым подходом.", specialty: "Сила", approach: "Азартный и прямой. Заряжает на работу, ценит усилие и радуется каждому завершённому занятию."),
        CoachPersona(id: "yan", name: "Ян", tone: .focused, symbol: "scope", blurb: "Прогресс начинается с системы.", specialty: "Рост мышц", approach: "Сдержанный аналитик. Говорит коротко, замечает последовательность и напоминает записывать результаты."),
        CoachPersona(id: "lev", name: "Лев", tone: .supportive, symbol: "sun.max.fill", blurb: "Вернуться — уже хороший шаг.", specialty: "Возвращение в форму", approach: "Терпеливый наставник с тёплым юмором. Поддерживает после пауз и помогает сохранять ритм."),
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
            ["Сегодня следим за движением. Чётко, спокойно, без спешки.", "Красивый подход начинается с контроля. Начнём с разминки.", "Держим ровный темп. Каждый повтор — осознанно."]
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
            ["Собираем силу по одному подходу! Начнём с разминки.", "План готов! Сегодня работаем уверенно, без гонки за рекордом.", "Твой следующий шаг к силе — прийти и сделать план. Погнали!"]
        case (.energetic, .restDay):
            ["Сегодня заслуженный отдых! Дальше — {next}.", "Отдыхаем и набираемся сил!", "День отдыха! А хочешь размяться — есть лёгкий блок."]
        case (.energetic, .sessionCompleted):
            ["Есть! Ещё одна тренировка в копилке!", "Отличная работа{, name}! Так держать!", "Сделано! Ты молодец."]
        case (.energetic, .missedSession):
            ["Не беда! Следующая тренировка — твоя.", "Бывает! Главное — вернуться.", "Всё впереди. Ждём тебя на следующем занятии!"]
        case (.energetic, .returnAfterPause):
            ["Ты вернулся{, name}! Отлично, снова в деле.", "С возвращением! Разгоняемся потихоньку.", "Пауза позади — поехали!"]

        case (.supportive, .welcome):
            ["Привет{, name}. Найдём ритм, который впишется в твою жизнь.", "Хорошо, что ты здесь. Начнём без суеты."]
        case (.supportive, .upcomingWorkout):
            ["Форма возвращается шагами. Сегодня сделаем один.", "Разминка, первый блок — и мы снова в ритме. Без геройства."]
        case (.supportive, .restDay):
            ["Сегодня отдыхаем. Даже у привычки бывают выходные.", "Восстановление входит в план. Можно выдохнуть.", "Следующая встреча — {next}. Сегодня набираемся сил."]
        case (.supportive, .sessionCompleted):
            ["Ещё одна встреча с собой состоялась. Хорошая работа{, name}.", "На сегодня достаточно. Ритм строится из таких дней."]
        case (.supportive, .missedSession):
            ["Один пропуск не перечёркивает путь. Вернёмся на следующем занятии.", "Жизнь иногда меняет расписание. Продолжим, когда получится."]
        case (.supportive, .returnAfterPause):
            ["С возвращением{, name}. Рекорды подождут, сначала найдём ритм.", "Давно не виделись. Начнём спокойно — мы никуда не опаздываем."]

        case (.focused, .welcome):
            ["План готов. Начинаем.", "Всё на месте{, name}. Приступаем.", "Профиль загружен. Готов к работе."]
        case (.focused, .upcomingWorkout):
            ["План готов. Качественные подходы, затем запись результата.", "Рост любит последовательность. Начинаем с первого блока.", "Работаем по плану. Результаты сохраняем для следующего занятия."]
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
