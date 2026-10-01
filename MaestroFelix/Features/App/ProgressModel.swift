import Foundation
import Observation

/// The numbers behind the progress tab and what has been unlocked so far.
@MainActor @Observable
final class ProgressModel {
    private(set) var stats = TrainingStats()
    private(set) var achievements = AchievementsState()
    var storageError: String?

    @ObservationIgnored private let store: any DocumentStore

    init(store: any DocumentStore) {
        self.store = store
        do {
            achievements = try store.load(AchievementsState.self, key: StoreKey.achievements) ?? AchievementsState()
        } catch {
            storageError = "Не удалось прочитать достижения."
        }
    }

    func update(_ stats: TrainingStats) {
        self.stats = stats
    }

    /// Unlocks what the current stats meet and were not unlocked before, and returns just those.
    /// Called again with nothing new, it returns nothing.
    @discardableResult
    func unlock(at date: Date) -> [AchievementID] {
        let fresh = AchievementRules.newlyMet(stats: stats, state: achievements)
        guard !fresh.isEmpty else { return [] }
        var updated = achievements
        for id in fresh { updated.unlocked[id.rawValue] = date }
        do {
            try store.save(updated, key: StoreKey.achievements)
            achievements = updated
            return fresh
        } catch {
            storageError = "Не удалось сохранить достижения."
            return []
        }
    }
}
