import Foundation
import Testing
@testable import RPGFitMVP

@Suite(.serialized)
struct WorkoutEngineIntegrityTests {
    private func freshState() -> AppState {
        let state = AppState(persistenceEnabled: false)
        state.user = UserProfile()
        state.history = []
        return state
    }

    @Test func heterogeneousSetsUseExactRepsForQuestsAndRebuilds() {
        let state = freshState()
        state.user.dailyChallenges = [
            Challenge(
                id: UUID(),
                type: .daily,
                title: "True reps",
                description: "Regression test",
                targetCategory: .strength,
                targetAmount: 100,
                unit: .reps,
                expReward: 25,
                classType: .warrior,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(3_600),
                completedAt: nil
            )
        ]

        let entry = state.logWorkout(
            name: "",
            category: .benchPress,
            sets: 3,
            reps: 8,
            weight: 60,
            durationMinutes: nil,
            distanceKm: nil,
            performedSets: [
                PerformedSet(reps: 8, weightKg: 60),
                PerformedSet(reps: 6, weightKg: 70),
                PerformedSet(reps: 4, weightKg: 80)
            ]
        )

        #expect(state.user.dailyChallenges[0].progress == 18)

        var renamed = entry
        renamed.name = "Descending bench"
        state.updateWorkout(renamed)

        #expect(state.user.dailyChallenges[0].progress == 18)
        #expect(state.history.first?.performedSets?.count == 3)
    }

    @Test func directPerformanceEditClearsStaleSetRows() {
        let state = freshState()
        let entry = state.logWorkout(
            name: "",
            category: .squat,
            sets: 2,
            reps: 5,
            weight: 100,
            durationMinutes: nil,
            distanceKm: nil,
            performedSets: [
                PerformedSet(reps: 5, weightKg: 90),
                PerformedSet(reps: 5, weightKg: 100)
            ]
        )

        var edited = entry
        edited.reps = 3
        state.updateWorkout(edited)

        #expect(state.history.first?.performedSets == nil)
    }

    @Test func legacyCustomRecordsCannotRepopulateBuiltInPRs() {
        let state = freshState()
        var custom = state.logWorkout(
            name: "Paused Bench",
            category: .benchPress,
            sets: 1,
            reps: 5,
            weight: 100,
            durationMinutes: nil,
            distanceKm: nil,
            customExerciseID: UUID()
        )
        custom.est1RM = 999
        custom.prevBest1RM = 900
        state.history = [custom]
        state.user.best1RM[.benchPress] = 999

        state.updateWorkout(custom)

        #expect(state.history.first?.est1RM == nil)
        #expect(state.history.first?.prevBest1RM == nil)
        #expect(state.user.best1RM[.benchPress] == nil)
    }
}
