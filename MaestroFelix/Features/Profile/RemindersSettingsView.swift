import SwiftUI
import UIKit

/// Reminders, all off until asked for. The system's permission is requested only when the person turns
/// them on; a refusal leaves them off and says where to change it.
struct RemindersSettingsView: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(\.openURL) private var openURL
    @State private var refused = false

    private var settings: ReminderSettings { app.reminders.settings }

    var body: some View {
        ScreenScaffold(glow: UnitPoint(x: 0.9, y: 0)) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Напоминания").font(.felixTitle)
                Text("Только о занятиях по плану. Без веса и ограничений.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if app.reminders.authorization == .denied || refused { deniedNote }
                // Two different things: a note before a session, and a signal while one is under way.
                SectionHeader(title: "Перед занятием").padding(.top, 6)
                FelixList {
                    toggleRow("Напоминать о тренировках", isOn: enabledBinding)
                    if settings.isEnabled {
                        FelixDivider()
                        leadRow
                        FelixDivider()
                        quietRow("Тихие часы с", minutes: \.quietStart)
                        FelixDivider()
                        quietRow("до", minutes: \.quietEnd)
                        FelixDivider()
                        toggleRow("Слова тренера в уведомлении", isOn: binding(\.usesPersonalText))
                        FelixDivider()
                        toggleRow("Мягко напомнить после пропуска", isOn: binding(\.comebackEnabled))
                    }
                }
                Text(settings.isEnabled
                     ? "В тихие часы не беспокоим. После пропуска не чаще раза в неделю."
                     : "Придёт перед занятием. iOS спросит разрешение.")
                    .font(.footnote)
                    .foregroundStyle(FelixTheme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                SectionHeader(title: "Во время тренировки").padding(.top, 6)
                FelixList {
                    toggleRow("Сигнал об окончании отдыха", isOn: restAlertBinding)
                }
                Text("Придёт уведомление, даже если экран погас.")
                    .font(.footnote)
                    .foregroundStyle(FelixTheme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if let error = app.reminders.storageError { FelixInlineIssue(text: error) }
            }
            .entranceScope("reminders")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await app.reminders.refreshAuthorization() }
    }

    // MARK: Rows

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.body.weight(.medium))
            .tint(FelixTheme.cobalt)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
    }

    private var leadRow: some View {
        HStack {
            Text("Когда напомнить").font(.body.weight(.medium))
            Spacer(minLength: 8)
            Picker("Когда напомнить", selection: binding(\.leadMinutes)) {
                ForEach(ReminderSettings.leadOptions, id: \.self) { Text(ReminderSettings.leadText($0)).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(FelixTheme.ice)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }

    private func quietRow(_ title: String, minutes: WritableKeyPath<ReminderSettings, Int>) -> some View {
        DatePicker(title, selection: timeBinding(minutes), displayedComponents: .hourAndMinute)
            .font(.body.weight(.medium))
            .tint(FelixTheme.ice)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
    }

    private var deniedNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Уведомления для Maestro Felix выключены в настройках iOS.", systemImage: "bell.slash")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(FelixTheme.ice)
                .fixedSize(horizontal: false, vertical: true)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Открыть настройки iOS") { openURL(url) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FelixTheme.ice)
                    .frame(minHeight: 44)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface(radius: 22))
    }

    // MARK: Bindings

    private var enabledBinding: Binding<Bool> {
        Binding { settings.isEnabled } set: { on in
            Task {
                refused = on ? !(await app.reminders.setEnabled(true)) : false
                if !on { await app.reminders.setEnabled(false) }
                app.scheduleReconcile()
            }
        }
    }

    private var restAlertBinding: Binding<Bool> {
        Binding { settings.restAlertEnabled } set: { on in
            Task { refused = !(await app.reminders.setRestAlert(on)) && on }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ReminderSettings, Value>) -> Binding<Value> {
        Binding { settings[keyPath: keyPath] } set: { value in
            app.reminders.update { $0[keyPath: keyPath] = value }
            app.scheduleReconcile()
        }
    }

    /// Minutes since midnight as the time of day a picker works with.
    private func timeBinding(_ keyPath: WritableKeyPath<ReminderSettings, Int>) -> Binding<Date> {
        Binding {
            let minutes = settings[keyPath: keyPath]
            return app.today.at(hour: minutes / 60, minute: minutes % 60, calendar: app.calendar)
        } set: { date in
            let parts = app.calendar.dateComponents([.hour, .minute], from: date)
            app.reminders.update { $0[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0) }
            app.scheduleReconcile()
        }
    }
}
