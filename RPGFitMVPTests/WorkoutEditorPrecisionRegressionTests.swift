import Foundation
import Testing
@testable import RPGFitMVP

@Suite("Workout editor precision regressions")
struct WorkoutEditorPrecisionRegressionTests {
    private func originalWorkout() -> WorkoutEntry {
        WorkoutEntry(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_700_000_000),
            name: "Bench Press",
            category: .benchPress,
            sets: 2,
            reps: 5,
            weight: 100.04,
            durationMinutes: 12.49,
            distanceKm: 3.456,
            performedSets: [
                PerformedSet(reps: 5, weightKg: 100.04),
                PerformedSet(reps: 5, weightKg: 102.5)
            ],
            statGains: StatBlock(size: 1.25, strength: 2.5),
            expGained: 42.75,
            prevBest1RM: 105,
            est1RM: 116.7,
            totalProgressXP: 77
        )
    }

    @Test func untouchedSavePreservesExactStoredPerformanceAndRewards() throws {
        let state = AppState(persistenceEnabled: false)
        state.user.units = .kg
        let original = originalWorkout()
        let displayed = WorkoutEditFields(workout: original, units: .kg)

        // The editor intentionally presents friendlier, rounded strings.
        #expect(displayed.weight == "100.0")
        #expect(displayed.duration == "12")
        #expect(displayed.distance == "3.46")

        let resolution = EditWorkoutView.resolveWorkoutEdit(
            original,
            name: original.name,
            fields: displayed,
            initialFields: displayed,
            state: state
        )
        let saved = try #require(resolution.workout)

        #expect(resolution.validationMessage == nil)
        #expect(saved.weight == original.weight)
        #expect(saved.durationMinutes == original.durationMinutes)
        #expect(saved.distanceKm == original.distanceKm)
        #expect(saved.performedSets == original.performedSets)
        #expect(saved.statGains == original.statGains)
        #expect(saved.expGained == original.expGained)
        #expect(saved.prevBest1RM == original.prevBest1RM)
        #expect(saved.est1RM == original.est1RM)
        #expect(saved.totalProgressXP == original.totalProgressXP)
    }

    @Test func changingOneFieldPreservesPrecisionOfEveryUntouchedField() throws {
        let state = AppState(persistenceEnabled: false)
        state.user.units = .kg
        let original = originalWorkout()
        state.history = [original]
        let initial = WorkoutEditFields(workout: original, units: .kg)
        var edited = initial
        edited.reps = "6"

        let resolution = EditWorkoutView.resolveWorkoutEdit(
            original,
            name: original.name,
            fields: edited,
            initialFields: initial,
            state: state
        )
        let resolved = try #require(resolution.workout)
        state.updateWorkout(resolved)
        let saved = try #require(state.history.first)

        #expect(saved.reps == 6)
        #expect(saved.weight == original.weight)
        #expect(saved.durationMinutes == original.durationMinutes)
        #expect(saved.distanceKm == original.distanceKm)
        #expect(saved.performedSets == nil)
        #expect(saved.expGained != original.expGained)
        #expect(saved.statGains != original.statGains)
        #expect(saved.est1RM != original.est1RM)
    }

    @Test func changedNonnumericFieldIsRejectedInsteadOfClearingStoredValue() {
        let state = AppState(persistenceEnabled: false)
        let original = originalWorkout()
        let initial = WorkoutEditFields(workout: original, units: .kg)
        var edited = initial
        edited.duration = "twelve"

        let resolution = EditWorkoutView.resolveWorkoutEdit(
            original,
            name: original.name,
            fields: edited,
            initialFields: initial,
            state: state
        )

        #expect(resolution.workout == nil)
        #expect(resolution.validationMessage == "Duration must be a number")
    }
}
