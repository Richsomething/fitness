import SwiftUI

/// The fourth tab: who the plan is for and how the app behaves. Body, goal and days open the same
/// steps as the first sign-up; the coach, reminders and data have screens of their own.
struct ProfileScreen: View {
    let edit: (OnboardingStep) -> Void
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        NavigationStack {
            ScreenScaffold(glow: UnitPoint(x: 0.5, y: 0)) {
                if let draft = app.profile {
                    VStack(alignment: .leading, spacing: 14) {
                        header(draft).entrance(0)
                        // What the app does comes first; what it knows about the person follows.
                        settings.entrance(1)
                        SectionHeader(title: "Твоя анкета").padding(.top, 8).entrance(2)
                        ProfileMetricsCard(draft: draft) { edit(.body) }.entrance(2)
                        ProfileDetailsList(draft: draft, edit: edit).entrance(3)
                        Text("Нажми на строку, чтобы изменить её. Новые дни расписания действуют сразу, а уже прожитые остаются как были.")
                            .font(.footnote)
                            .foregroundStyle(FelixTheme.tertiary)
                            .padding(.horizontal, 4)
                            .entrance(3)
                        footer.entrance(4)
                    }
                    .entranceScope("profile")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func header(_ draft: OnboardingDraft) -> some View {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Профиль", color: FelixTheme.ice)
            Text(name.isEmpty ? "Твой профиль" : name).font(.felixTitle).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var settings: some View {
        FelixList {
            FelixLinkRow(title: "Подбор нагрузки", detail: app.adaptiveTraining.state.trainingClass?.title ?? "Класс пока не выбран", icon: "dumbbell.fill") {
                TrainingStartView()
            }
            FelixDivider()
            FelixLinkRow(title: "Тренер", detail: "\(app.coach.persona.name) · \(app.coach.persona.tone.title.lowercased()) тон", icon: "person.wave.2.fill") {
                CoachPickerView()
            }
            FelixDivider()
            FelixLinkRow(title: "Напоминания", detail: reminderDetail, icon: "bell.fill") { RemindersSettingsView() }
            FelixDivider()
            FelixLinkRow(title: "Данные", detail: "Экспорт и удаление", icon: "externaldrive.fill") { DataSettingsView() }
            FelixDivider()
            FelixLinkRow(title: "О приложении", detail: "Версия и как хранятся данные", icon: "info.circle.fill") { AboutView() }
        }
    }

    private var reminderDetail: String {
        let settings = app.reminders.settings
        return settings.isEnabled ? ReminderSettings.leadText(settings.leadMinutes).lowercased() : "Выключены"
    }

    private var footer: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return Text("Maestro Felix \(version) · данные хранятся только на этом iPhone")
            .font(.footnote)
            .foregroundStyle(FelixTheme.tertiary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
}
