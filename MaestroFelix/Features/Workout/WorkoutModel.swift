import Foundation
import Observation

/// Finished workouts and the one in progress. Logs calibrate the next plans and fill the history.
@MainActor @Observable
final class WorkoutModel {
    private(set) var logs: [WorkoutLog] = []
    /// A workout that was under way when the app went away, if the record still fits its plan.
    private(set) var resumable: SessionSnapshot?
    var storageError: String?

    @ObservationIgnored private let store: any DocumentStore
    /// Where new workouts go when the main record cannot be read: it is left untouched, not overwritten.
    @ObservationIgnored private var mainIsReadable = true

    static let recoveredKey = "workoutLogs.recovered"

    init(store: any DocumentStore) {
        self.store = store
        var main: [WorkoutLog] = []
        do {
            main = try store.load([WorkoutLog].self, key: StoreKey.workoutLogs) ?? []
        } catch {
            mainIsReadable = false
            storageError = "Не удалось прочитать историю тренировок. Новые тренировки сохранятся отдельно."
        }
        let recovered = (try? store.load([WorkoutLog].self, key: Self.recoveredKey)) ?? []
        logs = main + recovered.filter { extra in !main.contains { $0.id == extra.id } }
        if mainIsReadable, !recovered.isEmpty { mergeRecovered() }
        resumable = loadSnapshot()
    }

    // MARK: Logs

    /// Saves a finished workout; false, with an explanation, when storage fails. The same workout
    /// saved twice stays one.
    @discardableResult
    func save(_ log: WorkoutLog) -> Bool {
        guard !logs.contains(where: { $0.id == log.id }) else { return true }
        let updated = logs + [log]
        do {
            try store.save(updated, key: mainIsReadable ? StoreKey.workoutLogs : Self.recoveredKey)
            logs = updated
            storageError = mainIsReadable ? nil : storageError
            return true
        } catch {
            storageError = "Тренировку не удалось сохранить. Попробуй ещё раз."
            return false
        }
    }

    /// Removes a finished workout for good. Nothing to do for one that is not there. While the main record cannot be
    /// read it is left alone, so nothing is deleted from what cannot be seen.
    @discardableResult
    func delete(_ id: UUID) -> Bool {
        guard logs.contains(where: { $0.id == id }) else { return true }
        guard mainIsReadable else {
            storageError = "История не читается, поэтому тренировку сейчас не удалить."
            return false
        }
        let updated = logs.filter { $0.id != id }
        do {
            try store.save(updated, key: StoreKey.workoutLogs)
            logs = updated
            storageError = nil
            return true
        } catch {
            storageError = "Тренировку не удалось удалить. Попробуй ещё раз."
            return false
        }
    }

    /// Once the main record reads again, what was kept apart joins it.
    private func mergeRecovered() {
        do {
            try store.save(logs, key: StoreKey.workoutLogs)
            try store.remove(key: Self.recoveredKey)
        } catch {
            storageError = "Не удалось объединить историю тренировок."
        }
    }

    /// The sets of the last time each of these exercises was done.
    func lastSets(for exerciseIDs: [String]) -> [String: [SetEntry]] {
        var found: [String: [SetEntry]] = [:]
        for log in logs.sorted(by: { $0.finishedAt > $1.finishedAt }) {
            for entry in log.entries where exerciseIDs.contains(entry.exerciseID) && !entry.sets.isEmpty && found[entry.exerciseID] == nil {
                found[entry.exerciseID] = entry.sets
            }
        }
        return found
    }

    // MARK: Session in progress

    func makeSession(plan: WorkoutPlan, slot: DayKey?, startedAt: Date = .now) -> WorkoutSession {
        WorkoutSession(plan: plan, slot: slot, history: lastSets(for: plan.exercises.map(\.exerciseID)), startedAt: startedAt)
    }

    /// The workout that was under way, ready to go on.
    func restore() -> WorkoutSession? {
        guard let resumable else { return nil }
        return WorkoutSession(snapshot: resumable, history: lastSets(for: resumable.plan.exercises.map(\.exerciseID)))
    }

    func persist(_ session: WorkoutSession) {
        let snapshot = session.snapshot()
        do {
            try store.save(snapshot, key: StoreKey.activeSession)
            resumable = snapshot
        } catch {
            storageError = "Не удалось сохранить ход тренировки."
        }
    }

    func discardSnapshot() {
        do {
            try store.remove(key: StoreKey.activeSession)
            resumable = nil
        } catch {
            storageError = "Не удалось убрать незавершённую тренировку."
        }
    }

    private func loadSnapshot() -> SessionSnapshot? {
        guard let snapshot = try? store.load(SessionSnapshot.self, key: StoreKey.activeSession) else { return nil }
        if snapshot.isConsistent { return snapshot }
        try? store.remove(key: StoreKey.activeSession)
        return nil
    }
}
