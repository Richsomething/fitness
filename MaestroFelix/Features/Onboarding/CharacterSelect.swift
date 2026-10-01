import SwiftUI

/// Character select as a close-up, like a game's character creator: both characters (the athletic
/// ones of the level step) are shown from the waist up, one in front, large and in focus, the other behind it, smaller, dim and soft. Swipe to
/// swap them, or tap the one behind; whoever is in front is the choice. Under the figures two named
/// buttons make the same choice without a gesture, and say which one is made.
struct CharacterSelect: View {
    @Binding var selection: ProfileGender?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turn = Lineup.rest(front: 0)
    @State private var dragStart: Double?

    static let height: CGFloat = 250
    private static let genders: [ProfileGender] = [.female, .male]
    /// Design units of the figure shown, from just above the crown to below the navel.
    private static let shownFrom: CGFloat = -12
    private static let shownTo: CGFloat = 240
    // Radians of turn per point of drag; a swipe across about half the width swaps the figures.
    private static let dragSensitivity = 0.012

    private var frontIndex: Int { Lineup.frontIndex(at: turn) }

    var body: some View {
        VStack(spacing: 14) {
            stage
            GlassSegmented(options: [(ProfileGender.female as ProfileGender?, "Женщина"), (ProfileGender.male as ProfileGender?, "Мужчина")],
                           selection: $selection)
            if selection == nil {
                Text("Смахни в сторону или выбери ниже")
                    .font(.footnote)
                    .foregroundStyle(FelixTheme.tertiary)
            }
        }
        // A choice made below brings that figure to the front.
        .onChange(of: selection) { _, chosen in
            guard let chosen, let index = Self.genders.firstIndex(of: chosen), index != frontIndex else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.8)) {
                turn = Lineup.rest(front: index)
            }
        }
    }

    private var stage: some View {
        GeometryReader { geometry in
            let scale = geometry.size.height / (Self.shownTo - Self.shownFrom)
            ZStack(alignment: .topLeading) {
                ForEach(Self.genders.indices, id: \.self) { index in
                    character(index, scale: scale, width: geometry.size.width)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            // The bodies run out of the frame below the waist.
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.72),
                                       .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .padding(.horizontal, -80)
                    .padding(.top, -40)
            }
            .background { spotlight(width: geometry.size.width, height: geometry.size.height) }
            .contentShape(Rectangle())
            .gesture(drag)
        }
        .frame(height: Self.height)
        .onAppear(perform: alignToSelection)
        .task { await hintTurn() }
        .sensoryFeedback(.selection, trigger: frontIndex)
        .sensoryFeedback(.impact(weight: .medium), trigger: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Персонаж")
        .accessibilityValue(selection?.title ?? "Не выбран")
        .accessibilityHint("Смахни вверх или вниз, чтобы сменить персонажа")
        .accessibilityAdjustableAction { _ in turnToNext() }
    }

    /// A figure in its place in the line-up. The whole body is laid out and the frame shows its top.
    private func character(_ index: Int, scale: CGFloat, width: CGFloat) -> some View {
        let gender = Self.genders[index]
        let place = Lineup.place(of: index, turn: turn, width: width)
        let isChosen = selection == gender && index == frontIndex
        let size = CGSize(width: BodyFigure.size.width * scale, height: BodyFigure.size.height * scale)
        let dim = selection == nil ? 0.8 : 1
        // The athletic character of the level step, so both screens share one cast. The one behind
        // stays opaque and only darkens and softens: a see-through figure would show the background.
        return LevelCharacterPortrait(assetName: gender == .female ? "female-level-3" : "level-3")
            .frame(width: size.width, height: size.height, alignment: .top)
            .scaleEffect(place.scale, anchor: .top)
            .saturation(0.35 + 0.65 * place.depth)
            .brightness(-0.35 * (1 - place.depth))
            .blur(radius: 2.2 * (1 - place.depth))
            .opacity(dim)
            .shadow(color: FelixTheme.cobalt.opacity(isChosen ? 0.35 : 0), radius: 18)
            .overlay(Color.clear.contentShape(Rectangle()).onTapGesture { tap(index) })
            .position(x: width / 2 + place.x, y: size.height / 2 - Self.shownFrom * scale + place.drop)
            .zIndex(place.depth)
    }

    /// Light behind whoever stands in front.
    private func spotlight(width: CGFloat, height: CGFloat) -> some View {
        let front = Lineup.place(of: frontIndex, turn: turn, width: width)
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [FelixTheme.cobalt.opacity(selection == nil ? 0.35 : 0.6), .clear],
                                     center: .center, startRadius: 0, endRadius: height * 0.55))
                .frame(width: height * 1.1, height: height * 1.1)
                .offset(x: front.x, y: -height * 0.05)
            LightTrails(intensity: 0.35)
                .mask(RadialGradient(colors: [.black, .clear], center: .center, startRadius: 20, endRadius: height * 0.7))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Interaction

    private var drag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let start = dragStart ?? turn
                if dragStart == nil { dragStart = turn }
                turn = start + value.translation.width * Self.dragSensitivity
            }
            .onEnded { value in
                let start = dragStart ?? turn
                dragStart = nil
                settle(near: start + value.predictedEndTranslation.width * Self.dragSensitivity)
            }
    }

    private func tap(_ index: Int) {
        if index == frontIndex {
            selection = Self.genders[index]
        } else {
            turnToNext()
        }
    }

    private func turnToNext() {
        settle(near: Lineup.nearestRest(to: turn) + .pi)
    }

    /// Comes to rest at the nearest stop and chooses the figure standing in front there.
    private func settle(near target: Double) {
        let rest = Lineup.nearestRest(to: target)
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.8)) {
            turn = rest
        }
        selection = Self.genders[Lineup.frontIndex(at: rest)]
    }

    private func alignToSelection() {
        guard let selection, let index = Self.genders.firstIndex(of: selection) else { return }
        turn = Lineup.rest(front: index)
    }

    /// Before a choice, the line-up sways once to show that it moves.
    private func hintTurn() async {
        guard selection == nil, !reduceMotion else { return }
        try? await Task.sleep(for: .milliseconds(700))
        guard selection == nil, dragStart == nil else { return }
        let rest = turn
        withAnimation(.easeInOut(duration: 0.4)) { turn = rest + 0.45 }
        try? await Task.sleep(for: .milliseconds(420))
        guard selection == nil, dragStart == nil else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { turn = rest }
    }
}

// MARK: - Line-up

/// The two figures stand on a circle seen from above: figure `index` is at angle `turn + index·π`,
/// angle 0 nearest the viewer. At rest the front figure stands left of centre and the one behind to
/// the right, so both faces show.
enum Lineup {
    struct Place {
        /// Offset from the centre of the frame.
        let x: CGFloat
        /// How far the figure sinks as it moves back, so the one behind looks further away.
        let drop: CGFloat
        /// 1 nearest the viewer, 0 furthest away.
        let depth: Double
        let scale: CGFloat
    }

    static let restOffset = -0.55

    static func place(of index: Int, turn: Double, width: CGFloat) -> Place {
        let angle = turn + Double(index) * .pi
        let depth = (cos(angle) + 1) / 2
        return Place(x: width * 0.3 * sin(angle), drop: 18 * (1 - depth), depth: depth, scale: 0.72 + 0.28 * depth)
    }

    static func rest(front index: Int) -> Double {
        restOffset - Double(index) * .pi
    }

    static func nearestRest(to turn: Double) -> Double {
        restOffset + ((turn - restOffset) / .pi).rounded() * .pi
    }

    static func frontIndex(at turn: Double) -> Int {
        cos(turn) >= cos(turn + .pi) ? 0 : 1
    }
}

// MARK: - Spawn pad

/// Concentric light rings under a figure, like the platform in a character creator. An active pad
/// glows and sends a ring outwards; Reduce Motion keeps it still.
struct SpawnPad: View {
    var isActive = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pulsePeriod = 2.4
    // The canvas reaches past the frame so the glow is not cut at its edges.
    private static let bleed: CGFloat = 24

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !isActive)) { timeline in
            Canvas { context, canvasSize in
                let bounds = CGRect(origin: .zero, size: canvasSize).insetBy(dx: Self.bleed, dy: Self.bleed)
                let size = bounds.size
                var glow = context
                glow.addFilter(.blur(radius: 14))
                glow.fill(Path(ellipseIn: bounds.insetBy(dx: size.width * 0.12, dy: size.height * 0.18)),
                          with: .color(FelixTheme.cobalt.opacity(isActive ? 0.85 : 0.2)))
                for (index, inset) in [0.0, 0.16, 0.32].enumerated() {
                    let ring = bounds.insetBy(dx: size.width * inset, dy: size.height * inset)
                    let color = index == 1 ? FelixTheme.ice : Color.white
                    context.stroke(Path(ellipseIn: ring), with: .color(color.opacity(isActive ? 0.6 - Double(index) * 0.12 : 0.14)),
                                   lineWidth: 1)
                }
                guard isActive, !reduceMotion else { return }
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.pulsePeriod) / Self.pulsePeriod
                let pulse = bounds.insetBy(dx: size.width * 0.34 * (1 - phase), dy: size.height * 0.34 * (1 - phase))
                context.stroke(Path(ellipseIn: pulse), with: .color(FelixTheme.ice.opacity(0.75 * (1 - phase))), lineWidth: 1.5)
            }
            .padding(-Self.bleed)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
