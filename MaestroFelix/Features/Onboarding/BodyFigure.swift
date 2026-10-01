import SwiftUI

/// A body in a 200 × 500 design space: the painting (`art`) plus a region and a hotspot for every
/// zone the view shows. From behind the person's left is on the viewer's left; from the front it is
/// on the viewer's right.
struct BodyFigure {
    enum Facing {
        case front, back

        var flipped: Facing { self == .front ? .back : .front }
    }

    static let size = CGSize(width: 200, height: 500)

    struct Region {
        let zone: BodyZone
        /// `.left` or `.right` for one of a pair; nil for a zone on the midline.
        let side: BodySide?
        let path: Path
        let center: CGPoint
    }

    struct Hotspot {
        let zone: BodyZone
        let side: BodySide?
        let point: CGPoint
    }

    let facing: Facing
    let art: BodyArt
    let regions: [Region]
    let hotspots: [Hotspot]

    // A tap this close to a hotspot, in design units, selects its zone.
    private static let hotspotReach: CGFloat = 24

    static func fit(in available: CGSize) -> (origin: CGPoint, scale: CGFloat) {
        let scale = min(available.width / size.width, available.height / size.height)
        return (CGPoint(x: (available.width - size.width * scale) / 2, y: (available.height - size.height * scale) / 2), scale)
    }

    /// Whether a limitation on the `chosen` side lights a part on `side`. An unspecified side lights both.
    static func lights(_ side: BodySide?, for chosen: BodySide) -> Bool {
        guard let side, chosen == .left || chosen == .right else { return true }
        return side == chosen
    }

    func shows(_ zone: BodyZone) -> Bool {
        hotspots.contains { $0.zone == zone }
    }

    /// Where a line to `zone` should end: the hotspot on the chosen side, otherwise the one on the
    /// preferred half of the screen. Nil when this view does not show the zone.
    func hotspot(for zone: BodyZone, side: BodySide?, preferLeading: Bool) -> CGPoint? {
        let candidates = hotspots.filter { $0.zone == zone }
        if let side, side == .left || side == .right, let match = candidates.first(where: { $0.side == side }) {
            return match.point
        }
        return (candidates.first { ($0.point.x < Self.size.width / 2) == preferLeading } ?? candidates.first)?.point
    }

    /// The nearest hotspot within reach, otherwise the smallest region under `point`.
    func zone(at point: CGPoint) -> BodyZone? {
        let nearest = hotspots.min { Self.distance($0.point, point) < Self.distance($1.point, point) }
        if let nearest, Self.distance(nearest.point, point) <= Self.hotspotReach { return nearest.zone }
        return regions
            .filter { $0.path.contains(point) }
            .min { Self.area($0.path) < Self.area($1.path) }?
            .zone
    }

    static func mirror(_ point: CGPoint) -> CGPoint {
        CGPoint(x: size.width - point.x, y: point.y)
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private static func area(_ path: Path) -> CGFloat {
        path.boundingRect.width * path.boundingRect.height
    }
}
