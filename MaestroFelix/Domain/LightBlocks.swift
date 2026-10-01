import Foundation

extension WorkoutPlanner {
    /// The light blocks that still hold an exercise once the zones the person marked are kept out. A block that
    /// comes up empty would start a workout with nothing in it, so it is never offered.
    static func playableBlocks(for profile: OnboardingDraft, logs: [WorkoutLog] = []) -> [LightBlock] {
        LightBlock.allCases.filter { !light($0, for: profile, logs: logs).exercises.isEmpty }
    }
}
