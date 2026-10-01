import SwiftUI

public extension View {
    /// Puts glass behind a view, cut to `shape`. On iOS 26 and later it is the system's Liquid Glass (`interactive`
    /// makes it react to touch); before that, or with `GlassEngine.frosted`, the library's own frosted glass.
    func glassSurface<S: InsettableShape>(in shape: S, style: GlassStyle = .regular, interactive: Bool = true) -> some View {
        modifier(GlassSurface(shape: shape, style: style, interactive: interactive))
    }
}

struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let style: GlassStyle
    let interactive: Bool
    @Environment(\.glassPalette) private var palette
    @Environment(\.glassEngine) private var engine

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if engine == .automatic {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(systemGlass, in: shape)
                    // Only a coloured glow; plain system glass casts none.
                    .shadow(color: style.shadowUsesAccent ? palette.accent.opacity(style.shadowOpacity) : Color.clear,
                            radius: style.shadowRadius, y: style.shadowY)
            } else {
                frosted(content)
            }
        } else {
            frosted(content)
        }
        #else
        frosted(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var systemGlass: Glass {
        let base: Glass = style.isClear ? .clear : .regular
        return base.tint(style.systemTint(palette)).interactive(interactive)
    }
    #endif

    // MARK: Frosted

    private func frosted(_ content: Content) -> some View {
        content
            .background { frostedBase.shadow(color: shadowColor, radius: style.shadowRadius, y: style.shadowY) }
            .overlay { edge }
    }

    private var shadowColor: Color {
        style.shadowUsesAccent ? palette.accent.opacity(style.shadowOpacity) : Color.black.opacity(style.shadowOpacity)
    }

    /// The blur, a pale body, the accent, and a light from above, in that order.
    private var frostedBase: some View {
        ZStack {
            if style.usesBlur { shape.fill(.ultraThinMaterial) }
            shape.fill(LinearGradient(colors: [Color.white.opacity(style.fillTop), Color.white.opacity(style.fillBottom)],
                                      startPoint: .top, endPoint: .bottom))
            if style.accentTop > 0 {
                shape.fill(LinearGradient(colors: [palette.accent.opacity(style.accentTop), palette.accentDeep.opacity(style.accentBottom)],
                                          startPoint: .top, endPoint: .bottom))
            }
            if let tint = style.tint { shape.fill(tint) }
            shape.fill(LinearGradient(colors: [Color.white.opacity(style.highlight), Color.clear],
                                      startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)))
        }
    }

    private var edge: some View {
        shape
            .strokeBorder(LinearGradient(colors: [Color.white.opacity(style.edgeTop), Color.white.opacity(style.edgeBottom)],
                                         startPoint: .top, endPoint: .bottom), lineWidth: 1)
            .allowsHitTesting(false)
    }
}

/// Groups glass so that on iOS 26 and later neighbouring pieces blend and move as one material, which is how a bar
/// and the lens under its chosen item should behave. Before that it is just a container.
public struct GlassGroup<Content: View>: View {
    private let spacing: CGFloat?
    private let content: Content
    @Environment(\.glassEngine) private var engine

    public init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    public var body: some View {
        #if compiler(>=6.2)
        if engine == .automatic {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: spacing) { content }
            } else {
                content
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
