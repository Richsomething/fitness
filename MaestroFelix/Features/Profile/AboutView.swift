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
                    FelixDivider()
                    FelixLinkRow(title: "Конфиденциальность", detail: "Что хранится и куда уходит", icon: "lock.shield.fill") {
                        PrivacyView()
                    }
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

/// What the app keeps, where, and what leaves the phone, in plain words. It states what the code does today
/// (see docs/architecture/privacy.md); a store listing and a legal policy are a separate matter before release.
struct PrivacyView: View {
    private static let facts: [(title: String, text: String)] = [
        ("Где хранятся данные",
         "Профиль, тренировки, вес, расписание, достижения и настройки хранятся только на этом iPhone."),
        ("Что уходит по сети",
         "Ничего: в приложении нет сетевого кода, сторонней аналитики и отслеживания."),
        ("Отметки о здоровье",
         "Зоны с дискомфортом нужны только чтобы обойти нагрузку на них при подборе упражнений. Они остаются на этом iPhone, как и всё остальное."),
        ("Уведомления",
         "Разрешение запрашивается только когда ты включаешь напоминания. В текстах уведомлений нет веса, цели и ограничений."),
        ("Экспорт и удаление",
         "В разделе «Данные» всё можно сохранить в файл или удалить. Удаление очищает приложение, но не затрагивает резервные копии iPhone."),
    ]

    var body: some View {
        ScreenScaffold(glow: UnitPoint(x: 0.5, y: 0)) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Maestro Felix", color: FelixTheme.ice)
                    Text("Конфиденциальность").font(.felixTitle).fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(Self.facts.enumerated()), id: \.offset) { _, fact in
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(fact.title)
                        Text(fact.text)
                            .font(.subheadline)
                            .foregroundStyle(FelixTheme.text.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
