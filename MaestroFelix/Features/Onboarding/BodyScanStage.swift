import SwiftUI

/// The body map as a character inspection screen: the anatomy figure on a pad in the middle and a
/// glass chip for every zone of the side in view, joined to its hotspot by a leader line. The switch
/// under the pad turns the figure between front and back, and with it the chips: a chip is never
/// there for a zone the figure does not show.
struct BodyScanStage: View {
    let limitations: [BodyLimitation]
    let build: BodyFigure.Build
    @Binding var facing: BodyFigure.Facing
    let isClear: Bool
    let ping: BodyMapPing?
    let onSelect: (BodyZone) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flipAngle = 0.0

    static let height: CGFloat = 472
    private static let chipHeight: CGFloat = 34
    private static let hitHeight: CGFloat = 44
    // Width kept free for the chips on both sides together; the figure takes the rest.
    private static let chipRoom: CGFloat = 172
    // Height below the feet for the side switch.
    private static let footer: CGFloat = 64

    private var figure: BodyFigure { BodyFigure.anatomy(facing: facing, build: build) }
    private var places: [BodyCallout] { BodyCallout.all.filter { figure.shows($0.zone) } }

    var body: some View {
        GeometryReader { geometry in
            let layout = StageLayout(size: geometry.size, chipRoom: Self.chipRoom, footer: Self.footer)
            let feet = layout.point(CGPoint(x: BodyFigure.size.width / 2, y: BodyFigure.size.height))
            ZStack(alignment: .topLeading) {
                SpawnPad(isActive: true)
                    .frame(width: layout.figureSize.width * 0.9, height: 40)
                    .position(x: feet.x, y: feet.y - 4)
                BodyMap(limitations: limitations, figure: figure, isClear: isClear, ping: ping, showsSides: true,
                        onTap: select)
                    .frame(width: layout.figureSize.width, height: layout.figureSize.height)
                    .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                    .offset(x: layout.origin.x, y: layout.origin.y)
                callouts(layout)
                sideSwitch
                    .position(x: feet.x, y: feet.y + 36)
            }
        }
        .frame(height: Self.height)
        // Chips are placed around the figure; beyond this size the step shows a list instead.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .sensoryFeedback(.impact(weight: .light), trigger: facing)
    }

    /// Front or back, said in words; choosing the other side turns the figure.
    private var sideSwitch: some View {
        GlassSegmented(options: [(BodyFigure.Facing.front, "Спереди"), (BodyFigure.Facing.back, "Сзади")],
                       selection: Binding(get: { facing }, set: { if $0 != facing { turn() } }))
            .frame(width: 220)
    }

    private func callouts(_ layout: StageLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(places, id: \.zone) { callout in
                chip(callout)
                    .frame(maxWidth: .infinity, alignment: callout.isLeading ? .leading : .trailing)
                    .padding(.top, layout.point(CGPoint(x: 0, y: callout.labelY)).y - Self.hitHeight / 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .backgroundPreferenceValue(CalloutBoundsKey.self) { bounds in
            GeometryReader { proxy in
                ForEach(places, id: \.zone) { callout in
                    let limitation = limitation(for: callout.zone)
                    if let anchor = bounds[callout.zone],
                       let hotspot = figure.hotspot(for: callout.zone, side: limitation?.side, preferLeading: callout.isLeading) {
                        Self.leader(from: proxy[anchor], to: layout.point(hotspot), isLeading: callout.isLeading)
                            .stroke(limitation == nil ? Color.white.opacity(0.24) : FelixTheme.ice.opacity(0.9),
                                    style: StrokeStyle(lineWidth: limitation == nil ? 1 : 1.3, lineCap: .round, lineJoin: .round))
                            .shadow(color: limitation == nil ? .clear : FelixTheme.cobalt, radius: 4)
                    }
                }
            }
            // Lines point at hotspots of one side, so they wait out a turn.
            .opacity(flipAngle == 0 ? 1 : 0)
            .allowsHitTesting(false)
        }
    }

    private func chip(_ callout: BodyCallout) -> some View {
        let limitation = limitation(for: callout.zone)
        return Button { select(callout.zone) } label: {
            Text(callout.title)
                .lineLimit(1)
                .fixedSize()
            .font(.footnote.weight(.semibold))
            .foregroundStyle(limitation == nil ? FelixTheme.text.opacity(0.9) : Color.white)
            .padding(.horizontal, 12)
            .frame(height: Self.chipHeight)
            .felixGlass(in: Capsule(), tint: limitation == nil ? nil : FelixTheme.cobalt.opacity(0.8))
            .shadow(color: limitation == nil ? .clear : FelixTheme.cobalt.opacity(0.6), radius: 10)
            .anchorPreference(key: CalloutBoundsKey.self, value: .bounds) { [callout.zone: $0] }
            .padding(.vertical, (Self.hitHeight - Self.chipHeight) / 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(callout.zone.title)
        .accessibilityValue(limitation.map { "\($0.kind.title), \($0.side.title)" } ?? "Не отмечено")
        .accessibilityHint("Открывает параметры ограничения")
    }

    private func limitation(for zone: BodyZone) -> BodyLimitation? {
        limitations.first { $0.zone == zone }
    }

    /// Opens a zone, turning the figure first when the zone is on its hidden side.
    private func select(_ zone: BodyZone) {
        if figure.shows(zone) {
            onSelect(zone)
        } else {
            turn { onSelect(zone) }
        }
    }

    /// Turns the figure edge-on, swaps the side, and turns it back to face the viewer.
    private func turn(then action: (() -> Void)? = nil) {
        guard !reduceMotion else {
            facing = facing.flipped
            action?()
            return
        }
        withAnimation(.easeIn(duration: 0.16)) { flipAngle = 90 } completion: {
            // The chips move to their places around the other side while it turns in.
            withAnimation(.snappy(duration: 0.3)) { facing = facing.flipped }
            flipAngle = -90
            withAnimation(.easeOut(duration: 0.24)) { flipAngle = 0 }
            action?()
        }
    }

    /// Out from the chip level with it until close to the body, then straight to the hotspot,
    /// stopping just short of it. The level run keeps lines clear of the hands.
    private static func leader(from chip: CGRect, to hotspot: CGPoint, isLeading: Bool) -> Path {
        let direction: CGFloat = isLeading ? 1 : -1
        let start = CGPoint(x: (isLeading ? chip.maxX : chip.minX) + 4 * direction, y: chip.midY)
        let bendX = isLeading ? max(start.x + 12, hotspot.x - 26) : min(start.x - 12, hotspot.x + 26)
        let bend = CGPoint(x: bendX, y: start.y)
        let dx = hotspot.x - bend.x
        let dy = hotspot.y - bend.y
        let length = max(hypot(dx, dy), 1)
        var path = Path()
        path.move(to: start)
        path.addLine(to: bend)
        path.addLine(to: CGPoint(x: hotspot.x - dx / length * 9, y: hotspot.y - dy / length * 9))
        return path
    }
}

/// Where the figure sits inside the stage, and how design units map to stage points. The figure is
/// pinned to the top, leaving `footer` below the feet.
private struct StageLayout {
    let scale: CGFloat
    let origin: CGPoint

    private static let topInset: CGFloat = 6

    init(size: CGSize, chipRoom: CGFloat, footer: CGFloat) {
        let figure = BodyFigure.size
        scale = max(min((size.height - footer - Self.topInset) / figure.height, (size.width - chipRoom) / figure.width), 0.1)
        origin = CGPoint(x: (size.width - figure.width * scale) / 2, y: Self.topInset)
    }

    var figureSize: CGSize {
        CGSize(width: BodyFigure.size.width * scale, height: BodyFigure.size.height * scale)
    }

    func point(_ design: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + design.x * scale, y: origin.y + design.y * scale)
    }
}

/// A chip beside the figure. Short titles keep the chips clear of the arms; the full title is read
/// by VoiceOver and shown in the editor.
private struct BodyCallout {
    let zone: BodyZone
    let title: String
    let isLeading: Bool
    /// Vertical centre of the chip, in design units.
    let labelY: CGFloat

    static let all = [
        BodyCallout(zone: .neck, title: "Шея", isLeading: true, labelY: 66),
        BodyCallout(zone: .shoulders, title: "Плечи", isLeading: true, labelY: 112),
        BodyCallout(zone: .elbows, title: "Локти", isLeading: true, labelY: 172),
        // Just above the hand, so the chip and its line stay clear of the fingers.
        BodyCallout(zone: .wrists, title: "Кисти", isLeading: true, labelY: 234),
        BodyCallout(zone: .ankles, title: "Голеностоп", isLeading: true, labelY: 470),
        BodyCallout(zone: .upperBack, title: "Верх спины", isLeading: false, labelY: 140),
        BodyCallout(zone: .lowerBack, title: "Поясница", isLeading: false, labelY: 196),
        // Below the hand.
        BodyCallout(zone: .hips, title: "Таз", isLeading: false, labelY: 306),
        BodyCallout(zone: .knees, title: "Колени", isLeading: false, labelY: 372),
    ]
}

private struct CalloutBoundsKey: PreferenceKey {
    static var defaultValue: [BodyZone: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [BodyZone: Anchor<CGRect>], nextValue: () -> [BodyZone: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}
