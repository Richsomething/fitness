import SwiftUI

public extension View {
    /// The chrome of a sheet: its sizes and a drag indicator. On iOS 26 and later the system's glass sheet is left
    /// alone, so the sheet is glass; before that, or with `GlassEngine.frosted`, it gets a dark ground of its own
    /// (`fallbackBackground`) and round corners.
    func glassSheet(detents: Set<PresentationDetent> = [.medium],
                    fallbackBackground: Color = Color(red: 0.035, green: 0.04, blue: 0.07),
                    cornerRadius: CGFloat = 34) -> some View {
        modifier(GlassSheet(detents: detents, fallbackBackground: fallbackBackground, cornerRadius: cornerRadius))
    }
}

struct GlassSheet: ViewModifier {
    let detents: Set<PresentationDetent>
    let fallbackBackground: Color
    let cornerRadius: CGFloat
    @Environment(\.glassEngine) private var engine

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if engine == .automatic {
            if #available(iOS 26.0, *) {
                content
                    .presentationDetents(detents)
                    .presentationDragIndicator(.visible)
            } else {
                fallback(content)
            }
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(cornerRadius)
            .presentationBackground(fallbackBackground)
    }
}
