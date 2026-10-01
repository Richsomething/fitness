import SwiftUI

private struct BodyBuildKey: EnvironmentKey {
    static let defaultValue = BodyFigure.Build.male
}

extension EnvironmentValues {
    /// Which of the two painted bodies the person's drawings use, from the character they chose.
    var bodyBuild: BodyFigure.Build {
        get { self[BodyBuildKey.self] }
        set { self[BodyBuildKey.self] = newValue }
    }
}

/// The anatomy drawing with some muscles lit in ice blue. Whole, it shows the figure; cropped, only
/// the region of the lit muscles — which makes a small, distinct picture of what an exercise works.
struct MuscleHighlightView: View {
    let muscles: [String]
    let facing: BodyFigure.Facing
    let build: BodyFigure.Build
    var crop = false

    private static let wholeFigure = CGRect(x: -20, y: 0, width: 240, height: 505)
    private static let cropPadding: CGFloat = 14
    private static let smallestCrop: CGFloat = 100

    var body: some View {
        Canvas { context, size in
            let art = BodyFigure.anatomy(facing: facing, build: build).art
            let lit = muscles.compactMap { name in art.muscles.first { $0.image == "\(art.image)-\(name)" } }
            let view = Self.viewport(of: lit, crop: crop)
            let scale = min(size.width / view.width, size.height / view.height)
            var design = context
            design.translateBy(x: (size.width - view.width * scale) / 2 - view.minX * scale,
                               y: (size.height - view.height * scale) / 2 - view.minY * scale)
            design.scaleBy(x: scale, y: scale)
            var body = design
            body.opacity = lit.isEmpty ? 0.35 : 0.5
            body.draw(Image(art.image), in: art.frame)
            for muscle in lit {
                var glow = design
                glow.blendMode = .plusLighter
                glow.addFilter(.colorMatrix(BodyMap.iceTint))
                glow.draw(Image(muscle.image), in: muscle.frame)
            }
        }
        .accessibilityHidden(true)
    }

    private static func viewport(of lit: [BodyArt.Muscle], crop: Bool) -> CGRect {
        guard crop, let first = lit.first else { return wholeFigure }
        let box = lit.dropFirst().reduce(first.frame) { $0.union($1.frame) }.insetBy(dx: -cropPadding, dy: -cropPadding)
        let side = max(box.width, box.height, smallestCrop)
        return CGRect(x: box.midX - side / 2, y: box.midY - side / 2, width: side, height: side)
    }
}

/// A round badge that says what an exercise trains: the drawing, cropped to the muscles at work.
struct ExerciseBadge: View {
    let exerciseID: String
    var size: CGFloat = 52
    @Environment(\.bodyBuild) private var build

    var body: some View {
        let exercise = ExerciseCatalog.exercise(exerciseID)
        Group {
            if exercise.group == .cardio || exercise.group == .mobility {
                // Cardio and mobility work the whole body, so a cropped muscle says nothing: the movement does.
                Image(systemName: exercise.symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(FelixTheme.ice)
                    .frame(width: size, height: size)
                    .background(Circle().fill(FelixTheme.cobalt.opacity(0.22)))
            } else {
                let info = ExerciseCatalog.info(exerciseID)
                let facing: BodyFigure.Facing = info.front.count >= info.back.count ? .front : .back
                MuscleHighlightView(muscles: facing == .front ? info.front : info.back, facing: facing, build: build, crop: true)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// The whole drawing with the muscles of an exercise lit, on the side where most of them are. It fills
/// the room above the input of a set with what is being trained.
struct ExerciseFigure: View {
    let exerciseID: String
    var height: CGFloat = 200
    @Environment(\.bodyBuild) private var build

    var body: some View {
        let info = ExerciseCatalog.info(exerciseID)
        let facing: BodyFigure.Facing = info.front.count >= info.back.count ? .front : .back
        VStack(spacing: 6) {
            MuscleHighlightView(muscles: facing == .front ? info.front : info.back, facing: facing, build: build)
                .frame(height: height)
            Text(MuscleNames.list(facing == .front ? info.front : info.back))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FelixTheme.ice)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Работают мышцы: \(MuscleNames.list(info.front + info.back))")
    }
}

/// Russian names of the muscles on the drawings.
enum MuscleNames {
    static func title(_ name: String) -> String {
        names[name] ?? name
    }

    /// "Грудь, Трицепс, Плечи": the names once each, in the order given.
    static func list(_ muscles: [String]) -> String {
        var seen = Set<String>()
        return muscles.map(title).filter { seen.insert($0).inserted }.joined(separator: ", ")
    }

    private static let names = [
        "chest": "Грудь", "shoulders": "Плечи", "biceps": "Бицепс", "triceps": "Трицепс", "forearms": "Предплечья",
        "abs": "Пресс", "serratus": "Зубчатые", "lats": "Широчайшие", "obliques": "Косые мышцы живота",
        "hip-flexors": "Сгибатели бедра", "hips": "Таз", "adductors": "Приводящие", "quadriceps": "Квадрицепс",
        "calves": "Икры", "shins": "Голени", "neck-trapezius": "Шея и трапеции", "neck": "Шея", "trapezius": "Трапеции",
        "rear-shoulders": "Задние дельты", "infraspinatus": "Подостная", "teres-major": "Большая круглая",
        "erector-spinae": "Разгибатели спины", "gluteus-medius": "Средняя ягодичная", "gluteus-maximus": "Большая ягодичная",
        "hamstrings": "Задняя поверхность бедра", "soleus": "Камбаловидная", "achilles-tendons": "Ахиллы",
    ]
}
