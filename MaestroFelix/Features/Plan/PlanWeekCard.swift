import SwiftUI

/// The top of the plan: the week's dates, how far along it is, the seven days at a glance and what comes next.
/// A day with a session opens it; the others are only dates.
struct PlanWeekCard: View {
    let days: [DayKey]
    let sessions: [PlannedSession]
    let overview: WeekOverview
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(TrainingCalendar.shortDateText(days[0])) – \(TrainingCalendar.shortDateText(days[6]))")
                    .font(.felixHeadline)
                Text(progressText).font(.subheadline).foregroundStyle(FelixTheme.secondary)
            }
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { column($0) }
            }
            footer
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
    }

    private var progressText: String {
        guard overview.sessionCount > 0 else { return "Тренировок на этой неделе нет" }
        return "Выполнено \(overview.doneCount) из \(overview.sessionCount)"
    }

    // MARK: Days

    @ViewBuilder private func column(_ day: DayKey) -> some View {
        let session = sessions.first { $0.day == day }
        if let session {
            NavigationLink { SessionDetailView(slot: session.key) } label: { dayColumn(day, session) }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Открыть занятие")
        } else {
            dayColumn(day, nil)
        }
    }

    private func dayColumn(_ day: DayKey, _ session: PlannedSession?) -> some View {
        let isToday = day == app.today
        let weekday = day.isoWeekday(calendar: app.calendar)
        return VStack(spacing: 8) {
            Text(OnboardingDraft.weekdayNames[weekday - 1])
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isToday ? FelixTheme.ice : FelixTheme.tertiary)
            marker(day, session)
            Circle().fill(isToday ? FelixTheme.ice : Color.clear).frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(day, session, isToday: isToday))
    }

    @ViewBuilder private func marker(_ day: DayKey, _ session: PlannedSession?) -> some View {
        let number = Text("\(TrainingCalendar.dayNumber(day))").font(.subheadline.weight(.semibold)).monospacedDigit()
        ZStack {
            switch session?.status {
            case .some(.done):
                Circle().fill(LinearGradient(colors: [FelixTheme.cobalt, FelixTheme.cobaltDeep], startPoint: .top, endPoint: .bottom))
                Image(systemName: "checkmark").font(.footnote.weight(.bold))
            case .some(.planned):
                Circle().fill(FelixTheme.cobalt.opacity(0.2))
                Circle().strokeBorder(FelixTheme.cobalt, lineWidth: 2)
                number
            case .some:
                Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5)
                number.foregroundStyle(FelixTheme.tertiary)
            case .none:
                number.foregroundStyle(FelixTheme.tertiary)
            }
        }
        .frame(width: 34, height: 34)
    }

    private func label(_ day: DayKey, _ session: PlannedSession?, isToday: Bool) -> String {
        let name = OnboardingDraft.fullWeekdayNames[day.isoWeekday(calendar: app.calendar) - 1]
        let date = "\(name), \(TrainingCalendar.dateText(day))\(isToday ? ", сегодня" : "")"
        guard let session else { return "\(date): отдых" }
        return "\(date): \(session.plan.title), \(session.status.title.lowercased())"
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        if let next = overview.next {
            line("Дальше: \(next.plan.title) — \(when(next.day))", symbol: "arrow.turn.down.right")
        } else if overview.sessionCount > 0 && overview.doneCount == overview.sessionCount {
            line("Все занятия недели выполнены", symbol: "checkmark.circle")
        }
    }

    private func line(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(FelixTheme.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "завтра", or "в пятницу, 2 окт" once it is further off.
    private func when(_ day: DayKey) -> String {
        let phrase = TrainingCalendar.dayPhrase(day, today: app.today, calendar: app.calendar)
        return app.today.days(to: day, calendar: app.calendar) > 1 ? "\(phrase), \(TrainingCalendar.shortDateText(day))" : phrase
    }
}
