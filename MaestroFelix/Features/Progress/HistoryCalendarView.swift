import SwiftUI

/// The history as a calendar: a month at a time, a mark on each day with a workout, and the day's workouts below
/// the grid for the day that is tapped.
struct HistoryCalendarView: View {
    @Environment(AppCoordinator.self) private var app
    /// The first day of the month shown; the current month until the person moves.
    @State private var month: DayKey?
    @State private var selected: DayKey?

    var body: some View {
        let shown = month ?? HistoryCalendar.firstDay(ofMonthContaining: app.today, calendar: app.calendar)
        let day = selected ?? app.today
        let logs = app.workouts.logs
        return VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                header(shown, logs: logs)
                weekdays
                grid(shown, logs: logs, selected: day)
            }
            .padding(16)
            .background(CardSurface())
            dayList(day, logs: logs)
        }
    }

    // MARK: Month

    private func header(_ shown: DayKey, logs: [WorkoutLog]) -> some View {
        let current = HistoryCalendar.firstDay(ofMonthContaining: app.today, calendar: app.calendar)
        let earliest = logs.map { $0.day(calendar: app.calendar) }.min().map { HistoryCalendar.firstDay(ofMonthContaining: $0, calendar: app.calendar) }
        return HStack {
            step("chevron.left", label: "Предыдущий месяц", enabled: earliest.map { shown > $0 } ?? false) {
                month = HistoryCalendar.shifted(shown, byMonths: -1, calendar: app.calendar)
            }
            Spacer()
            Text(TrainingCalendar.monthYearText(shown)).font(.headline)
            Spacer()
            step("chevron.right", label: "Следующий месяц", enabled: shown < current) {
                month = HistoryCalendar.shifted(shown, byMonths: 1, calendar: app.calendar)
            }
        }
    }

    private func step(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(enabled ? FelixTheme.text : FelixTheme.tertiary.opacity(0.5))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var weekdays: some View {
        HStack(spacing: 4) {
            ForEach(OnboardingDraft.weekdayNames, id: \.self) { name in
                Text(name).font(.caption2.weight(.semibold)).foregroundStyle(FelixTheme.tertiary).frame(maxWidth: .infinity)
            }
        }
    }

    private func grid(_ shown: DayKey, logs: [WorkoutLog], selected: DayKey) -> some View {
        let weeks = HistoryCalendar.month(containing: shown, logs: logs, calendar: app.calendar)
        return VStack(spacing: 4) {
            ForEach(weeks.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    ForEach(weeks[index]) { cell($0, selected: selected) }
                }
            }
        }
    }

    private func cell(_ item: CalendarDay, selected: DayKey) -> some View {
        let isSelected = item.day == selected
        let isToday = item.day == app.today
        let hasWorkout = item.workouts > 0
        return Button { self.selected = item.day } label: {
            Text("\(TrainingCalendar.dayNumber(item.day))")
                .font(.subheadline.weight(hasWorkout || isSelected ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(item.isInMonth ? (hasWorkout ? Color.white : FelixTheme.text) : FelixTheme.tertiary.opacity(0.45))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    if hasWorkout { Circle().fill(FelixTheme.cobalt.opacity(item.isInMonth ? 1 : 0.4)).padding(2) }
                }
                .overlay {
                    if isSelected { Circle().strokeBorder(Color.white, lineWidth: 1.5).padding(2) }
                    else if isToday { Circle().strokeBorder(FelixTheme.ice.opacity(0.8), lineWidth: 1).padding(2) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(TrainingCalendar.dateText(item.day))\(isToday ? ", сегодня" : "")")
        .accessibilityValue(hasWorkout ? "тренировок: \(item.workouts)" : "тренировок нет")
    }

    // MARK: The chosen day

    private func dayList(_ day: DayKey, logs: [WorkoutLog]) -> some View {
        let found = HistoryCalendar.workouts(on: day, in: logs, calendar: app.calendar)
        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow(TrainingCalendar.dateText(day), color: FelixTheme.ice)
            if found.isEmpty {
                Text("В этот день тренировок не было.").font(.subheadline).foregroundStyle(FelixTheme.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(found.enumerated()), id: \.element.id) { offset, log in
                        if offset > 0 { FelixDivider() }
                        WorkoutLogRow(log: log).padding(.horizontal, 16)
                    }
                }
                .background(CardSurface(radius: 24))
            }
        }
    }
}
