import SwiftUI

/// The app after sign-up: Today, Plan, Progress and Profile, and the workout over all of them.
struct MainTabView: View {
    let edit: (OnboardingStep) -> Void
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = coordinator
        // The system bar is hidden and FelixTabBar stands in its place; TabView still keeps each tab's state.
        // The bar takes room under the tabs instead of floating over them, so a screen pushed inside a tab
        // (with actions of its own at the bottom) ends above it.
        VStack(spacing: 0) {
            tabs(selection: $app.selectedTab)
            FelixTabBar(selection: $app.selectedTab)
        }
        .background(Color.black.ignoresSafeArea())
        .tint(FelixTheme.ice)
        .environment(\.bodyBuild, BodyFigure.Build(app.profile?.gender))
        .fullScreenCover(item: $app.activeSession) { session in
            WorkoutSessionView(session: session)
                .environment(coordinator)
        }
        .task { coordinator.becameActive() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { coordinator.becameActive() }
        }
        .onChange(of: AppRouter.shared.opensToday) { _, opens in
            guard opens else { return }
            coordinator.selectedTab = .today
            AppRouter.shared.opensToday = false
        }
    }

    private func tabs(selection: Binding<AppTab>) -> some View {
        TabView(selection: selection) {
            Tab(AppTab.today.title, systemImage: AppTab.today.symbol, value: AppTab.today) {
                TodayScreen().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(AppTab.plan.title, systemImage: AppTab.plan.symbol, value: AppTab.plan) {
                PlanScreen(edit: edit).toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(AppTab.progress.title, systemImage: AppTab.progress.symbol, value: AppTab.progress) {
                ProgressScreen().toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab(AppTab.profile.title, systemImage: AppTab.profile.symbol, value: AppTab.profile) {
                ProfileScreen(edit: edit).toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
    }
}
