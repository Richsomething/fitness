import SwiftUI

/// What the app is, which version this is and what it does with data: the plain facts a person looks for under
/// "about". Nothing here is a setting.
struct AboutView: View {
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—" }

    var body: some View {
        ScreenScaffold(glow: UnitPoint(x: 0.5, y: 0)) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Maestro Felix", color: FelixTheme.ice)
                    Text("О приложении").font(.felixTitle)
                }
                FelixList {
                    line("Версия", "\(version) (\(build))")
                }
                note("Данные", "Профиль, тренировки, вес и настройки хранятся только на этом iPhone. Приложение ничего не отправляет по сети и не использует сторонней аналитики. Экспорт и удаление — в разделе «Данные».")
                note("План", "Составлен по общим правилам из твоих ответов и оценок тренировок. Он не заменяет врача и тренера: при боли или сомнениях сначала спроси специалиста.")
                note("Копии", "Копии между устройствами пока не делаются: при смене iPhone сохрани файл из «Данных».")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.body.weight(.medium))
            Spacer()
            Text(value).font(.body).monospacedDigit().foregroundStyle(FelixTheme.secondary)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 56)
    }

    private func note(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(title)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(FelixTheme.text.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }
}
