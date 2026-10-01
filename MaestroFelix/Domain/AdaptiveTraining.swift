import Foundation

enum TrainingClass: String, Codable, CaseIterable, Identifiable {
    case bodybuilding, powerlifting
    var id: String { rawValue }
    var title: String { self == .bodybuilding ? "Бодибилдинг" : "Пауэрлифтинг" }
    var detail: String {
        self == .bodybuilding
            ? "Развитие мышц: баланс групп, основные упражнения и изоляция."
            : "Развитие силы: акцент на приседе, жиме и становой, затем подсобные упражнения."
    }
}

enum TrainingStartRoute: String, Codable, CaseIterable, Identifiable {
    case knownResults, preparation, assessAfterPreparation
    var id: String { rawValue }
    var title: String {
        switch self {
        case .knownResults: "Знаю свои результаты"
        case .preparation: "Начать с подготовки"
        case .assessAfterPreparation: "Хочу оценить силу позже"
        }
    }
}

enum TrainingAdjustmentReason: String, Codable, CaseIterable, Identifiable {
    case ordinary, fatigue, returning, discomfort, technique
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ordinary: "Обычная тренировка"
        case .fatigue: "Усталость или недосып"
        case .returning: "Возвращение после перерыва"
        case .discomfort: "Боль или дискомфорт"
        case .technique: "Не удержал технику"
        }
    }
}

struct ExerciseFeedback: Codable, Equatable {
    var reserve: Int? = nil
    var reason: TrainingAdjustmentReason = .ordinary
}

struct StrengthResult: Codable, Equatable, Identifiable {
    var id = UUID()
    var exerciseID: String
    var weightKg: Double
    var reps: Int
    var reserve: Int
    var measuredAt: Date
    var fromAssessment = false
    var incrementKg = 2.5

    var isValid: Bool {
        weightKg.isFinite && weightKg > 0 && weightKg <= 500 && (1...10).contains(reps)
            && (0...5).contains(reserve) && reps + reserve <= 12
            && incrementKg.isFinite && incrementKg > 0 && incrementKg <= 10
    }
}

struct AdaptiveTrainingState: Codable, Equatable {
    var version = 1
    var route: TrainingStartRoute?
    var startedAt: Date?
    var results: [StrengthResult] = []
    var trainingClass: TrainingClass? = nil
}

/// Product defaults for a first calibration, not a reconstruction of the coach's exact progression.
enum AdaptiveTraining {
    static let preparationDays = 14
    static let preparationSessions = 4

    static func isPrepared(_ state: AdaptiveTrainingState, logs: [WorkoutLog], now: Date,
                           calendar: Calendar = .current) -> Bool {
        guard let start = state.startedAt,
              let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                                  to: calendar.startOfDay(for: now)).day,
              days >= preparationDays else { return false }
        let completed = logs.filter {
            $0.kind == .strength && $0.finishedAt >= start && $0.finishedAt <= now && !$0.isPartial
                && $0.entries.contains { $0.sets.contains { $0.kind == .normal } }
        }
        return Set(completed.map(\.id)).count >= preparationSessions
    }

    /// Epley estimate. Reserve is optional evidence supplied by the person, never inferred from "fine".
    static func estimatedMaximum(weight: Double, reps: Int, reserve: Int) -> Double? {
        guard weight.isFinite, weight > 0, weight <= 500, (1...10).contains(reps),
              (0...5).contains(reserve), reps + reserve <= 12 else { return nil }
        let capacity = reps + reserve
        return capacity == 1 ? weight : weight * (1 + Double(capacity) / 30)
    }

    static func workingWeight(maximum: Double, reps: Int, reserve: Int, increment: Double = 2.5) -> Double? {
        guard maximum.isFinite, maximum > 0, maximum <= 750, (1...15).contains(reps),
              (0...5).contains(reserve), increment.isFinite, increment > 0 else { return nil }
        // Extra margin for repeated sets. This coefficient is a provisional product choice.
        let raw = maximum / (1 + Double(reps + reserve) / 30) * 0.95
        let rounded = floor(raw / increment) * increment
        return rounded > 0 ? rounded : nil
    }

    /// Explicit feedback gates escalation; missing ratings, warm-ups and failure sets cannot raise a load.
    static func correction(for entry: ExerciseLog, target: Int, plannedSets: Int, upperTarget: Int? = nil) -> Double {
        if let feedback = entry.feedback {
            switch feedback.reason {
            case .discomfort, .technique: return 0
            case .fatigue, .returning: return 0.9
            case .ordinary: break
            }
        }
        let sets = entry.sets.filter { $0.kind == .normal }
        guard !sets.isEmpty else { return 1 }
        if (entry.feedback?.reserve ?? 5) <= 1 || entry.feel == .limit || sets.contains(where: { ($0.reps ?? 0) < target }) { return 0.95 }
        if entry.feel == .easy, let reserve = entry.feedback?.reserve, reserve >= 3,
           sets.count >= plannedSets, sets.allSatisfy({ ($0.reps ?? 0) >= (upperTarget ?? target) }) { return 1.025 }
        return 1
    }

    static func plan(_ original: WorkoutPlan, state: AdaptiveTrainingState, logs: [WorkoutLog], now: Date,
                     calendar: Calendar = .current, profile: OnboardingDraft? = nil) -> WorkoutPlan {
        guard state.route != nil, original.kind == .strength else { return original }
        let prepared = isPrepared(state, logs: logs, now: now, calendar: calendar)
        var plan = original
        if prepared, let trainingClass = state.trainingClass, let profile {
            plan = WorkoutPlanner.classPlan(original, profile: profile, trainingClass: trainingClass)
        }
        let preparing = state.route != .knownResults && !isPrepared(state, logs: logs, now: now, calendar: calendar)
        for index in plan.exercises.indices {
            var item = plan.exercises[index]
            if preparing {
                item.sets = min(item.sets, 2)
                if !item.exercise.isTimed { item.repsLow = 8; item.repsHigh = 10 }
                item.restSeconds = max(item.restSeconds, 90)
            }
            item.targetReserve = preparing || (prepared && state.trainingClass != nil && profile?.goal == .fatLoss) ? 3 : 2
            let recentLogs = logs.filter { $0.finishedAt <= now && now.timeIntervalSince($0.finishedAt) <= 90 * 86400 }
                .sorted { $0.finishedAt > $1.finishedAt }
            let recent = recentLogs.compactMap { $0.entries.first { $0.exerciseID == item.exerciseID && $0.sets.contains { $0.kind == .normal } } }
            let latest = recent.first
            let latestDate = recentLogs.first { log in
                log.entries.contains { $0.exerciseID == item.exerciseID && $0.sets.contains { $0.kind == .normal } }
            }?.finishedAt
            if latest?.feedback?.reason == .discomfort || latest?.feedback?.reason == .technique {
                item.suggestedWeightKg = nil
                item.calibration = "Автоподбор веса остановлен: сначала разберись с дискомфортом или техникой."
                item.loadBlocked = true
                plan.exercises[index] = item
                continue
            }
            // Temporary fatigue is not used as evidence of a permanent loss of strength.
            let ordinary = recent.first { ($0.feedback?.reason ?? .ordinary) == .ordinary }
            let result = state.results.filter {
                $0.exerciseID == item.exerciseID && $0.isValid && $0.measuredAt <= now
                    && now.timeIntervalSince($0.measuredAt) <= 90 * 86400
            }.max { $0.measuredAt < $1.measuredAt }
            let lastWorking = ordinary?.sets.last { $0.kind == .normal }
            let historySet = lastWorking.flatMap { set in
                (1...10).contains(set.reps ?? 0) ? set : nil
            }
            let historyDate = recentLogs.first { log in
                log.entries.contains { $0.exerciseID == item.exerciseID && ($0.feedback?.reason ?? .ordinary) == .ordinary
                    && $0.sets.contains { $0.kind == .normal } }
            }?.finishedAt
            let preferResult = result.map { $0.measuredAt > (historyDate ?? .distantPast) } ?? false
            let estimate: Double?
            if preferResult, let result {
                estimate = estimatedMaximum(weight: result.weightKg, reps: result.reps, reserve: result.reserve)
            } else if let set = historySet, let kg = set.weightKg, let reps = set.reps {
                estimate = estimatedMaximum(weight: kg, reps: reps, reserve: ordinary?.feedback?.reserve ?? 0)
            } else if let result {
                estimate = estimatedMaximum(weight: result.weightKg, reps: result.reps, reserve: result.reserve)
            } else { estimate = nil }
            let increment = result?.incrementKg ?? 2.5
            // A known working load at the same target also works for high-repetition accessories.
            // No high-repetition maximum extrapolation is needed to preserve that actual load.
            let matching = preferResult ? nil : ordinary?.sets.filter { $0.kind == .normal && $0.reps == item.repsHigh }
            let calculated = estimate.flatMap {
                workingWeight(maximum: $0, reps: item.repsHigh, reserve: item.targetReserve ?? 2, increment: increment)
            }
            if ExerciseCatalog.info(item.exerciseID).usesWeight,
               let baseline = matching?.last?.weightKg ?? calculated {
                let newerResult = result.map { $0.measuredAt > (latestDate ?? .distantPast) } ?? false
                let factor: Double = newerResult ? 1 : (latest.map { entry -> Double in
                    // A change of repetition range is not a failed old prescription.
                    if state.trainingClass == nil || matching?.isEmpty == false {
                        return correction(for: entry, target: item.repsLow, plannedSets: item.sets, upperTarget: item.repsHigh)
                    }
                    switch entry.feedback?.reason {
                    case .fatigue, .returning: return 0.9
                    default: return (entry.feedback?.reserve ?? 5) <= 1 || entry.feel == .limit ? 0.95 : 1
                    }
                } ?? 1)
                guard baseline.isFinite, baseline > 0, baseline <= 500 else {
                    item.suggestedWeightKg = nil
                    item.calibration = "Проверь записанный вес: расчёт недоступен."
                    plan.exercises[index] = item
                    continue
                }
                let raw = factor > 1 ? baseline + increment : baseline * factor
                let corrected = floor(raw / increment) * increment
                item.suggestedWeightKg = corrected > 0 ? corrected : nil
                item.calibration = factor < 1 ? "Вес облегчили по последнему выполнению и отзыву."
                    : factor > 1 ? "Все подходы выполнены легко с запасом: небольшой следующий шаг веса."
                    : "Начальная оценка по твоему результату; уточняй вес по технике и запасу."
            } else {
                item.calibration = "Вес ещё не известен: начни с комфортной нагрузки и запиши результат с запасом."
            }
            if preparing { item.calibration = "Подготовка: 2 подхода, около 3 повторов в запасе. " + (item.calibration ?? "") }
            plan.exercises[index] = item
        }
        return plan
    }
}
