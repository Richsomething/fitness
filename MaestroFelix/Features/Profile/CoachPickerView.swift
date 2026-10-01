import SwiftUI

/// Choosing the coach. A coach is a virtual helper — never a person — and changing it changes only the
/// words: the plan, the load and the history stay as they are. Three emblems in a row to pick from, and one card
/// under them with how the chosen one sounds.
struct CoachPickerView: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScreenScaffold(glow: UnitPoint(x: 0.1, y: 0)) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Тренер").font(.felixTitle)
                Text("Виртуальный помощник, не живой человек. Меняет только слова.")
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ForEach(CoachCatalog.personas) { avatarButton($0) }
                }
                chosenCard(app.coach.persona)
                if let error = app.coach.storageError { FelixInlineIssue(text: error) }
            }
            .entranceScope("coach-picker")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: app.coach.state.personaID)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: app.coach.state.personaID)
    }

    /// An emblem and a name; the one chosen has a ring around it and a brighter name.
    private func avatarButton(_ persona: CoachPersona) -> some View {
        let isChosen = persona.id == app.coach.persona.id
        return Button { app.coach.select(persona.id) } label: {
            VStack(spacing: 10) {
                CoachAvatar(persona: persona, size: 72)
                    .padding(6)
                    .overlay(Circle().strokeBorder(isChosen ? FelixTheme.ice : Color.clear, lineWidth: 3))
                Text(persona.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isChosen ? FelixTheme.text : FelixTheme.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(persona.name)
        .accessibilityValue(persona.tone.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// The name, the tone in one word and how the coach sounds before a workout.
    private func chosenCard(_ persona: CoachPersona) -> some View {
        let line = CoachCatalog.line(for: .upcomingWorkout, persona: persona, context: CoachContext(), seed: 0)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(persona.name).font(.headline)
                Spacer(minLength: 8)
                Eyebrow(persona.tone.title, color: FelixTheme.ice)
            }
            Text("«\(line)»")
                .font(.subheadline.italic())
                .foregroundStyle(FelixTheme.text.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface(radius: 24, highlighted: true))
        .accessibilityElement(children: .combine)
    }
}
