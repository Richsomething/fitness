import SwiftUI

/// The result of a saved workout: what was done, the coach's word, what it unlocked, and what is next.
struct WorkoutSummaryView: View {
    let summary: FinishSummary
    let onClose: () -> Void

    private var log: WorkoutLog { summary.log }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    trophy.entrance(0)
                    VStack(spacing: 8) {
                        // The word follows the work: a finished plan is "in the jar", a part of one is just written down.
                        Text(log.isPartial ? "Тренировка записана" : "Тренировка выполнена").font(.felixHeadline)
                        Text(log.title).font(.headline).foregroundStyle(FelixTheme.secondary)
                        if log.isPartial {
                            Label("Частично: \(log.setsDone) из \(log.setsPlanned) \(log.kind.setWords.form(log.setsPlanned))",
                                  systemImage: "circle.lefthalf.filled")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(FelixTheme.ice)
                        }
                    }
                    .entrance(1)
                    stats.entrance(2)
                    if summary.comparison != nil || !summary.records.isEmpty { results.entrance(3) }
                    coachCard.entrance(4)
                    if !summary.newAchievements.isEmpty { achievements.entrance(5) }
                    if summary.streak >= 2 || summary.nextSessionText != nil { footnotes.entrance(6) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            FelixPrimaryButton(title: "Готово", systemImage: "checkmark", action: onClose)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .multilineTextAlignment(.center)
        .entranceScope("summary-\(log.id.uuidString)")
        .sensoryFeedback(.success, trigger: log.id)
    }

    /// A cup for a workout done in full; a quieter mark for part of one.
    private var trophy: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [FelixTheme.cobalt.opacity(log.isPartial ? 0.4 : 0.6), .clear], center: .center,
                                         startRadius: 0, endRadius: 110))
                .frame(width: 200, height: 200)
            Image(systemName: log.isPartial ? "checkmark.circle.fill" : "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(colors: [.white, FelixTheme.ice], startPoint: .top, endPoint: .bottom))
                .symbolEffect(.bounce, options: .nonRepeating)
            if !log.isPartial { SparkBurst(trigger: log.id).frame(width: 190, height: 190) }
        }
        .accessibilityHidden(true)
    }

    // MARK: Results

    /// What the workout did against the past: the volume and the personal bests.
    private var results: some View {
        WorkoutResultsBlock(records: summary.records, comparison: summary.comparison)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat("\(log.minutes)", "мин")
            stat("\(log.setsDone)", log.kind.setWords.form(log.setsDone))
            if log.volumeKg > 0 {
                stat(Self.tons(log.volumeKg), "объём, кг")
            } else {
                stat("\(log.entries.count)", RussianPlural.form(log.entries.count, one: "упражнение", few: "упражнения", many: "упражнений"))
            }
        }
    }

    private func stat(_ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.felixNumber(28)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(unit).font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(CardSurface(radius: 22))
        .accessibilityElement(children: .combine)
    }

    private var coachCard: some View {
        HStack(spacing: 14) {
            CoachAvatar(persona: summary.coach, size: 44)
            Text(summary.coachLine)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(CardSurface(radius: 22))
    }

    private var achievements: some View {
        VStack(spacing: 10) {
            Eyebrow("Новое достижение", color: FelixTheme.ice)
            ForEach(summary.newAchievements, id: \.self) { id in
                Label(id.title, systemImage: id.symbol)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .felixGlass(in: Capsule(), interactive: false, tint: FelixTheme.cobalt.opacity(0.6))
                    .accessibilityLabel("Достижение: \(id.title). \(id.detail)")
            }
        }
    }

    private var footnotes: some View {
        VStack(spacing: 6) {
            if summary.streak >= 2 {
                Text("Серия: \(summary.streak) \(RussianPlural.form(summary.streak, one: "тренировка", few: "тренировки", many: "тренировок")) по плану подряд")
            }
            if let next = summary.nextSessionText {
                Text("Следующая тренировка — \(next)")
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(FelixTheme.secondary)
    }

    /// "4 200" — thousands separated by a thin space.
    static func tons(_ kg: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "\u{202F}"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: kg.rounded())) ?? "\(Int(kg))"
    }
}
