import SwiftUI

/// Goals as selectable classes: swipe, or tap a side card; the centred card is the choice.
struct GoalCarousel: View {
    @Binding var selection: TrainingGoal?
    @State private var focused: TrainingGoal?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let goals = TrainingGoal.allCases

    var body: some View {
        VStack(spacing: 18) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(goals.enumerated()), id: \.element) { offset, goal in
                        GoalClassCard(goal: goal, number: offset + 1, total: goals.count, focused: focused == goal)
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                    .opacity(phase.isIdentity ? 1 : 0.45)
                                    .rotation3DEffect(.degrees(phase.value * -10), axis: (x: 0, y: 1, z: 0))
                            }
                            .onTapGesture { focus(goal) }
                            .accessibilityAddTraits(focused == goal ? [.isButton, .isSelected] : .isButton)
                            .accessibilityAction { focus(goal) }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 52, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focused)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .frame(height: 460)
            // Swiping is not the only way: arrows with a full-size target, and the position between them.
            HStack(spacing: 12) {
                step("chevron.left", label: "Предыдущая цель", to: -1)
                HStack(spacing: 8) {
                    ForEach(goals, id: \.self) { goal in
                        Capsule()
                            .fill(goal == focused ? Color.white : Color.white.opacity(0.22))
                            .frame(width: goal == focused ? 24 : 8, height: 8)
                    }
                }
                .accessibilityHidden(true)
                step("chevron.right", label: "Следующая цель", to: 1)
            }
        }
        .padding(.horizontal, -20)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: focused)
        .onAppear { if focused == nil { focused = selection ?? goals.first } }
        .onChange(of: focused) { _, goal in
            if let goal, selection != goal { selection = goal }
        }
        .sensoryFeedback(.selection, trigger: focused)
    }

    private func focus(_ goal: TrainingGoal) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { focused = goal }
    }

    /// An arrow that moves the choice one goal along; dimmed at the ends.
    private func step(_ symbol: String, label: String, to direction: Int) -> some View {
        let current = goals.firstIndex(of: focused ?? goals[0]) ?? 0
        let target = current + direction
        let enabled = goals.indices.contains(target)
        return Button {
            if enabled { focus(goals[target]) }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(enabled ? FelixTheme.text : FelixTheme.tertiary.opacity(0.5))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

private struct GoalClassCard: View {
    let goal: TrainingGoal
    let number: Int
    let total: Int
    let focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Цель \(number) из \(total)", color: FelixTheme.ice)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [FelixTheme.cobalt.opacity(focused ? 0.8 : 0.3), .clear],
                                         center: .center, startRadius: 0, endRadius: 62))
                    .frame(width: 124, height: 124)
                Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1).frame(width: 88, height: 88)
                Circle().strokeBorder(Color.white.opacity(0.06), lineWidth: 1).frame(width: 118, height: 118)
                Image(systemName: goal.symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: FelixTheme.cobalt, radius: focused ? 22 : 0)
                    .symbolEffect(.bounce, value: focused)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 124)
            Text(goal.title)
                .font(.felixHeadline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(goal.detail)
                .font(.subheadline)
                .foregroundStyle(FelixTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            // What the plan will actually do with this choice, in the words of the plan's own rules.
            Label(goal.planSummary, systemImage: "list.bullet.rectangle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FelixTheme.ice)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            Spacer(minLength: 6)
            // The numbers illustrate where the plan puts its weight; they are not measurements of the person.
            Eyebrow("Примерный акцент · шкала 1–5")
            StatRadar(stats: goal.emphasis, isActive: focused)
                .frame(height: 150)
                .padding(.top, 14)
        }
        .foregroundStyle(FelixTheme.text)
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(LinearGradient(colors: focused ? [FelixTheme.cobaltDeep.opacity(0.7), Color.black.opacity(0.35)]
                                                          : [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                                          startPoint: .top, endPoint: .bottom))
                if focused { LightTrails(intensity: 0.35).clipShape(shape) }
            }
        }
        .overlay(shape.strokeBorder(focused
                                    ? AnyShapeStyle(LinearGradient(colors: [FelixTheme.ice.opacity(0.9), FelixTheme.cobalt.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(Color.white.opacity(0.1)),
                                    lineWidth: focused ? 1.5 : 1))
        .shadow(color: focused ? FelixTheme.cobalt.opacity(0.45) : .clear, radius: 24, y: 10)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stat radar

/// A goal's three emphases as a triangle radar, like a character's stat chart. The shape grows in
/// when its card comes into focus.
private struct StatRadar: View {
    let stats: [GoalEmphasis]
    let isActive: Bool

    private static let maximum = 5.0
    private static let centerY = 0.58
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height * Self.centerY)
            let radius = min(geometry.size.width * 0.3, geometry.size.height * 0.42)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [FelixTheme.cobalt.opacity(isActive ? 0.35 : 0), .clear],
                                         center: .center, startRadius: 0, endRadius: radius))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                grid(center: center, radius: radius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                grid(center: center, radius: radius, levels: [1])
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                let shape = polygon(center: center, radius: radius)
                shape
                    .fill(LinearGradient(colors: [FelixTheme.ice.opacity(0.55), FelixTheme.cobalt.opacity(0.55)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(shape.stroke(FelixTheme.ice, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round)))
                    .shadow(color: FelixTheme.cobalt, radius: 10)
                    .scaleEffect(isActive ? 1 : 0.35, anchor: UnitPoint(x: 0.5, y: Self.centerY))
                    .opacity(isActive ? 1 : 0.45)
                ForEach(stats.indices, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 7, height: 7)
                        .shadow(color: FelixTheme.ice, radius: 4)
                        .position(point(index, fraction: isActive ? Double(stats[index].value) / Self.maximum : 0.12,
                                        center: center, radius: radius))
                        .opacity(isActive ? 1 : 0)
                    label(stats[index])
                        .position(labelPoint(index, center: center, radius: radius))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: isActive)
        }
    }

    private func label(_ stat: GoalEmphasis) -> some View {
        HStack(spacing: 5) {
            Text(stat.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FelixTheme.secondary)
            Text("\(stat.value)")
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(FelixTheme.ice)
        }
        .fixedSize()
    }

    /// Top, bottom right, bottom left.
    private func angle(_ index: Int) -> Double {
        -Double.pi / 2 + Double(index) * 2 * Double.pi / 3
    }

    private func point(_ index: Int, fraction: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + radius * fraction * cos(angle(index)), y: center.y + radius * fraction * sin(angle(index)))
    }

    /// One ring per step of the 1–5 scale, and the three axes.
    private func grid(center: CGPoint, radius: CGFloat, levels: [Double] = [0.2, 0.4, 0.6, 0.8]) -> Path {
        var path = Path()
        for level in levels {
            path.addLines((0..<3).map { point($0, fraction: level, center: center, radius: radius) })
            path.closeSubpath()
        }
        for index in 0..<3 where levels.count > 1 {
            path.move(to: center)
            path.addLine(to: point(index, fraction: 1, center: center, radius: radius))
        }
        return path
    }

    private func polygon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        path.addLines(stats.indices.map {
            point($0, fraction: Double(stats[$0].value) / Self.maximum, center: center, radius: radius)
        })
        path.closeSubpath()
        return path
    }

    private func labelPoint(_ index: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let vertex = point(index, fraction: 1, center: center, radius: radius)
        return index == 0 ? CGPoint(x: vertex.x, y: vertex.y - 16) : CGPoint(x: vertex.x, y: vertex.y + 18)
    }
}

// MARK: - Goal presentation

struct GoalEmphasis {
    let name: String
    let value: Int
}

extension TrainingGoal {
    // What each goal leans on, out of 5; an illustration for the choice, not a generated plan.
    var emphasis: [GoalEmphasis] {
        switch self {
        case .fatLoss: [GoalEmphasis(name: "Кардио", value: 5), GoalEmphasis(name: "Сила", value: 3), GoalEmphasis(name: "Мышцы", value: 2)]
        case .muscleGain: [GoalEmphasis(name: "Кардио", value: 2), GoalEmphasis(name: "Сила", value: 4), GoalEmphasis(name: "Мышцы", value: 5)]
        case .maintenance: [GoalEmphasis(name: "Кардио", value: 3), GoalEmphasis(name: "Сила", value: 3), GoalEmphasis(name: "Мышцы", value: 3)]
        }
    }

    /// What the day's dose does for this goal — the same numbers the planner uses.
    var planSummary: String {
        switch self {
        case .fatLoss: "Повторений 12–15, отдых около 45 секунд"
        case .muscleGain: "Повторений 8–12, отдых до 90 секунд, подходов больше"
        case .maintenance: "Повторений 10–12, отдых около минуты"
        }
    }

    var symbol: String {
        switch self {
        case .fatLoss: "flame.fill"
        case .muscleGain: "dumbbell.fill"
        case .maintenance: "figure.run"
        }
    }
}
