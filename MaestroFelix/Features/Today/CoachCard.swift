import SwiftUI

extension CoachPersona {
    var characterAccent: Color {
        switch tone {
        case .calm: Color(red: 0.38, green: 0.9, blue: 0.92)
        case .energetic: Color(red: 1, green: 0.3, blue: 0.2)
        case .focused: Color(red: 0.73, green: 0.55, blue: 1)
        case .supportive: Color(red: 0.86, green: 0.89, blue: 1)
        }
    }
}

/// Draws one square cell from the bundled expression sheet, preserving its full resolution.
struct CoachPortrait: View {
    let persona: CoachPersona
    var emotion: CoachEmotion = .neutral

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack(alignment: .topLeading) {
                Image(persona.portrait)
                    .resizable()
                    .frame(width: side * 3, height: side * 2)
                    .offset(x: -side * CGFloat(emotion.column), y: -side * CGFloat(emotion.row))
            }
            .frame(width: side, height: side, alignment: .topLeading)
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// Portrait shared by the roster and the daily coach card.
struct CoachAvatar: View {
    let persona: CoachPersona
    var size: CGFloat = 48
    var emotion: CoachEmotion = .neutral

    var body: some View {
        CoachPortrait(persona: persona, emotion: emotion)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            .shadow(color: persona.characterAccent.opacity(0.5), radius: 8)
            .accessibilityHidden(true)
    }
}

/// What the coach says now, with one action that fits the day.
struct CoachCard: View {
    let persona: CoachPersona
    let line: String
    var event: CoachEvent = .welcome
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
            CoachAvatar(persona: persona, size: 48, emotion: .forEvent(event))
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(persona.name, color: persona.characterAccent)
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
