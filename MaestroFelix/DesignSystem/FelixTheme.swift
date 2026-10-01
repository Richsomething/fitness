import FelixGlass
import SwiftUI
import UIKit

/// Design tokens: a true-black canvas, one electric cobalt accent and ice blue for small accent text.
enum FelixTheme {
    static let background = Color.black
    static let text = Color.white
    // Both stay above 4.5:1 on black and on the cobalt gradients, where a line of light may pass behind.
    static let secondary = Color.white.opacity(0.74)
    static let tertiary = Color.white.opacity(0.62)
    static let hairline = Color.white.opacity(0.1)
    static let surface = Color.white.opacity(0.06)
    static let surfaceStrong = Color.white.opacity(0.11)
    static let cobalt = Color(red: 0.16, green: 0.36, blue: 1)
    static let cobaltDeep = Color(red: 0.05, green: 0.14, blue: 0.62)
    // Plain cobalt is below 4.5:1 on black, so small accent text uses ice.
    static let ice = Color(red: 0.64, green: 0.74, blue: 1)
    static let accent = ice
    static let critical = Color(red: 1, green: 0.48, blue: 0.45)
    static let cardRadius: CGFloat = 28
}

/// Type: headings and big numbers in SF Pro Expanded, wide and sporty; everything else in SF Pro.
/// Labels are written in sentence case, never capitals.
extension Font {
    /// Screen titles. One step below a large title: the wide face runs to three lines on a small
    /// iPhone otherwise.
    static let felixTitle = Font.title.bold().width(.expanded)
    /// Titles inside cards and sheets.
    static let felixHeadline = Font.title2.bold().width(.expanded)

    /// A hero title at a given size, for scaled metrics.
    static func felixDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).width(.expanded)
    }

    /// Big readouts: weight, time, counters.
    static func felixNumber(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }
}

/// A short label above a section or a value, in sentence case.
struct Eyebrow: View {
    let text: String
    var color: Color

    init(_ text: String, color: Color = FelixTheme.secondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
    }
}

struct FelixBackground: View {
    var body: some View {
        ZStack {
            FelixTheme.background
            LinearGradient(colors: [FelixTheme.cobaltDeep.opacity(0.2), .clear], startPoint: .top, endPoint: .center)
        }
        .ignoresSafeArea()
    }
}

/// Soft cobalt light that drifts to a new position with each screen.
struct AmbientGlow: View {
    var anchor = UnitPoint(x: 0.85, y: 0)

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(FelixTheme.cobalt.opacity(0.4))
                .frame(width: geometry.size.width * 1.1)
                .blur(radius: 110)
                .position(x: geometry.size.width * anchor.x,
                          y: geometry.size.height * anchor.y - geometry.size.width * 0.3)
            // A second, deeper light low on the screen gives glass controls something to refract.
            Circle()
                .fill(FelixTheme.cobaltDeep.opacity(0.45))
                .frame(width: geometry.size.width * 0.9)
                .blur(radius: 120)
                .position(x: geometry.size.width * (1 - anchor.x),
                          y: geometry.size.height + geometry.size.width * 0.05)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Dark glass panel with a light top edge; `highlighted` marks the selected option.
struct CardSurface: View {
    var radius = FelixTheme.cardRadius
    var highlighted = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let fill = highlighted
            ? LinearGradient(colors: [FelixTheme.cobalt.opacity(0.34), FelixTheme.cobalt.opacity(0.14)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.035)], startPoint: .top, endPoint: .bottom)
        let edge = highlighted
            ? LinearGradient(colors: [FelixTheme.cobalt, FelixTheme.cobalt.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom)
        // Frosted base so the ambient glow behind the card reads as glass.
        shape.fill(.ultraThinMaterial)
            .overlay(shape.fill(fill))
            .overlay(shape.strokeBorder(edge, lineWidth: highlighted ? 1.5 : 1))
            .shadow(color: highlighted ? FelixTheme.cobalt.opacity(0.35) : .clear, radius: 18, y: 8)
    }
}

struct FelixCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardSurface())
    }
}

extension View {
    /// Glass behind a view, from the FelixGlass library: the system's Liquid Glass on iOS 26 and later, the library's
    /// frosted glass before that. `clear` keeps what is underneath readable, for a lens over content; `tint` colours
    /// the glass, and changing it animates, so a toggle can light up without swapping views.
    func felixGlass<S: InsettableShape>(in shape: S, interactive: Bool = true, clear: Bool = false,
                                        tint: Color? = nil) -> some View {
        glassSurface(in: shape, style: (clear ? GlassStyle.clear : GlassStyle.regular).tinted(tint), interactive: interactive)
    }

    /// Accent-tinted glass for the primary action.
    func felixTintedGlass<S: InsettableShape>(in shape: S) -> some View {
        glassSurface(in: shape, style: .accent)
    }
}

struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The main action of a screen: accent glass across the width. The look lives in `FelixGlass`.
struct FelixPrimaryButton: View {
    let title: String
    var systemImage: String? = "arrow.right"
    let action: () -> Void

    var body: some View {
        GlassButton(title, systemImage: systemImage, role: .primary, action: action)
    }
}

struct FelixSecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        GlassButton(title, systemImage: systemImage, role: .secondary, action: action)
    }
}

struct FelixIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        GlassIconButton(systemImage: systemImage, label: label, action: action)
    }
}

/// Large selectable row: icon disc, title and optional detail. Selection is shown by the surface only.
struct OptionCard: View {
    let title: String
    var detail: String?
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .symbolEffect(.bounce, value: selected)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(selected ? FelixTheme.cobalt : Color.white.opacity(0.08)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    if let detail {
                        Text(detail).font(.subheadline).foregroundStyle(FelixTheme.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(FelixTheme.text)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(CardSurface(radius: 24, highlighted: selected))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct FelixTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(title)
            TextField(title, text: $text, prompt: Text(placeholder).foregroundStyle(FelixTheme.tertiary))
                .font(.title3.weight(.medium))
                .submitLabel(.done)
                .padding(.horizontal, 20)
                .frame(minHeight: 60)
                .background(CardSurface(radius: 20))
        }
    }
}

struct FelixInlineIssue: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(FelixTheme.critical)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Drifting cobalt light streaks. Static when Reduce Motion is on.
struct LightTrails: View {
    var intensity = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                context.blendMode = .plusLighter
                for index in 0..<5 {
                    let path = Self.trail(index: index, time: time, in: size)
                    let color = index.isMultiple(of: 2) ? FelixTheme.cobalt : FelixTheme.ice
                    var glow = context
                    glow.addFilter(.blur(radius: 14))
                    glow.stroke(path, with: .color(color.opacity(0.5 * intensity)), lineWidth: 10)
                    var core = context
                    core.addFilter(.blur(radius: 1.2))
                    core.stroke(path, with: .color(color.opacity(0.85 * intensity)), lineWidth: index == 0 ? 2 : 1.2)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func trail(index: Int, time: Double, in size: CGSize) -> Path {
        let offset = Double(index)
        let phase = time * (0.35 + offset * 0.07) + offset * 1.3
        let baseline = size.height * (0.32 + offset * 0.12)
        let amplitude = size.height * (0.08 + 0.025 * offset)
        var path = Path()
        for step in 0...48 {
            let t = Double(step) / 48
            let point = CGPoint(x: -40 + (size.width + 80) * t,
                                y: baseline + sin(t * .pi * 1.7 + phase) * amplitude
                                    + cos(t * .pi * 0.8 - phase * 0.6) * amplitude * 0.5
                                    - t * size.height * 0.18)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
