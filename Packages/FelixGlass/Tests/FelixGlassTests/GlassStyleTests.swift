import SwiftUI
import Testing
@testable import FelixGlass

/// The glass itself is drawn, so these tests keep to the values it is drawn from: a preset that goes out of range or a
/// control that shrinks below a tappable size is the kind of slip that does not show up until it is on a screen.
struct GlassStyleTests {
    private static let presets: [GlassStyle] = [.regular, .clear, .accent, .lens]

    @Test("every opacity of every preset is a real opacity")
    func opacitiesAreInRange() {
        for style in Self.presets {
            let values = [style.fillTop, style.fillBottom, style.accentTop, style.accentBottom, style.highlight,
                          style.edgeTop, style.edgeBottom, style.shadowOpacity]
            for value in values {
                #expect((0.0...1.0).contains(value))
            }
        }
    }

    @Test("clear glass does not blur, the others do")
    func onlyClearGlassKeepsWhatIsBehindSharp() {
        #expect(!GlassStyle.clear.usesBlur && GlassStyle.clear.isClear)
        #expect(GlassStyle.regular.usesBlur && GlassStyle.accent.usesBlur && GlassStyle.lens.usesBlur)
        #expect(!GlassStyle.regular.isClear)
    }

    @Test("accent glass carries the accent and plain glass does not")
    func accentGlassCarriesTheAccent() {
        #expect(GlassStyle.accent.accentTop > 0 && GlassStyle.lens.accentTop > 0)
        #expect(GlassStyle.regular.accentTop == 0 && GlassStyle.clear.accentTop == 0)
    }

    @Test("the lens is more see-through than the main action, so the bar shows through it")
    func theLensIsLighterThanThePrimaryButton() {
        #expect(GlassStyle.lens.accentTop < GlassStyle.accent.accentTop)
        #expect(GlassStyle.lens.accentBottom < GlassStyle.accent.accentBottom)
    }

    @Test("tinting changes the colour and nothing else, and nil takes it away")
    func tintingKeepsTheRest() {
        let red = GlassStyle.regular.tinted(Color.red)
        #expect(red.tint == Color.red)
        #expect(red.fillTop == GlassStyle.regular.fillTop && red.edgeTop == GlassStyle.regular.edgeTop)
        #expect(red.tinted(nil) == GlassStyle.regular)
    }

    @Test("the system tint is the style's own, else the accent for accent glass, else none")
    func systemTintFollowsTheStyle() {
        let palette = GlassPalette(accent: Color.blue, accentDeep: Color.indigo)
        #expect(GlassStyle.regular.systemTint(palette) == nil)
        #expect(GlassStyle.regular.tinted(Color.green).systemTint(palette) == Color.green)
        #expect(GlassStyle.accent.systemTint(palette) != nil)
    }

    @Test("every density keeps a tappable height")
    func everyDensityKeepsATapHeight() {
        for density in GlassDensity.allCases {
            #expect(density.minHeight >= 40)
        }
    }

    @Test("tighter densities leave less room at the sides")
    func tighterDensitiesUseLessPadding() {
        #expect(GlassDensity.regular.horizontalPadding > GlassDensity.compact.horizontalPadding)
        #expect(GlassDensity.compact.horizontalPadding > GlassDensity.tight.horizontalPadding)
    }

    @Test("a tab item is told apart by its id")
    func tabItemsAreIdentifiedByTheirID() {
        let item = GlassTabItem(id: 3, title: "План", symbol: "calendar")
        #expect(item.id == 3 && item.title == "План" && item.symbol == "calendar")
    }
}
