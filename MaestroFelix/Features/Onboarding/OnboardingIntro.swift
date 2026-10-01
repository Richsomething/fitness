import SwiftUI

/// Opening screen as the start of character creation: the coach's neural core with its orbits, which
/// can be spun with a swipe and pulsed with a tap. The name typed below appears on the nameplate over it, and every letter sends a pulse
/// through the core. The body is chosen on the next step, so nothing here assumes a gender.
struct OnboardingIntro: View {
    @Binding var name: String
    /// An existing profile is being changed, not a new one made.
    var isEditing = false
    @FocusState private var isNameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 30

    private static let stageHeight: CGFloat = 300
    // While the name is typed the tagline steps aside and the stage tightens, so the core, the
    // nameplate and the field all stay above the keyboard.
    private static let typingStageHeight: CGFloat = 250
    private static let typingCoreScale: CGFloat = 0.82
    private static let coreSize: CGFloat = 200

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The steps after this one, each a short question.
    private var promise: String {
        if isEditing { return "Измени, что нужно: остальное останется как есть." }
        let steps = OnboardingStep.allCases.count - 1
        let word = RussianPlural.form(steps, one: "шаг", few: "шага", many: "шагов")
        return "\(steps) коротких \(word), около трёх минут, и у тебя план на неделю."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(isEditing ? "Maestro Felix · профиль" : "Maestro Felix · новый профиль", color: FelixTheme.ice)
                    .padding(.horizontal, 20)
                    .entrance(0)
                stage
                    .entrance(1)
                VStack(alignment: .leading, spacing: 24) {
                    if !isNameFocused {
                        Text("Твой ритм.\nТвоя следующая версия.")
                            .font(.felixDisplay(titleSize))
                            .tracking(-0.6)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                            .entrance(2)
                        // What this is, how long it takes and that nothing is final.
                        Text(promise)
                            .font(.subheadline)
                            .foregroundStyle(FelixTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                            .entrance(2)
                    }
                    nameField
                        .entrance(3)
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
            .entranceScope("intro")
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.4), value: isNameFocused)
    }

    // MARK: Stage

    private var stage: some View {
        let half = Self.coreSize / 2
        return ZStack {
            NeuralCore(energy: trimmedName.isEmpty ? (isNameFocused ? 0.7 : 0.3) : 1, pulse: name.count,
                       lit: trimmedName.count)
                .frame(width: Self.coreSize, height: Self.coreSize)
                .scaleEffect(isNameFocused ? Self.typingCoreScale : 1)
                .offset(y: isNameFocused ? 10 : 14)
            nameplate
                // The field below says the same.
                .accessibilityHidden(true)
                .offset(y: isNameFocused ? -half * Self.typingCoreScale - 22 : -half - 34)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isNameFocused ? Self.typingStageHeight : Self.stageHeight)
        // Decoration goes in the background so it never widens the layout.
        .background {
            LightTrails(intensity: 0.45)
                .mask(RadialGradient(colors: [.black, .clear], center: .center, startRadius: 40, endRadius: 200))
        }
    }

    /// The player's name over the core, tethered to it.
    private var nameplate: some View {
        let isEmpty = trimmedName.isEmpty
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: isEmpty ? "person.fill.questionmark" : "person.fill.checkmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(isEmpty ? FelixTheme.secondary : FelixTheme.ice)
                    .contentTransition(.symbolEffect(.replace))
                Text(isEmpty ? "Новый игрок" : trimmedName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.opacity)
            }
            .foregroundStyle(isEmpty ? FelixTheme.secondary : Color.white)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .felixGlass(in: Capsule(), interactive: false, tint: isEmpty ? nil : FelixTheme.cobalt.opacity(0.55))
            .shadow(color: isEmpty ? .clear : FelixTheme.cobalt.opacity(0.7), radius: 12)
            LinearGradient(colors: [FelixTheme.ice.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom)
                .frame(width: 1, height: 18)
        }
        .frame(maxWidth: 260)
        .animation(.snappy(duration: 0.25), value: isEmpty)
    }

    // MARK: Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Как тебя называть?")
            HStack(spacing: 12) {
                Image(systemName: "signature")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(isNameFocused || !trimmedName.isEmpty ? FelixTheme.cobalt : Color.white.opacity(0.1)))
                TextField("Имя", text: $name, prompt: Text("Имя · необязательно").foregroundStyle(FelixTheme.tertiary))
                    .font(.title3.weight(.semibold))
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isNameFocused)
                if !name.isEmpty {
                    Button { name = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(FelixTheme.tertiary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Стереть имя")
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, name.isEmpty ? 18 : 4)
            .frame(minHeight: 60)
            .felixGlass(in: Capsule(), interactive: false)
            .overlay(Capsule().strokeBorder(FelixTheme.cobalt.opacity(isNameFocused ? 0.9 : 0), lineWidth: 1.5))
            .shadow(color: FelixTheme.cobalt.opacity(isNameFocused ? 0.5 : 0), radius: 16)
            .contentShape(Capsule())
            .onTapGesture { isNameFocused = true }
            .animation(.snappy(duration: 0.2), value: isNameFocused)
        }
    }
}
