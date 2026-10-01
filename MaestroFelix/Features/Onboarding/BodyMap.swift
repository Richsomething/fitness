import SwiftUI

/// A short light effect on the map: rings around one zone, or a full-body sweep when `zone` is nil.
struct BodyMapPing: Equatable {
    let zone: BodyZone?
    let start: Date
}

/// The body on the map. The painted figure lights the muscles of a marked zone, amber for mild and
/// red for strong discomfort. A scanner beam passes over the body
/// and shows the muscles under it. A tap locks a sight on the zone, lights its muscles and names it,
/// then opens it. Decorative for VoiceOver: the zone chips and lists next to it carry the choice.
struct BodyMap: View {
    let limitations: [BodyLimitation]
    var figure = BodyFigure.anatomy(facing: .front)
    var isClear = false
    /// Mutes every other zone, for a close-up of one limitation.
    var focus: BodyZone?
    var ping: BodyMapPing?
    var animated = true
    /// Off for a plain figure, as on the character screen.
    var showsHotspots = true
    var showsSides = false
    var onTap: ((BodyZone) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The sight locked on a tapped point, in design units, and when it started.
    @State private var lock: (point: CGPoint, start: Date)?

    private static let scanPeriod = 3.6
    private static let pulsePeriod = 1.6
    private static let pingDuration = 0.9
    // How long the sight takes to lock on before the zone opens.
    private static let lockDuration = 0.32
    // The canvas reaches this far past the frame: a painting's hands and glow and the rings stay whole.
    private static let bleed: CGFloat = 40

    private var aim: CGPoint? { lock?.point }
    private var aimedZone: BodyZone? { aim.flatMap(figure.zone(at:)) }

    var body: some View {
        GeometryReader { geometry in
            let fit = BodyFigure.fit(in: geometry.size)
            let origin = CGPoint(x: fit.origin.x + Self.bleed, y: fit.origin.y + Self.bleed)
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !animated)) { timeline in
                Canvas { context, size in
                    var design = context
                    design.translateBy(x: origin.x, y: origin.y)
                    design.scaleBy(x: fit.scale, y: fit.scale)
                    draw(in: design, hairline: 1 / max(fit.scale, 0.01), now: timeline.date)
                    if let lock {
                        let progress = min(timeline.date.timeIntervalSince(lock.start) / Self.lockDuration, 1)
                        drawReticle(at: CGPoint(x: origin.x + lock.point.x * fit.scale, y: origin.y + lock.point.y * fit.scale),
                                    zone: aimedZone, progress: progress, bounds: CGRect(origin: .zero, size: size), in: context)
                    }
                }
            }
            .padding(-Self.bleed)
            .contentShape(Rectangle())
            // Touches arrive in the frame's own space, without the bleed.
            .onTapGesture { location in lockOn(designPoint(location, origin: fit.origin, scale: fit.scale)) }
            .allowsHitTesting(onTap != nil && lock == nil)
        }
        .sensoryFeedback(.selection, trigger: aimedZone)
        .accessibilityHidden(true)
    }

    // MARK: Touch

    private func designPoint(_ location: CGPoint, origin: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: (location.x - origin.x) / scale, y: (location.y - origin.y) / scale)
    }

    /// Locks the sight on the zone under a tap, then opens it. Without motion it opens at once.
    private func lockOn(_ point: CGPoint) {
        guard let zone = figure.zone(at: point) else { return }
        guard !reduceMotion else {
            onTap?(zone)
            return
        }
        lock = (point, .now)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.lockDuration))
            lock = nil
            onTap?(zone)
        }
    }

    /// The side of the person a point on the drawing belongs to. From the front the person's left is on
    /// the viewer's right.
    private func side(at point: CGPoint) -> BodySide {
        (point.x < BodyFigure.size.width / 2) == (figure.facing == .front) ? .right : .left
    }

    // MARK: Drawing

    /// `hairline` is one screen point in design units, so strokes and hotspots keep their size at any scale.
    private func draw(in context: GraphicsContext, hairline: CGFloat, now: Date) {
        let moving = animated && !reduceMotion
        let time = moving ? now.timeIntervalSinceReferenceDate : nil
        let marks = Dictionary(limitations.map { ($0.zone, $0) }, uniquingKeysWith: { first, _ in first })
        drawPainting(figure.art, marks: marks, time: time, in: context)
        drawAimedZone(in: context, hairline: hairline)
        if let time, focus == nil { drawScan(at: time, hairline: hairline, in: context) }
        if showsHotspots { drawHotspots(marks: marks, time: time, hairline: hairline, in: context) }
        if moving, let ping { drawPing(ping, now: now, marks: marks, hairline: hairline, in: context) }
        if showsSides { drawSideMarks(in: context) }
    }

    // MARK: Painted figure

    private func drawPainting(_ art: BodyArt, marks: [BodyZone: BodyLimitation], time: Double?, in context: GraphicsContext) {
        let painting = Image(art.image)
        context.draw(painting, in: art.frame)
        if isClear {
            var sheen = context
            sheen.blendMode = .plusLighter
            sheen.opacity = 0.16
            sheen.draw(painting, in: art.frame)
        }
        for layer in art.layers where focus == nil || focus == layer.zone {
            guard let limitation = marks[layer.zone], BodyFigure.lights(layer.side, for: limitation.side) else { continue }
            let breathing = limitation.kind == .currentDiscomfort ? time.map { 0.72 + 0.28 * sin($0 * 3) } ?? 1 : 1
            drawMuscle(layer, level: limitation.discomfortLevel, opacity: breathing, in: context)
        }
    }

    /// A muscle overlay in pain colours: soft amber at level 1, full red at 5.
    private func drawMuscle(_ layer: BodyArt.Layer, level: Int?, opacity: Double, in context: GraphicsContext) {
        let strength = level.map { 0.66 + 0.07 * Double($0) } ?? 0.82
        let warmth = level.map { Double(5 - $0) * 8 } ?? 14
        var muscle = context
        clip(&muscle, to: layer)
        muscle.opacity = strength * opacity
        muscle.addFilter(.hueRotation(.degrees(warmth)))
        muscle.addFilter(.shadow(color: Self.pain.opacity(0.85), radius: 5))
        muscle.draw(Image(layer.muscle.image), in: layer.muscle.frame)
    }

    /// Ice-tinted muscles, lit by the scanner or the sight.
    private func drawScanned(_ muscles: [BodyArt.Muscle], opacity: Double, in context: GraphicsContext) {
        var scanned = context
        scanned.blendMode = .plusLighter
        scanned.opacity = opacity
        scanned.addFilter(.colorMatrix(Self.iceTint))
        for muscle in muscles {
            scanned.draw(Image(muscle.image), in: muscle.frame)
        }
    }

    private func clip(_ context: inout GraphicsContext, to layer: BodyArt.Layer) {
        guard layer.isBand else {
            context.clip(to: Path(layer.window))
            return
        }
        let band = layer.window
        context.clipToLayer { mask in
            mask.fill(Path(band), with: .linearGradient(Self.bandFade, startPoint: CGPoint(x: band.midX, y: band.minY),
                                                       endPoint: CGPoint(x: band.midX, y: band.maxY)))
        }
    }

    /// Clips to the painting's own shape.
    private func clipToBody(_ context: inout GraphicsContext) {
        let art = figure.art
        context.clipToLayer { $0.draw(Image(art.image), in: art.frame) }
    }

    // MARK: Overlays

    /// The zone under a held finger, on the side it points at.
    private func drawAimedZone(in context: GraphicsContext, hairline: CGFloat) {
        guard let aim, let zone = aimedZone else { return }
        let side = side(at: aim)
        for layer in figure.art.layers where layer.zone == zone && BodyFigure.lights(layer.side, for: side) {
            var part = context
            clip(&part, to: layer)
            drawScanned([layer.muscle], opacity: 1, in: part)
        }
    }

    private func drawHotspots(marks: [BodyZone: BodyLimitation], time: Double?, hairline: CGFloat, in context: GraphicsContext) {
        let radius = 4.5 * hairline
        for spot in figure.hotspots where focus == nil || focus == spot.zone {
            let lit = marks[spot.zone].map { BodyFigure.lights(spot.side, for: $0.side) } ?? false
            if lit {
                if let time {
                    let phase = time.truncatingRemainder(dividingBy: Self.pulsePeriod) / Self.pulsePeriod
                    context.stroke(circle(spot.point, radius: radius + phase * 14 * hairline),
                                   with: .color(FelixTheme.ice.opacity(0.8 * (1 - phase))), lineWidth: hairline * 1.2)
                }
                var glow = context
                glow.addFilter(.blur(radius: 4 * hairline))
                glow.fill(circle(spot.point, radius: radius * 2), with: .color(FelixTheme.cobalt))
                context.fill(circle(spot.point, radius: radius * 1.1), with: .color(.white))
                context.stroke(circle(spot.point, radius: radius * 1.1), with: .color(FelixTheme.ice), lineWidth: hairline * 1.5)
            } else if focus == nil {
                context.fill(circle(spot.point, radius: radius), with: .color(.black.opacity(0.4)))
                context.stroke(circle(spot.point, radius: radius), with: .color(.white.opacity(isClear ? 0.9 : 0.6)),
                               lineWidth: hairline * 1.2)
                context.fill(circle(spot.point, radius: radius * 0.35), with: .color(.white.opacity(0.9)))
            }
        }
    }

    /// A slow scanner beam over the body; on a painting it shows the muscles it passes.
    private func drawScan(at time: Double, hairline: CGFloat, in context: GraphicsContext) {
        let progress = time.truncatingRemainder(dividingBy: Self.scanPeriod) / Self.scanPeriod
        drawBeam(at: progress * BodyFigure.size.height, strength: 0.4, height: 40, hairline: hairline, in: context)
    }

    private func drawBeam(at y: Double, strength: Double, height: Double, hairline: CGFloat, in context: GraphicsContext) {
        let art = figure.art
        let revealed = CGRect(x: art.frame.minX, y: y - height, width: art.frame.width, height: height * 2)
        var reveal = context
        reveal.clipToLayer { mask in
            mask.fill(Path(revealed), with: .linearGradient(Self.bandFade, startPoint: CGPoint(x: 0, y: revealed.minY),
                                                           endPoint: CGPoint(x: 0, y: revealed.maxY)))
        }
        drawScanned(art.muscles.filter { $0.frame.intersects(revealed) }, opacity: min(strength * 1.6, 1), in: reveal)
        let band = CGRect(x: -60, y: y - height / 2, width: BodyFigure.size.width + 120, height: height)
        var beam = context
        clipToBody(&beam)
        beam.blendMode = .plusLighter
        beam.fill(Path(band), with: .linearGradient(Gradient(colors: [.clear, FelixTheme.ice.opacity(strength), .clear]),
                                                   startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)))
        beam.fill(Path(CGRect(x: band.minX, y: y - hairline / 2, width: band.width, height: hairline)),
                  with: .color(FelixTheme.ice.opacity(strength * 1.5)))
    }

    private func drawPing(_ ping: BodyMapPing, now: Date, marks: [BodyZone: BodyLimitation], hairline: CGFloat,
                          in context: GraphicsContext) {
        let progress = now.timeIntervalSince(ping.start) / Self.pingDuration
        guard (0..<1).contains(progress) else { return }
        guard let zone = ping.zone else {
            // "No limitations": one bright pass over the whole body.
            drawBeam(at: progress * BodyFigure.size.height, strength: 0.95 * (1 - progress * 0.5), height: 80,
                     hairline: hairline, in: context)
            return
        }
        let side = marks[zone]?.side ?? .both
        for layer in figure.art.layers where layer.zone == zone && BodyFigure.lights(layer.side, for: side) {
            var part = context
            clip(&part, to: layer)
            drawScanned([layer.muscle], opacity: 1 - progress, in: part)
        }
        for spot in figure.hotspots where spot.zone == zone && BodyFigure.lights(spot.side, for: side) {
            context.stroke(circle(spot.point, radius: (8 + progress * 30) * hairline),
                           with: .color(FelixTheme.ice.opacity(0.9 * (1 - progress))), lineWidth: hairline * 1.5)
        }
    }

    private func drawSideMarks(in context: GraphicsContext) {
        // From the front the person's left is on the viewer's right.
        let leading = figure.facing == .back ? "Л" : "П"
        let trailing = figure.facing == .back ? "П" : "Л"
        for (text, x) in [(leading, 56.0), (trailing, BodyFigure.size.width - 56)] {
            context.draw(Text(text).font(.caption2.weight(.semibold)).foregroundStyle(FelixTheme.tertiary),
                         at: CGPoint(x: x, y: 16))
        }
    }

    /// A sight closing in on the tapped point, with the name of the zone above it. Drawn in screen points.
    private func drawReticle(at point: CGPoint, zone: BodyZone?, progress: Double, bounds: CGRect, in context: GraphicsContext) {
        let color = zone == nil ? Color.white.opacity(0.55) : FelixTheme.ice
        let eased = 1 - pow(1 - progress, 3)
        let radius: CGFloat = 18 + 16 * (1 - eased)
        context.stroke(circle(point, radius: radius), with: .color(color), lineWidth: 1.5)
        context.fill(circle(point, radius: 2.5), with: .color(color))
        for angle in stride(from: 0.0, to: 360, by: 90) {
            let direction = CGPoint(x: cos(angle * .pi / 180), y: sin(angle * .pi / 180))
            var tick = Path()
            tick.move(to: CGPoint(x: point.x + direction.x * (radius - 5), y: point.y + direction.y * (radius - 5)))
            tick.addLine(to: CGPoint(x: point.x + direction.x * (radius + 5), y: point.y + direction.y * (radius + 5)))
            context.stroke(tick, with: .color(color), lineWidth: 1.5)
        }
        guard let zone else { return }
        let label = context.resolve(Text(zone.title).font(.footnote.weight(.semibold)).foregroundStyle(.white))
        let size = label.measure(in: CGSize(width: 220, height: 40))
        let width = size.width + 24
        let height = size.height + 12
        // Above the finger, kept inside the canvas.
        let x = min(max(point.x - width / 2, bounds.minX + 4), bounds.maxX - width - 4)
        let pill = CGRect(x: x, y: max(point.y - radius - 14 - height, bounds.minY + 4), width: width, height: height)
        let shape = Path(roundedRect: pill, cornerRadius: height / 2)
        var shadow = context
        shadow.addFilter(.blur(radius: 10))
        shadow.fill(shape, with: .color(FelixTheme.cobalt.opacity(0.8)))
        context.fill(shape, with: .color(FelixTheme.cobalt.opacity(0.92)))
        context.stroke(shape, with: .color(FelixTheme.ice.opacity(0.7)), lineWidth: 1)
        context.draw(label, at: CGPoint(x: pill.midX, y: pill.midY))
    }

    private func circle(_ center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    // MARK: Colours

    private static let pain = Color(red: 1, green: 0.27, blue: 0.2)
    private static let painLight = Color(red: 1, green: 0.62, blue: 0.5)

    private static let bandFade = Gradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.3),
                                                   .init(color: .white, location: 0.7), .init(color: .clear, location: 1)])

    /// Maps the red muscle texture to its brightness in ice blue.
    static let iceTint: ColorMatrix = {
        var matrix = ColorMatrix()
        let boost: Float = 1.7
        let weights: (r: Float, g: Float, b: Float) = (0.3, 0.59, 0.11)
        let ice: (r: Float, g: Float, b: Float) = (0.64, 0.74, 1)
        (matrix.r1, matrix.r2, matrix.r3) = (weights.r * ice.r * boost, weights.g * ice.r * boost, weights.b * ice.r * boost)
        (matrix.g1, matrix.g2, matrix.g3) = (weights.r * ice.g * boost, weights.g * ice.g * boost, weights.b * ice.g * boost)
        (matrix.b1, matrix.b2, matrix.b3) = (weights.r * ice.b * boost, weights.g * ice.b * boost, weights.b * ice.b * boost)
        return matrix
    }()
}
