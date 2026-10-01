import SwiftUI

/// Choosing the coach. A coach is a virtual helper — never a person — and changing it changes only the
/// words: the plan, the load and the history stay as they are.
struct CoachPickerView: View {
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        ScreenScaffold(glow: UnitPoint(x: 0.1, y: 0)) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Тренер").font(.felixTitle)
                Text("Тренер — виртуальный помощник, а не живой человек. Он меняет только слова; план и история остаются прежними.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("Его реплики — на экране «Сегодня», после тренировки и в напоминаниях.", systemImage: "text.bubble")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(FelixTheme.ice)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(CoachCatalog.personas) { persona in card(persona) }
                if let error = app.coach.storageError { FelixInlineIssue(text: error) }
            }
            .entranceScope("coach-picker")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: app.coach.state.personaID)
    }

    private func card(_ persona: CoachPersona) -> some View {
        let isChosen = persona.id == app.coach.persona.id
        // The one chosen shows how it sounds before, after and between workouts; the others, just one line to compare.
        let moments: [(title: String, event: CoachEvent)] = isChosen
            ? [("Перед тренировкой", .upcomingWorkout), ("После тренировки", .sessionCompleted), ("В день отдыха", .restDay)]
            : [("Перед тренировкой", .upcomingWorkout)]
        return Button { app.coach.select(persona.id) } label: {
            HStack(alignment: .top, spacing: 14) {
                CoachAvatar(persona: persona, size: 56)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(persona.name).font(.headline)
                        Spacer(minLength: 8)
                        if isChosen { Image(systemName: "checkmark.circle.fill").foregroundStyle(FelixTheme.ice) }
                    }
                    Eyebrow("\(persona.tone.title) тон", color: FelixTheme.ice)
                    Text(persona.blurb).font(.subheadline).foregroundStyle(FelixTheme.secondary)
                    ForEach(moments, id: \.title) { moment in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(moment.title).font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
                            Text("«\(CoachCatalog.line(for: moment.event, persona: persona, context: CoachContext(), seed: 0))»")
                                .font(.subheadline.italic())
                                .foregroundStyle(FelixTheme.text.opacity(0.9))
                        }
                        .padding(.top, 4)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(FelixTheme.text)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardSurface(radius: 24, highlighted: isChosen))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}
