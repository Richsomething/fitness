import SwiftUI

/// Horizontal ruler with snapping ticks and a large live readout.
struct RulerPicker: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let accessibilityName: String
    var majorEvery = 10
    var emphasisEvery = 5
    var tickSpacing: CGFloat = 9
    var readoutScale: CGFloat = 1
    /// When set, the title and the readout share one row above the ruler, which saves height.
    var title: String?
    /// Inset for the title row when the ruler itself runs edge to edge.
    var titleInset: CGFloat = 0
    let valueText: (Double) -> String
    let tickText: (Double) -> String

    @State private var position: Int?
    @ScaledMetric(relativeTo: .largeTitle) private var readoutSize: CGFloat = 60

    private var count: Int { Int(((range.upperBound - range.lowerBound) / step).rounded()) + 1 }
    private var shown: Double { position.map(number(at:)) ?? min(max(value, range.lowerBound), range.upperBound) }

    private func index(of number: Double) -> Int {
        min(max(Int(((number - range.lowerBound) / step).rounded()), 0), count - 1)
    }

    private func number(at index: Int) -> Double { range.lowerBound + Double(index) * step }

    var body: some View {
        VStack(spacing: title == nil ? 14 : 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let title {
                    Eyebrow(title)
                    Spacer(minLength: 8)
                }
                Text(valueText(shown))
                    .font(.felixNumber(readoutSize * readoutScale))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: shown))
                    .animation(.snappy(duration: 0.18), value: shown)
                if !unit.isEmpty {
                    Text(unit).font(.title3.weight(.semibold)).foregroundStyle(FelixTheme.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, titleInset)
            ruler
        }
        .onAppear { if position == nil { position = index(of: value) } }
        .task(id: position) {
            // Commit once scrolling settles so each passing tick does not write to storage.
            guard let position else { return }
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            value = number(at: position)
        }
        .sensoryFeedback(.selection, trigger: position)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue("\(valueText(shown)) \(unit)")
        .accessibilityAdjustableAction { direction in
            let current = position ?? index(of: value)
            switch direction {
            case .increment: position = min(count - 1, current + 1)
            case .decrement: position = max(0, current - 1)
            @unknown default: break
            }
        }
    }

    private var ruler: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                HStack(spacing: tickSpacing) {
                    ForEach(0..<count, id: \.self) { index in tick(index) }
                }
                .frame(height: geometry.size.height, alignment: .top)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position)
            // Zero-width ticks plus half-width insets put the selected tick exactly under the needle.
            .safeAreaPadding(.horizontal, geometry.size.width / 2)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(FelixTheme.cobalt)
                    .frame(width: 3, height: 48)
                    .shadow(color: FelixTheme.cobalt.opacity(0.9), radius: 8)
            }
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.22),
                                         .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
        }
        .frame(height: 76)
    }

    private func tick(_ index: Int) -> some View {
        let major = index % majorEvery == 0
        let emphasized = !major && index % emphasisEvery == 0
        return Capsule()
            .fill(Color.white.opacity(major ? 0.75 : emphasized ? 0.4 : 0.2))
            .frame(width: major ? 2 : 1.5, height: major ? 40 : emphasized ? 28 : 18)
            .frame(width: 0, height: 40, alignment: .top)
            .overlay(alignment: .top) {
                if major {
                    Text(tickText(number(at: index)))
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(FelixTheme.secondary)
                        .fixedSize()
                        .offset(y: 52)
                }
            }
    }
}

/// Wraps children onto new lines, like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if origin.x > 0 && origin.x + size.width > maxWidth {
                origin = CGPoint(x: 0, y: origin.y + rowHeight + spacing)
                rowHeight = 0
            }
            width = max(width, origin.x + size.width)
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: origin.y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if origin.x > bounds.minX && origin.x + size.width > bounds.maxX {
                origin = CGPoint(x: bounds.minX, y: origin.y + rowHeight + spacing)
                rowHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct FelixChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : FelixTheme.text.opacity(0.82))
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(Capsule().fill(selected ? FelixTheme.cobalt : FelixTheme.surfaceStrong))
                .overlay(Capsule().strokeBorder(Color.white.opacity(selected ? 0.3 : 0.06), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Read-only week: lit blocks for training days, an outline around `emphasized`.
struct WeekBlocks: View {
    let selected: Set<Int>
    var emphasized: Int?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let on = selected.contains(day)
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on ? AnyShapeStyle(LinearGradient(colors: [FelixTheme.cobalt, FelixTheme.cobaltDeep], startPoint: .top, endPoint: .bottom))
                                 : AnyShapeStyle(Color.white.opacity(0.07)))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(day == emphasized ? 0.9 : 0), lineWidth: 1.5))
                        .frame(height: 34)
                        .shadow(color: on ? FelixTheme.cobalt.opacity(0.5) : .clear, radius: 8)
                    Text(OnboardingDraft.weekdayNames[day - 1])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(on ? FelixTheme.text : FelixTheme.tertiary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selected.isEmpty ? "Дни не выбраны"
                            : selected.sorted().map { OnboardingDraft.fullWeekdayNames[$0 - 1] }.joined(separator: ", "))
    }
}

/// A 1–5 self-rating as depth: a track from white (on the surface) to deep navy (deep), with a glass
/// lens that follows the finger and settles on a level, the number sharp on the lens. No lens means
/// no rating; "Сбросить" returns to it.
struct DiscomfortScale: View {
    @Binding var level: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragPosition: Double?

    private let names = ["Едва заметный", "Слабый", "Умеренный", "Сильный", "Очень сильный"]
    private static let depth: [Color] = [.white, Color(red: 0.8, green: 0.86, blue: 1), FelixTheme.ice, FelixTheme.cobalt,
                                         FelixTheme.cobaltDeep, Color(red: 0.03, green: 0.05, blue: 0.16)]
    private static let trackHeight: CGFloat = 58
    private static let lensWidth: CGFloat = 60

    /// Lens place along the track, 0...1.
    private var position: Double? { dragPosition ?? level.map { Double($0 - 1) / 4 } }
    private var liveLevel: Int? { position.map { Int(($0 * 4).rounded()) + 1 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            track
            HStack {
                Text("Поверхностно")
                Spacer()
                Text("Глубоко")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(FelixTheme.tertiary)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: level)
        .sensoryFeedback(.selection, trigger: liveLevel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Дискомфорт сейчас")
        .accessibilityValue(level.map { "\($0) из 5, \(names[$0 - 1])" } ?? "Не оцениваю")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: level = min(5, (level ?? 0) + 1)
            case .decrement: level = (level ?? 1) <= 1 ? nil : (level ?? 1) - 1
            @unknown default: break
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(liveLevel.map(String.init) ?? "—")
                .font(.felixNumber(44))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(liveLevel ?? 0)))
            Text(liveLevel.map { names[$0 - 1] } ?? "Не оцениваю")
                .font(.headline)
                .foregroundStyle(FelixTheme.secondary)
                .contentTransition(.opacity)
            Spacer(minLength: 8)
            if level != nil {
                Button("Сбросить") { level = nil }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FelixTheme.ice)
                    .frame(minHeight: 44)
                    .transition(.opacity)
            }
        }
    }

    private var track: some View {
        GeometryReader { geometry in
            let travel = geometry.size.width - Self.lensWidth
            let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
            ZStack(alignment: .leading) {
                shape
                    .fill(LinearGradient(colors: Self.depth, startPoint: .leading, endPoint: .trailing))
                    .overlay(shape.strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                    .padding(.vertical, 6)
                ForEach(1...5, id: \.self) { mark in
                    let place = Double(mark - 1) / 4
                    Text("\(mark)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(place < 0.3 ? Color.black.opacity(0.55) : Color.white.opacity(0.75))
                        .frame(width: Self.lensWidth)
                        // Gives way to the enlarged number as the lens passes over it.
                        .opacity(position.map { min(abs(place - $0) * travel / (Self.lensWidth * 0.7), 1) } ?? 1)
                        .offset(x: travel * place)
                }
                if let position {
                    lens(position: position)
                        .offset(x: travel * position)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let target = min(max((drag.location.x - Self.lensWidth / 2) / max(travel, 1), 0), 1)
                    // A tap glides the lens over; a drag tracks the finger directly.
                    if abs(drag.translation.width) < 2 {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { dragPosition = target }
                    } else {
                        dragPosition = target
                    }
                }
                .onEnded { _ in
                    let settled = liveLevel
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75)) {
                        level = settled
                        dragPosition = nil
                    }
                })
        }
        .frame(height: Self.trackHeight)
    }

    private func lens(position: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Color.clear
            .frame(width: Self.lensWidth, height: Self.trackHeight)
            .felixGlass(in: shape, clear: true)
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.3)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
            .overlay {
                Text(liveLevel.map(String.init) ?? "")
                    .font(.felixNumber(24, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(position < 0.3 ? Color.black.opacity(0.75) : Color.white)
                    .contentTransition(.numericText(value: Double(liveLevel ?? 0)))
            }
            .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
    }
}

/// Open 270° gauge with a cobalt value arc.
struct ArcGauge: View {
    let progress: Double
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: 0.75 * min(max(progress, 0), 1))
                .stroke(LinearGradient(colors: [FelixTheme.ice, FelixTheme.cobalt], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .shadow(color: FelixTheme.cobalt.opacity(0.6), radius: 8)
        }
        .rotationEffect(.degrees(135))
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }
}
