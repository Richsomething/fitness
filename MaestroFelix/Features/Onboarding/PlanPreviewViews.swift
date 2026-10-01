import SwiftUI

/// What the profile will produce: the training days of the week and the first session, so the last step of the
/// sign-up says what the person gets, not only what they entered.
struct PlanPreviewCard: View {
    let preview: PlanPreview
    var title = "Что получишь"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(title, color: FelixTheme.ice)
            Text("\(preview.weekdays.count) \(RussianPlural.trainings(preview.weekdays.count)) в неделю")
                .font(.felixHeadline)
            WeekBlocks(selected: Set(preview.weekdays))
            if let first = preview.first { firstSession(first) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface(highlighted: true))
        .accessibilityElement(children: .combine)
    }

    private func firstSession(_ first: PlanPreview.FirstSession) -> some View {
        let phrase = TrainingCalendar.dayPhrase(first.day, today: DayKey(.now), calendar: .current)
        let count = first.exerciseCount
        return VStack(alignment: .leading, spacing: 4) {
            Eyebrow("Первая тренировка")
            Text(first.title).font(.headline)
            Text("\(phrase.prefix(1).uppercased())\(phrase.dropFirst()), \(TrainingCalendar.clock(hour: first.hour, minute: first.minute))")
                .font(.subheadline.weight(.semibold))
            Text("\(count) \(RussianPlural.form(count, one: "упражнение", few: "упражнения", many: "упражнений")) · ≈ \(first.minutes) мин")
                .font(.footnote)
                .foregroundStyle(FelixTheme.secondary)
        }
        .padding(.top, 4)
    }
}

/// The moment after the profile is saved: the plan is ready, here is the week and what comes first. Without it the
/// sign-up ends on a screen that is often a rest day, as if nothing had been made.
struct PlanReadyView: View {
    let preview: PlanPreview
    let onDone: () -> Void

    var body: some View {
        ZStack {
            FelixBackground()
            AmbientGlow(anchor: UnitPoint(x: 0.5, y: 0.1))
            VStack(alignment: .leading, spacing: 22) {
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(LinearGradient(colors: [FelixTheme.cobalt, FelixTheme.cobaltDeep], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: FelixTheme.cobalt.opacity(0.7), radius: 24)
                VStack(alignment: .leading, spacing: 8) {
                    Text("План готов").font(.felixTitle)
                    Text("Составлен по общим правилам. Всё можно менять в плане.")
                        .font(.subheadline)
                        .foregroundStyle(FelixTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PlanPreviewCard(preview: preview, title: "Твоя неделя")
                Spacer(minLength: 0)
                FelixPrimaryButton(title: "К плану", systemImage: "arrow.right", action: onDone)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(FelixTheme.text)
    }
}
