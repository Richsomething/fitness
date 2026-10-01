import SwiftUI

/// The third tab: how the week is going, the streak, what was unlocked, the weighings and the last
/// workouts. Every number comes from the log; with nothing yet it says so instead of drawing a line.
struct ProgressScreen: View {
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        NavigationStack {
            ScreenScaffold(glow: UnitPoint(x: 0.9, y: 0)) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Итоги", color: FelixTheme.ice)
                        Text("Прогресс").font(.felixTitle)
                    }
                    .entrance(0)
                    WeekProgressCard(stats: app.progress.stats).entrance(1)
                    StrengthProgressCard().entrance(2)
                    WeeklyVolumeCard().entrance(3)
                    WeightCard().entrance(4)
                    AchievementsCard(state: app.progress.achievements, stats: app.progress.stats).entrance(5)
                    HistoryPreview().entrance(6)
                }
                .entranceScope("progress")
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct WeekProgressCard: View {
    let stats: TrainingStats

    var body: some View {
        let planned = stats.week?.planned ?? 0
        let done = stats.week?.done ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            // The ring and the streak are different measures, so each is named: this week, and the run in a row.
            Eyebrow("Эта неделя")
            HStack(spacing: 22) {
                ZStack {
                    ArcGauge(progress: planned == 0 ? 0 : Double(done) / Double(planned))
                    VStack(spacing: 2) {
                        Text(planned == 0 ? "—" : "\(done)").font(.felixNumber(40)).monospacedDigit()
                        Eyebrow(planned == 0 ? "нет занятий" : "из \(planned)")
                    }
                }
                .frame(width: 118, height: 118)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(planned == 0 ? "На этой неделе занятий нет" : "На этой неделе выполнено \(done) из \(planned)")
                VStack(alignment: .leading, spacing: 16) {
                    MetricTile(title: "Серия подряд", value: "\(stats.streak)", unit: RussianPlural.trainings(stats.streak))
                    MetricTile(title: "Полных недель", value: "\(stats.fullWeeks)")
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
    }
}

/// Each achievement with what it takes; a locked one shows how far along it is and how much is left.
private struct AchievementsCard: View {
    let state: AchievementsState
    let stats: TrainingStats

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow("Достижения")
            VStack(spacing: 14) {
                ForEach(AchievementID.allCases, id: \.self) { id in row(id) }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
    }

    private func row(_ id: AchievementID) -> some View {
        let unlocked = state.has(id)
        let progress = AchievementRules.progress(id, stats: stats)
        return HStack(spacing: 14) {
            Image(systemName: unlocked ? id.symbol : "lock.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(unlocked ? Color.white : FelixTheme.tertiary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(unlocked ? AnyShapeStyle(FelixTheme.cobalt) : AnyShapeStyle(Color.white.opacity(0.08))))
                .shadow(color: unlocked ? FelixTheme.cobalt.opacity(0.6) : .clear, radius: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(id.title).font(.subheadline.weight(.semibold)).foregroundStyle(unlocked ? FelixTheme.text : FelixTheme.secondary)
                Text(id.detail).font(.footnote).foregroundStyle(FelixTheme.secondary).fixedSize(horizontal: false, vertical: true)
                if unlocked, let date = state.unlocked[id.rawValue] {
                    Text("Получено \(date.formatted(.dateTime.day().month(.abbreviated)))").font(.caption).foregroundStyle(FelixTheme.ice)
                } else if !unlocked {
                    HStack(spacing: 8) {
                        ProgressView(value: progress.fraction)
                            .tint(FelixTheme.ice)
                            .frame(maxWidth: 120)
                        Text("\(progress.current) из \(progress.goal)").font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlocked ? "\(id.title). \(id.detail). Получено"
                            : "\(id.title): пока закрыто. \(id.detail). Сделано \(progress.current) из \(progress.goal)")
    }
}

private struct HistoryPreview: View {
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        let recent = Array(app.workouts.logs.sorted { $0.finishedAt > $1.finishedAt }.prefix(4))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Последние тренировки")
                Spacer()
                if !recent.isEmpty {
                    NavigationLink { HistoryListView() } label: {
                        Text("Вся история").font(.subheadline.weight(.semibold)).foregroundStyle(FelixTheme.ice).frame(minHeight: 44)
                    }
                }
            }
            if recent.isEmpty {
                Text("Здесь появятся завершённые тренировки: что сделано, с какими весами и как ощущалось.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { offset, log in
                        if offset > 0 { FelixDivider() }
                        WorkoutLogRow(log: log)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
    }
}
