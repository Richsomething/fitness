import SwiftUI

/// Browse first; only the explicit select action changes the saved coach.
struct CoachPickerView: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var inspecting: CoachPersona?

    var body: some View {
        ScreenScaffold(glow: UnitPoint(x: 0.1, y: 0)) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Тренеры").font(.felixTitle)
                Text("Разный характер. Твой темп.")
                    .font(.subheadline).foregroundStyle(FelixTheme.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach(CoachCatalog.personas) { persona in
                        let chosen = persona.id == app.coach.persona.id
                        Button { inspecting = persona } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                CoachPortrait(persona: persona, emotion: chosen ? .encouraging : .neutral)
                                    .frame(height: 116)
                                    .frame(maxWidth: .infinity)
                                HStack(spacing: 4) {
                                    Text(persona.name).font(.headline)
                                    Spacer(minLength: 0)
                                    if chosen { Image(systemName: "checkmark.circle.fill").foregroundStyle(FelixTheme.ice) }
                                }
                                Text(persona.specialty).font(.caption).foregroundStyle(FelixTheme.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .background(CardSurface(radius: 22, highlighted: chosen))
                            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(chosen ? FelixTheme.ice : .clear, lineWidth: 2))
                            .foregroundStyle(FelixTheme.text)
                            .contentShape(RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("\(persona.name), \(persona.specialty)")
                        .accessibilityHint("Познакомиться с тренером")
                        .accessibilityAddTraits(chosen ? .isSelected : [])
                    }
                }
                Text("Нажми на тренера, чтобы познакомиться.")
                    .font(.caption).foregroundStyle(FelixTheme.secondary)
                if let error = app.coach.storageError { FelixInlineIssue(text: error) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $inspecting) { persona in CoachDetails(persona: persona) }
        .sensoryFeedback(.selection, trigger: app.coach.state.personaID)
    }
}

private struct CoachDetails: View {
    let persona: CoachPersona
    @Environment(AppCoordinator.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var justSelected = false

    private var chosen: Bool { app.coach.persona.id == persona.id }
    private var expression: CoachEmotion { justSelected ? .proud : chosen ? .encouraging : .neutral }
    private var greeting: String {
        if justSelected { return persona.selectionLine }
        return CoachCatalog.line(for: chosen ? .welcome : .upcomingWorkout, persona: persona,
                          context: CoachContext(), seed: 0)
    }

    var body: some View {
        NavigationStack {
            ScreenScaffold {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack(alignment: .bottomLeading) {
                        CoachPortrait(persona: persona, emotion: expression)
                            .frame(width: 248, height: 248)
                            .id(expression)
                            .transition(.opacity)
                        if chosen {
                            Label("Твой тренер", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(12)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay {
                        if justSelected {
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(persona.characterAccent.opacity(0.85), lineWidth: 2)
                                .frame(width: 248, height: 248)
                                .shadow(color: persona.characterAccent.opacity(0.8), radius: 18)
                                .allowsHitTesting(false)
                        }
                    }
                    .shadow(color: persona.characterAccent.opacity(justSelected ? 0.55 : 0), radius: 26)
                    .frame(maxWidth: .infinity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: expression)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(persona.specialty).font(.title2.bold())
                        Text(persona.tone.title).font(.subheadline).foregroundStyle(FelixTheme.ice)
                        Text(persona.approach).font(.subheadline).foregroundStyle(FelixTheme.secondary)
                    }
                    Text("«\(greeting)»")
                        .font(.headline).foregroundStyle(persona.characterAccent)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(CardSurface(radius: 20))
                    if let error = app.coach.storageError { FelixInlineIssue(text: error) }
                }
                .padding(.bottom, 12)
            }
            .navigationTitle(persona.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if chosen {
                        Label(justSelected ? "Выбран" : "Твой тренер", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(FelixTheme.ice)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .accessibilityAddTraits(.updatesFrequently)
                    } else {
                        Button("Выбрать тренера") {
                            if app.coach.select(persona.id) { justSelected = true }
                        }
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.white)
                        .background(FelixTheme.cobalt, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(FelixTheme.background)
            }
            .sensoryFeedback(.success, trigger: justSelected)
            .task(id: justSelected) {
                guard justSelected else { return }
                // Allow the smile and confirmation to register before returning to the roster.
                do { try await Task.sleep(for: .milliseconds(1800)) }
                catch { return }
                dismiss()
            }
        }
        .preferredColorScheme(.dark)
    }
}
