import Charts
import SwiftUI

/// Body weight over time: the latest weighing, the change since the first one — in plain grey, never
/// green or red, since what is good depends on the goal — and a line once there are two weighings.
struct WeightCard: View {
    @Environment(AppCoordinator.self) private var app
    @State private var recording = false

    var body: some View {
        let entries = app.weights.entries
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Вес")
                Spacer()
                Button("Записать") { recording = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FelixTheme.ice)
                    .frame(minHeight: 44)
            }
            if let latest = app.weights.latest {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    // With one weighing there is nothing to read from the number but the number, so it stays modest.
                    Text(WeightFormat.kg(latest.kg)).font(.felixNumber(entries.count >= 2 ? 40 : 30)).monospacedDigit()
                    Text("кг").font(.title3.weight(.semibold)).foregroundStyle(FelixTheme.secondary)
                    Spacer(minLength: 8)
                    if let change = app.weights.change {
                        Text("\(WeightHistory.changeText(change)) с первой записи")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(FelixTheme.secondary)
                    }
                }
                if entries.count >= 2 {
                    chart(entries)
                } else {
                    EmptyHint(symbol: "chart.xyaxis.line", text: "Запиши ещё раз — появится график.")
                }
            } else {
                EmptyHint(symbol: "scalemass", text: "Записей веса пока нет.")
            }
            if let error = app.weights.storageError { FelixInlineIssue(text: error) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
        .sheet(isPresented: $recording) { WeightEntrySheet(initial: app.weights.latest?.kg ?? app.profile?.weight ?? 70) }
    }

    /// From three weighings on, a smoothed trend carries the story and each weighing is a point: a day's swing of a
    /// kilo is mostly water. With two, the plain line between them is all there is to say.
    private func chart(_ entries: [WeightEntry]) -> some View {
        let values = entries.map(\.kg)
        let low = (values.min() ?? 0) - 1
        let high = (values.max() ?? 0) + 1
        let showsTrend = entries.count >= 3
        return VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(entries) { entry in
                    PointMark(x: .value("Дата", entry.date), y: .value("Вес, кг", entry.kg))
                        .foregroundStyle(Color.white.opacity(showsTrend ? 0.7 : 1))
                        .symbolSize(showsTrend ? 22 : 28)
                    if !showsTrend {
                        LineMark(x: .value("Дата", entry.date), y: .value("Вес, кг", entry.kg))
                            .foregroundStyle(FelixTheme.ice)
                            .interpolationMethod(.monotone)
                    }
                }
                if showsTrend {
                    ForEach(WeightHistory.trend(entries)) { point in
                        LineMark(x: .value("Дата", point.date), y: .value("Тренд, кг", point.kg), series: .value("Линия", "Тренд"))
                            .foregroundStyle(FelixTheme.ice)
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                }
            }
            .weightChartStyle(low: low, high: high)
            .accessibilityLabel("График веса")
            .accessibilityValue("От \(WeightFormat.kg(values.first ?? 0)) до \(WeightFormat.kg(values.last ?? 0)) килограммов, \(entries.count) записей")
            if showsTrend {
                Label("Линия — тренд, сглаженный от дневных колебаний", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.footnote)
                    .foregroundStyle(FelixTheme.tertiary)
            }
        }
    }
}

private extension View {
    /// The shared look of the weight chart: a quiet grid, grey labels, three marks on each axis.
    func weightChartStyle(low: Double, high: Double) -> some View {
        self
            .chartYScale(domain: low...high)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(FelixTheme.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(FelixTheme.hairline)
                    AxisValueLabel().foregroundStyle(FelixTheme.secondary)
                }
            }
            .frame(height: 150)
    }
}

/// Records a weighing on a ruler, like the profile does: today's by default, or an earlier day's that was forgotten.
struct WeightEntrySheet: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var kg: Double
    @State private var date = Date()
    @State private var failed = false

    /// The ruler starts at `initial` (the last weighing), so it never rolls over from a default.
    init(initial: Double) {
        _kg = State(initialValue: initial)
    }

    private var isToday: Bool { app.calendar.isDate(date, inSameDayAs: app.now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(isToday ? "Сегодня" : "Другой день", color: FelixTheme.ice)
                    Text(isToday ? "Сколько сейчас?" : "Сколько было?").font(.felixHeadline)
                }
                Spacer(minLength: 8)
                // A forgotten weighing can be put on its own day; a future one cannot.
                DatePicker("Дата взвешивания", selection: $date, in: ...app.now, displayedComponents: .date)
                    .labelsHidden()
                    .tint(FelixTheme.ice)
            }
            RulerPicker(value: $kg, range: 20...400, step: 0.5, unit: "кг", accessibilityName: "Вес", emphasisEvery: 2,
                        readoutScale: 0.9, valueText: WeightFormat.kg, tickText: WeightFormat.kg)
            if failed { FelixInlineIssue(text: "Не удалось сохранить вес. Попробуй ещё раз.") }
            FelixPrimaryButton(title: "Записать", systemImage: "checkmark") {
                if app.recordWeight(kg, on: isToday ? nil : date) { dismiss() } else { failed = true }
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(FelixTheme.text)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Color(red: 0.035, green: 0.04, blue: 0.07))
    }
}
