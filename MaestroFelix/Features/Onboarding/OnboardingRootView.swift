import SwiftUI

struct OnboardingRootView: View {
    @Bindable var model: OnboardingModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var movesForward = true
    // Grows with each refused "next", so the button shakes.
    @State private var refusals = 0
    /// Set once the very first profile is saved: the plan that came of it, shown before the app proper.
    @State private var planReady: PlanPreview?

    var body: some View {
        Group {
            if model.showsOnboarding {
                wizard.transition(.opacity)
            } else if model.profile != nil {
                // One row of the profile opens as a step of its own that saves itself; only "from the start" walks them all.
                MainTabView { step in
                    navigate(forward: true) { step == .introduction ? model.edit() : model.editFromProfile(step) }
                }
                    .transition(.opacity)
            }
        }
        .fullScreenCover(item: $planReady) { preview in
            PlanReadyView(preview: preview) { planReady = nil }
        }
        .onChange(of: model.draft) { _, _ in
            model.validationError = nil
            model.persistDraft()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.persistDraft() }
        }
    }

    // MARK: Shell

    private var stepAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.42)
    }

    private var stepTransition: AnyTransition {
        reduceMotion ? .opacity : .step(forward: movesForward)
    }

    /// Moves on, or shakes the button when the step is not complete yet.
    private func advance() {
        // Only the first profile gets the "plan is ready" moment; changing an existing one goes straight back.
        let creating = model.draft.step == .review && !model.isEditing
        navigate(forward: true) { model.advance() }
        shakeIfRefused()
        if creating, !model.showsOnboarding, let details = model.profile?.details {
            planReady = PlanPreview.make(from: details, now: .now, calendar: .current)
        }
    }

    /// Goes to a step picked on the stepper; forward stops at the first incomplete step.
    private func go(to step: OnboardingStep) {
        navigate(forward: step.rawValue > model.draft.step.rawValue) { model.go(to: step) }
        shakeIfRefused()
    }

    private func shakeIfRefused() {
        guard model.validationError != nil, !reduceMotion else { return }
        withAnimation(.linear(duration: 0.42)) { refusals += 1 }
    }

    private func navigate(forward: Bool, _ change: () -> Void) {
        movesForward = forward
        withAnimation(stepAnimation, change)
    }

    private var wizard: some View {
        let step = model.draft.step
        return ZStack {
            AmbientGlow(anchor: step.glowAnchor)
            if step == .introduction {
                OnboardingIntro(name: $model.draft.name, isEditing: model.isEditing)
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    header
                    ZStack {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 28) {
                                titleBlock(step)
                                stepContent
                            }
                            .entranceScope("step-\(step.rawValue)")
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                            .frame(maxWidth: 620, alignment: .leading)
                            .frame(maxWidth: .infinity)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .scrollBounceBehavior(.basedOnSize)
                        .id(step)
                        .transition(stepTransition)
                    }
                }
                .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        // Changing a saved profile can always be given up, from any step.
        .overlay(alignment: .topTrailing) {
            if model.isEditing {
                Button("Отмена") { navigate(forward: false) { model.cancelEdit() } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FelixTheme.secondary)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .sensoryFeedback(.error, trigger: model.validationError) { _, issue in issue != nil }
    }

    private var header: some View {
        HStack(spacing: 16) {
            FelixIconButton(systemImage: "chevron.left", label: "Предыдущий шаг") {
                navigate(forward: false) { model.back() }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private func titleBlock(_ step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(step.shortTitle, color: FelixTheme.ice)
                .entrance(0)
            Text(step.title)
                .font(.felixTitle)
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
                .entrance(1)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let issue = model.validationError {
                FelixInlineIssue(text: issue)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if let issue = model.storageError {
                FelixInlineIssue(text: issue)
                Button("Повторить сохранение черновика") { model.persistDraft() }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FelixTheme.ice)
            }
            switch model.draft.step {
            case .introduction:
                FelixPrimaryButton(title: primaryTitle, action: advance)
                    .modifier(Shake(attempts: CGFloat(refusals)))
            case .review:
                // The last step is one plain action across the width: what it does is written on it.
                FelixPrimaryButton(title: primaryTitle, systemImage: "checkmark", action: advance)
                    .modifier(Shake(attempts: CGFloat(refusals)))
            default:
                // Where you are and how to jump, above the one action that goes on. A single row edited on its own
                // has nowhere to jump to: it saves, or it is cancelled.
                if !model.savesOnAdvance { OnboardingStepper(current: model.draft.step, onSelect: go(to:)) }
                FelixPrimaryButton(title: primaryTitle, action: advance)
                    .modifier(Shake(attempts: CGFloat(refusals)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 8)
        .frame(maxWidth: 660)
        .frame(maxWidth: .infinity)
        .background {
            // Lighter fade plus a cobalt pool of light, so the glass button has depth to refract.
            ZStack {
                // Dense by the top of the step bar, like the tab bar, so values behind it do not show through.
                LinearGradient(stops: [.init(color: .black.opacity(0), location: 0),
                                       .init(color: .black.opacity(0.9), location: 0.3),
                                       .init(color: .black.opacity(0.94), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [FelixTheme.cobalt.opacity(0.32), .clear],
                               center: .bottom, startRadius: 0, endRadius: 240)
            }
            .ignoresSafeArea()
        }
    }

    private var primaryTitle: String {
        switch model.draft.step {
        case .introduction: "Начать"
        case .review: "Сохранить профиль"
        // A row edited from the profile saves; one edited out of the review leads back there, not on to the next step.
        default: model.savesOnAdvance ? "Сохранить" : (model.returnsToReview ? "К проверке" : "Дальше")
        }
    }

    @ViewBuilder private var stepContent: some View {
        switch model.draft.step {
        case .introduction: EmptyView()
        case .body: bodyParameters
        case .goal: goals.entrance(2)
        case .preferences: ExperienceSelector(selection: $model.draft.experience, build: BodyFigure.Build(model.draft.gender)).entrance(2)
        case .schedule: ScheduleStep(model: model)
        case .limitations: LimitationsStep(model: model)
        case .review:
            VStack(alignment: .leading, spacing: 18) {
                // What the answers add up to, before the answers themselves.
                if let preview = PlanPreview.make(from: model.draft, now: .now, calendar: .current) {
                    PlanPreviewCard(preview: preview).entrance(2)
                }
                ProfileOverview(draft: model.draft) { step in navigate(forward: true) { model.edit(step) } }
                    .entrance(3)
            }
        }
    }

    // MARK: Steps

    private var bodyParameters: some View {
        VStack(alignment: .leading, spacing: 16) {
            CharacterSelect(selection: $model.draft.gender)
                .entrance(2)
            measurement("Рост", unit: "см", text: $model.draft.heightText, fallback: 170,
                        range: 80...250, step: 1, emphasisEvery: 5)
                .entrance(3)
            measurement("Вес", unit: "кг", text: $model.draft.weightText, fallback: 70,
                        range: 20...400, step: 0.5, emphasisEvery: 2)
                .entrance(4)
        }
    }

    private func measurement(_ title: String, unit: String, text: Binding<String>, fallback: Double,
                             range: ClosedRange<Double>, step: Double, emphasisEvery: Int) -> some View {
        // An empty field shows the fallback, and the ruler commits it once it settles.
        let value = Binding<Double> {
            OnboardingDraft.number(text.wrappedValue) ?? fallback
        } set: {
            text.wrappedValue = Self.decimalText($0)
        }
        return RulerPicker(value: value, range: range, step: step, unit: unit, accessibilityName: title,
                           emphasisEvery: emphasisEvery, readoutScale: 0.62, title: title, titleInset: 20,
                           valueText: Self.decimalText, tickText: Self.decimalText)
            .padding(.horizontal, -20)
    }

    private var goals: some View {
        GoalCarousel(selection: $model.draft.goal)
    }

    // MARK: Formatting

    private static func decimalText(_ value: Double) -> String {
        value.rounded() == value
            ? String(Int(value))
            : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Experience

/// Experience select: a vertical track from white (a beginner) to dark (a pro) with five levels. A glass lens
/// follows the finger and settles on the nearest level; the level number shows sharp and enlarged on
/// the lens, as under a magnifier. Beside it an animated emoji acts the level out.
private struct ExperienceSelector: View {
    @Binding var selection: TrainingExperience?
    let build: BodyFigure.Build
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragPosition: Double?

    private let levels = TrainingExperience.allCases
    private let summaries = ["Поставим технику и базовые движения",
                             "Плавно вернём привычный объём",
                             "Добавим системности и ритма",
                             "Будем прогрессировать в весах и объёме",
                             "Периодизация и работа на пределе"]
    private let trackColors: [Color] = [.white, Color(red: 0.8, green: 0.86, blue: 1), FelixTheme.ice,
                                        FelixTheme.cobalt, FelixTheme.cobaltDeep, Color(red: 0.03, green: 0.05, blue: 0.16)]
    private let lensHeight: CGFloat = 66

    private var index: Int? { selection.flatMap { levels.firstIndex(of: $0) } }
    private var position: Double { dragPosition ?? Double(index ?? 0) / Double(levels.count - 1) }
    private var liveIndex: Int { Int((position * Double(levels.count - 1)).rounded()) }
    private var isActive: Bool { selection != nil || dragPosition != nil }

    var body: some View {
        HStack(spacing: 20) {
            character
            track
        }
        .frame(height: 490)
        .sensoryFeedback(.selection, trigger: liveIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Уровень опыта")
        .accessibilityValue(selection?.title ?? "Не выбран")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: commit(min(levels.count - 1, (index ?? -1) + 1))
            case .decrement: commit(max(0, (index ?? 1) - 1))
            @unknown default: break
            }
        }
    }

    private var character: some View {
        // Never darker than cobalt, so the figure stays visible on black at the hard end.
        let tint = Color.white.mix(with: FelixTheme.cobalt, by: position * 0.85)
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow(isActive ? String(format: "Уровень %02d / %02d", liveIndex + 1, levels.count)
                             : String(format: "Уровень — / %02d", levels.count), color: FelixTheme.ice)
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(isActive ? 0.35 : 0.1), .clear],
                                         center: .center, startRadius: 0, endRadius: 110))
                    .frame(width: 220, height: 220)
                Ellipse()
                    .fill(RadialGradient(colors: [tint.opacity(isActive ? 0.75 : 0.2), .clear],
                                         center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 170, height: 32)
                    .offset(y: 10)
                // Stands on the light: soles in the lower half of the ellipse.
                LevelMascot(level: levels[liveIndex], build: build, isActive: isActive)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 290)
            VStack(alignment: .leading, spacing: 6) {
                Text(isActive ? levels[liveIndex].title : "Выбери уровень")
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(isActive ? summaries[liveIndex] : "Потяни рамку по шкале — от новичка до профи")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // The words change at once: crossfading two lines of text overlaps them.
            .transaction { $0.animation = nil }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: liveIndex)
    }

    private var track: some View {
        VStack(spacing: 10) {
            Eyebrow("Новичок")
            GeometryReader { geometry in
                let travel = geometry.size.height - lensHeight
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: trackColors, startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 8)
                    ForEach(levels.indices, id: \.self) { level in
                        let place = Double(level) / Double(levels.count - 1)
                        Text(String(format: "%02d", level + 1))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(place < 0.3 ? Color.black.opacity(0.55) : Color.white.opacity(0.75))
                            .frame(height: lensHeight)
                            // Gives way to the enlarged number as the lens passes over it.
                            .opacity(min(abs(place - position) * travel / (lensHeight * 0.7), 1))
                            .offset(y: travel * place)
                    }
                    lens.offset(y: travel * position)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let target = min(max((drag.location.y - lensHeight / 2) / max(travel, 1), 0), 1)
                        // A tap glides the lens over; a drag tracks the finger directly.
                        if abs(drag.translation.height) < 2 {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { dragPosition = target }
                        } else {
                            dragPosition = target
                        }
                    }
                    .onEnded { _ in commit(liveIndex) })
            }
            Eyebrow("Профи")
        }
        .frame(width: 92)
    }

    private var lens: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return Color.clear
            .frame(height: lensHeight)
            .felixGlass(in: shape, clear: true)
            .overlay {
                // The level under the lens, sharp and enlarged.
                Text(String(format: "%02d", liveIndex + 1))
                    .font(.felixNumber(26, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(position < 0.3 ? Color.black.opacity(0.75) : Color.white)
                    .shadow(color: .black.opacity(position < 0.3 ? 0 : 0.35), radius: 3, y: 1)
                    .contentTransition(.numericText(value: Double(liveIndex)))
                    .opacity(isActive ? 1 : 0)
            }
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.3)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
            .opacity(isActive ? 1 : 0.7)
    }

    private func commit(_ level: Int) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78)) {
            selection = levels[level]
            dragPosition = nil
        }
    }
}

// MARK: - Presentation

private extension OnboardingStep {
    var glowAnchor: UnitPoint {
        switch self {
        case .goal, .limitations: UnitPoint(x: 0.9, y: 0)
        case .body, .schedule: UnitPoint(x: 0.1, y: 0)
        case .introduction, .preferences, .review: UnitPoint(x: 0.5, y: 0)
        }
    }
}
