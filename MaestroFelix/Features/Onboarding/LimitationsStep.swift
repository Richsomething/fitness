import SwiftUI

/// Limitations step as a body scan: a figure that lights up marked zones next to the list of zones.
/// Tapping a zone on either marks it and opens its editor; closing the editor pings the zone.
struct LimitationsStep: View {
    @Bindable var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var editedZone: BodyZone?
    @State private var lastEditedZone: BodyZone?
    @State private var zonePendingRemoval: BodyZone?
    @State private var ping: BodyMapPing?
    @State private var facing = BodyFigure.Facing.front

        private var limitations: [BodyLimitation] { model.draft.limitations }
    private var isClear: Bool { model.draft.limitationsReviewed && limitations.isEmpty }
    private var build: BodyFigure.Build { BodyFigure.Build(model.draft.gender) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OptionCard(title: "Нет ограничений", detail: "Травм и болевых зон сейчас нет", icon: "checkmark.shield.fill",
                       selected: isClear, action: markClear)
                .entrance(2)
            scanner
                .entrance(3)
            // Why it is asked and where it stays: health information needs a reason and a place.
            Text("Это твоя оценка, не диагноз. Отметки остаются на iPhone.")
                .font(.footnote)
                .foregroundStyle(FelixTheme.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .entrance(4)
        }
        .sensoryFeedback(.selection, trigger: limitations.count)
        .sensoryFeedback(.success, trigger: isClear) { _, clear in clear }
        .sheet(item: $editedZone, onDismiss: finishEditing) { zone in editor(zone) }
    }

    // MARK: Scanner

    private var scanner: some View {
        let marked = limitations.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Eyebrow(facing == .front ? "Карта тела · вид спереди" : "Карта тела · вид со спины", color: FelixTheme.ice)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
                Text("Отмечено \(marked) из \(BodyZone.allCases.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(marked > 0 ? FelixTheme.ice : FelixTheme.tertiary)
                    .contentTransition(.numericText(value: Double(marked)))
                    .accessibilityLabel("Отмечено зон: \(marked) из \(BodyZone.allCases.count)")
            }
            // At accessibility text sizes the figure gives way to a plain list of every zone.
            if dynamicTypeSize.isAccessibilitySize {
                zoneList(BodyZone.allCases)
            } else {
                BodyScanStage(limitations: limitations, build: build, facing: $facing, isClear: isClear, ping: ping, onSelect: open)
                if marked > 0 { zoneList(markedZones) }
            }
            status
        }
        .padding(16)
        .background(CardSurface(radius: 28))
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: limitations)
    }

    private var markedZones: [BodyZone] {
        BodyZone.allCases.filter { zone in limitations.contains { $0.zone == zone } }
    }

    private func zoneList(_ zones: [BodyZone]) -> some View {
        VStack(spacing: 8) {
            ForEach(zones) { zone in zoneRow(zone) }
        }
    }

    /// Full-width row: the whole zone name and what was recorded, so nothing has to be squeezed.
    private func zoneRow(_ zone: BodyZone) -> some View {
        let limitation = limitations.first { $0.zone == zone }
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button { open(zone) } label: {
            HStack(spacing: 14) {
                Image(systemName: limitation?.kind.symbol ?? "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(limitation == nil ? FelixTheme.secondary : Color.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(limitation == nil ? Color.white.opacity(0.08) : FelixTheme.cobalt))
                VStack(alignment: .leading, spacing: 3) {
                    Text(zone.title)
                        .font(.headline)
                    Text(limitation?.summary ?? "Не отмечено")
                        .font(.footnote)
                        .foregroundStyle(limitation == nil ? FelixTheme.tertiary : FelixTheme.ice)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FelixTheme.tertiary)
            }
            .foregroundStyle(FelixTheme.text)
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(limitation == nil ? Color.white.opacity(0.04) : FelixTheme.cobalt.opacity(0.16)))
            .overlay(shape.strokeBorder(limitation == nil ? Color.white.opacity(0.06) : FelixTheme.cobalt.opacity(0.6), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Открывает параметры ограничения")
    }

    private var status: some View {
        let count = limitations.count
        let (icon, text): (String, String) = if count > 0 {
            ("scope", "Учтём \(count) \(RussianPlural.form(count, one: "зону", few: "зоны", many: "зон")) при подборе упражнений")
        } else if isClear {
            ("checkmark.shield.fill", "Ограничений нет — подбор без поправок")
        } else {
            ("hand.tap.fill", "Коснись зоны на схеме или в списке")
        }
        return Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).contentTransition(.symbolEffect(.replace))
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(count > 0 || isClear ? FelixTheme.ice : FelixTheme.secondary)
    }

    // MARK: Actions

    private func open(_ zone: BodyZone) {
        if !limitations.contains(where: { $0.zone == zone }) { model.toggleZone(zone) }
        lastEditedZone = zone
        editedZone = zone
    }

    private func markClear() {
        model.draft.limitations = []
        model.draft.limitationsReviewed = true
        ping = BodyMapPing(zone: nil, start: .now)
    }

    private func finishEditing() {
        if let zone = zonePendingRemoval {
            zonePendingRemoval = nil
            withAnimation(reduceMotion ? nil : .smooth) { model.toggleZone(zone) }
        } else if let zone = lastEditedZone {
            ping = BodyMapPing(zone: zone, start: .now)
        }
    }

    /// The side of the anatomy figure that shows `zone`, preferring the one on screen.
    private func closeUp(of zone: BodyZone) -> BodyFigure {
        let current = BodyFigure.anatomy(facing: facing, build: build)
        return current.shows(zone) ? current : BodyFigure.anatomy(facing: facing.flipped, build: build)
    }

    @ViewBuilder private func editor(_ zone: BodyZone) -> some View {
        if let index = limitations.firstIndex(where: { $0.zone == zone }) {
            LimitationEditorSheet(zone: zone, figure: closeUp(of: zone), limitation: $model.draft.limitations[index]) {
                editedZone = nil
            } onRemove: {
                // Remove after the sheet closes so its binding never points at a deleted row.
                zonePendingRemoval = zone
                editedZone = nil
            }
        }
    }
}

private extension BodyLimitation {
    /// What was recorded, in words, e.g. "Травма в прошлом · слева · дискомфорт 3 из 5".
    var summary: String {
        let sideText: String? = switch side {
        case .unspecified: nil
        case .left: "слева"
        case .right: "справа"
        case .both: "с обеих сторон"
        }
        let levelText = discomfortLevel.map { "дискомфорт \($0) из 5" }
        return [kind.title, sideText, levelText].compactMap { $0 }.joined(separator: " · ")
    }
}

private extension LimitationKind {
    var symbol: String {
        switch self {
        case .pastInjury: "bandage.fill"
        case .currentDiscomfort: "bolt.fill"
        case .movementRestriction: "figure.flexibility"
        }
    }
}

// MARK: - Limitation editor

private struct LimitationEditorSheet: View {
    let zone: BodyZone
    let figure: BodyFigure
    @Binding var limitation: BodyLimitation
    let onDone: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Ограничение", color: FelixTheme.ice)
                        Text(zone.title)
                            .font(.felixTitle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    // Close-up of this zone; it follows the side and discomfort chosen below.
                    BodyMap(limitations: [limitation], figure: figure, focus: zone, animated: false)
                        .frame(width: 70, height: 175)
                }
                section("Что учитывать") {
                    FlowLayout(spacing: 8) {
                        ForEach(LimitationKind.allCases) { kind in
                            FelixChip(title: kind.title, selected: limitation.kind == kind) { limitation.kind = kind }
                        }
                    }
                }
                section("Сторона") {
                    FlowLayout(spacing: 8) {
                        ForEach(BodySide.allCases) { side in
                            FelixChip(title: side.title, selected: limitation.side == side) { limitation.side = side }
                        }
                    }
                }
                section("Дискомфорт сейчас") {
                    DiscomfortScale(level: $limitation.discomfortLevel)
                }
                VStack(spacing: 6) {
                    FelixPrimaryButton(title: "Готово", systemImage: "checkmark", action: onDone)
                    Button(role: .destructive, action: onRemove) {
                        Text("Убрать ограничение")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .foregroundStyle(FelixTheme.critical)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(FelixTheme.text)
        .sensoryFeedback(.selection, trigger: limitation.kind)
        .sensoryFeedback(.selection, trigger: limitation.side)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Color(red: 0.035, green: 0.04, blue: 0.07))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(title)
            content()
        }
    }
}
