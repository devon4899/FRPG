import Foundation
import Testing
@testable import RPGFitMVP

private func stabilizationState() -> AppState {
    let state = AppState(persistenceEnabled: false)
    state.user = UserProfile()
    state.history = []
    return state
}

struct DraftUnitStabilizationTests {
    @Test func routineDraftPinsItsEntryUnits() throws {
        let state = stabilizationState()
        state.user.units = .lb
        let routine = Routine(
            name: "Imperial day",
            exercises: [
                RoutineExercise(
                    category: .benchPress,
                    plannedSets: [PlannedSet(reps: 5, weightKg: 45.359237)],
                    plannedDistanceKm: nil
                )
            ]
        )

        let draft = state.sessionDraft(from: routine)

        #expect(draft.unitsAtStart == .lb)
        #expect(draft.exercises[0].sets[0].weight == "100")
        let decoded = try JSONDecoder().decode(
            ActiveSessionDraft.self,
            from: JSONEncoder().encode(draft)
        )
        #expect(decoded.unitsAtStart == .lb)
    }

    @Test func legacyDraftWithoutUnitsStillDecodes() throws {
        let json = """
        {
          "id":"00000000-0000-0000-0000-000000000001",
          "startedAt":0,
          "levelAtStart":1,
          "exercises":[]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ActiveSessionDraft.self, from: json)

        #expect(decoded.unitsAtStart == nil)
    }
}

struct SharedEquipmentAvailabilityTests {
    @Test func anyCompatibleEquipmentMakesMovementAvailable() {
        let state = stabilizationState()
        state.configuredEquipment = [.dumbbells]

        #expect(state.isAvailable(.benchPress))
        #expect(state.isAvailable(.squat))
        #expect(state.isAvailable(.row))
        #expect(!state.isAvailable(.legPress))
        #expect(state.isAvailable(.cycle)) // outdoor cycling needs no machine
    }

    @Test func customMovementInheritsItsBaseEquipmentRule() {
        let state = stabilizationState()
        let cableOnly = CustomExercise(name: "Cable Special", basedOn: .legPress)
        state.configuredEquipment = []
        #expect(!state.isAvailable(cableOnly))

        state.configuredEquipment = [.machines]
        #expect(state.isAvailable(cableOnly))
    }
}

struct WarmupOnlyStabilizationTests {
    @Test func warmupOnlyHistoryEntryHasNoGameRewards() {
        let state = stabilizationState()
        state.user.trialMight = 0
        state.user.hatchedCompanions = [CompanionSpecies.wisp.rawValue]
        state.user.activeCompanion = CompanionSpecies.wisp.rawValue
        state.user.dailyChallenges = [
            Challenge(
                id: UUID(),
                type: .daily,
                title: "Working sets",
                description: "test",
                targetCategory: .strength,
                targetAmount: 1,
                unit: .sets,
                expReward: 25,
                classType: .warrior,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(3600),
                completedAt: nil
            )
        ]
        let xpBefore = state.user.xp

        let entry = state.logWarmupOnlyExercise(
            name: "",
            category: .benchPress,
            performedSets: [PerformedSet(reps: 5, weightKg: 40, isWarmup: true)],
            sessionID: UUID(),
            customExerciseID: nil
        )

        #expect(entry.expGained == 0)
        #expect(entry.est1RM == nil)
        #expect(entry.performedSets?.allSatisfy(\.isWarmup) == true)
        #expect(state.user.xp == xpBefore)
        #expect(state.user.trialMight == 0)
        #expect(state.user.dailyChallenges[0].progress == 0)
        #expect(state.bondDays(for: .wisp) == 0)
        #expect(state.user.best1RM[.benchPress] == nil)
    }
}
