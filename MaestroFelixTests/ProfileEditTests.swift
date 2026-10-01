import Foundation
import Testing
@testable import MaestroFelix

@MainActor
struct ProfileEditTests {
    @Test("a row edited from the profile is saved by its own button, with no trip through the review")
    func quickEditSavesAndLeaves() throws {
        let h = try Harness.make()
        let model = h.app.onboarding
        model.editFromProfile(.body)
        #expect(model.isEditing && model.savesOnAdvance && model.draft.step == .body)
        model.draft.heightText = "171"
        model.advance()
        #expect(!model.isEditing && !model.savesOnAdvance && !model.showsOnboarding)
        #expect(h.app.profile?.heightText == "171")
    }

    @Test("a quick edit that is not valid is not saved, and says why")
    func invalidQuickEditStays() throws {
        let h = try Harness.make()
        let model = h.app.onboarding
        model.editFromProfile(.schedule)
        model.draft.weekdays = []
        model.advance()
        #expect(model.isEditing && model.validationError != nil)
        #expect(h.app.profile?.weekdays == [1, 3, 5])
    }

    @Test("cancelling puts the draft back, leaves the saved profile alone and forgets the pending draft")
    func cancelRestoresTheProfile() throws {
        let h = try Harness.make()
        let model = h.app.onboarding
        model.edit(.schedule)
        model.draft.weekdays = [2, 4]
        model.cancelEdit()
        #expect(!model.isEditing && !model.showsOnboarding)
        #expect(model.draft == h.app.profile)
        #expect(h.app.profile?.weekdays == [1, 3, 5])
        let reopened = try Harness.reopen(h)
        #expect(!reopened.app.onboarding.showsOnboarding, "the half-made edit is not waiting at the next start")
    }

    @Test("back from a quick edit is a cancel")
    func backFromQuickEditCancels() throws {
        let h = try Harness.make()
        let model = h.app.onboarding
        model.editFromProfile(.body)
        model.draft.heightText = "190"
        model.back()
        #expect(!model.isEditing && h.app.profile?.heightText != "190")
    }

    @Test("an ordinary edit from the review still goes back to the review")
    func editFromReviewStillReturns() throws {
        let h = try Harness.make()
        let model = h.app.onboarding
        model.edit(.schedule)
        #expect(model.returnsToReview && !model.savesOnAdvance)
        model.advance()
        #expect(model.draft.step == .review && model.isEditing)
    }
}
