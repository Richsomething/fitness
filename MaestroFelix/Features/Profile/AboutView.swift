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
                note("План", "Не заменяет врача и тренера. При боли сначала спроси специалиста.")
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
        ("Хранение", "Всё только на этом iPhone, включая отметки о здоровье."),
        ("Сеть", "Ничего не отправляется. Сторонней аналитики нет."),
        ("Уведомления", "Только по твоему включению, без веса и ограничений."),
        ("Экспорт и удаление", "В разделе «Данные». Резервные копии iPhone не затрагиваются."),
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
