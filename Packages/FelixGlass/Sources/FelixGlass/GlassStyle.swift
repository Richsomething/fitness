import SwiftUI

/// How a piece of glass looks. On iOS 26 and later the system draws the glass and only `isClear` and the tint
/// matter; the numbers are for the frosted glass of iOS 18 to 25 (blur, a pale body, a light from above, a bright
/// edge and a soft shadow). They are tuned for a dark background.
public struct GlassStyle: Equatable {
    /// Blur what is behind. Off for a clear lens that must leave it readable.
    public var usesBlur: Bool
    /// The pale body of the glass, top and bottom, as white at this opacity.
    public var fillTop: Double
    public var fillBottom: Double
    /// The accent colour mixed into the body, top and bottom; 0 for plain glass.
    public var accentTop: Double
    public var accentBottom: Double
    /// The light from above that fades out over the upper half.
    public var highlight: Double
    /// The bright rim, top and bottom.
    public var edgeTop: Double
    public var edgeBottom: Double
    public var shadowOpacity: Double
    public var shadowRadius: CGFloat
    public var shadowY: CGFloat
    /// A coloured glow under tinted glass instead of a black shadow.
    public var shadowUsesAccent: Bool
    /// Keeps what is underneath readable (the system's clear glass).
    public var isClear: Bool
    /// A colour of its own, instead of the palette's accent.
    public var tint: Color?

    public init(usesBlur: Bool = true, fillTop: Double = 0, fillBottom: Double = 0, accentTop: Double = 0,
                accentBottom: Double = 0, highlight: Double = 0, edgeTop: Double = 0, edgeBottom: Double = 0,
                shadowOpacity: Double = 0, shadowRadius: CGFloat = 0, shadowY: CGFloat = 0,
                shadowUsesAccent: Bool = false, isClear: Bool = false, tint: Color? = nil) {
        self.usesBlur = usesBlur
        self.fillTop = fillTop
        self.fillBottom = fillBottom
        self.accentTop = accentTop
        self.accentBottom = accentBottom
        self.highlight = highlight
        self.edgeTop = edgeTop
        self.edgeBottom = edgeBottom
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowY = shadowY
        self.shadowUsesAccent = shadowUsesAccent
        self.isClear = isClear
        self.tint = tint
    }

    /// A control floating over content: a bar, a plain button, a round button.
    public static let regular = GlassStyle(fillTop: 0.10, fillBottom: 0.04, highlight: 0.14, edgeTop: 0.38, edgeBottom: 0.07,
                                           shadowOpacity: 0.28, shadowRadius: 10, shadowY: 4)

    /// A lens over content: no blur, so the content stays readable.
    public static let clear = GlassStyle(usesBlur: false, fillTop: 0.10, fillBottom: 0.05, highlight: 0.10,
                                         edgeTop: 0.30, edgeBottom: 0.05, isClear: true)

    /// The main action: glass in the accent colour with a glow.
    public static let accent = GlassStyle(accentTop: 0.72, accentBottom: 0.66, highlight: 0.22, edgeTop: 0.55, edgeBottom: 0.08,
                                          shadowOpacity: 0.40, shadowRadius: 20, shadowY: 8, shadowUsesAccent: true)

    /// The lens under the chosen segment or tab: accent glass, more see-through than the main action so the bar's
    /// glass shows through it.
    public static let lens = GlassStyle(accentTop: 0.60, accentBottom: 0.42, highlight: 0.28, edgeTop: 0.55, edgeBottom: 0.10,
                                        shadowOpacity: 0.35, shadowRadius: 10, shadowY: 3, shadowUsesAccent: true)

    /// The same glass with a colour of its own; `nil` takes it away.
    public func tinted(_ color: Color?) -> GlassStyle {
        var copy = self
        copy.tint = color
        return copy
    }

    /// The tint the system glass is given: the style's own, else the accent for accent glass, else none.
    func systemTint(_ palette: GlassPalette) -> Color? {
        if let tint { return tint }
        return accentTop > 0 ? palette.accent.opacity(0.62) : nil
    }
}

/// How roomy a row of segments is.
public enum GlassDensity: CaseIterable, Equatable {
    /// The usual size.
    case regular
    /// Smaller type and height, for a choice inside a card or a row of its own.
    case compact
    /// Smaller still, for four long names side by side, so they keep one size instead of shrinking unevenly.
    case tight

    /// Never below 40 pt: the least that is comfortable to hit.
    public var minHeight: CGFloat {
        switch self {
        case .regular: 44
        case .compact: 40
        case .tight: 44
        }
    }

    public var font: Font {
        switch self {
        case .regular: Font.subheadline.weight(.semibold)
        case .compact: Font.footnote.weight(.semibold)
        case .tight: Font.caption.weight(.semibold)
        }
    }

    /// Room between the words and the edge of the lens, so a long name shrinks instead of touching it.
    public var horizontalPadding: CGFloat {
        switch self {
        case .regular: 12
        case .compact: 8
        case .tight: 5
        }
    }

    public var minimumScale: CGFloat {
        switch self {
        case .regular: 0.8
        case .compact: 0.7
        case .tight: 0.8
        }
    }
}
