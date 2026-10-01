import SwiftUI

/// Motion shared by the screens: blocks that rise into place one after another, a step change that
/// slides and focuses, a shake for a refused action and a burst of sparks for an arrival. All of it
/// steps aside for Reduce Motion.

// MARK: - Entrance

/// Remembers which screens already played their entrance in this run, so coming back to a screen
/// shows it at once instead of staggering its blocks in again.
@MainActor
final class EntranceLedger {
    static let shared = EntranceLedger()
    private var played: Set<String> = []

    func hasPlayed(_ scope: String) -> Bool { played.contains(scope) }
    func markPlayed(_ scope: String) { played.insert(scope) }
    func reset() { played = [] }
}

private struct EntranceScopeKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var entranceScope: String? {
        get { self[EntranceScopeKey.self] }
        set { self[EntranceScopeKey.self] = newValue }
    }
}

private struct EntranceScope: ViewModifier {
    let id: String
    // Long enough for the staggered blocks to finish before the screen counts as seen.
    private static let settle: Duration = .seconds(0.9)

    func body(content: Content) -> some View {
        content
            .environment(\.entranceScope, id)
            .task {
                try? await Task.sleep(for: Self.settle)
                EntranceLedger.shared.markPlayed(id)
            }
    }
}

extension View {
    /// Names a screen for `entrance`: its blocks rise in the first time it shows and are simply there after.
    func entranceScope(_ id: String) -> some View {
        modifier(EntranceScope(id: id))
    }
}

/// Rises, fades and sharpens into place when it first appears; `order` staggers siblings. Inside an
/// `entranceScope` that already played, it does nothing.
private struct Entrance: ViewModifier {
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.entranceScope) private var scope
    @State private var isShown = false

    // Quick on purpose: a screen reads as ready within about a third of a second, so moving between
    // tabs and sheets never shows an empty frame for long.
    private static let firstDelay = 0.0
    private static let stagger = 0.035

    func body(content: Content) -> some View {
        let seen = scope.map { EntranceLedger.shared.hasPlayed($0) } ?? false
        let visible = isShown || seen
        let hidden = !visible && !reduceMotion
        return content
            .opacity(visible ? 1 : 0)
            .offset(y: hidden ? 10 : 0)
            .onAppear {
                guard !seen else { return }
                let delay = Self.firstDelay + Double(order) * Self.stagger
                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.28).delay(delay)) {
                    isShown = true
                }
            }
    }
}

extension View {
    func entrance(_ order: Int) -> some View {
        modifier(Entrance(order: order))
    }
}

// MARK: - Step change

/// Slides a whole step in from the side while it comes into focus.
private struct StepShift: ViewModifier {
    let offset: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.offset(x: offset).blur(radius: blur).opacity(opacity)
    }
}

extension AnyTransition {
    static func step(forward: Bool) -> AnyTransition {
        let shift: CGFloat = forward ? 44 : -44
        return .asymmetric(
            insertion: .modifier(active: StepShift(offset: shift, blur: 10, opacity: 0), identity: StepShift(offset: 0, blur: 0, opacity: 1)),
            removal: .modifier(active: StepShift(offset: -shift * 0.6, blur: 10, opacity: 0), identity: StepShift(offset: 0, blur: 0, opacity: 1)))
    }
}

// MARK: - Shake

/// A short sideways shake each time `attempts` grows, for an action that was refused.
struct Shake: GeometryEffect {
    var attempts: CGFloat

    var animatableData: CGFloat {
        get { attempts }
        set { attempts = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(attempts * .pi * 4), y: 0))
    }
}

// MARK: - Sparks

/// Sparks thrown out of a point and fading, once per change of `trigger`.
struct SparkBurst<Trigger: Equatable>: View {
    let trigger: Trigger
    var color = FelixTheme.ice

    private static var sparkCount: Int { 10 }
    private static var duration: Double { 0.75 }

    var body: some View {
        Color.clear
            .keyframeAnimator(initialValue: 1.0, trigger: trigger) { _, progress in
                Canvas { context, size in
                    draw(progress: progress, in: context, size: size)
                }
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(1, duration: Self.duration)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func draw(progress: Double, in context: GraphicsContext, size: CGSize) {
        guard progress < 1 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let eased = 1 - pow(1 - progress, 3)
        let fade = 1 - progress
        let ring = 6 + 22 * eased
        context.stroke(Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)),
                       with: .color(color.opacity(0.6 * fade)), lineWidth: 1.2)
        for index in 0..<Self.sparkCount {
            let angle = Double(index) / Double(Self.sparkCount) * 2 * .pi + (index.isMultiple(of: 2) ? 0.2 : -0.1)
            let reach = (index.isMultiple(of: 2) ? 26.0 : 18.0) * eased + 5
            let point = CGPoint(x: center.x + cos(angle) * reach, y: center.y + sin(angle) * reach)
            let radius = 2.2 * fade + 0.4
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color((index.isMultiple(of: 3) ? Color.white : color).opacity(fade)))
        }
    }
}
