import Foundation
import Testing
@testable import MaestroFelix

struct CoachTests {
    private static let combos = CoachTone.allCases.flatMap { tone in CoachEvent.allCases.map { (tone, $0) } }

    @Test("every tone has at least two lines per event that need no next session", arguments: combos)
    func enoughLinesWithoutANextSession(tone: CoachTone, event: CoachEvent) {
        let plain = CoachCatalog.templates(for: event, tone: tone).filter { !$0.contains("{next}") }
        #expect(plain.count >= 2)
    }

    @Test("no line shames, judges the body or claims a health assessment", arguments: combos)
    func linesStayKind(tone: CoachTone, event: CoachEvent) {
        let banned = ["толст", "жир", "ленив", "стыд", "здоровь", "диагноз", "нельзя", "слаб", "вес "]
        for line in CoachCatalog.templates(for: event, tone: tone) {
            for word in banned { #expect(!line.lowercased().contains(word), "\(line) contains \(word)") }
        }
    }

    @Test func aLineNeedingTheNextSessionIsLeftOutWithoutOne() {
        let persona = CoachCatalog.persona("vera")
        for seed in 0..<12 {
            let line = CoachCatalog.line(for: .restDay, persona: persona, context: CoachContext(), seed: seed)
            #expect(!line.contains("{") && !line.contains("Следующая тренировка"))
        }
    }

    @Test func aLineCanNameTheNextSession() {
        let persona = CoachCatalog.persona("vera")
        let lines = (0..<6).map { CoachCatalog.line(for: .restDay, persona: persona, context: CoachContext(nextDay: "в пятницу"), seed: $0) }
        #expect(lines.contains("Сегодня отдых по плану. Следующая тренировка — в пятницу."))
    }

    @Test func theNameIsWovenInOrLeftOutCleanly() {
        let persona = CoachCatalog.persona("vera")
        let named = (0..<3).map { CoachCatalog.line(for: .welcome, persona: persona, context: CoachContext(name: "Аня"), seed: $0) }
        #expect(named.contains("Привет, Аня. Идём по плану, шаг за шагом."))
        let anonymous = (0..<3).map { CoachCatalog.line(for: .welcome, persona: persona, context: CoachContext(name: "  "), seed: $0) }
        #expect(anonymous.allSatisfy { !$0.contains(", .") && !$0.contains("{") && !$0.contains(" ,") && !$0.contains("  ") })
    }

    @Test("the same line does not come twice in a row", arguments: CoachCatalog.personas.map(\.id))
    func avoidsTheLastLine(personaID: String) {
        let persona = CoachCatalog.persona(personaID)
        for event in CoachEvent.allCases {
            for seed in 0..<9 {
                let first = CoachCatalog.line(for: event, persona: persona, context: CoachContext(), seed: seed)
                let second = CoachCatalog.line(for: event, persona: persona, context: CoachContext(), seed: seed, avoiding: first)
                #expect(first != second)
            }
        }
    }

    @Test func aSeedAlwaysGivesTheSameLine() {
        let persona = CoachCatalog.persona("max")
        let one = CoachCatalog.line(for: .sessionCompleted, persona: persona, context: CoachContext(), seed: 41)
        let two = CoachCatalog.line(for: .sessionCompleted, persona: persona, context: CoachContext(), seed: 41)
        #expect(one == two)
    }

    @Test func unknownCoachFallsBackToTheFirst() {
        #expect(CoachCatalog.persona("nobody").id == CoachCatalog.personas[0].id)
        #expect(CoachCatalog.persona(nil).id == CoachCatalog.personas[0].id)
    }

    @Test func eachCoachHasItsOwnToneAndLook() {
        #expect(Set(CoachCatalog.personas.map(\.tone)).count == CoachCatalog.personas.count)
        #expect(Set(CoachCatalog.personas.map(\.symbol)).count == CoachCatalog.personas.count)
    }

    @Test func stateReadsOldDataAndSurvivesJSON() throws {
        #expect(try JSONDecoder().decode(CoachState.self, from: Data("{}".utf8)).personaID == "vera")
        var state = CoachState()
        state.personaID = "yan"
        #expect(try JSONDecoder().decode(CoachState.self, from: JSONEncoder().encode(state)) == state)
    }
}
