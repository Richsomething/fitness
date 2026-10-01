import FelixGlass
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

/// The bottom bar: the FelixGlass tab bar (a glass capsule with a glass lens under the open tab, the same pair of
/// pieces as `GlassSegmented` and the step bar of the sign-up, so a choice looks the same wherever it is made) set
/// on a pool of cobalt light. It replaces the system tab bar, whose own lens could not be made to match.
struct FelixTabBar: View {
    @Binding var selection: AppTab

    private var items: [GlassTabItem<AppTab>] {
        AppTab.ordered.map { GlassTabItem(id: $0, title: $0.title, symbol: $0.symbol) }
    }

    var body: some View {
        GlassTabBar(items: items, selection: $selection)
            // Like the system bar, it stays at a size that fits four tabs however large the text is set.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            // Sits lower than the home-indicator inset, like the system bar, so it does not float with a wide gap.
            .padding(.bottom, -12)
            // Black under the bar down to the screen edge with a soft cobalt light in it: glass over flat black has
            // nothing to show, and the light is what it picks up. A fade above it lets content scrolling toward the
            // bar go out softly instead of being cut.
            .background(alignment: .bottom) {
                ZStack {
                    Color.black
                    RadialGradient(colors: [FelixTheme.cobaltDeep.opacity(0.6), .clear], center: .bottom,
                                   startRadius: 0, endRadius: 220)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                LinearGradient(colors: [Color.black.opacity(0), Color.black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 22)
                    .offset(y: -22)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Разделы")
    }
}
