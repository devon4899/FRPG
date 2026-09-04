//
//  PlacementRiteTests.swift
//  RPGFitMVPTests
//
//  The Weighing at the Ledgerstone. The load-bearing invariants: seeds that
//  survive every history rebuild, ladders that never route through the engine,
//  a drawer that cannot be gamed, and an honesty bonus that pays exactly once.
//

import Foundation
import Testing
@testable import RPGFitMVP

// MARK: - Helpers

private func riteState(bodyweightKg: Double = 80) -> AppState {
    let state = AppState(persistenceEnabled: false)
    state.user = UserProfile()
    state.history = []
    state.user.bodyweightKg = bodyweightKg
    return state
}

/// Ladder-only answers with the fire burning (no discount, drawer open).
private func ladderAnswers(fire: Int? = 3, str: Int? = nil, dex: Int? = nil, end: Int? = nil) -> WeighingAnswers {
    var a = WeighingAnswers()
    a.fireIndex = fire
    a.strIndex = str
    a.dexIndex = dex
    a.endIndex = end
    return a
}

private func verdict(_ answers: WeighingAnswers,
                     bodyweightKg: Double = 80,
                     rpgClass: RPGClass? = nil,
                     units: Units = .kg) -> PlacementVerdict {
    PlacementVerdict.make(answers: answers, bodyweightKg: bodyweightKg, rpgClass: rpgClass, units: units)
}

// MARK: - Seeds vs. the history rebuild

struct PlacementSeedSurvivalTests {

    @Test func seedsSurviveRecalc() {
        let state = riteState()
        let record = verdict(ladderAnswers(str: 2)).makeRecord()
        state.applyPlacement(record: record)

        let seed = record.seeds[.squat] ?? 0
        #expect(seed > 0)
        #expect(state.user.best1RM[.squat] == seed)

        // A delete forces the full reset-and-replay path.
        _ = state.logWorkout(name: "", category: .benchPress, sets: 1, reps: 5,
                             weight: 60, durationMinutes: nil, distanceKm: nil)
        state.deleteWorkout(at: IndexSet(integer: 0))

        #expect(state.history.isEmpty)
        #expect((state.user.best1RM[.squat] ?? 0) >= seed)
    }

    @Test func realPRBeatsSeedAfterRecalc() {
        let state = riteState()
        state.applyPlacement(record: verdict(ladderAnswers(str: 2)).makeRecord())
        let seed = state.user.best1RM[.squat] ?? 0

        let entry = state.logWorkout(name: "", category: .squat, sets: 1, reps: 5,
                                     weight: 100, durationMinutes: nil, distanceKm: nil)
        let logged = state.user.best1RM[.squat] ?? 0
        #expect(logged > seed)

        // A rename-only edit still rebuilds everything from history.
        var renamed = entry
        renamed.name = "Back squat"
        state.updateWorkout(renamed)

        #expect(abs((state.user.best1RM[.squat] ?? 0) - logged) < 0.0001)
    }

    @Test func seedFactors() {
        let state = riteState()
        state.applyPlacement(record: verdict(ladderAnswers(str: 2)).makeRecord())

        // Rung 2 is "about my own bodyweight, for a clean single" at BW 80.
        let assessed = StatEngine.placementMetric(category: .squat, reps: 1, weight: 80,
                                                  durationMin: nil, distanceKm: nil, bodyweightKg: 80)
        #expect(abs(assessed - 80) < 0.0001)
        #expect(abs((state.user.best1RM[.squat] ?? 0) - 0.85 * 80) < 0.0001)
        #expect(abs((state.user.xpBaselines[.squat] ?? 0) - 0.90 * assessed) < 0.0001)
    }

    @Test func xpBaselineNoClobber() {
        let withExisting = riteState()
        withExisting.user.xpBaselines[.squat] = 999
        withExisting.applyPlacement(record: verdict(ladderAnswers(str: 4)).makeRecord())
        #expect(withExisting.user.xpBaselines[.squat] == 999)

        // A logged category owns its own EMA even when no baseline survived.
        let withHistory = riteState()
        _ = withHistory.logWorkout(name: "", category: .squat, sets: 1, reps: 5,
                                   weight: 100, durationMinutes: nil, distanceKm: nil)
        let live = withHistory.user.xpBaselines[.squat]
        withHistory.user.xpBaselines[.squat] = nil
        withHistory.applyPlacement(record: verdict(ladderAnswers(str: 4)).makeRecord())
        #expect(withHistory.user.xpBaselines[.squat] == nil)
        #expect(live != nil)
    }

    @Test func aQuieterRerunNeverErasesAnOlderSeed() {
        let state = riteState()
        state.applyPlacement(record: verdict(ladderAnswers(str: 2)).makeRecord())
        let seed = state.user.best1RM[.squat] ?? 0
        #expect(seed > 0)

        // The stored record is the fold-in's only seed source, so returning to
        // the stone and passing it unread must not unwrite the earlier page.
        var passing = WeighingAnswers()
        passing.skipped = true
        state.applyPlacement(record: verdict(passing).makeRecord(carryingOver: state.user.placement))
        #expect(abs((state.user.placement?.seeds[.squat] ?? 0) - seed) < 0.0001)

        _ = state.logWorkout(name: "", category: .benchPress, sets: 1, reps: 5,
                             weight: 60, durationMinutes: nil, distanceKm: nil)
        state.deleteWorkout(at: IndexSet(integer: 0))
        #expect((state.user.best1RM[.squat] ?? 0) >= seed)
    }

    @Test func rerunCannotRaiseARealHistoryCategoryFloor() {
        let state = riteState()

        // A modest first reading creates a floor before any real training.
        state.applyPlacement(record: verdict(ladderAnswers(str: 2)).makeRecord())
        let originalSeed = state.user.placement?.seeds[.squat] ?? 0
        #expect(originalSeed > 0)

        // A real single now owns squat, and beats that original floor.
        _ = state.logWorkout(name: "", category: .squat, sets: 1, reps: 1,
                             weight: 100, durationMinutes: nil, distanceKm: nil)
        let loggedPR = state.user.best1RM[.squat] ?? 0
        #expect(loggedPR > originalSeed)

        // The top self-reported rung would otherwise install a 129.2 kg floor
        // for an 80 kg athlete. It must preserve the pre-history seed instead.
        let inflated = verdict(ladderAnswers(str: 4)).makeRecord(carryingOver: state.user.placement)
        #expect((inflated.seeds[.squat] ?? 0) > loggedPR)
        state.applyPlacement(record: inflated)

        #expect(abs((state.user.best1RM[.squat] ?? 0) - loggedPR) < 0.0001)
        #expect(abs((state.user.placement?.seeds[.squat] ?? 0) - originalSeed) < 0.0001)

        state.recalculateStatsAndXP()
        #expect(abs((state.user.best1RM[.squat] ?? 0) - loggedPR) < 0.0001)
    }

    @Test func customVariationDoesNotOwnItsBasePlacementCategory() {
        let state = riteState()
        state.applyPlacement(record: verdict(ladderAnswers(str: 2)).makeRecord())
        let originalSeed = state.user.placement?.seeds[.squat] ?? 0

        _ = state.logWorkout(name: "Tempo Squat", category: .squat, sets: 1,
                             reps: 1, weight: 100, durationMinutes: nil,
                             distanceKm: nil, customExerciseID: UUID())
        #expect(!state.historyOwnedPlacementCategories.contains(.squat))

        let stronger = verdict(ladderAnswers(str: 4))
            .makeRecord(carryingOver: state.user.placement)
        let strongerSeed = stronger.seeds[.squat] ?? 0
        #expect(strongerSeed > originalSeed)
        state.applyPlacement(record: stronger)

        #expect(abs((state.user.placement?.seeds[.squat] ?? 0) - strongerSeed) < 0.0001)
    }

    @Test func warmupOnlyEntryDoesNotOwnItsPlacementCategory() {
        let state = riteState()
        state.applyPlacement(record: verdict(ladderAnswers(str: 2)).makeRecord())
        let originalSeed = state.user.placement?.seeds[.squat] ?? 0

        _ = state.logWarmupOnlyExercise(
            name: "Squat",
            category: .squat,
            performedSets: [PerformedSet(reps: 5, weightKg: 40, isWarmup: true)],
            sessionID: UUID(),
            customExerciseID: nil
        )
        #expect(!state.historyOwnedPlacementCategories.contains(.squat))

        let stronger = verdict(ladderAnswers(str: 4))
            .makeRecord(carryingOver: state.user.placement)
        let strongerSeed = stronger.seeds[.squat] ?? 0
        #expect(strongerSeed > originalSeed)
        state.applyPlacement(record: stronger)

        #expect(abs((state.user.placement?.seeds[.squat] ?? 0) - strongerSeed) < 0.0001)
    }

    @Test func onlyAMeasurableBuiltInRunOwnsRoadPlacement() {
        let state = riteState()
        _ = state.logWorkout(name: "Run", category: .run, reps: nil, weight: nil,
                             durationMinutes: 30, distanceKm: nil)
        #expect(!state.historyOwnedPlacementCategories.contains(.run))

        _ = state.logWorkout(name: "Run", category: .run, reps: nil, weight: nil,
                             durationMinutes: 30, distanceKm: 5)
        #expect(state.historyOwnedPlacementCategories.contains(.run))
    }

    @Test func skipWritesOnlyRecord() {
        let state = riteState()
        var answers = WeighingAnswers()
        answers.skipped = true
        let v = verdict(answers)
        let xpBefore = state.user.xp
        let levelBefore = state.user.level

        state.applyPlacement(record: v.makeRecord())

        #expect(state.user.placement != nil)
        #expect(state.user.placement?.skipped == true)
        #expect(state.user.placement?.seeds.isEmpty == true)
        #expect(state.user.best1RM.isEmpty)
        #expect(state.user.xpBaselines.isEmpty)
        #expect(state.user.bonusXP == 0)
        #expect(state.user.xp == xpBefore)
        #expect(state.user.level == levelBefore)
        #expect(v.epithet == PlacementRite.unwrittenEpithet)
    }
}

// MARK: - The ladders and the map

struct PlacementBandTests {

    @Test func bandBoundaries() {
        #expect(PlacementBand.from(level: 14) == .gate)
        #expect(PlacementBand.from(level: 15) == .kindlingVale)
        #expect(PlacementBand.from(level: 34) == .kindlingVale)
        #expect(PlacementBand.from(level: 35) == .ashenPasses)
        #expect(PlacementBand.from(level: 59) == .ashenPasses)
        #expect(PlacementBand.from(level: 60) == .stormreach)
        #expect(PlacementBand.from(level: 79) == .stormreach)
        #expect(PlacementBand.from(level: 80) == .crownOfDawn)
        #expect(PlacementBand.from(level: 94) == .crownOfDawn)
        #expect(PlacementBand.from(level: 95) == .elderWilds)
    }

    @Test func pushUpAnchorsMonotonicAndGrounded() {
        #expect(PlacementRite.pushUpLevel(reps: 12) == 20)
        #expect(PlacementRite.pushUpLevel(reps: 30) == 45)
        #expect(PlacementRite.pushUpLevel(reps: 0) == 0)

        var previous = -1
        for reps in 0...100 {
            let level = PlacementRite.pushUpLevel(reps: reps)
            #expect(level >= previous)
            #expect((0...100).contains(level))
            previous = level
        }
        // Self-report can reach Stormreach; the Crown is drawer-only.
        #expect(PlacementRite.pushUpLevel(reps: 200) <= 100)
    }

    @Test func ladderDirectLevels() {
        let expected: [(PlacementRite.Ladder, [(Int, PlacementBand)])] = [
            (PlacementRite.ironLadder, [(5, .gate), (8, .gate), (25, .kindlingVale), (45, .ashenPasses), (62, .stormreach)]),
            (PlacementRite.bodyLadder, [(2, .gate), (8, .gate), (20, .kindlingVale), (38, .ashenPasses), (62, .stormreach)]),
            (PlacementRite.roadLadder, [(5, .gate), (15, .kindlingVale), (25, .kindlingVale), (45, .ashenPasses), (65, .stormreach)])
        ]

        for (ladder, table) in expected {
            #expect(ladder.rungs.count == table.count)
            for (index, pair) in table.enumerated() {
                #expect(ladder.rungs[index].level == pair.0)
                #expect(ladder.rungs[index].band == pair.1)
            }
        }

        // The verdict must read those levels, not re-derive them from the engine.
        for index in 0..<5 {
            let v = verdict(ladderAnswers(str: index, dex: index, end: index))
            #expect(v.bands[.strength] == PlacementRite.ironLadder.rungs[index].band)
            #expect(v.bands[.dexterity] == PlacementRite.bodyLadder.rungs[index].band)
            #expect(v.bands[.endurance] == PlacementRite.roadLadder.rungs[index].band)
        }
        // The road never seeds — minutes without distance underdetermine both curves.
        #expect(verdict(ladderAnswers(end: 4)).seeds.isEmpty)
    }
}

// MARK: - The drawer

struct PlacementDrawerTests {

    @Test func drawerRepsAlwaysValid() {
        for reps in PlacementRite.repsRange {
            for lift in PlacementRite.drawerLifts {
                #expect(StatEngine.estimate1RM(category: lift, reps: reps, weight: 100) > 0)
                let outcome = PlacementRite.ironReading(lift: lift, weightKg: 100, reps: reps,
                                                        bodyweightKg: 80, units: .kg)
                #expect(outcome.value != nil)
                #expect((outcome.value?.estKg ?? 0) > 0)
            }
        }
    }

    @Test func walkerGuard() {
        // 5 km in 60 min = 5 km/h. The engine's lowest anchor clamps this to 25.
        let raw = StatEngine.placementLevelCandidate(category: .run, reps: nil, weight: nil,
                                                     durationMin: 60, distanceKm: 5, bodyweightKg: 80)
        #expect(raw >= 25)

        let reading = PlacementRite.roadReading(minutes: 60, km: 5, bodyweightKg: 80, units: .kg).value
        #expect(reading != nil)
        #expect((reading?.level ?? 99) <= PlacementRite.walkerLevelCap)
        #expect(reading?.band == .gate)
    }

    @Test func sanityClamp() {
        // A 4×BW squat claim at BW 80: 320 kg for a single.
        let reading = PlacementRite.ironReading(lift: .squat, weightKg: 320, reps: 1,
                                                bodyweightKg: 80, units: .kg).value
        #expect(reading?.clamped == true)
        #expect(abs((reading?.estKg ?? 0) - 3.0 * 80) < 0.0001)

        var answers = ladderAnswers(fire: 3)
        answers.drawerLift = .squat
        answers.drawerWeightKg = 320
        answers.drawerReps = 1
        let v = verdict(answers)
        #expect(v.ironClamped)
        #expect(abs((v.seeds[.squat] ?? 0) - 0.85 * 3.0 * 80) < 0.0001)
    }

    @Test func drawerRejectionsAreVisible() {
        #expect(PlacementRite.ironReading(lift: .squat, weightKg: 900, reps: 5,
                                          bodyweightKg: 80, units: .kg).problem == .weightOutOfRange)
        #expect(PlacementRite.bodyReading(pushUps: 500).problem == .pushUpsOutOfRange)
        // 1 km in 60 min = 1 km/h.
        #expect(PlacementRite.roadReading(minutes: 60, km: 1, bodyweightKg: 80, units: .kg).problem == .paceImplausible)
    }

    @Test func drawerStaysShutBelowWarmEmbers() {
        var answers = ladderAnswers(fire: 1, str: 1)
        answers.drawerLift = .deadlift
        answers.drawerWeightKg = 200
        answers.drawerReps = 1
        let v = verdict(answers)

        #expect(!v.usedDrawer)
        #expect(v.bands[.strength] == PlacementRite.ironLadder.rungs[1].band)
    }
}

// MARK: - The fire

struct PlacementFireTests {

    @Test func fireGatesSeeds() {
        let cold = verdict(ladderAnswers(fire: 0, str: 3, dex: 3))
        #expect(cold.seeds.isEmpty)
        #expect(cold.baselineSeeds.isEmpty)
        #expect(cold.bands[.strength] == .ashenPasses)
        #expect(cold.bands[.dexterity] == .ashenPasses)

        let rekindled = verdict(ladderAnswers(fire: 1, str: 3, dex: 3))
        let hot = verdict(ladderAnswers(fire: 3, str: 3, dex: 3))
        #expect(rekindled.bands[.strength] == hot.bands[.strength])
        #expect(rekindled.bands[.dexterity] == hot.bands[.dexterity])
        for (category, seed) in hot.seeds {
            #expect(abs((rekindled.seeds[category] ?? 0) - 0.7 * seed) < 0.0001)
        }
        #expect(!rekindled.seeds.isEmpty)
    }
}

// MARK: - Naming

struct PlacementEpithetTests {

    @Test func epithetSelection() {
        // Overrides, in precedence order.
        var skipped = WeighingAnswers()
        skipped.skipped = true
        #expect(verdict(skipped).epithet == PlacementRite.unwrittenEpithet)

        #expect(verdict(ladderAnswers(str: 0, dex: 0, end: 0)).epithet == PlacementRite.unlitEmberEpithet)
        #expect(verdict(ladderAnswers(fire: 1, str: 2)).epithet == PlacementRite.rekindledEpithet)
        // Duelist trains Strength & Dexterity; both land in the Kindling Vale.
        #expect(verdict(ladderAnswers(str: 2, dex: 2), rpgClass: .quality).epithet == PlacementRite.evenFlameEpithet)

        // Grid lookup on the vanguard.
        let loadbearer = verdict(ladderAnswers(str: 3), rpgClass: .warrior)
        #expect(loadbearer.vanguard == .strength)
        #expect(loadbearer.epithet.name == "the Loadbearer")

        // Tie broken by the class's own attributes: Ranger trains END first.
        let ranger = verdict(ladderAnswers(str: 3, end: 3), rpgClass: .ranger)
        #expect(ranger.vanguard == .endurance)
        #expect(ranger.epithet.name == "the Pacekeeper")

        // Remaining ties fall back to STR > END > DEX.
        let classless = verdict(ladderAnswers(str: 3, end: 3))
        #expect(classless.vanguard == .strength)
        #expect(classless.epithet.name == "the Loadbearer")
    }

    @Test func ledgerRowsAndClosingLines() {
        let v = verdict(ladderAnswers(str: 3), rpgClass: .warrior)
        #expect(v.rows.map(\.stat) == PlacementRite.ledgerOrder)
        // Size is inferred one band below strength and never seeds.
        #expect(v.bands[.strength] == .ashenPasses)
        #expect(v.rows.first(where: { $0.stat == .size })?.band == .kindlingVale)
        #expect(v.rows.first(where: { $0.stat == .size })?.inferred == true)
        #expect(v.seeds[.squat] != nil)
        #expect(v.headline == "Warrior, the Loadbearer")
        #expect(v.closingLine == PlacementCopy.closingDefault)

        // Unwritten by design.
        #expect(v.rows.first(where: { $0.stat == .agility })?.band == .unwritten)
        #expect(v.rows.first(where: { $0.stat == .vitality })?.band == .unwritten)
        #expect(v.rows.first(where: { $0.stat == .dexterity })?.aphorism == PlacementRite.unwrittenRowLine)

        // No class → the epithet stands alone.
        #expect(verdict(ladderAnswers(str: 3)).headline == "the Loadbearer")

        var skipped = WeighingAnswers()
        skipped.skipped = true
        #expect(verdict(skipped).closingLine == PlacementCopy.closingSkip)
        #expect(verdict(ladderAnswers(str: 0)).closingLine == PlacementCopy.closingAllGate)
    }

    @Test func narrationSaysOnlyWhatIsOnScreen() {
        // The skip rite renders no ledger, so it must not read six rows aloud.
        var skipped = WeighingAnswers()
        skipped.skipped = true
        let quiet = verdict(skipped)
        for row in quiet.rows {
            #expect(!quiet.narration.contains(row.accessibilityLine))
        }
        #expect(quiet.narration.contains(quiet.epithet.aphorism))
        #expect(quiet.narration.contains(quiet.closingLine))

        let written = verdict(ladderAnswers(str: 3), rpgClass: .warrior)
        #expect(written.narration.contains(written.headline))
        for row in written.rows {
            #expect(written.narration.contains(row.accessibilityLine))
        }
        #expect(written.narration.contains(written.closingLine))
    }
}

// MARK: - Returning to the stone

struct PlacementRerunTests {

    @Test func rerunRestoresWhatWasSaid() {
        // Iron rung 1 shares the Gate with rung 0 and is the only one of the
        // two that seeds, so a band-to-rung guess would silently drop it. The
        // drawer names a deadlift, which belongs to no rung at all.
        var answers = ladderAnswers(str: 1, dex: 1, end: 2)
        answers.drawerLift = .deadlift
        answers.drawerWeightKg = 180
        answers.drawerReps = 3
        let record = verdict(answers).makeRecord()

        let restored = WeighingAnswers(restoring: record)
        #expect(restored.strIndex == 1)
        #expect(restored.dexIndex == 1)
        #expect(restored.endIndex == 2)
        #expect(restored.drawerLift == .deadlift)
        #expect(restored.drawerWeightKg == 180)
        #expect(restored.drawerReps == 3)
        #expect(!restored.skipped)

        // A re-run that edits nothing seals exactly the reading it restored.
        #expect(verdict(restored).bands == verdict(answers).bands)
        #expect(verdict(restored).seeds == verdict(answers).seeds)
        #expect(verdict(restored).seeds[.deadlift] != nil)
        #expect(verdict(restored).seeds[.squat] == nil)

        // And never invents a baseline for a lift the player never claimed —
        // applyPlacement writes xpBaselines once and can never correct itself.
        let state = riteState()
        state.applyPlacement(record: record)
        state.applyPlacement(record: verdict(restored).makeRecord(carryingOver: state.user.placement))
        #expect(state.user.xpBaselines[.squat] == nil)
        #expect((state.user.xpBaselines[.deadlift] ?? 0) > 0)
    }

    @Test func aRecordWithoutAnswersGuessesNothing() {
        var record = verdict(ladderAnswers(fire: 2, str: 4)).makeRecord()
        record.answers = nil

        let restored = WeighingAnswers(restoring: record)
        #expect(restored.fireIndex == 2)
        #expect(restored.strIndex == nil)
        #expect(restored.dexIndex == nil)
        #expect(restored.endIndex == nil)
    }

    @Test func aDrawerTheFireShutAwayIsNotAReading() {
        // Typed while the embers were warm, then the fire was moved back down.
        var staged = WeighingAnswers()
        staged.fireIndex = 1
        staged.drawerPushUps = 30
        #expect(!verdict(staged).hasReading)
        #expect(verdict(staged).isSkip)

        var warm = staged
        warm.fireIndex = 2
        #expect(verdict(warm).hasReading)
        #expect(verdict(ladderAnswers(str: 0)).hasReading)
    }
}

// MARK: - Ledger and persistence

struct PlacementRecordTests {

    @Test func bonusXPIdempotent() {
        let state = riteState()
        let record = verdict(ladderAnswers(str: 2)).makeRecord()

        state.applyPlacement(record: record)
        #expect(state.user.bonusXP == PlacementRite.honestyBonusXP)
        #expect(state.user.placement?.bonusGranted == true)

        // A Settings re-run builds a fresh record whose flag is still false.
        state.applyPlacement(record: record)
        #expect(state.user.bonusXP == PlacementRite.honestyBonusXP)

        state.applyPlacement(record: verdict(ladderAnswers(str: 4)).makeRecord())
        #expect(state.user.bonusXP == PlacementRite.honestyBonusXP)
    }

    @Test func decodeMissingPlacementKey() throws {
        let json = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: json)
        #expect(decoded.placement == nil)

        // And a written record round-trips.
        var profile = UserProfile()
        profile.placement = verdict(ladderAnswers(str: 3)).makeRecord()
        let data = try JSONEncoder().encode(profile)
        let back = try JSONDecoder().decode(UserProfile.self, from: data)
        #expect(back.placement?.epithet == "the Loadbearer")
        #expect(back.placement?.band(for: .strength) == .ashenPasses)
        #expect((back.placement?.seeds[.squat] ?? 0) > 0)
    }

    @Test func answersRoundTripThroughTheProfile() throws {
        var answers = ladderAnswers(str: 1)
        answers.drawerPushUps = 30

        var profile = UserProfile()
        profile.placement = verdict(answers).makeRecord()
        let back = try JSONDecoder().decode(UserProfile.self, from: JSONEncoder().encode(profile))

        #expect(back.placement?.answers?.strIndex == 1)
        #expect(back.placement?.answers?.drawerPushUps == 30)
        #expect(back.placement?.answers?.fireIndex == 3)
    }
}
