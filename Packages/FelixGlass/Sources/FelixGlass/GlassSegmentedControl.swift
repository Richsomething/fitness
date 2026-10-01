import SwiftUI

/// The lens under the chosen segment or tab: accent glass that slides from one to the next when it is given the same
/// `matchedGeometryEffect` id in a shared namespace.
public struct GlassSelectionLens: View {
    public init() {}

    public var body: some View {
        Color.clear.glassSurface(in: Capsule(), style: .lens, interactive: false)
    }
}

/// A short choice between a few named options, as a glass capsule with a lens under the chosen one.
public struct GlassSegmentedControl<Value: Hashable>: View {
    private let options: [(value: Value, title: String)]
    @Binding private var selection: Value
    private let density: GlassDensity
    @Namespace private var lens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.glassPalette) private var palette

    public init(options: [(value: Value, title: String)], selection: Binding<Value>, density: GlassDensity = .regular) {
        self.options = options
        self._selection = selection
        self.density = density
    }

    public var body: some View {
        GlassGroup {
            HStack(spacing: 2) {
                ForEach(options.indices, id: \.self) { index in
                    segment(options[index])
                }
            }
            .padding(4)
            .glassSurface(in: Capsule(), style: .regular, interactive: false)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.78), value: selection)
    }

    private func segment(_ option: (value: Value, title: String)) -> some View {
        let isSelected = option.value == selection
        return Button { selection = option.value } label: {
            Text(option.title)
                .font(density.font)
                .foregroundStyle(isSelected ? Color.white : palette.secondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(density.minimumScale)
                .padding(.horizontal, density.horizontalPadding)
                .frame(maxWidth: .infinity, minHeight: density.minHeight)
                .background {
                    if isSelected { GlassSelectionLens().matchedGeometryEffect(id: "lens", in: lens) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
