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

/// What the app keeps and what leaves the phone: one glyph and one short line per fact. It states what the code
/// does today (see docs/architecture/privacy.md); a store listing and a legal policy are a separate matter
/// before release.
struct PrivacyView: View {
    private static let facts: [(symbol: String, text: String)] = [
        ("iphone", "Всё хранится только на этом iPhone"),
        ("wifi.slash", "Ничего не уходит по сети"),
        ("bell", "Уведомления без веса и ограничений"),
        ("square.and.arrow.up", "Экспорт и удаление: раздел «Данные»"),
        ("externaldrive", "Копии iPhone удаление не затрагивает"),
    ]

    var body: some View {
        ScreenScaffold(glow: UnitPoint(x: 0.5, y: 0)) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Maestro Felix", color: FelixTheme.ice)
                    Text("Конфиденциальность").font(.felixTitle).fixedSize(horizontal: false, vertical: true)
                }
                FelixList {
                    ForEach(Array(Self.facts.enumerated()), id: \.offset) { offset, fact in
                        if offset > 0 { FelixDivider() }
                        row(fact.symbol, fact.text)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(FelixTheme.ice)
                .frame(width: 40, height: 40)
                .background(Circle().fill(FelixTheme.cobalt.opacity(0.18)))
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
