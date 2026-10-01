import SwiftUI

/// One line saying what each state glyph of a list of sessions means, for the states that are there.
/// A single state needs no key, so the line shows only when the list mixes them.
struct StatusLegend: View {
    let statuses: [SessionStatus]

    init(sessions: [PlannedSession]) {
        statuses = Self.distinct(sessions.map(\.status))
    }

    /// Each state once, in the order it first appears.
    static func distinct(_ statuses: [SessionStatus]) -> [SessionStatus] {
        var seen = Set<String>()
        return statuses.filter { seen.insert($0.title).inserted }
    }

    var body: some View {
        if statuses.count > 1 {
            FlowLayout(spacing: 16) {
                ForEach(statuses, id: \.title) { status in
                    Label(status.title, systemImage: status.symbol)
                        .font(.footnote)
                        .foregroundStyle(FelixTheme.tertiary)
                }
            }
            .accessibilityHidden(true)
        }
    }
}
