//
//  RPGFitMVPTests.swift
//  RPGFitMVPTests
//
//  Regression net for the Milestone 1 persistence-correctness wave.
//  These tests pin the fixes for the release blockers: quest XP that
//  survives writeback, resets that erase, ids that survive relaunch,
//  per-set truth, and corruption that triggers recovery instead of
//  silently emptying history.
//

import Foundation
import Testing
@testable import RPGFitMVP

// MARK: - Helpers

private func makeQuest(target: Int = 10, reward: Int = 25, unit: ChallengeUnit = .reps) -> Challenge {
    Challenge(id: UUID(),
              type: .daily,
              title: "Test Quest",
              description: "test",
              targetCategory: .strength,
              targetAmount: target,
              unit: unit,
              expReward: reward,
              classType: .warrior,
              createdAt: Date(),
              expiresAt: Date().addingTimeInterval(3600),
              completedAt: nil)
}

private func makeItem(name: String) -> InventoryItem {
    InventoryItem(name: name, description: "test", type: .equipment,
                  rarity: .rare, iconName: "shield", quantity: 1,
                  dateObtained: Date(), value: 10)
}

private func freshState(persistenceEnabled: Bool = false) -> AppState {
    let state = AppState(persistenceEnabled: persistenceEnabled)
    state.user = UserProfile()
    state.history = []
    return state
}

// MARK: - Quest XP survives writeback (blocker 3)

struct QuestRewardTests {

    @Test func questCompletionKeepsItsXP() {
        let state = freshState()
        state.user.dailyChallenges = [makeQuest(target: 10, reward: 25)]

        state.updateChallengeProgress(for: .strength, amount: 10, unit: .reps)

        #expect(state.user.dailyChallenges[0].isCompleted)
        // The regression: the inout borrow's writeback erased this grant.
        #expect(state.user.bonusXP == 25)
    }

    @Test func twoSimultaneousCompletionsBothPay() {
        let state = freshState()
        state.user.dailyChallenges = [makeQuest(target: 10, reward: 25)]
        state.user.weeklyChallenges = [makeQuest(target: 10, reward: 40)]

        state.updateChallengeProgress(for: .strength, amount: 10, unit: .reps)

        #expect(state.user.dailyChallenges[0].isCompleted)
        #expect(state.user.weeklyChallenges[0].isCompleted)
        #expect(state.user.bonusXP == 65)
    }

    @Test func questXPSurvivesEncodeDecode() throws {
        let state = freshState()
        state.user.dailyChallenges = [makeQuest(target: 5, reward: 30)]
        state.updateChallengeProgress(for: .strength, amount: 5, unit: .reps)

        let data = try JSONEncoder().encode(PersistedData(user: state.user, history: state.history))
        let decoded = try JSONDecoder().decode(PersistedData.self, from: data)
        #expect(decoded.user.bonusXP == 30)
        #expect(decoded.user.dailyChallenges[0].isCompleted)
    }
}

// MARK: - Reset means reset (blocker 4)

struct ResetTests {

    @Test func resetClearsProfileHistoryAndDefaults() async throws {
        let state = freshState(persistenceEnabled: true)

        // Begin from a controlled on-disk profile, then force creation of an
        // automatic backup so the reset assertion proves it was removed.
        state.resetAll()
        await state.flushPersistence()
        state.user.bonusXP = 500
        state.history = []
        state.save(immediately: true)
        await state.flushPersistence()
        #expect(state.canRestoreBackup)
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")

        state.resetAll()
        await state.flushPersistence()

        #expect(state.user.bonusXP == 0)
        #expect(state.user.level == 1)
        #expect(state.history.isEmpty)
        // Every reader takes this through @AppStorage(default: false), so a
        // cleared key and a false one are the same fact: onboarding is pending.
        // Asserting absence instead pins a representation the live view layer
        // can rewrite, while `true` — the regression that would skip onboarding
        // over a wiped profile — still fails here.
        #expect(UserDefaults.standard.bool(forKey: "hasSeenOnboarding") == false)

        // The automatic backup that used to resurrect old data must be gone.
        #expect(state.canRestoreBackup == false)
    }
}

// MARK: - Ids survive relaunch (blocker 5)

struct StableIdentityTests {

    @Test func inventoryItemIdRoundTrips() throws {
        let item = makeItem(name: "Bronze Buckler")
        let decoded = try JSONDecoder().decode(InventoryItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.id == item.id)
    }

    @Test func chestAndRewardIdsRoundTrip() throws {
        let chest = TreasureChest(type: .rare, earnedAtLevel: 5, dateEarned: Date())
        let decoded = try JSONDecoder().decode(TreasureChest.self, from: JSONEncoder().encode(chest))
        #expect(decoded.id == chest.id)
    }

    @Test func preV4ItemWithoutIdStillDecodes() throws {
        let legacyJSON = """
        {"name":"Bronze Buckler","description":"d","type":"equipment","rarity":"rare",
         "iconName":"shield","quantity":1,"dateObtained":0,"value":10}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(InventoryItem.self, from: legacyJSON)
        #expect(decoded.name == "Bronze Buckler")
    }

    @Test func equippedGearSurvivesEncodeDecode() throws {
        var user = UserProfile()
        let item = makeItem(name: "Bronze Buckler")
        user.inventory = [item]
        user.equippedItems = [EquipSlot.guardSlot.rawValue: item.id.uuidString]

        let data = try JSONEncoder().encode(PersistedData(user: user, history: []))
        let decoded = try JSONDecoder().decode(PersistedData.self, from: data)

        let equippedID = decoded.user.equippedItems[EquipSlot.guardSlot.rawValue]
        // The regression: decode minted fresh item ids, so this reference dangled.
        #expect(decoded.user.inventory.contains { $0.id.uuidString == equippedID })
    }

    @Test func migrationRelinksUnambiguousSlot() {
        let state = freshState()
        let buckler = makeItem(name: "Bronze Buckler") // only Guard-slot item owned
        state.user.inventory = [buckler]
        state.user.equippedItems = [EquipSlot.guardSlot.rawValue: UUID().uuidString]

        state.relinkEquippedItemsAfterIDMigration()

        #expect(state.user.equippedItems[EquipSlot.guardSlot.rawValue] == buckler.id.uuidString)
    }

    @Test func migrationClearsAmbiguousSlot() {
        let state = freshState()
        // Two relic-slot candidates — no honest way to pick one.
        state.user.inventory = [makeItem(name: "Ancient Crown"), makeItem(name: "Mystic Orb")]
        state.user.equippedItems = [EquipSlot.relic.rawValue: UUID().uuidString]

        state.relinkEquippedItemsAfterIDMigration()

        #expect(state.user.equippedItems[EquipSlot.relic.rawValue] == nil)
    }
}

// MARK: - Per-set truth (blocker 6)

struct PerSetModelTests {

    @Test func legacySummaryExpandsAsEstimated() {
        let entry = WorkoutEntry(id: UUID(), date: Date(), name: "Bench",
                                 category: .benchPress, sets: 3, reps: 5, weight: 100,
                                 durationMinutes: nil, distanceKm: nil,
                                 statGains: StatBlock(), expGained: 10)
        let resolved = entry.resolvedSets
        #expect(resolved.count == 3)
        #expect(resolved.allSatisfy { $0.estimated })
        #expect(resolved.allSatisfy { $0.reps == 5 && $0.weightKg == 100 })
    }

    @Test func realSetsAreStoredVerbatim() {
        let real = [PerformedSet(reps: 8, weightKg: 60),
                    PerformedSet(reps: 6, weightKg: 70),
                    PerformedSet(reps: 4, weightKg: 80)]
        let entry = WorkoutEntry(id: UUID(), date: Date(), name: "Bench",
                                 category: .benchPress, sets: 3, reps: 4, weight: 80,
                                 durationMinutes: nil, distanceKm: nil,
                                 performedSets: real,
                                 statGains: StatBlock(), expGained: 10)
        #expect(entry.resolvedSets == real)
        #expect(entry.resolvedSets.allSatisfy { !$0.estimated })
    }

    @Test func performedSetsSurviveEncodeDecode() throws {
        let real = [PerformedSet(reps: 5, weightKg: 100), PerformedSet(reps: 1, weightKg: 140)]
        let entry = WorkoutEntry(id: UUID(), date: Date(), name: "Bench",
                                 category: .benchPress, sets: 2, reps: 5, weight: 100,
                                 durationMinutes: nil, distanceKm: nil,
                                 performedSets: real,
                                 statGains: StatBlock(), expGained: 10)
        let decoded = try JSONDecoder().decode(WorkoutEntry.self, from: JSONEncoder().encode(entry))
        #expect(decoded.performedSets == real)
    }

    @Test func prComesFromBestSetNotBiggestSet() {
        let state = freshState()
        // 5×100 wins on volume; the single at 140 is the real 1RM candidate.
        let sets = [PerformedSet(reps: 5, weightKg: 100), PerformedSet(reps: 1, weightKg: 140)]
        let entry = state.logWorkout(name: "Bench", category: .benchPress, sets: 2,
                                     reps: 5, weight: 100, durationMinutes: nil,
                                     distanceKm: nil, performedSets: sets)
        #expect(entry.est1RM == 140)
        #expect(state.user.best1RM[.benchPress] == 140)
    }
}

// MARK: - Corruption gets loud (blocker 7)

struct CorruptionRecoveryTests {

    @Test func corruptHistoryThrowsInsteadOfEmptying() {
        let corrupt = """
        {"schemaVersion":4,"user":{},"history":[{"id":"not-a-workout"}]}
        """.data(using: .utf8)!
        // The regression: this decoded "successfully" with history == [],
        // so the backup ladder never ran and history looked erased.
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(PersistedData.self, from: corrupt)
        }
    }

    @Test func missingUserThrows() {
        let corrupt = """
        {"schemaVersion":4,"history":[]}
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(PersistedData.self, from: corrupt)
        }
    }

    @Test func absentHistoryKeyIsToleratedAsOldSchema() throws {
        let oldSchema = """
        {"schemaVersion":1,"user":{}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PersistedData.self, from: oldSchema)
        #expect(decoded.history.isEmpty)
        #expect(decoded.schemaVersion == 1)
    }
}

// MARK: - Input gates (NaN never survives a comparison clamp)

struct ValidationTests {

    @Test func nonFiniteNumbersAreRejected() {
        let state = freshState()
        let v = state.validateWorkoutInputs(reps: 10, weight: .nan,
                                            durationMinutes: .infinity, distanceKm: nil)
        #expect(v.weight == nil)
        #expect(v.duration == nil)
        #expect(v.isValid == false)
    }

    @Test func boundsClampInsteadOfCrash() {
        let state = freshState()
        let v = state.validateWorkoutInputs(sets: 500, reps: 100000,
                                            weight: 99999, durationMinutes: nil, distanceKm: nil)
        #expect(v.sets == 100)
        #expect(v.reps == 9999)
        #expect(v.weight == 9999)
    }
}

// MARK: - Routines and repeat-last (M3)

struct RoutineTests {

    private func benchEntry(sessionID: UUID?, sets: [PerformedSet]?) -> WorkoutEntry {
        WorkoutEntry(id: UUID(), date: Date(), name: "Bench", category: .benchPress,
                     sessionID: sessionID, sets: sets?.count ?? 1, reps: 5, weight: 100,
                     durationMinutes: nil, distanceKm: nil, performedSets: sets,
                     statGains: StatBlock(), expGained: 10)
    }

    @Test func finishedSessionBecomesRoutineWithRealSets() {
        let state = freshState()
        state.user.units = .kg
        let sid = UUID()
        let sets = [PerformedSet(reps: 8, weightKg: 60), PerformedSet(reps: 6, weightKg: 70)]
        state.history = [benchEntry(sessionID: sid, sets: sets)]

        state.saveRoutine(named: "Push Day", from: state.lastSessionEntries)

        #expect(state.user.routines.count == 1)
        let routine = state.user.routines[0]
        #expect(routine.name == "Push Day")
        #expect(routine.exercises[0].plannedSets.map(\.reps) == [8, 6])

        // Starting the routine prefills each set individually, unchecked.
        let draft = state.sessionDraft(from: routine)
        #expect(draft.exercises[0].sets.map(\.reps) == ["8", "6"])
        #expect(draft.exercises[0].sets.map(\.weight) == ["60", "70"])
        #expect(draft.exercises[0].sets.allSatisfy { !$0.done })
    }

    @Test func repeatLastUsesTheMostRecentSession() {
        let state = freshState()
        let older = UUID(), newer = UUID()
        // History is newest-first.
        state.history = [
            benchEntry(sessionID: newer, sets: [PerformedSet(reps: 3, weightKg: 120)]),
            benchEntry(sessionID: older, sets: [PerformedSet(reps: 10, weightKg: 60)]),
            benchEntry(sessionID: older, sets: [PerformedSet(reps: 10, weightKg: 60)]),
        ]

        let draft = state.sessionDraftRepeatingLast()

        #expect(draft?.exercises.count == 1)
        #expect(draft?.exercises[0].sets.map(\.reps) == ["3"])
    }

    @Test func routinesSurviveEncodeDecode() throws {
        var user = UserProfile()
        user.routines = [Routine(name: "Legs",
                                 exercises: [RoutineExercise(category: .squat,
                                                             plannedSets: [PlannedSet(reps: 5, weightKg: 110)])])]
        let data = try JSONEncoder().encode(PersistedData(user: user, history: []))
        let decoded = try JSONDecoder().decode(PersistedData.self, from: data)
        #expect(decoded.user.routines.count == 1)
        #expect(decoded.user.routines[0].name == "Legs")
        #expect(decoded.user.routines[0].exercises[0].plannedSets[0].weightKg == 110)
    }

    @Test func renameAndDeleteRoutine() {
        let state = freshState()
        state.user.routines = [Routine(name: "Old Name")]
        let id = state.user.routines[0].id

        state.renameRoutine(id, to: "  New Name  ")
        #expect(state.user.routines[0].name == "New Name")

        state.renameRoutine(id, to: "   ")
        #expect(state.user.routines[0].name == "New Name") // blank rejected

        state.deleteRoutine(id)
        #expect(state.user.routines.isEmpty)
    }

    @Test func fieldNumberTrimsTrailingZeros() {
        #expect(AppState.fieldNumber(100.0) == "100")
        #expect(AppState.fieldNumber(62.5) == "62.5")
        #expect(AppState.fieldNumber(60.04) == "60")
    }
}

// MARK: - Warm-up sets and RPE (M3)

struct SetTypeTests {

    @Test func warmupsAreStoredButNeverSetRecords() {
        let state = freshState()
        // Heavy single as a WARM-UP plus a real working 5×100: the warm-up
        // must be kept in the data yet never become the PR.
        let sets = [PerformedSet(reps: 1, weightKg: 140, isWarmup: true),
                    PerformedSet(reps: 5, weightKg: 100)]
        let entry = state.logWorkout(name: "Bench", category: .benchPress, sets: 1,
                                     reps: 5, weight: 100, durationMinutes: nil,
                                     distanceKm: nil, performedSets: sets)
        #expect(entry.performedSets?.count == 2)
        #expect(entry.performedSets?.first?.isWarmup == true)
        // Brzycki 5×100 ≈ 112.5 — NOT the 140 warm-up single.
        #expect(entry.est1RM ?? 0 < 140)
        #expect(entry.est1RM ?? 0 > 112)
    }

    @Test func rpeRidesAlongOnPerformedSets() throws {
        let sets = [PerformedSet(reps: 5, weightKg: 100, rpe: 8.5)]
        let entry = WorkoutEntry(id: UUID(), date: Date(), name: "Bench",
                                 category: .benchPress, sets: 1, reps: 5, weight: 100,
                                 durationMinutes: nil, distanceKm: nil,
                                 performedSets: sets,
                                 statGains: StatBlock(), expGained: 10)
        let decoded = try JSONDecoder().decode(WorkoutEntry.self, from: JSONEncoder().encode(entry))
        #expect(decoded.performedSets?.first?.rpe == 8.5)
    }

    @Test func warmupFlagsSurviveTheRoutinePipeline() {
        let state = freshState()
        state.user.units = .kg
        let sets = [PerformedSet(reps: 10, weightKg: 40, isWarmup: true),
                    PerformedSet(reps: 5, weightKg: 100)]
        let entry = WorkoutEntry(id: UUID(), date: Date(), name: "Bench",
                                 category: .benchPress, sessionID: UUID(),
                                 sets: 1, reps: 5, weight: 100,
                                 durationMinutes: nil, distanceKm: nil,
                                 performedSets: sets,
                                 statGains: StatBlock(), expGained: 10)
        state.history = [entry]

        state.saveRoutine(named: "Push", from: state.lastSessionEntries)
        let draft = state.sessionDraft(from: state.user.routines[0])

        #expect(draft.exercises[0].sets.map(\.isWarmup) == [true, false])
    }

    @Test func oldDraftsWithoutSetTypesStillDecode() throws {
        let legacy = """
        {"id":"00000000-0000-0000-0000-000000000001","reps":"8","weight":"60","done":true}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DraftSet.self, from: legacy)
        #expect(decoded.done)
        #expect(decoded.isWarmup == false)
        #expect(decoded.rpe == nil)
    }
}

// MARK: - Supersets (M3)

struct SupersetTests {

    private func draft(with categories: [ExerciseCategory]) -> ActiveSessionDraft {
        var draft = ActiveSessionDraft()
        draft.exercises = categories.map { DraftExercise(category: $0, sets: [DraftSet()]) }
        return draft
    }

    @Test func linkingPairsWithTheNextExercise() {
        var d = draft(with: [.benchPress, .row, .squat])
        d.supersetWithNext(at: 0)
        #expect(d.exercises[0].supersetGroup != nil)
        #expect(d.exercises[0].supersetGroup == d.exercises[1].supersetGroup)
        #expect(d.exercises[2].supersetGroup == nil)

        // Extending the chain merges into the same group.
        d.supersetWithNext(at: 1)
        #expect(d.exercises[2].supersetGroup == d.exercises[0].supersetGroup)
    }

    @Test func onlyTheLastMemberOfARoundRests() {
        var d = draft(with: [.benchPress, .row, .squat])
        d.supersetWithNext(at: 0)

        // A (bench) → no rest; B (row) is the group's last → rest.
        #expect(d.shouldRest(afterSetIn: d.exercises[0].id) == false)
        #expect(d.shouldRest(afterSetIn: d.exercises[1].id) == true)
        // Squat is solo → always rests.
        #expect(d.shouldRest(afterSetIn: d.exercises[2].id) == true)
    }

    @Test func loggedMembersStopBlockingRest() {
        var d = draft(with: [.benchPress, .row])
        d.supersetWithNext(at: 0)
        d.exercises[1].logged = true
        // With B finished, A is the last unlogged member — it rests again.
        #expect(d.shouldRest(afterSetIn: d.exercises[0].id) == true)
    }

    @Test func breakingAGroupOfTwoDissolvesIt() {
        var d = draft(with: [.benchPress, .row])
        d.supersetWithNext(at: 0)
        d.breakSuperset(at: 0)
        #expect(d.exercises[0].supersetGroup == nil)
        #expect(d.exercises[1].supersetGroup == nil)
    }

    @Test func timedExercisesNeverJoinSupersets() {
        var d = draft(with: [.benchPress])
        d.exercises.append(DraftExercise(category: .run, sets: []))
        d.supersetWithNext(at: 0)
        #expect(d.exercises[0].supersetGroup == nil)
        #expect(d.exercises[1].supersetGroup == nil)
    }

    @Test func timedExerciseCannotStartASuperset() {
        var d = draft(with: [.run, .benchPress])
        d.supersetWithNext(at: 0)
        #expect(d.exercises.allSatisfy { $0.supersetGroup == nil })
    }

    @Test func linkingExistingGroupsMergesEveryMember() {
        var d = draft(with: [.benchPress, .row, .squat, .deadlift])
        d.exercises[0].supersetGroup = 10
        d.exercises[1].supersetGroup = 10
        d.exercises[2].supersetGroup = 20
        d.exercises[3].supersetGroup = 20

        d.supersetWithNext(at: 1)

        let groups = Set(d.exercises.compactMap(\.supersetGroup))
        #expect(groups.count == 1)
        #expect(d.exercises.allSatisfy { $0.supersetGroup != nil })
    }

    @Test func normalizationClearsTimedMembersAndDissolvesSingletons() {
        var d = draft(with: [.benchPress, .run, .row, .squat])
        d.exercises[0].supersetGroup = 5
        d.exercises[1].supersetGroup = 5
        d.exercises[2].supersetGroup = 5
        d.exercises[3].supersetGroup = 9

        d.normalizeSupersets()

        #expect(d.exercises[0].supersetGroup == 5)
        #expect(d.exercises[1].supersetGroup == nil)
        #expect(d.exercises[2].supersetGroup == 5)
        #expect(d.exercises[3].supersetGroup == nil)
    }
}

// MARK: - Custom exercises (M3)

struct CustomExerciseTests {

    @Test func customEntriesKeepTheirOwnIdentity() {
        let state = freshState()
        let custom = state.addCustomExercise(named: "Larsen Press", basedOn: .benchPress)
        #expect(custom != nil)
        guard let custom else { return }

        let entry = state.logWorkout(name: custom.name, category: custom.basedOn,
                                     sets: 1, reps: 5, weight: 100,
                                     durationMinutes: nil, distanceKm: nil,
                                     performedSets: [PerformedSet(reps: 5, weightKg: 100)],
                                     customExerciseID: custom.id)

        #expect(entry.customExerciseID == custom.id)
        #expect(entry.name == "Larsen Press")
        // A built-in lookup must not see the custom entry, and vice versa.
        #expect(state.lastEntry(category: .benchPress, customID: nil) == nil)
        #expect(state.lastEntry(category: .benchPress, customID: custom.id)?.id == entry.id)
    }

    @Test func customsNeverEnterTheRecordBook() {
        let state = freshState()
        guard let custom = state.addCustomExercise(named: "Board Press", basedOn: .benchPress) else {
            Issue.record("failed to create custom exercise"); return
        }

        let entry = state.logWorkout(name: custom.name, category: .benchPress,
                                     sets: 1, reps: 1, weight: 200,
                                     durationMinutes: nil, distanceKm: nil,
                                     performedSets: [PerformedSet(reps: 1, weightKg: 200)],
                                     customExerciseID: custom.id)

        // A 200 kg "Board Press" single must not become the Bench record.
        #expect(entry.est1RM == nil)
        #expect((state.user.best1RM[.benchPress] ?? 0) == 0)
    }

    @Test func customIdentityFlowsThroughRoutines() {
        let state = freshState()
        state.user.units = .kg
        guard let custom = state.addCustomExercise(named: "Larsen Press", basedOn: .benchPress) else {
            Issue.record("failed to create custom exercise"); return
        }
        state.logWorkout(name: custom.name, category: .benchPress,
                         sets: 1, reps: 8, weight: 60,
                         durationMinutes: nil, distanceKm: nil,
                         sessionID: UUID(),
                         performedSets: [PerformedSet(reps: 8, weightKg: 60)],
                         customExerciseID: custom.id)

        state.saveRoutine(named: "Press Day", from: state.lastSessionEntries)
        let routine = state.user.routines[0]
        #expect(routine.exercises[0].customExerciseID == custom.id)
        #expect(routine.exercises[0].displayName == "Larsen Press")

        let draft = state.sessionDraft(from: routine)
        #expect(draft.exercises[0].customExerciseID == custom.id)
        #expect(draft.exercises[0].displayName == "Larsen Press")
    }

    @Test func definitionsSurviveEncodeDecodeAndDelete() throws {
        var user = UserProfile()
        user.customExercises = [CustomExercise(name: "Sled Drag", basedOn: .sledPush)]
        let decoded = try JSONDecoder().decode(PersistedData.self,
                                               from: JSONEncoder().encode(PersistedData(user: user, history: [])))
        #expect(decoded.user.customExercises.first?.name == "Sled Drag")
        #expect(decoded.user.customExercises.first?.basedOn == .sledPush)

        let state = freshState()
        guard let custom = state.addCustomExercise(named: "Temp", basedOn: .curl) else {
            Issue.record("failed to create custom exercise"); return
        }
        state.deleteCustomExercise(custom.id)
        #expect(state.user.customExercises.isEmpty)
    }
}

// MARK: - Plate math (M3)

struct PlateMathTests {

    @Test func exactLoadSolvesGreedily() throws {
        let solution = try #require(PlateMath.solve(target: 100, bar: 20,
                                                    plates: PlateMath.standardPlates(kg: true)))
        // 40 per side = 25 + 15
        #expect(solution.perSide.map(\.weight) == [25, 15])
        #expect(solution.perSide.map(\.count) == [1, 1])
        #expect(solution.shortfall == 0)
        #expect(solution.achieved == 100)
    }

    @Test func unreachableTargetReportsShortfall() throws {
        // 101 kg needs 0.5 per side — smallest plate is 1.25.
        let solution = try #require(PlateMath.solve(target: 101, bar: 20,
                                                    plates: PlateMath.standardPlates(kg: true)))
        #expect(solution.shortfall == 1)
        #expect(solution.achieved == 100)
    }

    @Test func barOnlyAndImpossibleTargets() {
        let barOnly = PlateMath.solve(target: 20, bar: 20,
                                      plates: PlateMath.standardPlates(kg: true))
        #expect(barOnly?.perSide.isEmpty == true)
        #expect(PlateMath.solve(target: 15, bar: 20,
                                plates: PlateMath.standardPlates(kg: true)) == nil)
    }

    @Test func poundPlatesSolveToo() throws {
        let solution = try #require(PlateMath.solve(target: 225, bar: 45,
                                                    plates: PlateMath.standardPlates(kg: false)))
        // The classic two-plate bench: 90 per side = 45 × 2.
        #expect(solution.perSide.map(\.weight) == [45])
        #expect(solution.perSide.map(\.count) == [2])
        #expect(solution.shortfall == 0)
    }
}

// MARK: - M4: honest XP, game-layer bonuses, adaptive quests

struct GameLayerTests {

    @Test func classAffinityBoostsMightNeverXP() {
        // Same workout, with and without a matching class: XP must be
        // identical (decision D5 — XP measures training, full stop).
        let matchingClass = RPGClass.warrior
        let category = ExerciseCategory.allCases.first {
            matchingClass.focusCategories.contains($0.focus)
        }!

        let plain = freshState()
        let classed = freshState()
        classed.user.rpgClass = matchingClass
        // Per-log XP carries deliberate ±0.4 jitter, so single samples can't
        // be compared directly. Drive both states into the hard 60-XP cap
        // (tiny baseline, huge session): any surviving class multiplier
        // would have to act after the cap to show up — and the cap is the
        // last step, so equality here pins "class never changes XP".
        // A seed entry keeps relativeXP off its random first-ever path.
        let seed = WorkoutEntry(id: UUID(), date: Date().addingTimeInterval(-86400),
                                name: "", category: .yoga, sets: nil, reps: nil, weight: nil,
                                durationMinutes: 20, distanceKm: nil,
                                statGains: StatBlock(), expGained: 5)
        plain.history = [seed]
        classed.history = [seed]
        plain.user.xpBaselines[category] = 1
        classed.user.xpBaselines[category] = 1

        let entryPlain = plain.logWorkout(name: "", category: category, sets: 5,
                                          reps: 8, weight: 300, durationMinutes: nil, distanceKm: nil)
        let entryClassed = classed.logWorkout(name: "", category: category, sets: 5,
                                              reps: 8, weight: 300, durationMinutes: nil, distanceKm: nil)
        #expect(entryPlain.expGained == 60)
        #expect(entryClassed.expGained == 60)

        // …while the GAME layer does reward affinity: might banks +10%.
        let bonus = freshState()
        bonus.user.rpgClass = matchingClass
        bonus.bankTrialMight(from: 100, focus: category.focus)
        #expect(abs(bonus.user.trialMight - 110) < 0.001)

        let offFocus = FocusGroup.allCases.first { !matchingClass.focusCategories.contains($0) }!
        let noBonus = freshState()
        noBonus.user.rpgClass = matchingClass
        noBonus.bankTrialMight(from: 100, focus: offFocus)
        #expect(noBonus.user.trialMight == 100)
    }

    @Test func fullAndMatchedLoadoutsEarnSetBonuses() {
        let state = freshState()
        let arms = makeItem(name: "Arcane Tome")       // arms slot
        let guardItem = makeItem(name: "Bronze Buckler") // guard slot
        let relic = makeItem(name: "Ancient Crown")     // relic slot
        state.user.inventory = [arms, guardItem, relic]

        state.equip(arms)
        #expect(state.equipmentMight == 4) // one rare, no set bonus

        state.equip(guardItem)
        state.equip(relic)
        // 3 × rare(4) + full kit 2 + matched rarity 3
        #expect(state.equipmentMight == 17)
        #expect(state.equipmentSetBonusLabel == "Matched set · +5 Might")

        // Break the match: swap the relic for an epic.
        let epicRelic = InventoryItem(name: "Mystic Orb", description: "d", type: .equipment,
                                      rarity: .epic, iconName: "sparkle", quantity: 1,
                                      dateObtained: Date(), value: 10)
        state.user.inventory.append(epicRelic)
        state.equip(epicRelic)
        // rare(4) + rare(4) + epic(7) + full kit 2, no rarity match
        #expect(state.equipmentMight == 17)
        #expect(state.equipmentSetBonusLabel == "Full kit · +2 Might")
    }

    @Test func companionRenamePersistsAndReverts() {
        let state = freshState()
        state.user.hatchedCompanions = [CompanionSpecies.wisp.rawValue]
        state.user.activeCompanion = CompanionSpecies.wisp.rawValue

        state.renameCompanion(.wisp, to: "  Cinder  ")
        #expect(state.companionDisplayName(.wisp) == "Cinder")

        state.renameCompanion(.wisp, to: String(repeating: "x", count: 40))
        #expect(state.companionDisplayName(.wisp).count == 20)

        state.renameCompanion(.wisp, to: "   ")
        #expect(state.companionDisplayName(.wisp) == "Wisp")
    }

    @Test func habitsOutrankTheCharacterSheet() {
        let state = freshState()
        state.user.rpgClass = .warrior
        let offFocus = FocusGroup.allCases.first { !RPGClass.warrior.focusCategories.contains($0) }!
        let category = ExerciseCategory.allCases.first { $0.focus == offFocus }!

        func entry(daysAgo: Int) -> WorkoutEntry {
            WorkoutEntry(id: UUID(),
                         date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
                         name: "", category: category, sets: 1, reps: 10, weight: nil,
                         durationMinutes: 20, distanceKm: nil,
                         statGains: StatBlock(), expGained: 5)
        }

        state.history = [entry(daysAgo: 1), entry(daysAgo: 2)]
        #expect(state.dominantOffClassFocus() == nil) // two days isn't a habit

        state.history.append(entry(daysAgo: 3))
        #expect(state.dominantOffClassFocus() == offFocus)
    }

    @Test func campaignRegionsCoverTheAuthoredLadder() {
        let covered = CampaignRegion.all.flatMap { Array($0.rungs) }.sorted()
        #expect(covered == Array(0...11)) // no gaps, no overlaps
    }
}

// MARK: - Engine characterization (accidental tuning shows up here)

struct EngineCharacterizationTests {

    @Test func brzyckiSpotValues() {
        // A true single IS the 1RM.
        #expect(StatEngine.estimate1RM(category: .benchPress, reps: 1, weight: 140) == 140)
        // 5×100 via Brzycki: 100 / (1.0278 − 0.0278·5) ≈ 112.5
        let fiveRep = StatEngine.estimate1RM(category: .benchPress, reps: 5, weight: 100)
        #expect(fiveRep > 112.0 && fiveRep < 113.0)
        // Only meaningful for the compound lifts; everything else is 0.
        #expect(StatEngine.estimate1RM(category: .curl, reps: 5, weight: 100) == 0)
        // Formula breaks down past 15 reps — refuse rather than mislead.
        #expect(StatEngine.estimate1RM(category: .benchPress, reps: 16, weight: 100) == 0)
    }

    @Test func xpCurveIsPositiveAndGrows() {
        for level in 1...99 {
            #expect(StatEngine.xpNeeded(forNextLevel: level) > 0)
        }
        #expect(StatEngine.xpNeeded(forNextLevel: 50) > StatEngine.xpNeeded(forNextLevel: 1))
    }
}

// MARK: - Equipment availability (M3)

struct EquipmentAvailabilityTests {

    @Test func unconfiguredMeansEverythingShows() {
        let state = freshState()
        #expect(state.configuredEquipment == nil)
        #expect(state.isAvailable(.benchPress))
        #expect(state.isAvailable(.legPress))
    }

    @Test func togglingOffHidesOnlyThatGear() {
        let state = freshState()
        state.setEquipment(.machines, available: false)
        #expect(!state.isAvailable(.legPress))
        #expect(!state.isAvailable(.latPulldown))
        #expect(state.isAvailable(.pushUp))
        #expect(state.isAvailable(.benchPress))
        // First interaction seeds "has everything else".
        #expect(state.isAvailable(.kettlebellSwing))
    }

    @Test func bodyweightAndOutdoorAlwaysShow() {
        let state = freshState()
        state.configuredEquipment = []   // bodyweight-only home
        for category in ExerciseCategory.allCases where category.requiredEquipment == nil {
            #expect(state.isAvailable(category))
        }
        #expect(!state.isAvailable(.squat))
    }

    @Test func equipmentSurvivesEncodeDecode() throws {
        let state = freshState()
        state.setEquipment(.pool, available: false)
        let data = try AppState.jsonEncoder.encode(state.user)
        let decoded = try AppState.jsonDecoder.decode(UserProfile.self, from: data)
        #expect(decoded.availableEquipment == state.user.availableEquipment)
    }
}

// MARK: - Cloud backup payload (M5)

@Suite(.serialized)
struct CloudBackupPayloadTests {

    @Test func encodedSaveRoundTripsThroughRestore() throws {
        let state = freshState()
        state.user.bonusXP = 123
        _ = state.logWorkout(name: "", category: .benchPress, sets: 3, reps: 5,
                             weight: 100, durationMinutes: nil, distanceKm: nil)
        let payload = try state.encodedSaveData()

        let receiver = freshState()
        try receiver.applyRestoredSave(payload)
        #expect(receiver.history.count == 1)
        #expect(receiver.user.bonusXP == state.user.bonusXP)
        #expect(receiver.history[0].category == .benchPress)
    }

    @Test func corruptPayloadThrowsWithoutTouchingState() {
        let receiver = freshState()
        receiver.user.bonusXP = 55
        #expect(throws: (any Error).self) {
            try receiver.applyRestoredSave(Data("not json".utf8))
        }
        #expect(receiver.user.bonusXP == 55)
    }

    @Test func semanticallyIncompletePayloadDoesNotReplaceLiveState() throws {
        // This payload is syntactically valid but impossible for a healthy
        // save: workout history survived while the entire profile was wiped.
        let orphanedEntry = WorkoutEntry(
            id: UUID(), date: Date(), name: "Bench", category: .benchPress,
            sets: 1, reps: 5, weight: 80,
            durationMinutes: nil, distanceKm: nil,
            statGains: StatBlock(strength: 1), expGained: 10
        )
        let payload = try AppState.jsonEncoder.encode(
            PersistedData(user: UserProfile(), history: [orphanedEntry])
        )
        // Prove this is semantic validation, not a JSON decoding failure.
        _ = try AppState.jsonDecoder.decode(PersistedData.self, from: payload)

        let receiver = freshState()
        receiver.user.bonusXP = 55
        #expect(throws: (any Error).self) {
            try receiver.applyRestoredSave(payload)
        }
        #expect(receiver.user.bonusXP == 55)
        #expect(receiver.history.isEmpty)
    }

    @Test func schemaTwoRestoreRunsXPMigration() throws {
        var legacyUser = UserProfile()
        legacyUser.level = 42
        legacyUser.xp = 999
        legacyUser.stats = StatBlock(size: 99, strength: 99)
        let gains = StatBlock(size: 1.5, strength: 2.5)
        let entry = WorkoutEntry(
            id: UUID(), date: Date(), name: "Bench", category: .benchPress,
            sets: 1, reps: 5, weight: 80,
            durationMinutes: nil, distanceKm: nil,
            statGains: gains, expGained: 10
        )
        let payload = try AppState.jsonEncoder.encode(
            PersistedData(user: legacyUser, history: [entry], schemaVersion: 2)
        )

        let receiver = freshState()
        try receiver.applyRestoredSave(payload)

        #expect(receiver.user.level == 1)
        #expect(receiver.user.xp == 10)
        #expect(receiver.user.stats == gains)
        #expect(receiver.user.nextLevelXP == StatEngine.xpNeeded(forNextLevel: 1))
    }

    @Test func schemaThreeRestoreRelinksEquippedItems() throws {
        var legacyUser = UserProfile()
        let buckler = makeItem(name: "Bronze Buckler")
        legacyUser.inventory = [buckler]
        legacyUser.equippedItems = [EquipSlot.guardSlot.rawValue: UUID().uuidString]
        let payload = try AppState.jsonEncoder.encode(
            PersistedData(user: legacyUser, history: [], schemaVersion: 3)
        )

        let receiver = freshState()
        try receiver.applyRestoredSave(payload)

        #expect(receiver.user.equippedItems[EquipSlot.guardSlot.rawValue] == buckler.id.uuidString)
    }

    @Test func restoreDiscardsDraftFromReplacedProfile() throws {
        defer { ActiveSessionDraft.clear() }
        ActiveSessionDraft(
            exercises: [DraftExercise(category: .benchPress,
                                      sets: [DraftSet(reps: "5", weight: "80")])]
        ).persist()
        #expect(ActiveSessionDraft.loadResumable() != nil)

        let payload = try AppState.jsonEncoder.encode(
            PersistedData(user: UserProfile(), history: [])
        )
        let receiver = freshState()
        try receiver.applyRestoredSave(payload)

        #expect(ActiveSessionDraft.load() == nil)
    }
}

// MARK: - Gear set bonuses (M4 game layer)

struct EquipmentSetBonusTests {

    @Test func fullKitAndMatchedSetBonuses() {
        let state = freshState()
        let arms = makeItem(name: "Arcane Tome")         // arms slot
        let guardItem = makeItem(name: "Bronze Buckler") // guard slot
        let relic = makeItem(name: "Lucky Coin")         // relic (default)
        state.user.inventory = [arms, guardItem, relic]
        state.equip(arms)
        state.equip(guardItem)
        state.equip(relic)
        // 4+4+4 rare might, +2 full kit, +3 matched rarity.
        #expect(state.equipmentMight == 17)
        #expect(state.equipmentSetBonusLabel == "Matched set · +5 Might")

        state.unequip(slot: .relic)
        #expect(state.equipmentMight == 8)
        #expect(state.equipmentSetBonusLabel == nil)
    }
}

// MARK: - Save validation vs legitimate zero-XP history (review finding)

struct SaveValidationTests {

    @Test func warmupOnlySaveIsLegitimate() throws {
        // A fresh profile plus a zero-XP entry is exactly what a first-day
        // warm-up-only session produces — it must never read as corruption.
        let entry = WorkoutEntry(id: UUID(), date: Date(), name: "Bench Press",
                                 category: .benchPress,
                                 statGains: StatBlock.zero, expGained: 0)
        let data = try AppState.jsonEncoder.encode(
            PersistedData(user: UserProfile(), history: [entry]))
        let decoded = try AppState.decodeValidatedSave(data)
        #expect(decoded.history.count == 1)
    }

    @Test func wipedProfileWithEarnedHistoryStillRejected() throws {
        let entry = WorkoutEntry(id: UUID(), date: Date(), name: "Bench Press",
                                 category: .benchPress,
                                 statGains: StatBlock.zero, expGained: 12)
        let data = try AppState.jsonEncoder.encode(
            PersistedData(user: UserProfile(), history: [entry]))
        #expect(throws: (any Error).self) {
            _ = try AppState.decodeValidatedSave(data)
        }
    }
}

// MARK: - Edits that aren't performance edits keep per-set truth

struct EditNormalizationTests {

    @Test func renameKeepsPerformedSetsDespiteDisplayRounding() {
        let state = AppState(persistenceEnabled: false)
        _ = state.logWorkout(name: "", category: .benchPress, sets: 2, reps: 5,
                             weight: 100.04, durationMinutes: nil, distanceKm: nil,
                             performedSets: [PerformedSet(reps: 5, weightKg: 100.04),
                                             PerformedSet(reps: 5, weightKg: 102.5)])
        var edited = state.history[0]
        edited.name = "Paused Bench"
        edited.weight = 100.0 // display round-trip precision loss
        state.updateWorkout(edited)
        #expect(state.history[0].name == "Paused Bench")
        #expect(state.history[0].performedSets?.count == 2)
    }

    @Test func setsNilVsOneIsNotAPerformanceEdit() {
        let state = AppState(persistenceEnabled: false)
        _ = state.logWorkout(name: "", category: .benchPress, sets: 1, reps: 8,
                             weight: 60, durationMinutes: nil, distanceKm: nil,
                             performedSets: [PerformedSet(reps: 8, weightKg: 60)])
        var edited = state.history[0]
        edited.sets = nil // the edit sheet's round-trip for single-set entries
        state.updateWorkout(edited)
        #expect(state.history[0].performedSets?.count == 1)
    }

    @Test func realPerformanceEditsStillDropStaleSets() {
        let state = AppState(persistenceEnabled: false)
        _ = state.logWorkout(name: "", category: .benchPress, sets: 2, reps: 5,
                             weight: 100, durationMinutes: nil, distanceKm: nil,
                             performedSets: [PerformedSet(reps: 5, weightKg: 100),
                                             PerformedSet(reps: 5, weightKg: 100)])
        var edited = state.history[0]
        edited.weight = 110
        state.updateWorkout(edited)
        #expect(state.history[0].performedSets == nil)
    }
}

// MARK: - Widget summary tells "none yet" from "all done"

@Suite("Widget summary")
struct WidgetSummaryTests {
    private func summary(remaining: Int, total: Int?, updatedAt: Date = Date()) -> WidgetSummary {
        WidgetSummary(level: 1, xpProgress: 0, questsRemaining: remaining,
                      updatedAt: updatedAt, questsTotal: total)
    }

    @Test func noQuestsYetIsNotVictory() {
        #expect(summary(remaining: 0, total: 0).hasQuests == false)
    }

    @Test func finishingEveryQuestIsVictory() {
        #expect(summary(remaining: 0, total: 3).hasQuests)
    }

    @Test func outstandingQuestsCount() {
        #expect(summary(remaining: 2, total: 3).hasQuests)
    }

    /// Summaries written before questsTotal existed must never claim victory
    /// they cannot prove.
    @Test func legacySummaryWithoutTotalNeverClaimsAllDone() {
        #expect(summary(remaining: 0, total: nil).hasQuests == false)
        #expect(summary(remaining: 2, total: nil).hasQuests)
    }

    @Test func legacyPayloadWithoutTotalStillDecodes() throws {
        let json = #"{"level":7,"xpProgress":0.5,"questsRemaining":1,"updatedAt":760000000}"#
        let decoded = try JSONDecoder().decode(WidgetSummary.self, from: Data(json.utf8))
        #expect(decoded.level == 7)
        #expect(decoded.questsTotal == nil)
    }

    @Test func questCountsAreDayScoped() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(summary(remaining: 1, total: 3, updatedAt: yesterday)
            .hasCurrentQuestCount(asOf: Date()) == false)
        #expect(summary(remaining: 1, total: 3).hasCurrentQuestCount(asOf: Date()))
    }
}
