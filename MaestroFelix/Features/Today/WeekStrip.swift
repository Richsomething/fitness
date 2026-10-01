import SwiftUI

/// The week at a glance: a cell per day showing whether a session was planned, done, moved out of the
/// way or held, with how many are done so far.
struct WeekStrip: View {
    let week: (days: [DayKey], sessions: [PlannedSession])
    let today: DayKey
    let progress: WeekProgress?
    let streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Eyebrow("Эта неделя")
                    Spacer()
                    streakLabel
                }
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Эта неделя")
                    streakLabel
                }
            }
            HStack(spacing: 6) {
                ForEach(week.days, id: \.self) { day in cell(day) }
            }
            if let progress, progress.planned > 0 {
                Text("На этой неделе выполнено \(progress.done) из \(progress.planned)")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
            }
            StatusLegend(sessions: week.sessions)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
    }

    @ViewBuilder private var streakLabel: some View {
        if streak > 0 {
            // Said in words: a bare "Серия 1" does not tell what is being counted.
            Label("Серия: \(streak) \(RussianPlural.trainings(streak)) подряд", systemImage: "flame.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FelixTheme.ice)
                .lineLimit(1)
                .fixedSize()
                .accessibilityLabel("Серия: \(streak) \(RussianPlural.trainings(streak)) по плану подряд")
        }
    }

    /// A day with a session opens it, like a tap on a calendar date.
    @ViewBuilder private func cell(_ day: DayKey) -> some View {
        if let session = week.sessions.first(where: { $0.day == day }) {
            NavigationLink { SessionDetailView(slot: session.key) } label: { cellContent(day) }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Открыть занятие")
        } else {
            cellContent(day)
        }
    }

    private func cellContent(_ day: DayKey) -> some View {
        let session = week.sessions.first { $0.day == day }
        let isToday = day == today
        let weekday = day.isoWeekday()
        return VStack(spacing: 8) {
            // Seven cells share a row, so the day names stop growing at a large size; each cell is
            // read in full by VoiceOver.
            Text(OnboardingDraft.weekdayNames[weekday - 1])
                .font(.caption2.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .lineLimit(1)
                .foregroundStyle(isToday ? FelixTheme.text : FelixTheme.tertiary)
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill(for: session))
                if let session {
                    Image(systemName: session.status.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(session.status.isDone ? Color.white : session.status.color)
                } else {
                    Circle().fill(Color.white.opacity(0.14)).frame(width: 4, height: 4)
                }
            }
            .frame(height: 44)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(isToday ? 0.85 : 0), lineWidth: 1.5))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(day, session: session, isToday: isToday))
    }

    private func fill(for session: PlannedSession?) -> AnyShapeStyle {
        guard let session else { return AnyShapeStyle(Color.white.opacity(0.05)) }
        switch session.status {
        case .done: return AnyShapeStyle(LinearGradient(colors: [FelixTheme.cobalt, FelixTheme.cobaltDeep], startPoint: .top, endPoint: .bottom))
        case .planned: return AnyShapeStyle(FelixTheme.cobalt.opacity(0.28))
        case .missed, .skipped, .paused: return AnyShapeStyle(Color.white.opacity(0.08))
        }
    }

    private func label(_ day: DayKey, session: PlannedSession?, isToday: Bool) -> String {
        let name = OnboardingDraft.fullWeekdayNames[day.isoWeekday() - 1]
        let base = isToday ? "\(name), сегодня" : name
        guard let session else { return "\(base): отдых" }
        return "\(base): тренировка, \(session.status.title.lowercased())"
    }
}
