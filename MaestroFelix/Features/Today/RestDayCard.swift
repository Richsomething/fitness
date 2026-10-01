import SwiftUI

/// A day without a planned session. It says so, puts the next session first — the one thing to know on a rest
/// day — and below it offers something light for anyone who wants to move: cardio, or a block rolled on a reel.
struct RestDayCard: View {
    let next: PlannedSession?
    let movedTo: DayKey?
    let activity: [WorkoutLog]

    @Environment(AppCoordinator.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scrollToID) private var scrollToID
    @State private var reel = 0
    @State private var isRolling = false
    @State private var rolled: WorkoutPlanner.LightBlock?

    private static let blocks = WorkoutPlanner.LightBlock.allCases
    private static let startAnchor = "rolled-block-start"

    var body: some View {
        let profile = app.profile ?? OnboardingDraft()
        let cardio = WorkoutPlanner.cardio(for: profile, seed: app.today.ordinal(calendar: app.calendar), logs: app.workouts.logs)
        let playable = WorkoutPlanner.playableBlocks(for: profile, logs: app.workouts.logs)
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Сегодня · день отдыха", color: FelixTheme.ice)
                Text("Восстановление").font(.felixHeadline)
                if let movedTo {
                    Text("Тренировка перенесена на \(TrainingCalendar.dayPhrase(movedTo, today: app.today, calendar: app.calendar)).")
                        .font(.subheadline)
                        .foregroundStyle(FelixTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !activity.isEmpty { activityNote }
            if let next { nextBlock(next) }
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Если хочется подвигаться")
                optionRow(symbol: "figure.run", title: "Кардио", detail: "≈ \(cardio.estimatedMinutes) мин") {
                    app.start(cardio, slot: nil)
                }
                reelRow(playable: playable)
                if let rolled, !isRolling {
                    rolledBlock(WorkoutPlanner.light(rolled, for: profile, logs: app.workouts.logs))
                        .transition(.opacity)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HeroCardBackground())
        .animation(.smooth(duration: 0.3), value: rolled)
        .animation(.smooth(duration: 0.3), value: isRolling)
        .sensoryFeedback(.selection, trigger: reel)
        .sensoryFeedback(.success, trigger: isRolling) { was, now in was && !now }
    }

    private var activityNote: some View {
        Label("Уже сегодня: \(ActivityText.list(activity.map(\.title)))", systemImage: "checkmark.circle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(FelixTheme.ice)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Next session

    /// The answer to the question of a rest day — when to train next — as the biggest thing in the card.
    private func nextBlock(_ session: PlannedSession) -> some View {
        let when = TrainingCalendar.dayPhrase(session.day, today: app.today, calendar: app.calendar)
        let time = TrainingCalendar.clock(hour: app.profile?.startHour ?? 18, minute: app.profile?.startMinute ?? 0)
        let count = session.plan.exercises.count
        return NavigationLink { SessionDetailView(slot: session.key) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Следующая тренировка", color: FelixTheme.ice)
                    Text(session.plan.title).font(.headline).multilineTextAlignment(.leading)
                    // The answer first: when. Then what it holds.
                    Text("\(when.prefix(1).uppercased())\(when.dropFirst()), \(time)")
                        .font(.subheadline.weight(.semibold))
                    Text("\(count) \(RussianPlural.form(count, one: "упражнение", few: "упражнения", many: "упражнений")) · ≈ \(session.plan.estimatedMinutes) мин")
                        .font(.footnote)
                        .foregroundStyle(FelixTheme.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
            }
            .foregroundStyle(FelixTheme.text)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardSurface(radius: 20, highlighted: true))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Открыть занятие")
    }

    // MARK: Light options

    private func optionRow(symbol: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            optionLabel(symbol: symbol, title: title, detail: detail, filled: true)
        }
        .buttonStyle(PressableStyle())
    }

    private func optionLabel(symbol: String, title: String, detail: String, filled: Bool, highlighted: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(Circle().fill(filled ? FelixTheme.cobalt : Color.white.opacity(0.12)))
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                Text(detail).font(.footnote).foregroundStyle(FelixTheme.secondary)
            }
            Spacer(minLength: 8)
        }
        .foregroundStyle(FelixTheme.text)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(CardSurface(radius: 20, highlighted: highlighted))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// The light-block row: a reel of blocks that spins and slows down onto one that has exercises to give.
    private func reelRow(playable: [WorkoutPlanner.LightBlock]) -> some View {
        let block = Self.blocks[reel % Self.blocks.count]
        let idle = rolled == nil && !isRolling
        let nothing = playable.isEmpty
        let detail = nothing ? "Для твоих ограничений подходящих упражнений нет"
            : (isRolling ? "Крутим…" : (idle ? "Случайный набор упражнений" : "Выпало! Ещё раз?"))
        return Button { roll(among: playable) } label: {
            optionLabel(symbol: idle ? "dice.fill" : block.symbol,
                        title: idle ? "Лёгкий блок" : block.title,
                        detail: detail,
                        filled: rolled != nil && !isRolling,
                        highlighted: rolled != nil && !isRolling)
        }
        .buttonStyle(PressableStyle())
        .disabled(isRolling || nothing)
        .opacity(nothing ? 0.6 : 1)
        .accessibilityLabel(rolled.map { "Лёгкий блок: \($0.title). Бросить ещё раз" } ?? "Лёгкий блок, случайный")
    }

    /// What was rolled, kept short: the names, and the button that starts it.
    private func rolledBlock(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.exercises.map(\.exercise.title).joined(separator: ", "))
                .font(.footnote)
                .foregroundStyle(FelixTheme.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if !plan.avoidedZones.isEmpty { AvoidedNote(zones: plan.avoidedZones) }
            // The space under the button is part of what is scrolled to, so it clears the fade above the tab bar.
            FelixPrimaryButton(title: "Начать: \(plan.title)", systemImage: "play.fill") {
                app.start(plan, slot: nil)
            }
            .padding(.bottom, 28)
            .id(Self.startAnchor)
        }
        .padding(.top, 4)
    }

    /// Spins the reel through the blocks, slowing down, and stops on a random one.
    private func roll(among playable: [WorkoutPlanner.LightBlock]) {
        guard let landing = playable.randomElement(), let target = Self.blocks.firstIndex(of: landing) else { return }
        guard !reduceMotion else {
            reel = target
            rolled = Self.blocks[target]
            revealStart()
            return
        }
        isRolling = true
        Task { @MainActor in
            // At least two full turns, landing on the target.
            let steps = Self.blocks.count * 2 + (target - reel % Self.blocks.count + Self.blocks.count) % Self.blocks.count
            for step in 0..<steps {
                let progress = Double(step) / Double(max(steps - 1, 1))
                try? await Task.sleep(for: .milliseconds(Int(55 + 260 * progress * progress)))
                reel += 1
            }
            rolled = Self.blocks[reel % Self.blocks.count]
            isRolling = false
            revealStart()
        }
    }

    /// Brings the start button into view once the block is there, so it never waits under the tab bar.
    private func revealStart() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            scrollToID(Self.startAnchor)
        }
    }
}

/// How the day's activity reads in one line.
enum ActivityText {
    /// Titles in the order first done, with "×2" after one that was done more than once.
    static func list(_ titles: [String]) -> String {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for title in titles {
            if counts[title] == nil { order.append(title) }
            counts[title, default: 0] += 1
        }
        return order.map { counts[$0, default: 1] > 1 ? "\($0) ×\(counts[$0, default: 1])" : $0 }.joined(separator: ", ")
    }
}
