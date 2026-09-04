import Foundation
import Testing
@testable import RPGFitMVP

struct ActiveSessionTimingRegressionTests {
    @Test func explicitPauseIsExcludedFromElapsedTrainingTime() throws {
        let start = Date(timeIntervalSinceReferenceDate: 10_000)
        var draft = ActiveSessionDraft(startedAt: start)

        #expect(draft.activeDuration(at: start.addingTimeInterval(60)) == 60)

        draft.pause(at: start.addingTimeInterval(60))
        #expect(draft.activeDuration(at: start.addingTimeInterval(3_600)) == 60)

        draft.resume(at: start.addingTimeInterval(3_600))
        #expect(draft.activeDuration(at: start.addingTimeInterval(3_630)) == 90)

        draft.pause(at: start.addingTimeInterval(3_660))
        #expect(draft.activeDuration(at: start.addingTimeInterval(7_200)) == 120)
        draft.resume(at: start.addingTimeInterval(7_200))

        let decoded = try JSONDecoder().decode(
            ActiveSessionDraft.self,
            from: JSONEncoder().encode(draft)
        )
        #expect(decoded.activeDuration(at: start.addingTimeInterval(7_230)) == 150)
    }

    @Test func prePauseSchemaDraftStillDecodes() throws {
        let json = """
        {
          "id":"00000000-0000-0000-0000-000000000001",
          "startedAt":0,
          "levelAtStart":1,
          "exercises":[]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ActiveSessionDraft.self, from: json)

        #expect(decoded.pausedAt == nil)
        #expect(decoded.accumulatedPausedDuration == nil)
        #expect(decoded.activeDuration(at: decoded.startedAt.addingTimeInterval(45)) == 45)
    }
}

struct ActiveSessionRepresentativeSetRegressionTests {
    @Test func compoundLiftUsesBestValidOneRMSetInsteadOfMaximumVolume() {
        let exercise = DraftExercise(
            category: .benchPress,
            sets: [
                DraftSet(reps: "20", weight: "50", done: true),
                DraftSet(reps: "5", weight: "100", done: true)
            ]
        )

        let representative = exercise.representativeWorkingSet(units: .kg, bodyweightKg: 80)

        #expect(representative?.reps == "5")
        #expect(representative?.weight == "100")
    }

    @Test func accessoryLiftStillUsesItsVolumeMetric() {
        let exercise = DraftExercise(
            category: .row,
            sets: [
                DraftSet(reps: "20", weight: "50", done: true),
                DraftSet(reps: "5", weight: "100", done: true)
            ]
        )

        let representative = exercise.representativeWorkingSet(units: .kg, bodyweightKg: 80)

        #expect(representative?.reps == "20")
        #expect(representative?.weight == "50")
    }
}

struct UnevenSupersetRestRegressionTests {
    @Test func exhaustedShorterMemberDoesNotBlockLaterRest() {
        var draft = ActiveSessionDraft()
        draft.exercises = [
            DraftExercise(category: .benchPress, sets: [DraftSet(), DraftSet(), DraftSet()]),
            DraftExercise(category: .row, sets: [DraftSet()])
        ]
        draft.supersetWithNext(at: 0)

        draft.exercises[0].sets[0].done = true
        #expect(!draft.shouldRest(afterSetIn: draft.exercises[0].id))

        // The shorter member's final set closes round one even though the
        // longer member still has later rounds remaining.
        draft.exercises[1].sets[0].done = true
        #expect(draft.shouldRest(afterSetIn: draft.exercises[1].id))

        // Once B is exhausted, A becomes the final active member each round.
        draft.exercises[0].sets[1].done = true
        #expect(draft.shouldRest(afterSetIn: draft.exercises[0].id))

        // No recovery countdown is needed after the group's final set.
        draft.exercises[0].sets[2].done = true
        #expect(!draft.shouldRest(afterSetIn: draft.exercises[0].id))
    }

    @Test func checkingLaterMemberFirstWaitsForTheWholeRound() {
        var draft = ActiveSessionDraft()
        draft.exercises = [
            DraftExercise(category: .benchPress, sets: [DraftSet(), DraftSet()]),
            DraftExercise(category: .row, sets: [DraftSet()])
        ]
        draft.supersetWithNext(at: 0)

        draft.exercises[1].sets[0].done = true
        #expect(!draft.shouldRest(afterSetIn: draft.exercises[1].id))

        draft.exercises[0].sets[0].done = true
        #expect(draft.shouldRest(afterSetIn: draft.exercises[0].id))
    }
}
