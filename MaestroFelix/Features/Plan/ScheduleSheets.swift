import FelixGlass
import SwiftUI

/// Where to move a session: every day from today up to two weeks ahead, the free ones to pick and the busy
/// ones named by what stands on them, so a day is never missing without a reason.
struct MoveSessionSheet: View {
    let session: PlannedSession
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let free = Set(app.movableDays(for: session))
        let busy = busyDays()
        let days = (0...SchedulePlanner.moveHorizonDays).map { app.today.adding(days: $0, calendar: app.calendar) }
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Перенос", color: FelixTheme.ice)
                Text("Когда потренируемся?").font(.felixHeadline).fixedSize(horizontal: false, vertical: true)
                Text("Состав и серия сохранятся.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                    ForEach(days, id: \.self) { chip($0, isFree: free.contains($0), busyTitle: busy[$0]) }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(FelixTheme.text)
        .glassSheet(detents: [.fraction(0.78), .large])
    }

    /// Day → title of the session that stands on it, other than the one being moved.
    private func busyDays() -> [DayKey: String] {
        let horizon = app.today.adding(days: SchedulePlanner.moveHorizonDays, calendar: app.calendar)
        let others = app.sessions(from: app.today, through: horizon).filter { $0.key != session.key }
        return Dictionary(others.map { ($0.day, $0.plan.title) }, uniquingKeysWith: { first, _ in first })
    }

    private func chip(_ day: DayKey, isFree: Bool, busyTitle: String?) -> some View {
        let isCurrent = day == session.day
        let name = OnboardingDraft.fullWeekdayNames[day.isoWeekday(calendar: app.calendar) - 1]
        return Button {
            app.move(session, to: day)
            dismiss()
        } label: {
            VStack(spacing: 2) {
                Text(OnboardingDraft.weekdayNames[day.isoWeekday(calendar: app.calendar) - 1])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FelixTheme.secondary)
                Text(TrainingCalendar.shortDateText(day)).font(.subheadline.weight(.semibold))
                Text(isCurrent ? "сейчас" : (isFree ? "свободно" : (busyTitle ?? "занято")))
                    .font(.caption2)
                    .foregroundStyle(isFree || isCurrent ? FelixTheme.ice : FelixTheme.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(CardSurface(radius: 16, highlighted: isCurrent))
            .opacity(isFree || isCurrent ? 1 : 0.55)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(!isFree)
        .accessibilityLabel("\(name), \(TrainingCalendar.dateText(day))")
        .accessibilityValue(isCurrent ? "сейчас здесь" : (isFree ? "свободно" : (busyTitle.map { "занято: \($0)" } ?? "занято")))
    }
}

/// Puts the schedule on hold: a pause is not a miss, the streak waits and reminders stop.
struct PauseSheet: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Пауза", color: FelixTheme.ice)
                Text("На сколько отдохнём?").font(.felixHeadline).fixedSize(horizontal: false, vertical: true)
                Text("На паузе: пропусков и напоминаний нет.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 10) {
                option("До конца недели", until: app.today.weekDays(calendar: app.calendar)[6])
                option("На 7 дней", until: app.today.adding(days: 6, calendar: app.calendar))
                option("На 14 дней", until: app.today.adding(days: 13, calendar: app.calendar))
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(FelixTheme.text)
        .glassSheet(detents: [.medium])
    }

    private func option(_ title: String, until: DayKey) -> some View {
        FelixSecondaryButton(title: "\(title) · до \(TrainingCalendar.shortDateText(until))", systemImage: "pause.circle") {
            app.pause(until: until)
            dismiss()
        }
    }
}
