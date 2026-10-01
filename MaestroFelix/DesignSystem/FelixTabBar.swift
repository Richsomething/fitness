import SwiftUI

extension AppTab {
    static let ordered: [AppTab] = [.today, .plan, .progress, .profile]

    var title: String {
        switch self {
        case .today: "Сегодня"
        case .plan: "План"
        case .progress: "Прогресс"
        case .profile: "Профиль"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max.fill"
        case .plan: "calendar"
        case .progress: "chart.line.uptrend.xyaxis"
        case .profile: "person.fill"
        }
    }
}

/// The bottom bar: a glass capsule with the cobalt lens under the open tab, the same pair of pieces as
/// `GlassSegmented` and the step bar of the sign-up, so a choice looks the same wherever it is made.
/// It replaces the system tab bar, whose own lens could not be made to match.
struct FelixTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var lens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.ordered, id: \.self) { tab in
                item(tab)
            }
        }
        .padding(4)
        .felixGlass(in: Capsule(), interactive: false)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.78), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        // Like the system bar, it stays at a size that fits four tabs however large the text is set.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        // Sits lower than the home-indicator inset, like the system bar, so it does not float with a wide gap.
        .padding(.bottom, -12)
        // Black under the bar down to the screen edge, and a fade above it, so content scrolling toward the
        // bar goes out softly instead of being cut.
        .background(alignment: .bottom) { Color.black.ignoresSafeArea(edges: .bottom) }
        .overlay(alignment: .top) {
            LinearGradient(colors: [Color.black.opacity(0), Color.black], startPoint: .top, endPoint: .bottom)
                .frame(height: 22)
                .offset(y: -22)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Разделы")
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = tab == selection
        return Button { selection = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(height: 24)
                Text(tab.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.white : FelixTheme.secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                if isSelected { GlassLens().matchedGeometryEffect(id: "lens", in: lens) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
