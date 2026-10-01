import SwiftUI

/// The second tab: a week at a time. It opens with the week's dates and progress, lists only the days that have
/// a session, folds the rest into one row and shows how the week spreads over the body. A session opens to its
/// details, where it can be started, moved or skipped; the whole schedule can be put on hold.
struct PlanScreen: View {
    let edit: (OnboardingStep) -> Void
    @Environment(AppCoordinator.self) private var app
    /// Weeks from the current one: -1 is the last, 1 the next.
    @State private var weekOffset = 0
    @State private var pausing = false

    var body: some View {
        NavigationStack {
            ScreenScaffold(glow: UnitPoint(x: 0.1, y: 0)) {
                let week = app.week(of: app.today.adding(days: 7 * weekOffset, calendar: app.calendar))
                let overview = WeekOverview(sessions: week.sessions, today: app.today)
                let restDays = week.days.filter { day in !week.sessions.contains { $0.day == day } }
                VStack(alignment: .leading, spacing: 14) {
                    header(week.days).entrance(0)
                    GlassSegmented(options: [(-1, "Прошлая"), (0, "Эта неделя"), (1, "Следующая")], selection: $weekOffset).entrance(1)
                    StarterPlanNote().entrance(2)
                    if let pause = app.currentPause { pauseBanner(pause).entrance(3) }
                    PlanWeekCard(days: week.days, sessions: week.sessions, overview: overview).entrance(4)
                    VStack(spacing: 10) {
                        ForEach(week.sessions) { PlanSessionCard(session: $0) }
                    }
                    .entrance(5)
                    StatusLegend(sessions: week.sessions).entrance(5)
                    if !restDays.isEmpty { PlanRestDays(days: restDays).entrance(6) }
                    if !overview.loads.isEmpty { PlanLoadCard(overview: overview).entrance(7) }
                    FelixList {
                        FelixLinkRow(title: "История тренировок", detail: "Все недели и результаты", icon: "clock.arrow.circlepath") {
                            HistoryListView()
                        }
                    }
                    .entrance(8)
                }
                .entranceScope("plan")
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $pausing) { PauseSheet() }
    }

    private func header(_ days: [DayKey]) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                // The month most of the week falls in, as the calendar app names it.
                Eyebrow(TrainingCalendar.monthYearText(days[3]), color: FelixTheme.ice)
                Text("План").font(.felixTitle)
            }
            Spacer()
            Menu {
                if app.currentPause == nil {
                    Button { pausing = true } label: { Label("Поставить на паузу", systemImage: "pause.circle") }
                } else {
                    Button { app.resumeSchedule() } label: { Label("Снять паузу", systemImage: "play.circle") }
                }
                Button { edit(.schedule) } label: { Label("Изменить дни тренировок", systemImage: "calendar") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(FelixTheme.text)
                    .frame(width: 44, height: 44)
                    .felixGlass(in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("Действия с расписанием")
        }
    }

    private func pauseBanner(_ pause: SchedulePause) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "pause.circle.fill").font(.title2).foregroundStyle(FelixTheme.ice)
            VStack(alignment: .leading, spacing: 2) {
                Text("Пауза до \(TrainingCalendar.dateText(pause.until))").font(.subheadline.weight(.semibold))
                Text("Занятия не считаются пропусками, напоминаний нет.").font(.footnote).foregroundStyle(FelixTheme.secondary)
            }
            Spacer(minLength: 8)
            Button("Снять") { app.resumeSchedule() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FelixTheme.ice)
                .frame(minHeight: 44)
        }
        .padding(16)
        .background(CardSurface(radius: 22, highlighted: true))
    }
}
