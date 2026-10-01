import SwiftUI

/// The week's days without a session, kept to one short row instead of a card each. A day that has not passed
/// can take a session from another day.
struct PlanRestDays: View {
    let days: [DayKey]
    @Environment(AppCoordinator.self) private var app
    @State private var target: Target?

    private struct Target: Identifiable {
        let day: DayKey
        var id: String { day.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Дни отдыха")
            FlowLayout(spacing: 8) {
                ForEach(days, id: \.self) { chip($0) }
            }
            if days.contains(where: { $0 >= app.today }) {
                Text("Нажми на день, чтобы поставить туда занятие.")
                    .font(.footnote)
                    .foregroundStyle(FelixTheme.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $target) { PlaceSessionSheet(day: $0.day) }
    }

    @ViewBuilder private func chip(_ day: DayKey) -> some View {
        let isToday = day == app.today
        let isOpen = day >= app.today
        let text = "\(OnboardingDraft.weekdayNames[day.isoWeekday(calendar: app.calendar) - 1]) \(TrainingCalendar.dayNumber(day))"
        let label = Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isToday ? FelixTheme.ice : (isOpen ? FelixTheme.secondary : FelixTheme.tertiary))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Capsule().fill(FelixTheme.surface))
            .overlay(Capsule().strokeBorder(isToday ? FelixTheme.ice.opacity(0.7) : FelixTheme.hairline, lineWidth: 1))
        if isOpen {
            Button { target = Target(day: day) } label: { label.contentShape(Capsule()) }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(OnboardingDraft.fullWeekdayNames[day.isoWeekday(calendar: app.calendar) - 1]), \(TrainingCalendar.dateText(day)): отдых")
                .accessibilityHint("Поставить сюда занятие")
        } else {
            label.accessibilityLabel("\(OnboardingDraft.fullWeekdayNames[day.isoWeekday(calendar: app.calendar) - 1]), \(TrainingCalendar.dateText(day)): отдых")
        }
    }
}

/// Which session to bring to a free day: the open ones that may move there.
struct PlaceSessionSheet: View {
    let day: DayKey
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let horizon = app.today.adding(days: SchedulePlanner.moveHorizonDays, calendar: app.calendar)
        let candidates = app.sessions(from: app.today, through: horizon)
            .filter { $0.status == .planned && app.movableDays(for: $0).contains(day) }
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("\(OnboardingDraft.fullWeekdayNames[day.isoWeekday(calendar: app.calendar) - 1]), \(TrainingCalendar.dateText(day))",
                        color: FelixTheme.ice)
                Text("Какое занятие сюда?").font(.felixHeadline).fixedSize(horizontal: false, vertical: true)
            }
            if candidates.isEmpty {
                Text("Переносить нечего: все ближайшие занятия уже прошли или выполнены.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(candidates) { row($0) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(FelixTheme.text)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Color(red: 0.035, green: 0.04, blue: 0.07))
    }

    private func row(_ session: PlannedSession) -> some View {
        Button {
            app.move(session, to: day)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.plan.title).font(.headline).multilineTextAlignment(.leading)
                    Text("Сейчас: \(OnboardingDraft.weekdayNames[session.day.isoWeekday(calendar: app.calendar) - 1]), \(TrainingCalendar.shortDateText(session.day))")
                        .font(.footnote)
                        .foregroundStyle(FelixTheme.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.right").font(.footnote.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(CardSurface(radius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Перенести сюда")
    }
}
