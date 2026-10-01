import SwiftUI

/// Scrolls the screen's column to the view marked with `.id(_:)`, so a block that appears low on the screen
/// can bring its own button into view. Does nothing outside a `ScreenScaffold`.
private struct ScrollToIDKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var scrollToID: (String) -> Void {
        get { self[ScrollToIDKey.self] }
        set { self[ScrollToIDKey.self] = newValue }
    }
}

/// A screen's frame: the black canvas, a drifting glow and a scrolling column of blocks.
struct ScreenScaffold<Content: View>: View {
    var glow = UnitPoint(x: 0.85, y: 0)
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            FelixBackground()
            AmbientGlow(anchor: glow)
            ScrollViewReader { proxy in
                ScrollView {
                    content
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                        .frame(maxWidth: 620, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .environment(\.scrollToID) { id in
                    withAnimation(.smooth) { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
        .foregroundStyle(FelixTheme.text)
    }
}

/// The main card's ground: cobalt depth, one line of light near the top, a hairline edge. Only one
/// such card shows on a screen, so the moving light stays a single accent.
struct HeroCardBackground: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FelixTheme.cardRadius, style: .continuous)
        ZStack {
            LinearGradient(colors: [FelixTheme.cobaltDeep.opacity(0.7), Color.black.opacity(0.3)],
                           startPoint: .topTrailing, endPoint: .bottomLeading)
            // Kept to the upper part, away from the text below.
            LightTrails(intensity: 0.3)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)))
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0.04)],
                                                   startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}

/// Says plainly that the plan follows general rules, until a coach's own plan replaces it.
struct StarterPlanNote: View {
    @State private var explains = false

    var body: some View {
        Button { explains = true } label: {
            Label("Стартовый план по общим правилам", systemImage: "info.circle")
                .font(.footnote.weight(.medium))
                .foregroundStyle(FelixTheme.tertiary)
                .frame(minHeight: 44, alignment: .leading)
        }
        .alert("Стартовый план", isPresented: $explains) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Он составлен по общим правилам из твоих ответов: цель, опыт, ограничения и оценки прошлых тренировок. Позже его заменит план тренера.")
        }
    }
}

/// What marks the chosen item of a glass control: a cobalt lens with a light edge. The segmented choice,
/// the tab bar and the step bar all use it, so a selection reads the same everywhere.
struct GlassLens: View {
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [FelixTheme.cobalt.opacity(0.85), FelixTheme.cobaltDeep.opacity(0.85)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
    }
}

/// A short choice between a few named options, as a glass capsule with a lens under the chosen one.
struct GlassSegmented<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    /// Smaller type and height, for a choice that sits inside a card or a row of its own.
    var compact = false
    /// Smaller still, for four longer names side by side, so they all keep one size instead of shrinking unevenly.
    var tight = false
    @Namespace private var lens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                segment(options[index])
            }
        }
        .padding(4)
        .felixGlass(in: Capsule(), interactive: false)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.78), value: selection)
    }

    private func segment(_ option: (value: Value, title: String)) -> some View {
        let isSelected = option.value == selection
        return Button { selection = option.value } label: {
            Text(option.title)
                .font((tight ? Font.caption : compact ? Font.footnote : Font.subheadline).weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : FelixTheme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(compact ? 0.7 : 0.8)
                // Room between the words and the edge of the lens, so a long name shrinks instead of touching it.
                .padding(.horizontal, tight ? 5 : compact ? 8 : 12)
                .frame(maxWidth: .infinity, minHeight: compact ? 40 : 44)
                .background {
                    if isSelected { GlassLens().matchedGeometryEffect(id: "lens", in: lens) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Pins a row of actions to the bottom of a screen over a fade, so what scrolls under it stays out of the way.
private struct PinnedActions: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) {
                LinearGradient(stops: [.init(color: Color.black.opacity(0), location: 0),
                                       .init(color: Color.black.opacity(0.92), location: 0.4)],
                               startPoint: .top, endPoint: .bottom)
                    .padding(.top, -16)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    /// For the main actions of a screen: always in view, above the tab bar.
    func pinnedActions() -> some View { modifier(PinnedActions()) }
}

/// A title above a block, with an optional action on the right.
struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold())
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FelixTheme.ice)
                    .frame(minHeight: 44)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// A big value with its label and unit.
struct MetricTile: View {
    let title: String
    let value: String
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(title)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.felixNumber(32))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit { Text(unit).font(.subheadline.weight(.semibold)).foregroundStyle(FelixTheme.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The look of one row of a list card: an icon disc, a title with a detail, and what it leads to.
struct FelixRowLabel: View {
    let title: String
    var detail: String?
    var icon: String?
    var value: String?
    var showsChevron = true

    var body: some View {
        HStack(spacing: 14) {
            if let icon {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(FelixTheme.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            if let value { Text(value).font(.subheadline).foregroundStyle(FelixTheme.secondary) }
            if showsChevron {
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(FelixTheme.tertiary)
            }
        }
        .foregroundStyle(FelixTheme.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A row that does something when tapped.
struct FelixRow: View {
    let title: String
    var detail: String?
    var icon: String?
    var value: String?
    var showsChevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FelixRowLabel(title: title, detail: detail, icon: icon, value: value, showsChevron: showsChevron)
        }
        .buttonStyle(.plain)
    }
}

/// A row that opens another screen.
struct FelixLinkRow<Destination: View>: View {
    let title: String
    var detail: String?
    var icon: String?
    var value: String?
    @ViewBuilder var destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            FelixRowLabel(title: title, detail: detail, icon: icon, value: value)
        }
        .buttonStyle(.plain)
    }
}

/// Rows of one card separated by hairlines.
struct FelixList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(CardSurface())
            .clipShape(RoundedRectangle(cornerRadius: FelixTheme.cardRadius, style: .continuous))
    }
}

struct FelixDivider: View {
    var body: some View {
        Rectangle().fill(FelixTheme.hairline).frame(height: 1).padding(.leading, 16)
    }
}

extension SessionStatus {
    var title: String {
        switch self {
        case .planned: "Запланирована"
        case .done: "Выполнена"
        case .skipped: "Пропущена"
        case .missed: "Не состоялась"
        case .paused: "На паузе"
        }
    }

    var symbol: String {
        switch self {
        case .planned: "circle"
        case .done: "checkmark.circle.fill"
        case .skipped: "arrow.uturn.right.circle"
        case .missed: "minus.circle"
        case .paused: "pause.circle"
        }
    }

    var color: Color {
        switch self {
        case .done: FelixTheme.ice
        case .planned: FelixTheme.text
        case .skipped, .missed, .paused: FelixTheme.tertiary
        }
    }
}

/// A number with minus and plus, whose value can also be typed.
struct NumberStepper: View {
    let title: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    var unit: String?
    var fractionDigits = 0
    @FocusState private var isFocused: Bool
    @State private var text = ""

    var body: some View {
        VStack(spacing: 8) {
            Eyebrow(title)
            HStack(spacing: 2) {
                button("minus", label: "Меньше", delta: -step)
                // The typed text becomes the value as it is typed, so a set recorded with the keyboard
                // still up takes what is on the screen.
                // On entering the field it empties and the old value stays as a hint, so typing replaces it.
                TextField("", text: $text, prompt: Text(shown(value)).foregroundStyle(FelixTheme.tertiary))
                    .keyboardType(fractionDigits > 0 ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.center)
                    .font(.felixNumber(30))
                    .monospacedDigit()
                    .focused($isFocused)
                    .frame(minWidth: 56)
                    .accessibilityLabel(title)
                button("plus", label: "Больше", delta: step)
            }
            if isFocused {
                Button("Готово") { isFocused = false }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FelixTheme.ice)
                    .frame(minHeight: 24)
            } else if let unit {
                Text(unit).font(.footnote.weight(.semibold)).foregroundStyle(FelixTheme.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { text = shown(value) }
        .onChange(of: text) { _, typed in
            guard isFocused, let parsed = Double(typed.replacingOccurrences(of: ",", with: ".")) else { return }
            value = min(max(parsed, range.lowerBound), range.upperBound)
        }
        .onChange(of: value) { _, new in
            let clamped = min(max(new, range.lowerBound), range.upperBound)
            if clamped != new { value = clamped }
            if !isFocused { text = shown(clamped) }
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                text = ""
            } else {
                value = min(max(value, range.lowerBound), range.upperBound)
                text = shown(value)
            }
        }
    }

    /// 40, 62,5 — no trailing zeros.
    private func shown(_ number: Double) -> String {
        fractionDigits > 0 ? WeightFormat.kg(number) : String(Int(number.rounded()))
    }

    private func button(_ symbol: String, label: String, delta: Double) -> some View {
        Button {
            isFocused = false
            value = min(max(((value + delta) * 100).rounded() / 100, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(FelixTheme.text)
                .frame(width: 44, height: 44)
                .felixGlass(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(label): \(title)")
    }
}
