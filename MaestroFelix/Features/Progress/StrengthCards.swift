import Charts
import SwiftUI

/// Strength progress: pick an exercise to see its line, the latest number, the best and the change.
/// Every number comes from the log of sets; with too little of it the card says what is missing.
struct StrengthProgressCard: View {
    @Environment(AppCoordinator.self) private var app
    @State private var chosen: String?

    private static let shown = 8

    var body: some View {
        let logs = app.workouts.logs
        let exercises = Array(StrengthProgress.exercises(in: logs).prefix(Self.shown))
        let selected = chosen.flatMap { exercises.contains($0) ? $0 : nil } ?? exercises.first
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Силовой прогресс")
            if let selected, let progress = StrengthProgress.progress(for: selected, in: logs) {
                chips(exercises, selected: selected)
                detail(progress)
            } else {
                Text("Здесь появятся графики по упражнениям, когда в журнале будут рабочие подходы: расчётный максимум, повторения, удержание.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
    }

    private func chips(_ exercises: [String], selected: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(exercises, id: \.self) { id in
                    FelixChip(title: ExerciseCatalog.exercise(id).title, selected: id == selected) { chosen = id }
                }
            }
            .padding(.vertical, 2)
        }
        // Chips run to the card's edges so a long list reads as scrollable.
        .padding(.horizontal, -20)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    private func detail(_ progress: ExerciseProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(format(progress.points.last?.value ?? 0, progress.metric)).font(.felixNumber(36)).monospacedDigit()
                Text(progress.metric.unit).font(.title3.weight(.semibold)).foregroundStyle(FelixTheme.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.metric.title).font(.subheadline).foregroundStyle(FelixTheme.secondary)
                if let change = progress.change {
                    Text(change == 0 ? "Без изменений с первой записи" : "\(signed(change, progress.metric)) с первой записи")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(FelixTheme.tertiary)
                }
            }
            if progress.points.count >= 2 {
                chart(progress)
            } else {
                Text("Нужны минимум две тренировки с этим упражнением — тогда появится график.")
                    .font(.footnote)
                    .foregroundStyle(FelixTheme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let best = progress.best {
                Label("Лучшее: \(format(best.value, progress.metric)) \(progress.metric.unit) · \(best.date.formatted(.dateTime.day().month(.abbreviated)))",
                      systemImage: "trophy")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FelixTheme.ice)
            }
        }
    }

    private func chart(_ progress: ExerciseProgress) -> some View {
        let values = progress.points.map(\.value)
        let low = max((values.min() ?? 0) - 1, 0)
        let high = (values.max() ?? 0) + 1
        // Workouts close together would all read as the same date, so the axis then shows the time.
        let span = (progress.points.last?.date ?? .now).timeIntervalSince(progress.points.first?.date ?? .now)
        let sameDay = span < 2 * 86_400
        return Chart(progress.points) { point in
            LineMark(x: .value("Дата", point.date), y: .value(progress.metric.title, point.value))
                .foregroundStyle(FelixTheme.ice)
                .interpolationMethod(.monotone)
            PointMark(x: .value("Дата", point.date), y: .value(progress.metric.title, point.value))
                .foregroundStyle(Color.white)
                .symbolSize(28)
        }
        .chartYScale(domain: low...high)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                if sameDay {
                    AxisValueLabel(format: .dateTime.hour().minute()).foregroundStyle(FelixTheme.secondary)
                } else {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(FelixTheme.secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(FelixTheme.hairline)
                AxisValueLabel().foregroundStyle(FelixTheme.secondary)
            }
        }
        .frame(height: 150)
        .accessibilityLabel("График: \(ExerciseCatalog.exercise(progress.exerciseID).title)")
        .accessibilityValue("От \(format(values.first ?? 0, progress.metric)) до \(format(values.last ?? 0, progress.metric)) \(progress.metric.unit), \(values.count) тренировок")
    }

    private func format(_ value: Double, _ metric: ExerciseProgress.Metric) -> String {
        metric == .estimatedMax ? WeightFormat.kg((value * 2).rounded() / 2) : String(Int(value.rounded()))
    }

    private func signed(_ change: Double, _ metric: ExerciseProgress.Metric) -> String {
        let text = format(abs(change), metric)
        let isZero = (Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0) == 0
        return isZero ? "без изменений" : "\(change > 0 ? "+" : "−")\(text) \(metric.unit)"
    }
}

/// Sets and kilograms lifted, week by week, so a drift up or down over the last two months is visible.
struct WeeklyVolumeCard: View {
    @Environment(AppCoordinator.self) private var app

    private static let weeks = 8

    var body: some View {
        let weeks = StrengthProgress.weeklyVolume(in: app.workouts.logs, weeks: Self.weeks, endingWith: app.today, calendar: app.calendar)
        let total = weeks.reduce(0) { $0 + $1.volumeKg }
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Объём по неделям")
            if total > 0 {
                chart(weeks)
                if let current = weeks.last {
                    Text("На этой неделе: \(volumeText(current.volumeKg)) · \(current.sets) \(RussianPlural.form(current.sets, one: "подход", few: "подхода", many: "подходов"))")
                        .font(.subheadline)
                        .foregroundStyle(FelixTheme.secondary)
                }
            } else {
                Text("Объём — вес на повторения по рабочим подходам. Появится после первой тренировки с весом.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
    }

    private func chart(_ weeks: [WeekVolume]) -> some View {
        Chart(weeks) { week in
            BarMark(x: .value("Неделя", week.start.date(calendar: app.calendar), unit: .weekOfYear), y: .value("кг", week.volumeKg))
                .foregroundStyle(LinearGradient(colors: [FelixTheme.cobalt, FelixTheme.ice], startPoint: .bottom, endPoint: .top))
                .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) {
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(FelixTheme.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(FelixTheme.hairline)
                AxisValueLabel().foregroundStyle(FelixTheme.secondary)
            }
        }
        .frame(height: 140)
        .accessibilityLabel("Объём по неделям")
        .accessibilityValue(weeks.map { "\($0.start.rawValue): \(Int($0.volumeKg)) кг" }.joined(separator: "; "))
    }

    private func volumeText(_ kg: Double) -> String {
        kg >= 1000 ? "\(WeightFormat.kg((kg / 100).rounded() / 10)) т" : "\(Int(kg.rounded())) кг"
    }
}
