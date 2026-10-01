import FelixGlass
import SwiftUI

/// Schedule step: training days as glass cells and the start time as the sun's path across the day.
/// Kept short enough for the dial to sit above the step bar on a tall iPhone: the count and the days of rest
/// share one row, and the spacing between the blocks is tight.
struct ScheduleStep: View {
    @Bindable var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let count = model.draft.weekdays.count
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                weekSummary(count: count)
                    .entrance(2)
                TrainingWeekPicker(selected: model.draft.weekdays) { day in
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.68)) { model.toggleDay(day) }
                }
                .entrance(3)
            }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Начало тренировки")
                DayCycleDial(hours: startTime)
            }
            .entrance(5)
        }
    }

    /// The count of trainings in a week, big, and what the rest of the week holds: the days of rest. No label
    /// grades the choice.
    private func weekSummary(count: Int) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text("\(count)")
                .font(.felixNumber(56))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
            VStack(alignment: .leading, spacing: 2) {
                Text(count == 0 ? "Выбери дни в зале" : "\(RussianPlural.trainings(count)) в неделю")
                    .font(.headline)
                Text(count == 0 ? "Отметь дни ниже" : Self.restText(count))
                    .font(.subheadline)
                    .foregroundStyle(FelixTheme.secondary)
            }
            .contentTransition(.opacity)
            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: count)
        .accessibilityElement(children: .combine)
    }

    private static func restText(_ count: Int) -> String {
        let rest = 7 - count
        return rest == 0 ? "Без дней отдыха"
            : "\(rest) \(RussianPlural.form(rest, one: "день", few: "дня", many: "дней")) отдыха"
    }

    private var startTime: Binding<Double> {
        Binding {
            Double(model.draft.startHour) + Double(model.draft.startMinute) / 60
        } set: { hours in
            let minutes = Int((hours * 60).rounded())
            model.draft.startHour = minutes / 60
            model.draft.startMinute = minutes % 60
        }
    }
}

// MARK: - Week

/// Seven glass cells. A training day lights up and rises; neighbouring training days share one glow,
/// so a streak reads as a single charged block.
private struct TrainingWeekPicker: View {
    let selected: Set<Int>
    let toggle: (Int) -> Void

    private let spacing: CGFloat = 6
    private let cellHeight: CGFloat = 88
    private let lift: CGFloat = 6

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...7, id: \.self) { day in cell(day) }
        }
        .padding(.top, lift)
        .background { streakGlow }
        .sensoryFeedback(.impact(weight: .light), trigger: selected)
    }

    private func cell(_ day: Int) -> some View {
        let on = selected.contains(day)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return Button { toggle(day) } label: {
            VStack(spacing: 14) {
                Text(OnboardingDraft.weekdayNames[day - 1])
                    .font(.subheadline.weight(.bold))
                Image(systemName: "dumbbell.fill")
                    .font(.footnote.weight(.bold))
                    .symbolEffect(.bounce, value: on)
                    .scaleEffect(on ? 1 : 0.3)
                    .opacity(on ? 1 : 0)
            }
            .foregroundStyle(on ? Color.white : FelixTheme.secondary)
            .frame(maxWidth: .infinity, minHeight: cellHeight)
            .felixGlass(in: shape, tint: on ? FelixTheme.cobalt.opacity(0.78) : nil)
            .shadow(color: on ? FelixTheme.cobalt.opacity(0.55) : .clear, radius: 12, y: 6)
            .offset(y: on ? -lift : 0)
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(OnboardingDraft.fullWeekdayNames[day - 1])
        .accessibilityValue(on ? "Тренировка" : "Отдых")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Cobalt underglow beneath each run of consecutive training days.
    private var streakGlow: some View {
        GeometryReader { geometry in
            let cell = (geometry.size.width - spacing * 6) / 7
            ForEach(Self.streaks(in: selected), id: \.lowerBound) { run in
                let width = CGFloat(run.count) * cell + CGFloat(run.count - 1) * spacing
                Capsule()
                    .fill(FelixTheme.cobalt)
                    .frame(width: width, height: 28)
                    .blur(radius: 16)
                    .position(x: CGFloat(run.lowerBound - 1) * (cell + spacing) + width / 2, y: geometry.size.height - 6)
            }
        }
        .allowsHitTesting(false)
    }

    /// Runs of consecutive ISO weekdays, e.g. {1, 2, 4} → [1...2, 4...4].
    static func streaks(in days: Set<Int>) -> [ClosedRange<Int>] {
        days.sorted().reduce(into: []) { runs, day in
            if let last = runs.last, last.upperBound == day - 1 {
                runs[runs.count - 1] = last.lowerBound...day
            } else {
                runs.append(day...day)
            }
        }
    }
}

// MARK: - Day cycle

/// Start time as the sun's path over one day: the arc runs from the morning horizon on the left to
/// night on the right. Drag the sun along the arc, or nudge by 15 minutes. A drag is written back
/// when it ends, so the steps it passes do not each hit storage.
private struct DayCycleDial: View {
    @Binding var hours: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragHours: Double?
    @State private var isPickingTime = false

    private static let range: ClosedRange<Double> = 5...23.75
    private static let step = 0.25
    private static let maxRadius: CGFloat = 140
    private static let orbSize: CGFloat = 54
    private static let bandWidth: CGFloat = 18
    // Room below the horizon for the nudge buttons.
    private static let belowHorizon: CGFloat = 40
    // How far from the arc a drag may start and still move the sun.
    private static let grabDistance: CGFloat = 44

    private var shown: Double { dragHours ?? Self.clamp(hours) }
    private var fraction: Double { (shown - Self.range.lowerBound) / (Self.range.upperBound - Self.range.lowerBound) }
    private var period: DayPeriod { DayPeriod(hours: shown) }
    // White around midday, deepening to cobalt towards morning and night.
    private var light: Color { Color.white.mix(with: FelixTheme.cobalt, by: min(abs(shown - 13) / 9, 1)) }

    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width / 2 - Self.orbSize / 2 - 4, Self.maxRadius)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height - Self.belowHorizon)
            ZStack {
                dial(center: center, radius: radius)
                nudges(center: center, radius: radius)
            }
        }
        .frame(height: Self.maxRadius + Self.orbSize / 2 + 6 + Self.belowHorizon)
        .sheet(isPresented: $isPickingTime) { TimeWheelSheet(hours: $hours, range: Self.range) }
        .sensoryFeedback(.selection, trigger: shown)
        .sensoryFeedback(.impact(weight: .medium), trigger: period)
    }

    private func dial(center: CGPoint, radius: CGFloat) -> some View {
        let sun = Self.point(at: fraction, center: center, radius: radius)
        return ZStack {
            // Horizon light and the sun's own glow in the sky.
            Ellipse()
                .fill(RadialGradient(colors: [light.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: radius))
                .frame(width: radius * 2.2, height: 90)
                .position(center)
            Circle()
                .fill(light.opacity(0.45))
                .frame(width: 150, height: 150)
                .blur(radius: 44)
                .position(sun)
            track(center: center, radius: radius)
            orb.position(sun)
            Color.clear
                .contentShape(Rectangle())
                .gesture(drag(center: center, radius: radius))
            readout.position(x: center.x, y: center.y - 44)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Начало тренировки")
        .accessibilityValue("\(Self.clockText(shown)), \(period.title)")
        .accessibilityAction(named: "Ввести время") { isPickingTime = true }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(Self.step)
            case .decrement: nudge(-Self.step)
            @unknown default: break
            }
        }
    }

    /// A clear glass tube along the arc with a glowing filament filled up to the sun.
    private func track(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            Color.clear
                .felixGlass(in: SkyArc(lineWidth: Self.bandWidth, reference: Self.bandWidth), interactive: false, clear: true)
            SkyArc(progress: fraction, lineWidth: 7, reference: Self.bandWidth)
                .fill(LinearGradient(colors: [FelixTheme.ice, FelixTheme.cobalt], startPoint: .leading, endPoint: .trailing))
                .shadow(color: FelixTheme.cobalt.opacity(0.9), radius: 8)
        }
        .frame(width: radius * 2 + Self.bandWidth, height: radius + Self.bandWidth)
        .position(x: center.x, y: center.y - radius / 2)
        .allowsHitTesting(false)
    }

    /// The time in big digits; a tap on them opens the ordinary wheel for an exact time.
    private var readout: some View {
        Button { isPickingTime = true } label: {
            VStack(spacing: 2) {
                Eyebrow(period.title, color: FelixTheme.ice)
                HStack(spacing: 8) {
                    Text(Self.clockText(shown))
                        .font(.felixNumber(50))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: shown))
                    Image(systemName: "pencil")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(FelixTheme.tertiary)
                }
            }
            .animation(.snappy(duration: 0.18), value: shown)
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityHidden(true)
    }

    private var orb: some View {
        Image(systemName: period.symbol)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: Self.orbSize, height: Self.orbSize)
            .felixGlass(in: Circle(), interactive: false, tint: light.opacity(0.5))
            .background(Circle().fill(light).blur(radius: 16).opacity(0.85))
            .scaleEffect(dragHours == nil ? 1 : 1.15)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: dragHours == nil)
            .allowsHitTesting(false)
    }

    private func nudges(center: CGPoint, radius: CGFloat) -> some View {
        // Inset from the arc ends so the sun never passes under a button.
        let offset = radius - 58
        return ZStack {
            nudgeButton("minus", label: "На 15 минут раньше", delta: -Self.step, disabled: shown <= Self.range.lowerBound)
                .position(x: center.x - offset, y: center.y + 14)
            Eyebrow("Тяни солнце")
                .position(x: center.x, y: center.y + 14)
                .accessibilityHidden(true)
            nudgeButton("plus", label: "На 15 минут позже", delta: Self.step, disabled: shown >= Self.range.upperBound)
                .position(x: center.x + offset, y: center.y + 14)
        }
    }

    private func nudgeButton(_ symbol: String, label: String, delta: Double, disabled: Bool) -> some View {
        FelixIconButton(systemImage: symbol, label: label) { nudge(delta) }
            .disabled(disabled)
            .opacity(disabled ? 0.4 : 1)
    }

    // MARK: Interaction

    private func drag(center: CGPoint, radius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard Self.isNear(drag.startLocation, center: center, radius: radius) else { return }
                let target = Self.hours(at: drag.location, center: center)
                // A tap glides the sun over; a drag tracks the finger.
                if dragHours == nil && !reduceMotion {
                    withAnimation(.snappy(duration: 0.3)) { dragHours = target }
                } else {
                    dragHours = target
                }
            }
            .onEnded { _ in
                guard let dragHours else { return }
                hours = dragHours
                self.dragHours = nil
            }
    }

    private func nudge(_ delta: Double) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { hours = Self.clamp(shown + delta) }
    }

    // MARK: Geometry

    private static func point(at fraction: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = fraction * .pi
        return CGPoint(x: center.x - radius * cos(angle), y: center.y - radius * sin(angle))
    }

    /// The snapped time under `location`; below the horizon it holds at the nearer end.
    private static func hours(at location: CGPoint, center: CGPoint) -> Double {
        let dx = location.x - center.x
        let raw = atan2(center.y - location.y, -dx)
        let angle = raw >= 0 ? raw : (dx < 0 ? 0 : .pi)
        let value = range.lowerBound + angle / .pi * (range.upperBound - range.lowerBound)
        return clamp((value / step).rounded() * step)
    }

    private static func isNear(_ location: CGPoint, center: CGPoint, radius: CGFloat) -> Bool {
        let distance = hypot(location.x - center.x, location.y - center.y)
        return abs(distance - radius) <= grabDistance && location.y <= center.y + orbSize / 2
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func clockText(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

/// The start time on a plain wheel, for when the sun is too coarse.
private struct TimeWheelSheet: View {
    @Binding var hours: Double
    let range: ClosedRange<Double>
    @Environment(\.dismiss) private var dismiss
    @State private var time = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Начало тренировки", color: FelixTheme.ice)
                Text("Во сколько?").font(.felixHeadline)
            }
            DatePicker("Время начала", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            Text("Можно выбрать время с \(Self.clock(range.lowerBound)) до \(Self.clock(range.upperBound)).")
                .font(.footnote)
                .foregroundStyle(FelixTheme.tertiary)
            FelixPrimaryButton(title: "Готово", systemImage: "checkmark") {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                let picked = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
                hours = min(max(picked, range.lowerBound), range.upperBound)
                dismiss()
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(FelixTheme.text)
        .glassSheet(detents: [.medium])
        .onAppear {
            let minutes = Int((hours * 60).rounded())
            time = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        }
    }

    private static func clock(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

private enum DayPeriod {
    case morning, day, evening, night

    init(hours: Double) {
        switch hours {
        case ..<12: self = .morning
        case ..<17: self = .day
        case ..<22: self = .evening
        default: self = .night
        }
    }

    var title: String {
        switch self {
        case .morning: "Утро"
        case .day: "День"
        case .evening: "Вечер"
        case .night: "Ночь"
        }
    }

    var symbol: String {
        switch self {
        case .morning: "sunrise.fill"
        case .day: "sun.max.fill"
        case .evening: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }
}

/// The upper half of a circle as a stroked band, from the left horizon over the top to the right.
/// `reference` is the widest band drawn in the same frame, so bands of different widths share one arc.
private struct SkyArc: InsettableShape {
    var progress = 1.0
    var lineWidth: CGFloat
    var reference: CGFloat
    var inset: CGFloat = 0

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY - reference / 2)
        var arc = Path()
        arc.addArc(center: center, radius: rect.width / 2 - reference / 2, startAngle: .degrees(180),
                   endAngle: .degrees(180 + 180 * min(max(progress, 0), 1)), clockwise: false)
        return arc.strokedPath(StrokeStyle(lineWidth: max(lineWidth - inset * 2, 0), lineCap: .round))
    }

    func inset(by amount: CGFloat) -> SkyArc {
        var copy = self
        copy.inset += amount
        return copy
    }
}
