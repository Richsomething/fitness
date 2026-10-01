import SwiftUI

/// One tab of a `GlassTabBar`: what it is, what it is called and its symbol.
public struct GlassTabItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: String
    public let symbol: String

    public init(id: ID, title: String, symbol: String) {
        self.id = id
        self.title = title
        self.symbol = symbol
    }
}

/// A bar of a few tabs as one glass capsule, with a lens under the open one. It only draws and reports the choice:
/// the app decides where the bar sits and what it shows, so it works in place of the system bar or beside it.
public struct GlassTabBar<ID: Hashable>: View {
    private let items: [GlassTabItem<ID>]
    @Binding private var selection: ID
    @Namespace private var lens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.glassPalette) private var palette

    public init(items: [GlassTabItem<ID>], selection: Binding<ID>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        GlassGroup {
            HStack(spacing: 2) {
                ForEach(items) { tab($0) }
            }
            .padding(4)
            .glassSurface(in: Capsule(), style: .regular, interactive: false)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.78), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tab(_ item: GlassTabItem<ID>) -> some View {
        let isSelected = item.id == selection
        return Button { selection = item.id } label: {
            VStack(spacing: 3) {
                Image(systemName: item.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(height: 24)
                Text(item.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.white : palette.secondaryLabel)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                if isSelected { GlassSelectionLens().matchedGeometryEffect(id: "lens", in: lens) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
