import SwiftUI

/// A local coach conversation: results, preparation, or a voluntary assessment after preparation.
struct TrainingStartView: View {
    @Environment(AppCoordinator.self) private var app
    @State private var showsResult = false
    @State private var showsAssessment = false

    private var prepared: Bool {
        AdaptiveTraining.isPrepared(app.adaptiveTraining.state, logs: app.workouts.logs, now: app.now, calendar: app.calendar)
    }
    private var newOrReturning: Bool {
        app.profile?.experience == .beginner || app.profile?.experience == .returning
    }

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow("Твой тренер", color: FelixTheme.ice)
                Text("С чего начнём?").font(.felixTitle)
                Text("Знаешь свои рабочие веса или результат на несколько повторов? Можешь записать их. Если нет — сначала освоим движения и подберём нагрузку.")
                    .foregroundStyle(FelixTheme.secondary)
                choice(.preparation, detail: newOrReturning
                       ? "Рекомендую начать здесь: первые две недели учимся и записываем комфортные веса."
                       : "Базовый план по профилю, с подбором весов по выполнению и отзывам.")
                choice(.knownResults, detail: "Запиши недавний вес, повторы и запас. Проверять максимум заново не нужно.")
                choice(.assessAfterPreparation, detail: "Сначала подготовка, затем добровольная оценка с запасом повторов.")
                if let route = app.adaptiveTraining.state.route {
                    Text("Выбрано: \(route.title)").font(.headline)
                    if route != .knownResults {
                        Text(prepared
                             ? "Подготовительный срок и четыре полных занятия пройдены. Оценку можно обсудить сейчас или продолжить обычные тренировки."
                             : "Первый контроль через 14 дней и не раньше четырёх полных занятий. Это ориентир, а не автоматическая готовность к тяжёлым попыткам.")
                            .font(.footnote).foregroundStyle(FelixTheme.secondary)
                    }
                    FelixSecondaryButton(title: "Записать известный результат", systemImage: "square.and.pencil") { showsResult = true }
                    if route != .knownResults, prepared {
                        FelixSecondaryButton(title: "Оценить рабочую нагрузку", systemImage: "figure.strengthtraining.traditional") {
                            showsAssessment = true
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(app.adaptiveTraining.state.trainingClass.map { "Твой класс: \($0.title)" } ?? "Класс пока не выбран")
                        .font(.headline)
                    Text("Цель: \(app.profile?.goal?.title ?? "выбери в профиле"). Класс определяет акцент занятий, цель — объём и запас нагрузки.")
                        .font(.subheadline).foregroundStyle(FelixTheme.secondary)
                    if prepared {
                        Text("Подготовительный этап пройден. Что тебе ближе: развивать мышцы или силу в приседе, жиме и становой? Можно выбрать позже или сменить класс здесь.")
                            .font(.subheadline)
                        ForEach(TrainingClass.allCases) { trainingClass in
                            Button {
                                app.adaptiveTraining.chooseClass(trainingClass, logs: app.workouts.logs,
                                                                 now: app.now, calendar: app.calendar)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(trainingClass.title).font(.headline)
                                    Text(trainingClass.detail).font(.subheadline).foregroundStyle(FelixTheme.secondary)
                                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(CardSurface(radius: 22, highlighted: app.adaptiveTraining.state.trainingClass == trainingClass))
                            }.buttonStyle(PressableStyle())
                        }
                    } else {
                        Text("Первые две недели знакомимся с нагрузкой. Выбор класса откроется после 14 дней и четырёх полных силовых занятий. Известные результаты можно записать уже сейчас.")
                            .font(.footnote).foregroundStyle(FelixTheme.secondary)
                    }
                }
                ForEach(app.adaptiveTraining.state.results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ExerciseCatalog.exercise(result.exerciseID).title).font(.headline)
                        Text("\(WeightFormat.kg(result.weightKg)) кг × \(result.reps) · запас \(result.reserve)")
                        Text(result.measuredAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(FelixTheme.secondary)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(CardSurface(radius: 22))
                }
                if let error = app.adaptiveTraining.error { FelixInlineIssue(text: error) }
            }
        }
        .navigationTitle("Подбор нагрузки")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsResult) { StrengthResultSheet(assessment: false) }
        .sheet(isPresented: $showsAssessment) { StrengthResultSheet(assessment: true) }
    }

    private func choice(_ route: TrainingStartRoute, detail: String) -> some View {
        Button {
            if app.adaptiveTraining.choose(route, now: app.now), route == .knownResults { showsResult = true }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(route.title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(FelixTheme.secondary)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(CardSurface(radius: 22, highlighted: app.adaptiveTraining.state.route == route))
        }.buttonStyle(PressableStyle())
    }
}

/// Assessment is submaximal and voluntary. There is no fixed 60→90 kg ladder or mandatory 1RM attempt.
struct StrengthResultSheet: View {
    let assessment: Bool
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var exerciseID = "bench-press"
    @State private var weightText = ""
    @State private var reps = 8
    @State private var reserve = 3
    @State private var increment = 2.5
    @State private var measuredAt = Date.now
    @State private var technique = false
    @State private var supported = false
    @State private var discomfort = false
    @State private var attempts = 0
    @State private var stopped = false
    @State private var lastResult: StrengthResult?
    @State private var note: String?

    private var candidates: [Exercise] {
        ExerciseCatalog.all.filter { ExerciseCatalog.info($0.id).usesWeight && !$0.isTimed }
    }
    private var eligible: Bool {
        AdaptiveTraining.isPrepared(app.adaptiveTraining.state, logs: app.workouts.logs, now: app.now, calendar: app.calendar)
    }
    private var blocked: Bool {
        let zones = Set((app.profile?.limitations ?? []).map(\.zone))
        return !ExerciseCatalog.exercise(exerciseID).loads.isDisjoint(with: zones)
    }
    private var result: StrengthResult? {
        guard let kg = OnboardingDraft.number(weightText) else { return nil }
        let result = StrengthResult(exerciseID: exerciseID, weightKg: kg, reps: reps, reserve: reserve,
                                    measuredAt: assessment ? app.now : measuredAt,
                                    fromAssessment: assessment, incrementKg: increment)
        return result.isValid ? result : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(assessment ? "Подбираем нагрузку, сохраняя запас. Предельные одиночные и двойки не нужны. Начни с веса, который уже выполнял уверенно."
                         : "Запиши реально выполненный недавний подход. Вес штанги — общий; гантели — за одну. Значения относятся только к выбранному упражнению.")
                    Picker("Упражнение", selection: $exerciseID) {
                        ForEach(candidates) { Text($0.title).tag($0.id) }
                    }.disabled(assessment && attempts > 0)
                    TextField("Вес, кг", text: $weightText).keyboardType(.decimalPad)
                    Stepper("Повторы: \(reps)", value: $reps, in: 1...10)
                    Stepper("Осталось в запасе: \(reserve)", value: $reserve, in: 0...5)
                    Text("Запас — сколько ещё повторов мог бы сделать с той же техникой. Если не уверен, начни с подготовки.")
                        .font(.footnote)
                    Picker("Доступный шаг веса", selection: $increment) {
                        ForEach([0.5, 1, 2, 2.5, 5], id: \.self) { Text("\(WeightFormat.kg($0)) кг").tag($0) }
                    }
                    if !assessment { DatePicker("Когда выполнен", selection: $measuredAt, in: ...app.now, displayedComponents: .date) }
                }
                if assessment {
                    Section("Готовность к оценке") {
                        Toggle("Уверенно выполняю это движение", isOn: $technique)
                        Toggle("Есть тренер или подходящая страховка", isOn: $supported)
                        Toggle("Есть боль или дискомфорт", isOn: $discomfort)
                        Text("После подхода отдохни. Не увеличивай вес, если запас 2 или меньше, техника ухудшилась или есть дискомфорт. Можно закончить в любой момент.")
                        if blocked { Text("Для этого движения отмечены ограничения. Оценка здесь недоступна.").foregroundStyle(.red) }
                        if !eligible { Text("Сначала заверши подготовительный этап.") }
                    }
                    Section {
                        Button("Записать оценочный подход") { recordAttempt() }
                            .disabled(stopped || !eligible || blocked || !technique || !supported || discomfort || result == nil)
                        Button("Закончить оценку") { stopped = true; note = "Оценка закончена. Можно сохранить последний подход с запасом." }
                        if let lastResult {
                            Text("Последний подход: \(WeightFormat.kg(lastResult.weightKg)) кг × \(lastResult.reps), запас \(lastResult.reserve)")
                        }
                    }
                }
                if let note { Section { Text(note) } }
                if let error = app.adaptiveTraining.error { Section { Text(error).foregroundStyle(.red) } }
                Section {
                    Button(assessment ? "Сохранить результат оценки" : "Сохранить результат") {
                        guard let value = assessment ? lastResult : result else { return }
                        if app.adaptiveTraining.record(value, now: app.now) { dismiss() }
                    }
                    .disabled(assessment ? lastResult == nil || discomfort || !technique || !supported || blocked || !eligible : result == nil)
                }
            }
            .navigationTitle(assessment ? "Оценка с запасом" : "Известный результат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
        }
        .onChange(of: exerciseID) { _, _ in lastResult = nil; attempts = 0; stopped = false; weightText = "" }
        .onChange(of: technique) { _, value in
            if !value, attempts > 0 { stopped = true; lastResult = nil; note = "Оценка остановлена: сначала восстанови уверенную технику." }
        }
        .onChange(of: discomfort) { _, value in if value { stopped = true; lastResult = nil; note = "Остановись: результат с дискомфортом не используем для подбора нагрузки." } }
    }

    private func recordAttempt() {
        guard eligible, !blocked, !stopped, technique, supported, !discomfort, let value = result else { return }
        attempts += 1
        guard reps >= 6, reserve >= 2 else {
            stopped = true
            note = "Дальше вес не повышаем. Этот тяжёлый подход не используем; можно сохранить предыдущий подход с запасом."
            return
        }
        lastResult = value
        if reserve <= 2 || attempts >= 4 {
            stopped = true
            note = "Достаточно для начальной оценки. Повышать вес дальше не нужно."
        } else {
            note = "Подход записан. После отдыха можешь закончить или вручную выбрать небольшой следующий шаг \(WeightFormat.kg(increment)) кг."
        }
    }
}
