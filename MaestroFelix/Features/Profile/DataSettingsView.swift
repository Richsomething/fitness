import SwiftUI

/// The person's data: take a copy out as a file, or erase everything. Nothing here leaves the device
/// unless the person sends the file themselves.
struct DataSettingsView: View {
    @Environment(AppCoordinator.self) private var app
    @State private var exportURL: URL?
    @State private var exportFailed = false
    @State private var confirmsErase = false

    var body: some View {
        ScreenScaffold(glow: UnitPoint(x: 0.1, y: 0)) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Данные").font(.felixTitle)
                Text("Данные только на этом iPhone. Копию можно сохранить файлом.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                exportCard
                eraseCard
                if let error = app.dataError { FelixInlineIssue(text: error) }
            }
            .entranceScope("data")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { prepareExport() }
        .confirmationDialog("Удалить все данные?", isPresented: $confirmsErase, titleVisibility: .visible) {
            Button("Удалить всё", role: .destructive) { Task { await app.eraseEverything() } }
            Button("Оставить", role: .cancel) {}
        } message: {
            Text("Всё исчезнет с этого iPhone. Вернуть нельзя.")
        }
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Копия данных", systemImage: "square.and.arrow.up").font(.headline)
            Text("Один файл JSON со всеми данными.")
                .font(.subheadline)
                .foregroundStyle(FelixTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let exportURL {
                ShareLink(item: exportURL) {
                    Text("Экспортировать")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .felixGlass(in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
            } else if exportFailed {
                FelixInlineIssue(text: "Не удалось подготовить файл.")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface(radius: 24))
    }

    private var eraseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Удалить всё", systemImage: "trash").font(.headline)
            Text("Стирает данные и уведомления. Приложение начнёт заново.")
                .font(.subheadline)
                .foregroundStyle(FelixTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(role: .destructive) { confirmsErase = true } label: {
                Text("Удалить все данные")
                    .font(.headline)
                    .foregroundStyle(FelixTheme.critical)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .felixGlass(in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface(radius: 24))
    }

    private func prepareExport() {
        do {
            exportURL = try app.exportFile()
            exportFailed = false
        } catch {
            exportURL = nil
            exportFailed = true
        }
    }
}
