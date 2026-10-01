import Foundation
import Observation

@MainActor @Observable
final class OnboardingModel {
    var draft: OnboardingDraft
    var profile: LocalProfile?
    var isEditing = false
    var validationError: String?
    var storageError: String?
    /// One step is being edited from the review: "next" goes back there instead of on to the following step.
    private(set) var returnsToReview = false
    /// A single row was edited from the profile: finishing the step saves it and leaves, with no review in between.
    private(set) var savesOnAdvance = false
    private let repository: any ProfileRepository
    /// Called after a profile is saved, so the schedule and the weighings follow it.
    var onProfileSaved: ((LocalProfile) -> Void)?

    init(repository: any ProfileRepository) throws {
        self.repository = repository
        let savedProfile = try repository.loadProfile()
        let pending = try repository.loadDraft()
        profile = savedProfile
        draft = pending ?? savedProfile?.details ?? OnboardingDraft()
        isEditing = savedProfile != nil && pending != nil
    }

    var showsOnboarding: Bool { profile == nil || isEditing }

    func persistDraft() {
        guard showsOnboarding else { return }
        do {
            try repository.saveDraft(draft)
            storageError = nil
        } catch {
            storageError = "Не удалось сохранить изменения на устройстве. Попробуй ещё раз."
        }
    }

    func advance() {
        validationError = draft.validationMessage(for: draft.step)
        guard validationError == nil else { return }
        if draft.step == .review || savesOnAdvance {
            // A row edited on its own is saved as it is, so the whole profile must still be sound.
            if savesOnAdvance {
                validationError = draft.validationMessage(for: .review)
                guard validationError == nil else { return }
            }
            saveProfile()
        } else if returnsToReview {
            draft.step = .review
            returnsToReview = false
            persistDraft()
        } else if let next = OnboardingStep(rawValue: draft.step.rawValue + 1) {
            draft.step = next
            persistDraft()
        }
    }

    private func saveProfile() {
        do {
            let saved = try repository.complete(draft, existing: profile)
            profile = saved
            isEditing = false
            returnsToReview = false
            savesOnAdvance = false
            storageError = nil
            onProfileSaved?(saved)
        } catch {
            storageError = "Профиль пока не сохранён. Попробуй ещё раз."
        }
    }

    func back() {
        // Backing out of a single row is giving the edit up.
        if savesOnAdvance {
            cancelEdit()
            return
        }
        if returnsToReview {
            draft.step = .review
            returnsToReview = false
            validationError = nil
            persistDraft()
            return
        }
        guard let previous = OnboardingStep(rawValue: draft.step.rawValue - 1) else { return }
        draft.step = previous
        validationError = nil
        persistDraft()
    }

    /// Jumps to a step from the stepper. Back is always allowed; forward walks through the steps in
    /// between and stops at the first one that is not complete, with its explanation.
    func go(to step: OnboardingStep) {
        guard step != .introduction, step != draft.step else { return }
        returnsToReview = false
        validationError = nil
        if step.rawValue < draft.step.rawValue {
            draft.step = step
        } else {
            while draft.step.rawValue < step.rawValue {
                validationError = draft.validationMessage(for: draft.step)
                guard validationError == nil, let next = OnboardingStep(rawValue: draft.step.rawValue + 1) else { break }
                draft.step = next
            }
        }
        persistDraft()
    }

    /// Changes one row of a saved profile: the step opens on its own and its button saves and leaves.
    func editFromProfile(_ step: OnboardingStep) {
        edit(step)
        savesOnAdvance = step != .introduction
    }

    /// Gives up an edit of a saved profile: the draft goes back to what is saved and the pending one is forgotten.
    func cancelEdit() {
        guard isEditing, let profile else { return }
        draft = profile.details
        isEditing = false
        returnsToReview = false
        savesOnAdvance = false
        validationError = nil
        do {
            try repository.discardDraft()
            storageError = nil
        } catch {
            storageError = "Не удалось убрать черновик правки."
        }
    }

    func edit(_ step: OnboardingStep = .introduction) {
        savesOnAdvance = false
        returnsToReview = step != .introduction
        if !isEditing, let profile { draft = profile.details }
        isEditing = true
        draft.step = step
        validationError = nil
        persistDraft()
    }

    /// A new weighing becomes the profile's current weight. Not while the profile is being edited: the
    /// edit in progress would overwrite it.
    func applyWeight(_ kg: Double) {
        guard !isEditing, let current = profile else { return }
        var details = current.details
        details.weightText = WeightFormat.kg(kg)
        do {
            profile = try repository.complete(details, existing: current)
            storageError = nil
        } catch {
            storageError = "Вес записан, но в профиле не обновился."
        }
    }

    func toggleDay(_ day: Int) {
        if draft.weekdays.contains(day) { draft.weekdays.remove(day) }
        else { draft.weekdays.insert(day) }
    }

    func toggleZone(_ zone: BodyZone) {
        if let index = draft.limitations.firstIndex(where: { $0.zone == zone }) {
            draft.limitations.remove(at: index)
        } else {
            draft.limitations.append(BodyLimitation(zone: zone))
        }
        draft.limitationsReviewed = !draft.limitations.isEmpty
    }
}
