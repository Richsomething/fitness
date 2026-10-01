import FelixGlass
import SwiftUI
import SwiftData

@main
struct MaestroFelixApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
                .tint(FelixTheme.accent)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                // The glass of FelixGlass takes its colours from the app's theme.
                .environment(\.glassPalette, GlassPalette(accent: FelixTheme.cobalt, accentDeep: FelixTheme.cobaltDeep,
                                                         label: FelixTheme.text, secondaryLabel: FelixTheme.secondary))
        }
    }
}

@MainActor
struct AppRootView: View {
    @State private var model: OnboardingModel?
    @State private var coordinator: AppCoordinator?
    @State private var failed = false
    // One container for the life of the app; erasing the data starts over on the same one.
    @State private var container: ModelContainer?

    var body: some View {
        ZStack {
            FelixBackground()
            if let model, let coordinator {
                OnboardingRootView(model: model)
                    .environment(coordinator)
            } else if failed {
                ContentUnavailableView {
                    Label("Не удалось открыть профиль", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Данные не удалены. Попробуй открыть хранилище ещё раз.")
                } actions: {
                    Button("Повторить", action: load)
                }
            } else {
                ProgressView("Открываем профиль…")
            }
        }
        .foregroundStyle(FelixTheme.text)
        .task { if model == nil && !failed { load() } }
    }

    private func load() {
        do {
            let storage = try container ?? Self.makeContainer()
            let repository = SwiftDataProfileRepository(container: storage)
            let loaded = try OnboardingModel(repository: repository)
            let app = AppCoordinator(store: repository, onboarding: loaded, scheduler: SystemNotificationScheduler())
            app.onErase = { restart() }
            container = storage
            coordinator = app
            model = loaded
            failed = false
        } catch {
            failed = true
        }
    }

    /// After everything was erased: forget what is in memory and open a clean profile.
    private func restart() {
        model = nil
        coordinator = nil
        EntranceLedger.shared.reset()
        load()
    }

    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: ProfileSchemaV1.self)
        return try ModelContainer(for: schema, migrationPlan: ProfileMigrationPlan.self,
                                  configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)])
    }
}
