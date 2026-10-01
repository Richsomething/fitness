import SwiftUI

/// One training day of the plan: what the session is made of and how long it takes, so two sessions are told
/// apart by more than their names. Its state is a glyph, explained once by the legend under the list.
struct PlanSessionCard: View {
    let session: PlannedSession
    @Environment(AppCoordinator.self) private var app

    private var isToday: Bool { session.day == app.today }

    var body: some View {
        NavigationLink { SessionDetailView(slot: session.key) } label: { content }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Открыть занятие")
    }

    private var content: some View {
        HStack(spacing: 14) {
            dayTile
            VStack(alignment: .leading, spacing: 4) {
                if isToday {
                    Text("Сегодня").font(.footnote.weight(.semibold)).foregroundStyle(FelixTheme.ice)
                }
                Text(session.plan.title).font(.headline).multilineTextAlignment(.leading)
                Text(meta).font(.subheadline).foregroundStyle(FelixTheme.secondary).multilineTextAlignment(.leading)
                Text(preview).font(.footnote).foregroundStyle(FelixTheme.tertiary).lineLimit(1)
                if session.isMoved {
                    Text("перенесена с \(OnboardingDraft.fullWeekdayNames[session.key.isoWeekday(calendar: app.calendar) - 1].lowercased())")
                        .font(.footnote)
                        .foregroundStyle(FelixTheme.ice)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: session.status.symbol).font(.title3).foregroundStyle(session.status.color)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
        }
        .foregroundStyle(FelixTheme.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(CardSurface(radius: 22, highlighted: isToday && session.status == .planned))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue(session.status.title)
    }

    private var dayTile: some View {
        VStack(spacing: 2) {
            Text(OnboardingDraft.weekdayNames[session.day.isoWeekday(calendar: app.calendar) - 1])
                .font(.caption.weight(.semibold))
                .foregroundStyle(isToday ? FelixTheme.ice : FelixTheme.secondary)
            Text("\(TrainingCalendar.dayNumber(session.day))").font(.felixNumber(22)).monospacedDigit()
        }
        .frame(width: 44)
    }

    /// "5 упражнений · ≈ 20 мин". The start time is the same for every session, so it stays in the details.
    private var meta: String {
        let count = session.plan.exercises.count
        let exercises = "\(count) \(RussianPlural.form(count, one: "упражнение", few: "упражнения", many: "упражнений"))"
        return "\(exercises) · ≈ \(session.plan.estimatedMinutes) мин"
    }

    /// The first exercises by name, cut off by the line.
    private var preview: String {
        session.plan.exercises.map(\.exercise.title).joined(separator: ", ")
    }
}
