import Foundation
import Observation

/// The person's weighings over time.
@MainActor @Observable
final class WeightModel {
    private(set) var entries: [WeightEntry] = []
    var storageError: String?

    @ObservationIgnored private let store: any DocumentStore
    @ObservationIgnored private let calendar: Calendar

    init(store: any DocumentStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        do {
            entries = try store.load([WeightEntry].self, key: StoreKey.weights) ?? []
        } catch {
            storageError = "Не удалось прочитать записи веса."
        }
    }

    var latest: WeightEntry? { entries.last }
    var change: Double? { WeightHistory.change(entries) }

    /// Adds a weighing; a second one on the same day replaces the first. False for a weight outside
    /// what the profile accepts, or when storage fails.
    @discardableResult
    func add(_ kg: Double, on date: Date = .now) -> Bool {
        guard kg.isFinite, WeightHistory.allowed.contains(kg) else { return false }
        let updated = WeightHistory.adding(kg, on: date, to: entries, calendar: calendar)
        do {
            try store.save(updated, key: StoreKey.weights)
            entries = updated
            storageError = nil
            return true
        } catch {
            storageError = "Не удалось сохранить вес. Попробуй ещё раз."
            return false
        }
    }
}
