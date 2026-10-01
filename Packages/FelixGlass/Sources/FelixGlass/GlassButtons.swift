import SwiftUI

/// Press feedback for glass: a small shrink and dim while the finger is down, none when motion is reduced.
public struct GlassPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A full-width capsule button. `primary` is accent glass with a glow, and its symbol follows the title; `secondary`
/// is plain glass, and its symbol comes first.
public struct GlassButton: View {
    public enum Role: Equatable {
        case primary
        case secondary
    }

    private let title: String
    private let systemImage: String?
    private let role: Role
    private let action: () -> Void
    @Environment(\.glassPalette) private var palette

    public init(_ title: String, systemImage: String? = nil, role: Role = .primary, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if role == .secondary, let systemImage {
                    Image(systemName: systemImage).font(.subheadline.weight(.semibold))
                }
                Text(title).font(.headline)
                if role == .primary, let systemImage {
                    Image(systemName: systemImage).font(.subheadline.weight(.bold))
                }
            }
            .foregroundStyle(role == .primary ? Color.white : palette.label)
            .frame(maxWidth: .infinity, minHeight: role == .primary ? 56 : 54)
            .glassSurface(in: Capsule(), style: role == .primary ? .accent : .regular)
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle())
    }
}

/// A round glass button with a symbol. The label is for VoiceOver, since the symbol alone says nothing to it.
public struct GlassIconButton: View {
    private let systemImage: String
    private let label: String
    private let action: () -> Void
    @Environment(\.glassPalette) private var palette

    public init(systemImage: String, label: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.label)
                .frame(width: 44, height: 44)
                .glassSurface(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(label)
    }
}
