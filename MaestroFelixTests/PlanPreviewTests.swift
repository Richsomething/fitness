import Foundation
import Testing
@testable import MaestroFelix

@MainActor
struct PlanPreviewTests {
    @Test("the preview names the week's days and the first session, as the plan will really make it")
    func previewNamesWeekAndFirstSession() throws {
        // Wednesday noon, training on Monday, Wednesday and Friday at 18:00.
        let preview = try #require(PlanPreview.make(from: T.profile(weekdays: [1, 3, 5]), now: T.date("2026-09-30", hour: 12),
                                                    calendar: T.calendar))
        #expect(preview.weekdays == [1, 3, 5] && preview.weekdayNames == ["Пн", "Ср", "Пт"])
        let first = try #require(preview.first)
        #expect(first.day == T.day("2026-09-30") && first.hour == 18 && first.minute == 0)
        let real = try #require(WorkoutPlanner.plan(for: T.profile(weekdays: [1, 3, 5]), weekdays: [1, 3, 5],
                                                    on: T.date("2026-09-30", hour: 18), calendar: T.calendar))
        #expect(first.title == real.title && first.exerciseCount == real.exercises.count && first.minutes == real.estimatedMinutes)
    }

    @Test("once today's time has passed, the first session is the next training day")
    func firstSessionMovesOn() throws {
        let preview = try #require(PlanPreview.make(from: T.profile(weekdays: [1, 3, 5]), now: T.date("2026-09-30", hour: 20),
                                                    calendar: T.calendar))
        #expect(preview.first?.day == T.day("2026-10-02"))
    }

    @Test("without training days there is nothing to preview")
    func noDaysNoPreview() {
        var draft = T.profile()
        draft.weekdays = []
        #expect(PlanPreview.make(from: draft, now: T.date("2026-09-30"), calendar: T.calendar) == nil)
    }

    @Test("editing one step ends in a return to the review, and the button says so")
    func editingOneStepReturnsToTheReview() throws {
        let h = try Harness.make()
        let model = h.app.onboarding
        model.edit(.schedule)
        #expect(model.returnsToReview && model.draft.step == .schedule)
        model.advance()
        #expect(model.draft.step == .review && !model.returnsToReview)
        model.edit()
        #expect(!model.returnsToReview, "editing from the start walks all the steps")
    }
}
