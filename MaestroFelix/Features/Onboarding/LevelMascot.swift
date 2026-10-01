import SwiftUI
import UIKit

/// The character of a training level, from skinny to bodybuilder (Assets › Levels), in the build of the
/// chosen gender, standing still on the stage. If the level has pose frames (level-N-pose2, -pose3,
/// ...), they follow one another with a soft crossfade. Dimmed until a level is chosen.
///
/// A change of level never shows two half-transparent figures at once, which would let the dark
/// background show through the body: the new figure appears at full opacity and the old one fades out
/// on top of it.
struct LevelMascot: View {
    let level: TrainingExperience
    var build = BodyFigure.Build.male
    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var outgoing: String?
    @State private var outgoingOpacity = 0.0

    static let height: CGFloat = 268
    private static let poseDuration = 1.1

    // Looked up once: the catalog does not change while the app runs.
    private static let maleCast = Dictionary(uniqueKeysWithValues: TrainingExperience.allCases.map { ($0, $0.poseImages(for: .male)) })
    private static let femaleCast = Dictionary(uniqueKeysWithValues: TrainingExperience.allCases.map { ($0, $0.poseImages(for: .female)) })
    private var poses: [String] { (build == .female ? Self.femaleCast : Self.maleCast)[level] ?? [] }

    var body: some View {
        ZStack {
            current
            if let outgoing {
                figure(outgoing).opacity(outgoingOpacity)
            }
        }
        .onChange(of: poses.first) { old, _ in fadeOut(old) }
        .saturation(isActive ? 1 : 0.15)
        .opacity(isActive ? 1 : 0.5)
        .accessibilityHidden(true)
    }

    private func fadeOut(_ image: String?) {
        guard !reduceMotion, let image else { return }
        outgoing = image
        outgoingOpacity = 1
        withAnimation(.easeOut(duration: 0.22)) { outgoingOpacity = 0 } completion: { outgoing = nil }
    }

    @ViewBuilder private var current: some View {
        Group {
            if poses.count > 1 && isActive && !reduceMotion {
                TimelineView(.periodic(from: .now, by: Self.poseDuration)) { timeline in
                    let frame = Int(timeline.date.timeIntervalSinceReferenceDate / Self.poseDuration) % poses.count
                    figure(poses[frame])
                        .id(frame)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: frame)
                }
            } else {
                figure(poses.first ?? "level-1")
            }
        }
    }

    private func figure(_ image: String) -> some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .frame(height: Self.height)
            .shadow(color: FelixTheme.cobalt.opacity(isActive ? 0.3 : 0), radius: 18)
    }
}

extension TrainingExperience {
    /// The character image and any extra pose frames found in the asset catalog.
    func poseImages(for build: BodyFigure.Build) -> [String] {
        let base = (build == .female ? "female-" : "") + "level-\(ladderIndex + 1)"
        let extra = (2...8).map { "\(base)-pose\($0)" }.prefix { UIImage(named: $0) != nil }
        return [base] + extra
    }

    private var ladderIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}
