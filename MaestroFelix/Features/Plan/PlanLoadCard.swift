import SwiftUI

/// How the week's sets spread over the body, so it shows at a glance whether every group gets its turn.
/// A bar is the sets planned for a group; the lit part of it is what is already done.
struct PlanLoadCard: View {
    let overview: WeekOverview

    private var mostSets: Int { max(overview.loads.map(\.plannedSets).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Нагрузка недели")
            VStack(spacing: 10) {
                ForEach(overview.loads) { row($0) }
            }
            Label(coverage, systemImage: overview.untouched.isEmpty ? "checkmark.circle" : "exclamationmark.circle")
                .font(.footnote.weight(.medium))
                .foregroundStyle(overview.untouched.isEmpty ? FelixTheme.ice : FelixTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface())
        .accessibilityElement(children: .combine)
    }

    private func row(_ load: GroupLoad) -> some View {
        HStack(spacing: 12) {
            Text(load.group.title)
                .font(.subheadline)
                .frame(width: 92, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { proxy in
                let planned = proxy.size.width * CGFloat(load.plannedSets) / CGFloat(mostSets)
                let done = proxy.size.width * CGFloat(load.doneSets) / CGFloat(mostSets)
                ZStack(alignment: .leading) {
                    Capsule().fill(FelixTheme.cobalt.opacity(0.28)).frame(width: planned)
                    Capsule().fill(LinearGradient(colors: [FelixTheme.cobalt, FelixTheme.ice], startPoint: .leading, endPoint: .trailing))
                        .frame(width: done)
                }
            }
            .frame(height: 10)
            Text("\(load.plannedSets)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(FelixTheme.secondary)
                .frame(minWidth: 24, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(load.group.title): \(load.plannedSets) \(RussianPlural.form(load.plannedSets, one: "подход", few: "подхода", many: "подходов")), сделано \(load.doneSets)")
    }

    private var coverage: String {
        guard !overview.untouched.isEmpty else { return "Всё тело в деле: ни одна группа не осталась без нагрузки." }
        return "Без нагрузки на этой неделе: \(overview.untouched.map { $0.title.lowercased() }.joined(separator: ", "))."
    }
}
