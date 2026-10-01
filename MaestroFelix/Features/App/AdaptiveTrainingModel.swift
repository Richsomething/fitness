import Foundation
import Observation

@MainActor @Observable
final class AdaptiveTrainingModel {
    private(set) var state = AdaptiveTrainingState()
    var error: String?
    @ObservationIgnored private let store: any DocumentStore
    @ObservationIgnored private var readable = true

    init(store: any DocumentStore) {
        self.store = store
        do { state = try store.load(AdaptiveTrainingState.self, key: "adaptiveTraining") ?? AdaptiveTrainingState() }
        catch { readable = false; self.error = "Не удалось прочитать настройки нагрузки. Исходные данные сохранены." }
    }

    @discardableResult
    func choose(_ route: TrainingStartRoute, now: Date) -> Bool {
        var next = state
        next.route = route
        if next.startedAt == nil || (state.route == .knownResults && route != .knownResults) { next.startedAt = now }
        return save(next)
    }

    @discardableResult
    func chooseClass(_ trainingClass: TrainingClass, logs: [WorkoutLog], now: Date,
                     calendar: Calendar = .current) -> Bool {
        guard AdaptiveTraining.isPrepared(state, logs: logs, now: now, calendar: calendar) else {
            error = "Выбор класса откроется после 14 дней и четырёх полных силовых занятий."
            return false
        }
        var next = state
        next.trainingClass = trainingClass
        return save(next)
    }

    @discardableResult
    func record(_ result: StrengthResult, now: Date) -> Bool {
        guard result.isValid, result.measuredAt <= now,
              ExerciseCatalog.info(result.exerciseID).usesWeight else {
            error = "Проверь вес, повторы, запас и дату результата."
            return false
        }
        var next = state
        next.results.removeAll { $0.exerciseID == result.exerciseID }
        next.results.append(result)
        return save(next)
    }

    private func save(_ next: AdaptiveTrainingState) -> Bool {
        guard readable else { return false }
        do {
            try store.save(next, key: "adaptiveTraining")
            state = next
            error = nil
            return true
        } catch { self.error = "Не удалось сохранить подбор нагрузки. Попробуй ещё раз."; return false }
    }
}
