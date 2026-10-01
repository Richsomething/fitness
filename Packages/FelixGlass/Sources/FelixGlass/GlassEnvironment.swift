import SwiftUI

/// The colours the glass is tinted with. The library knows nothing about an app's theme: the app hands in its own
/// through the environment, once, near the root (`.environment(\.glassPalette, …)`).
public struct GlassPalette: Equatable {
    /// The colour of tinted glass: a primary button, the lens under the chosen segment.
    public var accent: Color
    /// A deeper step of the accent, for the lower edge of tinted glass.
    public var accentDeep: Color
    /// Text and symbols on glass.
    public var label: Color
    /// Text and symbols that are not chosen.
    public var secondaryLabel: Color

    public init(accent: Color, accentDeep: Color, label: Color = .white, secondaryLabel: Color = Color.white.opacity(0.74)) {
        self.accent = accent
        self.accentDeep = accentDeep
        self.label = label
        self.secondaryLabel = secondaryLabel
    }

    /// Electric cobalt on white text: what the library looks like before an app chooses its own.
    public static let cobalt = GlassPalette(accent: Color(red: 0.16, green: 0.36, blue: 1),
                                            accentDeep: Color(red: 0.05, green: 0.14, blue: 0.62))
}

/// Which glass is drawn.
public enum GlassEngine: Equatable {
    /// The system's Liquid Glass where it exists (iOS 26 and later, so iOS 27 too), and the library's own
    /// frosted glass on iOS 18 to 25.
    case automatic
    /// Always the frosted glass. For comparing the two, or for a screen that must look the same everywhere.
    case frosted
}

private struct GlassPaletteKey: EnvironmentKey {
    static let defaultValue = GlassPalette.cobalt
}

private struct GlassEngineKey: EnvironmentKey {
    static let defaultValue = GlassEngine.automatic
}

public extension EnvironmentValues {
    var glassPalette: GlassPalette {
        get { self[GlassPaletteKey.self] }
        set { self[GlassPaletteKey.self] = newValue }
    }

    var glassEngine: GlassEngine {
        get { self[GlassEngineKey.self] }
        set { self[GlassEngineKey.self] = newValue }
    }
}
