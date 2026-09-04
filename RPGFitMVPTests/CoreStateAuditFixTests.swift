import Foundation
import Testing
@testable import RPGFitMVP

private func auditState() -> AppState {
    let state = AppState(persistenceEnabled: false)
    state.user = UserProfile()
    state.history = []
    return state
}

private func auditEntry(
    date: Date,
    category: ExerciseCategory,
    xp: Double = 10,
    previousLevel: Int? = 1
) -> WorkoutEntry {
    WorkoutEntry(
        id: UUID(),
        date: date,
        name: category.displayName,
        category: category,
        sets: 1,
        reps: category.focus == .endurance ? nil : 5,
        weight: category.focus == .endurance ? nil : 50,
        durationMinutes: category.focus == .endurance ? 20 : nil,
        distanceKm: nil,
        statGains: .zero,
        expGained: xp,
        prevLevel: previousLevel,
        newLevel: previousLevel
    )
}

struct ReplayableWorkoutRewardTests {

    @Test func deletingSpentTrialMightCreatesDebtThatReloggingMustRepay() throws {
        let state = auditState()
        let first = state.logWorkout(
            name: "Squat",
            category: .squat,
            sets: 3,
            reps: 5,
            weight: 100,
            durationMinutes: nil,
            distanceKm: nil
        )
        let firstMight = try #require(first.trialMightGained)
        #expect(firstMight > 0)

        // Model already-consumed might without revoking the resolved trophy.
        state.user.trialMight = 0
        state.user.trialRung = 1
        state.user.trialVictories = [
            TrialVictory(rung: 0, bossName: "Ember Wisp", date: Date())
        ]
        state.deleteWorkout(at: IndexSet(integer: 0))

        #expect(abs(state.user.trialMightDebt - firstMight) < 0.000_001)
        #expect(state.user.trialMight == 0)
        #expect(state.user.trialRung == 1)
        #expect(state.user.trialVictories.count == 1)

        let replacement = state.logWorkout(
            name: "Squat",
            category: .squat,
            sets: 3,
            reps: 5,
            weight: 100,
            durationMinutes: nil,
            distanceKm: nil
        )
        let replacementMight = try #require(replacement.trialMightGained)
        #expect(abs(state.user.trialMight - max(0, replacementMight - firstMight)) < 0.000_001)
        #expect(abs(state.user.trialMightDebt - max(0, firstMight - replacementMight)) < 0.000_001)
    }

    @Test func deletingSpentMaxLevelCoinsCreatesDebtThatReloggingMustRepay() throws {
        let state = auditState()
        state.user.level = StatEngine.maxLevel
        state.user.xp = 1
        state.user.nextLevelXP = 1

        let first = state.logWorkout(
            name: "Squat",
            category: .squat,
            sets: 3,
            reps: 5,
            weight: 100,
            durationMinutes: nil,
            distanceKm: nil
        )
        let firstCoins = try #require(first.endgameCoinsGained)
        #expect(firstCoins > 0)

        // The coins were spent already; deletion must preserve the purchase
        // and carry a debt rather than forcing the balance below zero.
        state.user.coins = 0
        state.user.ownedAccessories = ["keepsake"]
        state.deleteWorkout(at: IndexSet(integer: 0))
        #expect(state.user.endgameCoinDebt == firstCoins)
        #expect(state.user.coins == 0)
        #expect(state.user.ownedAccessories == ["keepsake"])

        state.user.level = StatEngine.maxLevel
        state.user.xp = 1
        state.user.nextLevelXP = 1
        let replacement = state.logWorkout(
            name: "Squat",
            category: .squat,
            sets: 3,
            reps: 5,
            weight: 100,
            durationMinutes: nil,
            distanceKm: nil
        )
        let replacementCoins = try #require(replacement.endgameCoinsGained)
        #expect(state.user.coins == max(0, replacementCoins - firstCoins))
        #expect(state.user.endgameCoinDebt == max(0, firstCoins - replacementCoins))
    }

    @Test func rewardAttributionAndDebtRoundTrip() throws {
        var entry = auditEntry(date: Date(), category: .squat)
        entry.trialMightGained = 12.5
        entry.endgameCoinsGained = 5
        var user = UserProfile()
        user.trialMightDebt = 7.25
        user.endgameCoinDebt = 3

        let encoded = try AppState.jsonEncoder.encode(PersistedData(user: user, history: [entry]))
        let decoded = try AppState.jsonDecoder.decode(PersistedData.self, from: encoded)

        #expect(decoded.history[0].trialMightGained == 12.5)
        #expect(decoded.history[0].endgameCoinsGained == 5)
        #expect(decoded.user.trialMightDebt == 7.25)
        #expect(decoded.user.endgameCoinDebt == 3)
    }

    @Test func preAttributionSaveDecodesAndMigratesWithoutDebtFields() throws {
        var user = UserProfile()
        user.level = 2 // Keep semantic save validation from treating this as a wiped profile.
        let entry = auditEntry(date: Date(), category: .squat, xp: 12)
        let encoded = try AppState.jsonEncoder.encode(
            PersistedData(user: user, history: [entry], schemaVersion: 4)
        )

        var root = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var legacyUser = try #require(root["user"] as? [String: Any])
        legacyUser.removeValue(forKey: "trialMightDebt")
        legacyUser.removeValue(forKey: "endgameCoinDebt")
        root["user"] = legacyUser
        var legacyHistory = try #require(root["history"] as? [[String: Any]])
        legacyHistory[0].removeValue(forKey: "trialMightGained")
        legacyHistory[0].removeValue(forKey: "endgameCoinsGained")
        root["history"] = legacyHistory

        let legacyData = try JSONSerialization.data(withJSONObject: root)
        let state = auditState()
        try state.replaceState(withValidatedSave: legacyData)

        #expect(state.user.trialMightDebt == 0)
        #expect(state.user.endgameCoinDebt == 0)
        #expect(state.history[0].trialMightGained == 12)
        #expect(state.history[0].endgameCoinsGained == 0)
    }
}

struct BaselineReplayTests {

    @Test func directPerformanceEditRecomputesRewardsAndBaseline() throws {
        let state = auditState()
        let original = state.logWorkout(
            name: "Bad entry",
            category: .squat,
            sets: 1,
            reps: 5,
            weight: 1_000,
            durationMinutes: nil,
            distanceKm: nil
        )

        var corrected = original
        corrected.weight = 100
        // Deliberately leave the old rewards in place: updateWorkout itself,
        // not just EditWorkoutView, must make this correction coherent.
        state.updateWorkout(corrected)

        let saved = try #require(state.history.first)
        let perf = StatEngine.placementMetric(
            category: .squat,
            reps: 5,
            weight: 100,
            durationMin: nil,
            distanceKm: nil,
            bodyweightKg: state.user.bodyweightKg
        )
        let expectedXP = (StatEngine.estimatedXP(
            category: .squat,
            perf: perf,
            baseline: nil,
            sets: 1
        ) * 10).rounded() / 10
        let score = StatEngine.intensityScore(
            category: .squat,
            reps: 5,
            weight: 100,
            durationMin: nil,
            distanceKm: nil
        )

        #expect(saved.expGained == expectedXP)
        #expect(saved.statGains == StatEngine.statGains(for: .squat, score: score).scaled(10))
        #expect(abs((state.user.xpBaselines[.squat] ?? 0) - perf) < 0.000_001)
        #expect(abs(state.user.trialMight - (saved.trialMightGained ?? 0)) < 0.000_001)
    }

    @Test func deletingOutlierRebuildsBaselineFromRemainingHistory() throws {
        let state = auditState()
        _ = state.logWorkout(
            name: "Squat",
            category: .squat,
            sets: 1,
            reps: 5,
            weight: 100,
            durationMinutes: nil,
            distanceKm: nil
        )
        let honestBaseline = try #require(state.user.xpBaselines[.squat])

        _ = state.logWorkout(
            name: "Bad entry",
            category: .squat,
            sets: 1,
            reps: 5,
            weight: 1_000,
            durationMinutes: nil,
            distanceKm: nil
        )
        #expect((state.user.xpBaselines[.squat] ?? 0) > honestBaseline)

        state.deleteWorkout(at: IndexSet(integer: 0))

        let rebuilt = try #require(state.user.xpBaselines[.squat])
        #expect(abs(rebuilt - honestBaseline) < 0.000_001)
    }
}

struct FocusStreakCalendarDayTests {

    @Test func multipleExercisesOnOneDayCountOnce() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 2, hour: 18
        )))
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let twoDaysAgo = try #require(calendar.date(byAdding: .day, value: -2, to: today))

        let state = auditState()
        state.history = [
            auditEntry(date: today.addingTimeInterval(8 * 3_600), category: .run),
            auditEntry(date: today.addingTimeInterval(10 * 3_600), category: .cycle),
            auditEntry(date: today.addingTimeInterval(12 * 3_600), category: .rower),
            auditEntry(date: yesterday.addingTimeInterval(9 * 3_600), category: .run),
            auditEntry(date: yesterday.addingTimeInterval(17 * 3_600), category: .cycle),
            auditEntry(date: twoDaysAgo.addingTimeInterval(9 * 3_600), category: .run)
        ]

        let info = state.focusStreakInfo(for: .endurance, asOf: now, calendar: calendar)
        #expect(info.streak == 3)
        #expect(info.gapDays == 0)
    }
}

struct CalendarWeekQuestTests {

    @Test func rolloverReplacesPriorWeekInsteadOfOverlappingIt() throws {
        let state = auditState()
        state.user.rpgClass = .warrior

        let thisWeek = AppState.weeklyQuestInterval(containing: Date())
        let firstGeneration = try #require(
            Calendar.current.date(byAdding: .day, value: 2, to: thisWeek.start)
        )
        state.generateWeeklyChallenges(asOf: firstGeneration)
        let oldIDs = Set(state.user.weeklyChallenges.map(\.id))

        #expect(state.user.weeklyChallenges.count == 2)
        #expect(state.user.weeklyChallenges.allSatisfy { $0.expiresAt == thisWeek.end })

        let nextGeneration = try #require(
            Calendar.current.date(byAdding: .hour, value: 1, to: thisWeek.end)
        )
        let nextWeek = AppState.weeklyQuestInterval(containing: nextGeneration)
        state.generateWeeklyChallenges(asOf: nextGeneration)

        #expect(state.user.weeklyChallenges.count == 2)
        #expect(state.user.weeklyChallenges.allSatisfy { !oldIDs.contains($0.id) })
        #expect(state.user.weeklyChallenges.allSatisfy { $0.expiresAt == nextWeek.end })
        #expect(state.user.weeklyChallenges.allSatisfy {
            AppState.weeklyQuestInterval(containing: $0.createdAt).start == nextWeek.start
        })
    }
}
