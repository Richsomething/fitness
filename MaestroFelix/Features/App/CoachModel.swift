import Foundation
import Observation

/// The coach the person picked. Lines are chosen from the day, so a screen shows the same words all
/// day and the next day brings others.
@MainActor @Observable
final class CoachModel {
    private(set) var state = CoachState()
    var storageError: String?

    @ObservationIgnored private let store: any DocumentStore

    init(store: any DocumentStore) {
        self.store = store
        do {
            state = try store.load(CoachState.self, key: StoreKey.coach) ?? CoachState()
        } catch {
            storageError = "Не удалось прочитать выбор тренера."
        }
    }

    var persona: CoachPersona { CoachCatalog.persona(state.personaID) }

    /// Changing the coach changes the words and nothing else: not the plan, not the history.
    @discardableResult
    func select(_ id: String) -> Bool {
        var updated = state
        updated.personaID = CoachCatalog.persona(id).id
        do {
            try store.save(updated, key: StoreKey.coach)
            state = updated
            storageError = nil
            return true
        } catch {
            storageError = "Не удалось сохранить выбор тренера."
            return false
        }
    }

    func line(for event: CoachEvent, context: CoachContext, seed: Int) -> String {
        CoachCatalog.line(for: event, persona: persona, context: context, seed: seed)
    }
}
