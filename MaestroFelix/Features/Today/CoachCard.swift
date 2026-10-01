import SwiftUI

/// The coach's emblem: a round badge with a symbol of their own. A placeholder until the characters
/// are drawn — never a photo, never a claim of a live person.
struct CoachAvatar: View {
    let persona: CoachPersona
    var size: CGFloat = 48

    var body: some View {
        Image(systemName: persona.symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            .shadow(color: FelixTheme.cobalt.opacity(0.5), radius: 8)
            .accessibilityHidden(true)
    }

    private var colors: [Color] {
        switch persona.tone {
        case .calm: [FelixTheme.ice.opacity(0.9), FelixTheme.cobalt]
        case .energetic: [FelixTheme.cobalt, FelixTheme.cobaltDeep]
        case .focused: [Color(red: 0.8, green: 0.86, blue: 1).opacity(0.85), FelixTheme.cobaltDeep]
        }
    }
}

/// What the coach says now, with one action that fits the day.
struct CoachCard: View {
    let persona: CoachPersona
    let line: String
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize

    // At accessibility sizes the words need the full width, so the emblem moves above them.
    private var layout: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                                     : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    // One short phrase is not worth a tall card: a small emblem, the name over the line, no link that repeats a tab.
    var body: some View {
        layout {
            CoachAvatar(persona: persona, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(persona.name, color: FelixTheme.ice)
                Text(line)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FelixTheme.ice)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardSurface(radius: 22))
        .accessibilityElement(children: .contain)
    }
}
