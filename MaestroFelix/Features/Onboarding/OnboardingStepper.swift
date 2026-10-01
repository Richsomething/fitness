import FelixGlass
import SwiftUI

/// The steps as a glass tab bar at the bottom, like the iOS tab bar: an icon per step and a lighter
/// lens under the current one, which also carries the step's name; passed steps in ice with a small
/// tick, steps ahead dimmed. Any step can be tapped: back always, forward as far as the steps in
/// between are complete. On a step change the lens flows over on a spring and the new icon bounces
/// and throws a few sparks. VoiceOver reads the step names.
struct OnboardingStepper: View {
    let current: OnboardingStep
    let onSelect: (OnboardingStep) -> Void

    @Namespace private var lens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let steps = OnboardingStep.allCases.filter { $0 != .introduction }

    var body: some View {
        GlassGroup {
            HStack(spacing: 2) {
                ForEach(Self.steps) { step in
                    item(step)
                }
            }
            .padding(5)
            .felixGlass(in: Capsule(), interactive: false)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.46, dampingFraction: 0.7), value: current)
    }

    private func item(_ step: OnboardingStep) -> some View {
        let isCurrent = step == current
        let isPassed = step.rawValue < current.rawValue
        return Button { onSelect(step) } label: {
            HStack(spacing: 6) {
                Image(systemName: step.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolEffect(.bounce.up.byLayer, options: .speed(1.3), value: isCurrent)
                    .overlay(alignment: .topTrailing) {
                        if isPassed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(FelixTheme.ice, FelixTheme.cobaltDeep)
                                .offset(x: 5, y: -4)
                                .transition(.scale(scale: 0.2).combined(with: .opacity))
                        }
                    }
                    .background {
                        if isCurrent && !reduceMotion {
                            SparkBurst(trigger: current).frame(width: 70, height: 70)
                        }
                    }
                if isCurrent {
                    Text(step.shortTitle)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .foregroundStyle(isCurrent ? Color.white : isPassed ? FelixTheme.ice : Color.white.opacity(0.62))
            .padding(.horizontal, isCurrent ? 14 : 0)
            .frame(maxWidth: isCurrent ? nil : .infinity, minHeight: 46)
                .background {
                    if isCurrent { GlassLens().matchedGeometryEffect(id: "lens", in: lens) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(isCurrent)
        .accessibilityLabel(step.shortTitle)
        .accessibilityValue(isCurrent ? "Текущий шаг" : isPassed ? "Пройден" : "Впереди")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

extension OnboardingStep {
    var shortTitle: String {
        switch self {
        case .introduction: "Знакомство"
        case .body: "Параметры"
        case .goal: "Цель"
        case .preferences: "Опыт"
        case .schedule: "Расписание"
        case .limitations: "Здоровье"
        case .review: "Проверка"
        }
    }

    var symbol: String {
        switch self {
        case .introduction: "person.fill"
        case .body: "figure.stand"
        case .goal: "target"
        case .preferences: "chart.bar.fill"
        case .schedule: "calendar"
        case .limitations: "cross.case.fill"
        case .review: "checkmark.seal.fill"
        }
    }
}
