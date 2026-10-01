import SwiftUI

/// The coach's core on the opening screen: a slowly turning sphere of neurons, each linked to its
/// nearest neighbours, with signals running along the links, and two tilted orbits with sparks running
/// round it. `energy` (0...1) sets how brightly it glows. Typing charges it: each new letter (a rise of
/// `pulse`) sends a comet into the core from a new side each time, which flashes, and `lit` letters keep
/// that many groups of neurons alight, so the sphere fills with light as the name grows and dims as
/// it is erased. A swipe spins it and it coasts to its own pace; a tap sends a pulse. Reduce Motion holds
/// it still.
struct NeuralCore: View {
    var energy: Double
    var pulse: Int
    var lit = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseStart = Date.distantPast
    /// Comets in flight, one per letter typed; several can fly at once.
    @State private var comets: [Comet] = []

    private struct Comet {
        let start: Date
        /// Where round the core it comes from, in radians; 0 is to the right, going clockwise.
        let angle: Double
        /// How far its path bows to the side, as a share of the distance flown.
        let bend: Double
    }
    /// Turn added by the finger, in radians.
    @State private var spin = 0.0
    @State private var dragStart: Double?
    /// The fling left by the last swipe: when it was let go and how fast it turned, in radians a second.
    @State private var fling: (start: Date, speed: Double)?

    private static let nodeCount = 72
    private static let goldenAngle = 2.399_963
    private static let nodes: [SIMD3<Double>] = (0..<nodeCount).map(node)
    private static let links = makeLinks()
    private static let turnSpeed = 0.22
    private static let tilt = 0.38
    private static let pulseDuration = 0.8
    private static let cometDuration = 0.36
    private static let neuronsPerLetter = 4
    /// The order in which neurons light up, spread over the sphere rather than in a band.
    private static let lightOrder: [Int] = {
        var rank = [Int](repeating: 0, count: nodeCount)
        for (position, node) in (0..<nodeCount).sorted(by: { ($0 * 37) % nodeCount < ($1 * 37) % nodeCount }).enumerated() {
            rank[node] = position
        }
        return rank
    }()
    private static let spinPerPoint = 0.012
    // How quickly a fling slows down, per second.
    private static let friction = 2.2
    /// Orbits: tilt towards the viewer, roll in the picture plane, radius as a share of the sphere, speed.
    private static let orbits: [(incline: Double, roll: Double, radius: Double, speed: Double)] = [
        (0.3, 0.32, 1.3, 0.9), (0.42, -0.45, 1.18, -0.65),
    ]
    // The canvas reaches past the frame so the halo is not cut at its edges.
    // Comets start well outside the sphere, so the canvas reaches that far too.
    private static let bleed: CGFloat = 64
    private static let cometReach = 1.65

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                // Before its start (while a comet is still flying in) a pulse counts as finished.
                let sincePulse = timeline.date.timeIntervalSince(pulseStart)
                let pulseProgress = sincePulse < 0 ? 1 : sincePulse / Self.pulseDuration
                let bounds = CGRect(origin: .zero, size: size).insetBy(dx: Self.bleed, dy: Self.bleed)
                draw(in: context, bounds: bounds, time: time, turn: turn(at: timeline.date),
                     pulseProgress: reduceMotion ? 1 : pulseProgress)
                if !reduceMotion {
                    for comet in comets {
                        let progress = timeline.date.timeIntervalSince(comet.start) / Self.cometDuration
                        if (0..<1).contains(progress) { drawComet(comet, in: context, bounds: bounds, progress: progress) }
                    }
                }
            }
            .padding(-Self.bleed)
        }
        .contentShape(Circle())
        .gesture(swipe)
        .onTapGesture { pulseStart = .now }
        .onChange(of: pulse) { old, new in
            guard new > old else {
                pulseStart = .now
                return
            }
            // A new letter: the comet flies in first, and the core flashes as it arrives.
            // Each letter comes from somewhere else: a golden-angle step round the core with some jitter.
            let comet = Comet(start: .now, angle: Double(new) * 2.4 + .random(in: -0.4...0.4), bend: .random(in: -0.35...0.35))
            comets = comets.filter { Date.now.timeIntervalSince($0.start) < Self.cometDuration } + [comet]
            pulseStart = .now.addingTimeInterval(Self.cometDuration)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: pulseStart)
        .accessibilityHidden(true)
    }

    /// The finger's turn plus what is left of the last fling, which slows down exponentially.
    private func turn(at date: Date) -> Double {
        guard let fling, !reduceMotion else { return spin }
        let elapsed = date.timeIntervalSince(fling.start)
        return spin + fling.speed * (1 - exp(-Self.friction * elapsed)) / Self.friction
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { drag in
                if dragStart == nil {
                    // Keep whatever the fling had turned, then take over.
                    spin = turn(at: .now)
                    fling = nil
                    dragStart = spin
                }
                spin = (dragStart ?? 0) + drag.translation.width * Self.spinPerPoint
            }
            .onEnded { drag in
                dragStart = nil
                let speed = (drag.predictedEndTranslation.width - drag.translation.width) * Self.spinPerPoint * Self.friction
                fling = (.now, speed)
            }
    }

    private struct Projected {
        let point: CGPoint
        /// 1 nearest the viewer, 0 furthest away.
        let depth: Double
    }

    private func draw(in context: GraphicsContext, bounds: CGRect, time: Double, turn: Double, pulseProgress: Double) {
        let flash = max(0, 1 - pulseProgress)
        let glow = 0.45 + 0.55 * energy
        let center = CGPoint(x: bounds.midX, y: bounds.midY + sin(time * 1.3) * 4)
        let radius = min(bounds.width, bounds.height) / 2 * 0.86
        drawHeart(in: context, center: center, radius: radius, glow: glow, flash: flash)
        let angle = time * Self.turnSpeed + turn
        let points = Self.nodes.map { project($0, angle: angle, center: center, radius: radius) }
        drawOrbits(in: context, center: center, radius: radius, time: time, glow: glow, front: false)
        drawLinks(points, in: context, time: time, glow: glow)
        drawNodes(points, in: context, time: time, glow: glow, flash: flash,
                  litCount: min(lit * Self.neuronsPerLetter, Self.nodeCount))
        drawOrbits(in: context, center: center, radius: radius, time: time, glow: glow, front: true)
        if flash > 0 {
            let ring = radius * (0.35 + 0.95 * pulseProgress)
            context.stroke(circle(center, radius: ring), with: .color(FelixTheme.ice.opacity(0.8 * flash)), lineWidth: 1.5)
        }
    }

    /// The orbits in two passes: the half behind the sphere before it, the half in front after it.
    private func drawOrbits(in context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, glow: Double,
                            front: Bool) {
        let steps = 72
        for (index, orbit) in Self.orbits.enumerated() {
            let ring = (0...steps).map { step in
                orbitPoint(orbit, at: Double(step) / Double(steps) * 2 * .pi, center: center, radius: radius)
            }
            for step in 0..<steps where (ring[step].depth > 0.5) == front {
                var segment = Path()
                segment.move(to: ring[step].point)
                segment.addLine(to: ring[step + 1].point)
                context.stroke(segment, with: .color(FelixTheme.ice.opacity((0.08 + 0.32 * ring[step].depth) * glow)),
                               lineWidth: 0.6 + 0.8 * ring[step].depth)
            }
            // Two sparks run round each orbit.
            for spark in 0..<2 {
                let phase = time * orbit.speed + Double(spark) * .pi + Double(index)
                let point = orbitPoint(orbit, at: phase, center: center, radius: radius)
                guard (point.depth > 0.5) == front else { continue }
                let size = 1.6 + 2.2 * point.depth
                var halo = context
                halo.addFilter(.blur(radius: 5))
                halo.fill(circle(point.point, radius: size * 3), with: .color(FelixTheme.cobalt.opacity(0.9 * glow)))
                context.fill(circle(point.point, radius: size), with: .color(Color.white.opacity((0.5 + 0.5 * point.depth) * glow)))
            }
        }
    }

    private func orbitPoint(_ orbit: (incline: Double, roll: Double, radius: Double, speed: Double), at angle: Double,
                            center: CGPoint, radius: CGFloat) -> Projected {
        // A circle in the horizontal plane, tipped towards the viewer and rolled in the picture plane.
        let flat = SIMD3(cos(angle), 0, sin(angle)) * orbit.radius
        let tipped = SIMD3(flat.x, flat.y * cos(orbit.incline) - flat.z * sin(orbit.incline),
                           flat.y * sin(orbit.incline) + flat.z * cos(orbit.incline))
        let rolled = SIMD3(tipped.x * cos(orbit.roll) - tipped.y * sin(orbit.roll),
                           tipped.x * sin(orbit.roll) + tipped.y * cos(orbit.roll), tipped.z)
        let perspective = 1 + rolled.z * 0.12
        return Projected(point: CGPoint(x: center.x + rolled.x * radius * perspective, y: center.y + rolled.y * radius * perspective),
                         depth: (rolled.z / orbit.radius + 1) / 2)
    }

    /// A soft halo and a bright centre, so the sphere reads as lit from inside.
    private func drawHeart(in context: GraphicsContext, center: CGPoint, radius: CGFloat, glow: Double, flash: Double) {
        var halo = context
        halo.addFilter(.blur(radius: 30))
        halo.fill(circle(center, radius: radius * 0.95), with: .color(FelixTheme.cobalt.opacity(0.5 * glow + 0.3 * flash)))
        let heart = radius * 0.45
        let colors = [Color.white.opacity(0.85 * glow), FelixTheme.ice.opacity(0.5 * glow), FelixTheme.cobalt.opacity(0)]
        context.fill(circle(center, radius: heart),
                     with: .radialGradient(Gradient(colors: colors), center: center, startRadius: 0, endRadius: heart))
    }

    private func drawLinks(_ points: [Projected], in context: GraphicsContext, time: Double, glow: Double) {
        for (index, link) in Self.links.enumerated() {
            let (a, b) = (points[link.0], points[link.1])
            let depth = (a.depth + b.depth) / 2
            var line = Path()
            line.move(to: a.point)
            line.addLine(to: b.point)
            context.stroke(line, with: .color(FelixTheme.ice.opacity((0.05 + 0.3 * depth) * glow)), lineWidth: 0.4 + 0.7 * depth)
            // Every fourth link carries a signal.
            guard index % 4 == 0, time > 0 else { continue }
            let phase = (time * 0.5 + Double(index) * 0.29).truncatingRemainder(dividingBy: 1)
            let spark = CGPoint(x: a.point.x + (b.point.x - a.point.x) * phase, y: a.point.y + (b.point.y - a.point.y) * phase)
            let fade = sin(phase * .pi) * depth * glow
            context.fill(circle(spark, radius: 1.6), with: .color(Color.white.opacity(0.95 * fade)))
        }
    }

    private func drawNodes(_ points: [Projected], in context: GraphicsContext, time: Double, glow: Double, flash: Double,
                           litCount: Int) {
        for (index, node) in points.enumerated() {
            if Self.lightOrder[index] < litCount {
                drawLitNeuron(node, in: context, time: time, index: index)
                continue
            }
            let twinkle = time > 0 ? 0.7 + 0.3 * sin(time * 2.2 + Double(index)) : 1
            let radius = 0.8 + 1.8 * node.depth
            let brightness = min((0.2 + 0.75 * node.depth) * twinkle * glow + 0.4 * flash * node.depth, 1)
            var halo = context
            halo.addFilter(.blur(radius: 3))
            halo.fill(circle(node.point, radius: radius * 2.2), with: .color(FelixTheme.cobalt.opacity(0.9 * node.depth * glow)))
            context.fill(circle(node.point, radius: radius), with: .color(FelixTheme.ice.opacity(brightness)))
        }
    }

    /// A neuron charged by a letter: white, larger, with a cobalt glow that breathes.
    private func drawLitNeuron(_ node: Projected, in context: GraphicsContext, time: Double, index: Int) {
        let breath = time > 0 ? 0.85 + 0.15 * sin(time * 3 + Double(index)) : 1
        let radius = (1.6 + 2.2 * node.depth) * breath
        var halo = context
        halo.addFilter(.blur(radius: 5))
        halo.fill(circle(node.point, radius: radius * 3), with: .color(FelixTheme.cobalt.opacity(0.5 + 0.5 * node.depth)))
        context.fill(circle(node.point, radius: radius), with: .color(Color.white.opacity(0.55 + 0.45 * node.depth)))
    }

    /// A letter flying into the core from the side it came from, on a bowed path: a bright head with a
    /// fading tail.
    private func drawComet(_ comet: Comet, in context: GraphicsContext, bounds: CGRect, progress: Double) {
        let end = CGPoint(x: bounds.midX, y: bounds.midY)
        let reach = min(bounds.width, bounds.height) / 2 * Self.cometReach
        let start = CGPoint(x: end.x + cos(comet.angle) * reach, y: end.y + sin(comet.angle) * reach)
        // The control point sits beside the middle of the path, so the comet swings in.
        let control = CGPoint(x: (start.x + end.x) / 2 - sin(comet.angle) * reach * comet.bend,
                              y: (start.y + end.y) / 2 + cos(comet.angle) * reach * comet.bend)
        func point(_ t: Double) -> CGPoint {
            let eased = t * t
            let u = 1 - eased
            return CGPoint(x: u * u * start.x + 2 * u * eased * control.x + eased * eased * end.x,
                           y: u * u * start.y + 2 * u * eased * control.y + eased * eased * end.y)
        }
        let head = point(progress)
        let tailStart = max(progress - 0.35, 0)
        var tail = Path()
        tail.move(to: point(tailStart))
        for step in 1...10 {
            tail.addLine(to: point(tailStart + (progress - tailStart) * Double(step) / 10))
        }
        let fadeIn = min(progress / 0.15, 1)
        var glow = context
        glow.addFilter(.blur(radius: 6))
        glow.stroke(tail, with: .color(FelixTheme.cobalt.opacity(0.9 * fadeIn)), lineWidth: 6)
        context.stroke(tail, with: .linearGradient(Gradient(colors: [.clear, FelixTheme.ice.opacity(fadeIn)]),
                                                   startPoint: point(tailStart), endPoint: head),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
        glow.fill(circle(head, radius: 9), with: .color(FelixTheme.cobalt.opacity(fadeIn)))
        context.fill(circle(head, radius: 3.2), with: .color(Color.white.opacity(fadeIn)))
    }

    /// Turns the node around the vertical axis, tilts it towards the viewer and projects it with a
    /// little perspective, so the near side of the sphere is larger.
    private func project(_ node: SIMD3<Double>, angle: Double, center: CGPoint, radius: CGFloat) -> Projected {
        let x = node.x * cos(angle) + node.z * sin(angle)
        let turnedZ = node.z * cos(angle) - node.x * sin(angle)
        let y = node.y * cos(Self.tilt) - turnedZ * sin(Self.tilt)
        let z = node.y * sin(Self.tilt) + turnedZ * cos(Self.tilt)
        let perspective = 1 + z * 0.18
        return Projected(point: CGPoint(x: center.x + x * radius * perspective, y: center.y + y * radius * perspective),
                         depth: (z + 1) / 2)
    }

    private func circle(_ center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    /// A Fibonacci sphere spreads the nodes evenly over the surface.
    private static func node(_ index: Int) -> SIMD3<Double> {
        let y = 1 - (Double(index) + 0.5) / Double(nodeCount) * 2
        let ring = (1 - y * y).squareRoot()
        let theta = Double(index) * goldenAngle
        return SIMD3(cos(theta) * ring, y, sin(theta) * ring)
    }

    /// Each node links to its three nearest neighbours.
    private static func makeLinks() -> [(Int, Int)] {
        var keys = Set<Int>()
        for index in nodes.indices {
            let neighbours = nodes.indices
                .filter { $0 != index }
                .sorted { distance(nodes[$0], nodes[index]) < distance(nodes[$1], nodes[index]) }
                .prefix(3)
            for other in neighbours {
                // One number per pair drops the duplicates.
                keys.insert(min(index, other) * nodeCount + max(index, other))
            }
        }
        return keys.sorted().map { ($0 / nodeCount, $0 % nodeCount) }
    }

    private static func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let difference = a - b
        return (difference * difference).sum()
    }
}
