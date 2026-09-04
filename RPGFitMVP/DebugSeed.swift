#if DEBUG
import Foundation

// MARK: - Screenshot seeding (debug builds only)
//
// One tap in Developer Tools produces a lived-in month: progressing lifts
// with real per-set records, cardio sprinkled through, a saved routine,
// and chests waiting to open. Everything flows through logWorkout so XP,
// streaks, quests, and records stay engine-honest.

extension AppState {

    func seedScreenshotData() {
        let calendar = Calendar.current

        func backdate(_ daysAgo: Int) {
            guard !history.isEmpty else { return }
            history[0].date = calendar.date(byAdding: .day, value: -daysAgo,
                                            to: Date()) ?? Date()
        }

        func lift(_ daysAgo: Int, _ category: ExerciseCategory,
                  _ sets: [(Int, Double)], warmup: (Int, Double)? = nil,
                  sessionID: UUID? = nil) {
            var performed = sets.map { PerformedSet(reps: $0.0, weightKg: $0.1) }
            if let warmup {
                performed.insert(PerformedSet(reps: warmup.0, weightKg: warmup.1,
                                              isWarmup: true), at: 0)
            }
            let top = sets.max(by: { $0.0 * Int($0.1) < $1.0 * Int($1.1) }) ?? sets[0]
            _ = logWorkout(name: "", category: category, sets: sets.count,
                           reps: top.0, weight: top.1, durationMinutes: nil,
                           distanceKm: nil, sessionID: sessionID,
                           performedSets: performed)
            backdate(daysAgo)
        }

        func bodyweight(_ daysAgo: Int, _ category: ExerciseCategory,
                        sets: Int, reps: Int, sessionID: UUID? = nil) {
            _ = logWorkout(name: "", category: category, sets: sets, reps: reps,
                           weight: nil, durationMinutes: nil, distanceKm: nil,
                           sessionID: sessionID)
            backdate(daysAgo)
        }

        func cardio(_ daysAgo: Int, _ category: ExerciseCategory,
                    minutes: Double, km: Double?) {
            _ = logWorkout(name: "", category: category, sets: nil, reps: nil,
                           weight: nil, durationMinutes: minutes, distanceKm: km)
            backdate(daysAgo)
        }

        // Four weeks, oldest first, bench and squat visibly progressing.
        lift(27, .benchPress, [(8, 60), (8, 60), (8, 60)])
        lift(27, .squat, [(5, 80), (5, 80), (5, 80)])
        cardio(25, .run, minutes: 28, km: 4.2)
        lift(23, .benchPress, [(8, 62.5), (8, 62.5), (7, 62.5)])
        bodyweight(23, .pullUp, sets: 3, reps: 6)
        lift(20, .squat, [(5, 87.5), (5, 87.5), (5, 87.5)])
        cardio(18, .run, minutes: 31, km: 4.8)
        lift(16, .benchPress, [(6, 67.5), (6, 67.5), (6, 67.5)])
        bodyweight(16, .pullUp, sets: 3, reps: 8)
        lift(13, .squat, [(5, 95), (5, 95), (4, 95)])
        lift(11, .overheadPress, [(8, 40), (8, 40), (6, 42.5)])
        cardio(9, .run, minutes: 26, km: 4.5)
        lift(7, .benchPress, [(5, 72.5), (5, 72.5), (4, 75)])
        bodyweight(7, .pullUp, sets: 3, reps: 10)
        lift(4, .squat, [(3, 105), (3, 105), (3, 105)], warmup: (5, 60))

        // The most recent training is one full session (Repeat Last shows it).
        let session = UUID()
        lift(1, .benchPress, [(5, 75), (5, 75), (3, 77.5)], warmup: (8, 40),
             sessionID: session)
        bodyweight(1, .pullUp, sets: 3, reps: 11, sessionID: session)
        cardio(1, .rower, minutes: 12, km: 2.5)
        if let index = history.firstIndex(where: { $0.category == .rower }) {
            history[index].sessionID = session
        }

        // Level, streaks, and records replayed date-honestly.
        recalculateStatsAndXP()

        // A routine saved from the latest session, and loot to open.
        saveRoutine(named: "Push & Pull", from: lastSessionEntries)
        user.treasureChests.append(contentsOf: [
            StatEngine.generateTreasureChest(forLevel: 2),
            StatEngine.generateTreasureChest(forLevel: 5),
            StatEngine.generateTreasureChest(forLevel: user.level),
        ])

        // A complete matched loadout makes the Inventory screenshot explain
        // the equipment system and its set bonus instead of showing an empty
        // grid beside unopened chests. Debug seed data only; real gear remains
        // earned through play.
        let showcaseGear = [
            InventoryItem(name: "Wand of Stars",
                          description: "A star-lit training weapon.",
                          type: .equipment, rarity: .legendary,
                          iconName: "wand.and.stars", quantity: 1,
                          dateObtained: Date(), value: 500),
            InventoryItem(name: "Champion's Trophy",
                          description: "Proof of a hard-won campaign.",
                          type: .equipment, rarity: .legendary,
                          iconName: "trophy.fill", quantity: 1,
                          dateObtained: Date(), value: 500),
            InventoryItem(name: "Starforged Relic",
                          description: "A rune that sharpens every Trial strike.",
                          type: .equipment, rarity: .legendary,
                          iconName: "glyph:rune", quantity: 1,
                          dateObtained: Date(), value: 500),
        ]
        user.inventory.append(contentsOf: showcaseGear)
        for item in showcaseGear {
            user.equippedItems[item.equipSlot.rawValue] = item.id.uuidString
        }
        user.coins = max(user.coins, 240)

        // The Skills screenshot should demonstrate the companion loop, not an
        // empty placeholder. Keep the seed deterministic so repeat captures
        // show the same character and bond stage.
        user.hatchedCompanions = [CompanionSpecies.wisp.rawValue]
        user.activeCompanion = CompanionSpecies.wisp.rawValue
        user.companionNames[CompanionSpecies.wisp.rawValue] = "Ember"
        user.companionBondDays[CompanionSpecies.wisp.rawValue] = 8

        save(immediately: true)
    }
}
#endif
