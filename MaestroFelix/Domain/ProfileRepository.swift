import Foundation

@MainActor
protocol ProfileRepository {
    func loadDraft() throws -> OnboardingDraft?
    func loadProfile() throws -> LocalProfile?
    func saveDraft(_ draft: OnboardingDraft) throws
    /// Forgets the draft that is waiting, as when an edit of a saved profile is given up.
    func discardDraft() throws
    func complete(_ draft: OnboardingDraft, existing: LocalProfile?) throws -> LocalProfile
}
