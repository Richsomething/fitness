import SwiftUI

/// Metrics and details of a draft; each block opens its onboarding step. The week is one row of the details,
/// not a card of its own: the Plan tab already shows it in full.
struct ProfileOverview: View {
    let draft: OnboardingDraft
    let edit: (OnboardingStep) -> Void

    var body: some View {
        VStack(spacing: 14) {
            ProfileMetricsCard(draft: draft) { edit(.body) }
            ProfileDetailsList(draft: draft, edit: edit)
        }
    }
}

struct ProfileMetricsCard: View {
    let draft: OnboardingDraft
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Eyebrow("Параметры")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
                }
                HStack(alignment: .top, spacing: 0) {
                    metric("Рост", draft.heightText, unit: "см")
                    Rectangle().fill(FelixTheme.hairline).frame(width: 1, height: 58).padding(.horizontal, 20)
                    metric("Вес", draft.weightText, unit: "кг")
                }
            }
            .foregroundStyle(FelixTheme.text)
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardSurface())
            .contentShape(RoundedRectangle(cornerRadius: FelixTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Изменить параметры")
    }

    private func metric(_ title: String, _ value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(title)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value.isEmpty ? "—" : value)
                    .font(.felixNumber(40))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Eyebrow(unit, color: FelixTheme.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileDetailsList: View {
    let draft: OnboardingDraft
    let edit: (OnboardingStep) -> Void

    private var limitationsText: String {
        draft.limitations.isEmpty ? "Нет" : draft.limitations.map(\.zone.title).joined(separator: ", ")
    }

    /// "Пн, Ср, Пт · 15:15".
    private var scheduleText: String {
        draft.weekdays.isEmpty ? "Дни не выбраны" : "\(draft.daysLabel) · \(draft.timeLabel)"
    }

    var body: some View {
        VStack(spacing: 0) {
            row("Цель", draft.goal?.title ?? "Не выбрана", step: .goal)
            divider
            row("Опыт", draft.experience?.title ?? "Не выбран", step: .preferences)
            divider
            row("Пол", draft.gender?.title ?? "Не указан", step: .body)
            divider
            row("Расписание", scheduleText, step: .schedule)
            divider
            row("Ограничения", limitationsText, step: .limitations)
        }
        .background(CardSurface())
    }

    private var divider: some View {
        Rectangle().fill(FelixTheme.hairline).frame(height: 1).padding(.leading, 20)
    }

    private func row(_ title: String, _ value: String, step: OnboardingStep) -> some View {
        Button { edit(step) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(title)
                    Text(value).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
            }
            .foregroundStyle(FelixTheme.text)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint("Изменить")
        .accessibilityAddTraits(.isButton)
    }
}
