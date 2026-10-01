import SwiftUI

/// One exercise under way. A set of repetitions shows the muscles at work and the weight and repetitions
/// to record, filled in from last time; a held or timed one shows a ring; between sets a countdown. The
/// person moves on themselves: "Подход сделан", "Начать подход", "Дальше".
struct ExerciseRunnerView: View {
    let session: WorkoutSession
    let index: Int
    let onFinishWorkout: () -> Void

    @Environment(AppCoordinator.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var restOver = false
    @State private var weight = 0.0
    @State private var reps = 10
    @State private var kind = SetKind.normal
    @State private var step = 2.5
    @State private var editing: EditTarget?
    @State private var showsTechnique = false
    @State private var alertNote: String?

    private struct EditTarget: Identifiable {
        let position: Int
        var id: Int { position }
    }

    private var item: PlannedExercise { session.plan.exercises[index] }
    private var exercise: Exercise { item.exercise }
    private var usesWeight: Bool { ExerciseCatalog.info(item.exerciseID).usesWeight }
    private var done: [SetEntry] { session.sets[index] }
    /// The planned sets done: warm-ups are in the list but do not count here.
    private var workingDone: Int { session.setsDone[index] }
    private var setNumber: Int { min(workingDone + 1, item.sets) }
    /// A single stretch of time, as cardio blocks are, is not "set 1 of 1".
    private var isSingle: Bool { item.sets == 1 }
    private var isCardio: Bool { session.plan.kind == .cardio }
    /// Changes when a new set starts, to fill the inputs in again.
    private var setKey: String { "\(index)-\(done.count)" }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
            // Short content sits in the middle of the space; long content scrolls.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        Spacer(minLength: 0)
                        center
                        if !done.isEmpty { doneSets }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
            controls
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .task(id: restDeadline) { await watchRest() }
        .task(id: setKey) { prefill() }
        .sensoryFeedback(.success, trigger: restOver) { _, over in over }
        .sensoryFeedback(.impact(weight: .medium), trigger: done.count)
        .sheet(item: $editing) { target in
            if done.indices.contains(target.position) {
                SetEditSheet(exerciseTitle: exercise.title, number: target.position + 1, isTimed: exercise.isTimed,
                             usesWeight: usesWeight, initial: done[target.position],
                             onSave: { session.updateSet(index, at: target.position, to: $0) },
                             onDelete: { session.deleteSet(index, at: target.position) })
            }
        }
        .sheet(isPresented: $showsTechnique) { ExerciseTechniqueSheet(exerciseID: item.exerciseID) }
    }

    private func prefill() {
        let suggestion = session.suggestion(for: index)
        weight = suggestion.weightKg ?? 0
        reps = suggestion.reps ?? item.repsHigh
        kind = .normal
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Button { withAnimation(.smooth) { session.showOverview() } } label: {
                    // Hands are busy in the gym: the two links at the top are body size, not a caption.
                    Label("К списку", systemImage: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(FelixTheme.ice)
                        .frame(minHeight: 48)
                }
                Spacer()
                if hasRest { restAlertToggle }
                Button { showsTechnique = true } label: {
                    Label("Техника", systemImage: "figure.strengthtraining.traditional")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(FelixTheme.ice)
                        .frame(minHeight: 48)
                }
            }
            HStack(alignment: .top, spacing: 14) {
                ExerciseBadge(exerciseID: item.exerciseID, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Упражнение \(index + 1) из \(session.plan.exercises.count)")
                    Text(exercise.title)
                        .font(.felixHeadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detailText)
                        .font(.subheadline)
                        .foregroundStyle(FelixTheme.secondary)
                }
            }
            if let reserve = item.targetReserve {
                Text("Ориентир: \(reserve) повтора в запасе").font(.footnote).foregroundStyle(FelixTheme.ice)
            }
            if let calibration = item.calibration {
                Text(calibration).font(.footnote).foregroundStyle(FelixTheme.secondary)
            }
            if let alertNote {
                Text(alertNote).font(.footnote).foregroundStyle(FelixTheme.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailText: String {
        let target = exercise.isTimed ? "цель \(item.targetText)" : "\(item.repsLow)–\(item.repsHigh) повторений"
        if isSingle { return target.prefix(1).uppercased() + target.dropFirst() }
        return "Подход \(setNumber) из \(item.sets) · \(target)"
    }

    // MARK: Centre

    @ViewBuilder private var center: some View {
        switch session.phase {
        case let .working(_, since):
            if exercise.isTimed {
                ring(now: { timedWorkingRing(since: since, now: $0) })
            } else {
                VStack(spacing: 14) {
                    ExerciseFigure(exerciseID: item.exerciseID, height: 190)
                    SetInputCard(usesWeight: usesWeight, repsRange: item.repsLow...max(item.repsLow, item.repsHigh), weight: $weight,
                                 reps: $reps, kind: $kind, step: $step, previous: session.previousText(for: index))
                }
            }
        case let .paused(_, elapsed):
            RingView(content: timedRing(elapsed: elapsed, label: "Пауза")).frame(width: 280, height: 280)
        case let .resting(_, until, length):
            VStack(spacing: 14) {
                ring(now: { restRing(until: until, length: length, now: $0) })
                nextSetLine
            }
        default:
            doneRing
        }
    }

    private func ring(now content: @escaping (Date) -> RingContent) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion && !isTiming)) { timeline in
            RingView(content: content(timeline.date))
        }
        .frame(width: 280, height: 280)
    }

    private var isTiming: Bool {
        switch session.phase {
        case .working, .resting: true
        default: false
        }
    }

    private func timedWorkingRing(since: Date, now: Date) -> RingContent {
        timedRing(elapsed: now.timeIntervalSince(since), label: isSingle ? "Идёт" : "Подход \(setNumber)")
    }

    private func timedRing(elapsed: TimeInterval, label: String) -> RingContent {
        let reached = elapsed >= Double(item.holdSeconds)
        return RingContent(progress: elapsed / Double(max(item.holdSeconds, 1)), colors: [FelixTheme.ice, FelixTheme.cobalt],
                           label: label, value: Self.clock(elapsed),
                           caption: reached ? "Цель есть!" : "Цель \(Self.clock(Double(item.holdSeconds)))")
    }

    private func restRing(until: Date, length: TimeInterval, now: Date) -> RingContent {
        let left = max(until.timeIntervalSince(now), 0)
        return RingContent(progress: left / max(length, 1), colors: [Color.white, FelixTheme.ice], label: left > 0 ? "Отдых" : "Пора!",
                           value: Self.clock(left.rounded(.up)), caption: left > 0 ? "Дальше подход \(setNumber)" : "Начинай подход \(setNumber)")
    }

    private var doneRing: some View {
        let result = done.first?.seconds
        let content = isSingle
            ? RingContent(progress: 1, colors: [FelixTheme.ice, FelixTheme.cobalt], label: "Готово",
                          value: result.map { Self.clock(Double($0)) } ?? "✓", caption: isCardio ? "Блок выполнен" : "Выполнено")
            : RingContent(progress: 1, colors: [FelixTheme.ice, FelixTheme.cobalt], label: "Готово",
                          value: "\(item.sets)/\(item.sets)", caption: "Все подходы сделаны")
        return RingView(content: content).frame(width: 280, height: 280)
    }

    /// What the next set will start from.
    @ViewBuilder private var nextSetLine: some View {
        let next = session.suggestion(for: index)
        Label("Подход \(setNumber): \(next.summary)", systemImage: "arrow.turn.down.right")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(FelixTheme.secondary)
    }

    // MARK: Rest alert

    /// Whether this exercise has a rest to be told about.
    private var hasRest: Bool { item.sets > 1 && item.restSeconds > 0 }

    private var restAlertToggle: some View {
        let isOn = app.reminders.settings.restAlertEnabled
        return Button { Task { await setRestAlert(!isOn) } } label: {
            Image(systemName: isOn ? "bell.fill" : "bell")
                .font(.body.weight(.semibold))
                .foregroundStyle(isOn ? FelixTheme.ice : FelixTheme.secondary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Сообщить, когда отдых закончится")
        .accessibilityValue(isOn ? "Включено" : "Выключено")
    }

    private func setRestAlert(_ on: Bool) async {
        let changed = await app.reminders.setRestAlert(on)
        // Said back, so the bell is not a silent toggle: what it now does, or why it could not.
        if on && !changed {
            alertNote = "Уведомления выключены в настройках iOS."
        } else {
            alertNote = changed ? (on ? "Сигнал включён: скажем, когда отдых закончится, даже если экран погас." : "Сигнал выключен.") : nil
        }
        if changed { app.syncRestAlert(for: session) }
    }

    // MARK: Done sets

    private var doneSets: some View {
        let titles = done.rowTitles(noun: "Подход")
        return VStack(spacing: 8) {
            ForEach(Array(done.enumerated()), id: \.element.id) { position, entry in
                let title = isSingle ? "Результат" : titles[position]
                Button { editing = EditTarget(position: position) } label: {
                    HStack {
                        Text(title).foregroundStyle(FelixTheme.secondary)
                        Spacer()
                        Text(entry.rowSummary).monospacedDigit()
                        Image(systemName: "pencil").font(.footnote).foregroundStyle(FelixTheme.tertiary)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(FelixTheme.text)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(CardSurface(radius: 16))
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(title): \(entry.rowSummary)")
                .accessibilityHint("Изменить или удалить")
            }
        }
    }

    // MARK: Controls

    @ViewBuilder private var controls: some View {
        switch session.phase {
        case let .working(_, since):
            VStack(spacing: 10) {
                FelixPrimaryButton(title: finishTitle, systemImage: "checkmark") { finishSet(since: since) }
                if exercise.isTimed { timedExtras { session.pause() } }
            }
        case .paused:
            VStack(spacing: 10) {
                FelixPrimaryButton(title: "Продолжить", systemImage: "play.fill") { session.resume() }
                timedExtras()
            }
        case .resting:
            VStack(spacing: 10) {
                FelixPrimaryButton(title: "Начать подход \(setNumber)", systemImage: "play.fill") {
                    withAnimation(.smooth) { session.startNextSet() }
                }
                HStack(spacing: 10) {
                    FelixSecondaryButton(title: "15 с", systemImage: "plus") { session.addRest(15) }
                    FelixSecondaryButton(title: "Пропустить", systemImage: "forward.fill") {
                        withAnimation(.smooth) { session.startNextSet() }
                    }
                }
            }
        default:
            if let next = session.nextExercise(after: index) {
                FelixPrimaryButton(title: "Дальше: \(session.plan.exercises[next].exercise.title)", systemImage: "arrow.right") {
                    withAnimation(.smooth) { session.start(next) }
                }
            } else {
                FelixPrimaryButton(title: "Завершить и оценить", systemImage: "flag.checkered", action: onFinishWorkout)
            }
        }
    }

    /// Under a timed set: hold the clock (when it runs) and leave the exercise for now. Nothing is written down
    /// by "Пропустить"; sets already done stay.
    private func timedExtras(onPause: (() -> Void)? = nil) -> some View {
        HStack(spacing: 10) {
            if let onPause {
                FelixSecondaryButton(title: "Пауза", systemImage: "pause.fill", action: onPause)
            }
            FelixSecondaryButton(title: "Пропустить", systemImage: "forward.fill") {
                withAnimation(.smooth) { session.skip(index) }
            }
        }
    }

    private var finishTitle: String {
        if kind == .warmup && !exercise.isTimed { return "Разминка сделана" }
        return isCardio ? "Блок сделан" : "Подход сделан"
    }

    private func finishSet(since: Date) {
        let entry = exercise.isTimed
            ? SetEntry(seconds: max(1, Int(Date.now.timeIntervalSince(since))))
            : SetEntry(weightKg: usesWeight ? weight : nil, reps: reps, kind: kind)
        withAnimation(.smooth) { session.finishSet(entry) }
    }

    // MARK: Rest

    private var restDeadline: Date? {
        if case let .resting(_, until, _) = session.phase { return until }
        return nil
    }

    /// Buzzes once when the rest runs out while the screen is open.
    private func watchRest() async {
        restOver = false
        guard let deadline = restDeadline else { return }
        let wait = deadline.timeIntervalSinceNow
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        if !Task.isCancelled { restOver = true }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Ring

struct RingContent {
    let progress: Double
    let colors: [Color]
    let label: String
    let value: String
    let caption: String?
}

/// The big ring with a label, a reading and a caption in its middle.
struct RingView: View {
    let content: RingContent

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [FelixTheme.cobalt.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 150))
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 14)
            Circle()
                .trim(from: 0, to: min(max(content.progress, 0), 1))
                .stroke(AngularGradient(colors: content.colors + [content.colors[0]], center: .center),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: FelixTheme.cobalt.opacity(0.7), radius: 12)
            VStack(spacing: 6) {
                Text(content.label)
                    .font(.headline)
                    .foregroundStyle(FelixTheme.ice)
                Text(content.value)
                    .font(.felixNumber(64))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                if let caption = content.caption {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(FelixTheme.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 30)
        }
        .padding(8)
        .accessibilityElement(children: .combine)
    }
}
