import SwiftUI
import Foundation
import UserNotifications

final class AppState: ObservableObject {
    /// The app-wide instance every scene shares. Tests may still create
    /// their own throwaway AppState()s; the running app must not.
    static let shared = AppState()

    @Published var user: UserProfile
    @Published var history: [WorkoutEntry] {
        didSet {
            clearCache()
        }
    }

    // Cache for expensive operations
    private var cachedSortedHistory: [WorkoutEntry]?
    private var cachedGroupedWorkouts: [(String, [WorkoutEntry])]?
    private var cacheValidationTime: Date?
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    // Keep backup creation and state writes serialized to avoid file replacement races.
    private let persistenceQueue = DispatchQueue(label: "com.devoncheng.RPGFitMVP.persistence", qos: .utility)
    /// Unit tests that exercise pure game logic use an in-memory state so
    /// parallel test cases cannot race through the app's real Documents
    /// directory. The running app always uses the default persisted mode.
    private let persistenceEnabled: Bool
    private var pendingSaveWorkItem: DispatchWorkItem?

    private enum PersistenceSource {
        case primary
        case backup
        case fallback
    }

    private struct PersistedLoadResult {
        let data: PersistedData
        let source: PersistenceSource
        let requiresRewrite: Bool
    }

    enum SaveValidationError: LocalizedError {
        case implausibleProfile

        var errorDescription: String? {
            switch self {
            case .implausibleProfile:
                return "This backup is incomplete or damaged and was not restored."
            }
        }
    }

    // A stray NaN/∞ that slips into any stored Double must never brick every
    // future save (the default nonConformingFloat strategy is .throw, which
    // would fail performSave forever while the poisoned value sits in memory).
    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return encoder
    }()
    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return decoder
    }()

    func seedSampleData() {
        _ = history.count
        // Simple demo data (uses current units for input, but we convert to kg)
        _ = logWorkout(name: "Bench", category: .benchPress, reps: 5, weight: user.units == .kg ? 80 : 176, durationMinutes: nil, distanceKm: nil)
        // Distances entered in the user's display units, then converted to km for storage
        let runDisplayDist = user.units == .kg ? 4.2 : 2.6   // ~4.2 km ≈ 2.6 mi
        let cycleDisplayDist = user.units == .kg ? 18.0 : 11.2 // ~18 km ≈ 11.2 mi
        let runKm = user.units.toKm(runDisplayDist)
        let cycleKm = user.units.toKm(cycleDisplayDist)
        _ = logWorkout(name: "Run", category: .run, reps: nil, weight: nil, durationMinutes: 25, distanceKm: runKm)
        _ = logWorkout(name: "Squat", category: .squat, reps: 5, weight: user.units == .kg ? 120 : 265, durationMinutes: nil, distanceKm: nil)
        _ = logWorkout(name: "Pull-Ups", category: .pullUp, reps: 10, weight: nil, durationMinutes: nil, distanceKm: nil)
        _ = logWorkout(name: "Cycle", category: .cycle, reps: nil, weight: nil, durationMinutes: 40, distanceKm: cycleKm)

        // Add sample treasure chests for demo
        let sampleChest1 = StatEngine.generateTreasureChest(forLevel: 2)
        let sampleChest2 = StatEngine.generateTreasureChest(forLevel: 5)
        let sampleChest3 = StatEngine.generateTreasureChest(forLevel: 25) // Special level for higher tier
        user.treasureChests.append(contentsOf: [sampleChest1, sampleChest2, sampleChest3])

    }

    /// Reset means reset: deletes every stored artifact — primary save,
    /// backup (and its temp), the caches fallback, and the app's entire
    /// UserDefaults domain (onboarding flag, workout draft, and any future
    /// @AppStorage key) — then writes a fresh profile. Deliberately does NOT
    /// route the wipe through the normal save path alone: performSave rotates
    /// the current file into the backup first, which would faithfully
    /// preserve the data the user just asked to destroy and offer to
    /// "restore" it later.
    func resetAll() {
        guard persistenceEnabled else {
            discardActiveSessionArtifacts()
            user = UserProfile()
            history = []
            persistenceError = nil
            inputWarning = nil
            return
        }

        // A debounced save scheduled before the wipe must not resurrect the
        // old profile after it.
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil

        // Runs on persistenceQueue ahead of the fresh save below (FIFO), so
        // the deletions land first and the fresh write can't rotate the old
        // profile into a new backup — createBackup's "primary exists" guard
        // fails once the file is gone.
        persistenceQueue.async {
            let fileManager = FileManager.default
            let stored = [Self.saveURL,
                          Self.backupURL,
                          Self.backupURL?.appendingPathExtension("tmp"),
                          Self.fallbackURL,
                          Self.saveURL?.deletingLastPathComponent()
                              .appendingPathComponent("rpgfit_mvp_corrupt.json")]
            for url in stored.compactMap({ $0 }) {
                try? fileManager.removeItem(at: url)
            }
        }

        // One canonical wipe for every key the app owns — a hand-kept key
        // list would silently miss the next @AppStorage addition. Keys are
        // removed individually rather than via removePersistentDomain, which
        // can leave freshly-written values visible in the in-process cache.
        let defaults = UserDefaults.standard
        if let bundleID = Bundle.main.bundleIdentifier,
           let ownedKeys = defaults.persistentDomain(forName: bundleID)?.keys {
            for key in ownedKeys {
                defaults.removeObject(forKey: key)
            }
        } else {
            ActiveSessionDraft.clear()
            defaults.removeObject(forKey: "hasSeenOnboarding")
            defaults.removeObject(forKey: "lastViewedLevel")
            defaults.removeObject(forKey: "hasUsedWorkoutContextMenu")
        }
        // Keep the reset outcome explicit while an in-process @AppStorage
        // observer is still alive. A removed key and `false` mean the same
        // thing at launch, but the explicit value prevents a cached `true`
        // from being written back before observers receive the domain wipe.
        defaults.set(false, forKey: "hasSeenOnboarding")

        discardActiveSessionArtifacts()

        self.user = UserProfile()
        self.history = []
        self.persistenceError = nil
        self.inputWarning = nil
        save(immediately: true)
    }

    init(persistenceEnabled: Bool = true) {
        self.persistenceEnabled = persistenceEnabled

        guard persistenceEnabled else {
            self.user = UserProfile()
            self.history = []
            return
        }

        if let loaded = Self.load() {
            self.user = loaded.data.user
            self.history = loaded.data.history
            runMigrations(from: loaded.data.schemaVersion)
            if loaded.requiresRewrite {
                save(immediately: true)
            }
            if loaded.source != .primary {
                // Recovery worked — say so instead of pretending nothing
                // happened (the restored state may be slightly older).
                pushToast(title: "Data Restored",
                          subtitle: loaded.source == .backup
                              ? "Your save file was unreadable — restored from the automatic backup"
                              : "Your save file was unreadable — restored from temporary storage",
                          icon: "arrow.counterclockwise.circle.fill", kind: .accent)
            }
        } else {
            // Nothing decoded. If store files exist this is corruption, not a
            // first launch — keep the unreadable file for recovery instead of
            // silently starting a fresh life over it.
            let fileManager = FileManager.default
            let hadStoredData = [Self.saveURL, Self.backupURL, Self.fallbackURL]
                .compactMap { $0 }
                .contains { fileManager.fileExists(atPath: $0.path) }
            self.user = UserProfile()
            self.history = []
            if hadStoredData {
                if let primaryURL = Self.saveURL, fileManager.fileExists(atPath: primaryURL.path) {
                    let archiveURL = primaryURL.deletingLastPathComponent()
                        .appendingPathComponent("rpgfit_mvp_corrupt.json")
                    try? fileManager.removeItem(at: archiveURL)
                    try? fileManager.copyItem(at: primaryURL, to: archiveURL)
                }
                persistenceError = "Your saved data couldn't be read, so the app started fresh. The unreadable file was kept as rpgfit_mvp_corrupt.json in the app's documents folder."
            }
        }
    }

    /// Applies every schema migration that launch and explicit restores need.
    /// Keeping this in one place prevents an older iCloud/local backup from
    /// bypassing work that the same save would receive during normal launch.
    private func runMigrations(from schemaVersion: Int) {
        if schemaVersion < 3 {
            // v3 changed the XP curve — renormalize level/XP from history
            // once so stored nextLevelXP matches the new curve.
            recalculateStatsAndXP()
        }
        if schemaVersion < 4 {
            // Pre-v4 saves regenerated inventory ids on every decode, so
            // every equipped-gear reference is dangling by now. Re-link
            // where unambiguous, come clean where not.
            relinkEquippedItemsAfterIDMigration()
        }
        if schemaVersion < 5 {
            migrateReplayableWorkoutRewardsAndWeeklyWindows()
        }
    }

    /// v5 gives every workout ownership of the spendable game-layer rewards
    /// it minted. Legacy files did not retain the original equipment/class
    /// multiplier, so use today's multiplier once and persist that estimate;
    /// from then on edit/delete/re-log accounting is exact and stable.
    private func migrateReplayableWorkoutRewardsAndWeeklyWindows() {
        history = history.map { entry in
            var migrated = entry
            if migrated.trialMightGained == nil {
                migrated.trialMightGained = trialMightReward(
                    from: migrated.expGained,
                    focus: migrated.category.focus
                )
            }
            if migrated.endgameCoinsGained == nil {
                migrated.endgameCoinsGained = legacyEndgameCoinReward(for: migrated)
            }
            return migrated
        }

        user.weeklyChallenges = user.weeklyChallenges.map(normalizedWeeklyChallenge)
    }

    /// The single state-replacement door for local and iCloud restores.
    /// Validation happens before any mutation; then migrations, session
    /// cleanup, and persistence happen in the same order for both sources.
    func replaceState(withValidatedSave data: Data) throws {
        let restored = try Self.decodeValidatedSave(data)

        // A queued write from the pre-restore profile must not land after the
        // restored state and make the replacement appear to revert.
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil

        user = restored.user
        history = restored.history
        runMigrations(from: restored.schemaVersion)
        discardActiveSessionArtifacts()
        persistenceError = nil
        inputWarning = nil
        save(immediately: true)
    }

    /// A restored profile cannot safely keep a draft or rest alert created
    /// against the profile it replaced.
    private func discardActiveSessionArtifacts() {
        ActiveSessionDraft.clear()
        let notificationID = "rpgfit.sessionRest"
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationID])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationID])

        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            Task { @MainActor in
                RestLiveActivity.end()
            }
        }
        #endif
    }

    // Input validation for workout values. NOTE: every numeric gate must
    // reject non-finite values explicitly — NaN compares false against ANY
    // bound, so `x < 0 || x > limit` silently passes it through.
    func validateWorkoutInputs(sets: Int? = nil, reps: Int?, weight: Double?, durationMinutes: Double?, distanceKm: Double?) -> (sets: Int?, reps: Int?, weight: Double?, duration: Double?, distance: Double?, isValid: Bool, error: String?) {
        var validatedSets = sets
        var validatedReps = reps
        var validatedWeight = weight
        var validatedDuration = durationMinutes
        var validatedDistance = distanceKm
        var errors: [String] = []

        // Validate sets (1-100)
        if let s = sets {
            if s < 1 {
                validatedSets = 1
                errors.append("Sets must be at least 1")
            } else if s > 100 {
                validatedSets = 100
                errors.append("Sets cannot exceed 100")
            }
        }

        // Validate reps (1-9999)
        if let r = reps {
            if r < 1 {
                validatedReps = 1
                errors.append("Reps must be at least 1")
            } else if r > 9999 {
                validatedReps = 9999
                errors.append("Reps cannot exceed 9999")
            }
        }

        // Validate weight (0.1-9999 kg)
        if let w = weight {
            if !w.isFinite {
                validatedWeight = nil
                errors.append("Weight must be a number")
            } else if w < 0 {
                validatedWeight = 0
                errors.append("Weight cannot be negative")
            } else if w > 9999 {
                validatedWeight = 9999
                errors.append("Weight cannot exceed 9999 kg")
            }
        }

        // Validate duration (0.1-1440 minutes = 24 hours)
        if let d = durationMinutes {
            if !d.isFinite {
                validatedDuration = nil
                errors.append("Duration must be a number")
            } else if d < 0 {
                validatedDuration = 0
                errors.append("Duration cannot be negative")
            } else if d > 1440 {
                validatedDuration = 1440
                errors.append("Duration cannot exceed 24 hours")
            }
        }

        // Validate distance (0.001-9999 km)
        if let dist = distanceKm {
            if !dist.isFinite {
                validatedDistance = nil
                errors.append("Distance must be a number")
            } else if dist < 0 {
                validatedDistance = 0
                errors.append("Distance cannot be negative")
            } else if dist > 9999 {
                validatedDistance = 9999
                errors.append("Distance cannot exceed 9999 km")
            }
        }

        let errorMessage = errors.isEmpty ? nil : errors.joined(separator: "; ")
        return (validatedSets, validatedReps, validatedWeight, validatedDuration, validatedDistance, errors.isEmpty, errorMessage)
    }

    // Logging workflow
    @discardableResult
    func logWorkout(name: String, category: ExerciseCategory, sets: Int? = nil, reps: Int?, weight: Double?, durationMinutes: Double?, distanceKm: Double?, sessionID: UUID? = nil, performedSets: [PerformedSet]? = nil, customExerciseID: UUID? = nil) -> WorkoutEntry {
        // Per-set records get the same numeric gates as the summary fields
        // (same NaN rule: non-finite never survives a comparison-based clamp).
        let sanitizedSets: [PerformedSet]? = performedSets.map { list in
            list.map { set in
                var clean = set
                if let r = set.reps { clean.reps = min(9999, max(1, r)) }
                if let w = set.weightKg {
                    clean.weightKg = w.isFinite ? min(9999, max(0, w)) : nil
                }
                return clean
            }
        }

        // Validate inputs
        let validation = validateWorkoutInputs(sets: sets, reps: reps, weight: weight, durationMinutes: durationMinutes, distanceKm: distanceKm)
        let (validatedSets, validatedReps, validatedWeight, validatedDuration, validatedDistance, isValid, validationError) = validation

        if !isValid, let error = validationError {
            inputWarning = error
        }
        // Base scores use the work that was actually performed. A summary
        // entry still expands representative reps × set count, while a real
        // set list contributes its exact working-set rep total. Using the
        // representative set for every row over-credits descending sets and
        // under-credits ascending ones.
        let workingSets = sanitizedSets?.filter { !$0.isWarmup }
        let setCount: Int
        let totalReps: Int?
        let scoringWeight: Double?
        if let workingSets {
            setCount = workingSets.count
            let repValues = workingSets.compactMap(\.reps)
            totalReps = repValues.isEmpty ? nil : repValues.reduce(0, +)

            let weightedVolume = workingSets.reduce(0.0) { partial, set in
                partial + Double(set.reps ?? 0) * (set.weightKg ?? 0)
            }
            if let totalReps, totalReps > 0, weightedVolume > 0 {
                scoringWeight = weightedVolume / Double(totalReps)
            } else {
                scoringWeight = validatedWeight
            }
        } else {
            setCount = max(1, validatedSets ?? 1)
            totalReps = validatedReps.map { $0 * setCount }
            scoringWeight = validatedWeight
        }
        let storedSetCount: Int? = workingSets == nil ? validatedSets : setCount
        let levelBefore = user.level
        let xpBefore = user.xp
        let score = StatEngine.intensityScore(category: category, reps: totalReps, weight: scoringWeight, durationMin: validatedDuration, distanceKm: validatedDistance)
        // Performance & PR logic (for barbell lifts). With real per-set data
        // the PR candidate is the best WORKING set by estimated 1RM — the
        // max-volume representative can hide a heavy single, and warm-ups
        // aren't record attempts. Custom exercises never enter the record
        // book: pooling a variation's single into its base lift's records
        // would corrupt both.
        let summaryEst1RM = customExerciseID == nil
            ? StatEngine.estimate1RM(category: category, reps: validatedReps, weight: validatedWeight)
            : 0
        let est1RM = customExerciseID == nil
            ? (sanitizedSets ?? [])
                .filter { !$0.isWarmup }
                .reduce(summaryEst1RM) { best, set in
                    max(best, StatEngine.estimate1RM(category: category, reps: set.reps, weight: set.weightKg))
                }
            : 0
        let prevBest = user.best1RM[category] ?? 0
        var prRatio: Double = 1.0
        if est1RM > 0 {
            if est1RM > prevBest { user.best1RM[category] = est1RM }
            // Use a softer baseline when there's no prior best to simulate a time‑skip update
            let effectivePrev = prevBest > 0 ? prevBest : max(1.0, est1RM * 0.05)
            prRatio = max(1.0, est1RM / effectivePrev)
        }
        let prevBestForEntry = prevBest > 0 ? prevBest : nil
        let est1RMForEntry = est1RM > 0 ? est1RM : nil

        // Relative XP vs personal baseline (first‑time banding handled inside)
        let perf = StatEngine.placementMetric(category: category,
                                              reps: validatedReps,
                                              weight: validatedWeight,
                                              durationMin: validatedDuration,
                                              distanceKm: validatedDistance,
                                              bodyweightKg: user.bodyweightKg)
        let prevBaseline = user.xpBaselines[category]
        // Apply weekly decay to baseline when there was a gap since the last session of this category
        var decayedBaseline = prevBaseline
        if let base = prevBaseline, let lastSame = history.first(where: { $0.category == category })?.date {
            let days = Date().timeIntervalSince(lastSame) / 86400.0
            if days > 0 {
                let rate = (category.focus == .endurance || category.focus == .mobility) ? 0.04 : 0.02
                let weeks = days / 7.0
                decayedBaseline = base * pow(1.0 - rate, weeks)
            }
        }
        let isFirstEver = history.isEmpty
        let isFirstTimeForThisExercise = !history.contains { $0.category == category }
        var gainedXP = StatEngine.relativeXP(category: category,
                                             perf: perf,
                                             baseline: decayedBaseline,
                                             isFirstEver: isFirstEver)
        // Streak bonus (MVP-light): small DAILY streaks, with decay rules.
        // Multiple exercises in one session still represent one training day.
        let info = focusStreakInfo(for: category.focus)
        if category.focus == .endurance {
            var s = info.streak
            if info.gapDays >= 2 { s = Int(Double(s) * 0.5) } // next bonus effectively halved
            let mult = 1.0 + min(0.20, 0.02 * Double(s))
            gainedXP *= mult
        } else if category.focus == .mobility {
            var s = info.streak
            if info.gapDays >= 1 { s = max(0, s - 1) } // miss a day → streak −1
            let mult = 1.0 + min(0.30, 0.03 * Double(s))
            gainedXP *= mult
        }
        // Multiple sets earn more than one: +15% per extra set, capped at +60%.
        // relativeXP measures per-set quality, so volume is layered on here.
        if setCount > 1 {
            gainedXP *= min(1.60, 1.0 + 0.15 * Double(setCount - 1))
        }
        // The honest-XP invariant (decision D5): XP measures training, full
        // stop. Class affinity is a GAME-layer bonus — it sharpens Trial
        // might in bankTrialMight, never the XP number itself.
        gainedXP = (min(60.0, gainedXP) * 10).rounded() / 10
        let endgameCoinsGained = levelBefore >= StatEngine.maxLevel
            ? Self.endgameCoinReward(from: gainedXP)
            : 0
        if endgameCoinsGained > 0 {
            applyEndgameCoinLedgerDelta(endgameCoinsGained)
        } else if levelBefore < StatEngine.maxLevel {
            addXP(gainedXP)
        }
        let trialMightGained = trialMightReward(from: gainedXP, focus: category.focus)

        // Update personal baseline with EMA using μ based on improvement/regression
        if perf > 0 {
            let base = decayedBaseline ?? perf
            let ratio = max(0.0001, perf / max(0.0001, base))
            let mu: Double = (ratio >= 1.10) ? 0.50 : (ratio < 0.95 ? 0.10 : 0.25)
            let newBase = base * (1.0 - mu) + perf * mu
            user.xpBaselines[category] = newBase
        }

        // Track if catch-up was applied

        // Placement candidate from this entry (supports all categories)
        let candidate = StatEngine.placementLevelCandidate(category: category,
                                                           reps: validatedReps, weight: validatedWeight,
                                                           durationMin: validatedDuration, distanceKm: validatedDistance,
                                                           bodyweightKg: user.bodyweightKg)
        // Update simple per-stat rank (1–10) based on the candidate placement per focus
        let tier = max(1, min(10, Int(round(Double(candidate) / 10.0))))
        func bump(_ old: inout Int, to new: Int, label: String) {
            if new > old { old = new }
        }
        switch category.focus {
        case .strength:   bump(&user.ranks.strength, to: tier, label: "STR")
        case .hypertrophy:bump(&user.ranks.size,     to: tier, label: "SIZ")
        case .bodyweight: bump(&user.ranks.dexterity,to: tier, label: "DEX")
        case .explosive:  bump(&user.ranks.agility,  to: tier, label: "AGI")
        case .endurance:  bump(&user.ranks.endurance,to: tier, label: "END")
        case .mobility:   bump(&user.ranks.vitality, to: tier, label: "VIT")
        }
        // (No level catch-up; we only use candidate for ranks/telemetry)

        // Maintain best metric log for transparency (repurposes best1RM
        // storage). Custom exercises stay out of the shared per-category
        // pool here too — a variation's numbers aren't the base lift's.
        if customExerciseID == nil {
            let perfMetric = StatEngine.placementMetric(category: category, reps: validatedReps, weight: validatedWeight, durationMin: validatedDuration, distanceKm: validatedDistance, bodyweightKg: user.bodyweightKg)
            if perfMetric > (user.best1RM[category] ?? 0) {
                user.best1RM[category] = perfMetric
            }
        }

        let levelAfter = user.level
        let xpAfter = user.xp
        let totalDeltaXP = StatEngine.cumulativeXP(level: levelAfter, xpWithin: xpAfter) -
                           StatEngine.cumulativeXP(level: levelBefore, xpWithin: xpBefore)

        let prevBase = prevBaseline ?? 0
        let perfRatio = (prevBase > 0 && perf > 0) ? max(0.5, min(perf / prevBase, 2.0)) : 1.0
        // Combine PR from barbell estimate with relative improvement vs personal baseline
        let prBoost = max(0.0, max(log2(prRatio), log2(perfRatio)))

        let baseBudget = StatEngine.statBudget(forXPDelta: totalDeltaXP, level: levelAfter)
        let minBudget  = StatEngine.minimumSessionBudget(for: category, score: score)
        // Always award at least a small, visible gain each session
        let finalBudget = max(baseBudget, minBudget)
        let profile = StatEngine.statWeights(for: category)
        var distributedGains = StatEngine.distribute(budget: finalBudget, weights: profile, prBoost: prBoost)

        // First time logging this exercise? Use the fixed first-time grant **instead of** normal distribution.
        if isFirstTimeForThisExercise {
            distributedGains = StatEngine.firstTimeGrant(for: category)
        } else {
            // Apply the x10 display scale for all non-first logs
            distributedGains = distributedGains.scaled(10.0)
        }

        // Apply gains AFTER we know the true total XP progress for this entry
        user.stats.add(distributedGains)

        // Record entry (using validated inputs)
        let entry = WorkoutEntry(
            id: UUID(),
            date: Date(),
            name: name.isEmpty ? category.displayName : name,
            category: category,
            sessionID: sessionID,
            customExerciseID: customExerciseID,
            sets: storedSetCount,
            reps: validatedReps,
            weight: validatedWeight,
            durationMinutes: validatedDuration,
            distanceKm: validatedDistance,
            performedSets: sanitizedSets,
            statGains: distributedGains,
            expGained: gainedXP,
            catchUpLevel: nil,
            prevLevel: levelBefore,
            newLevel: levelAfter,
            prevBest1RM: prevBestForEntry,
            est1RM: est1RMForEntry,
            totalProgressXP: totalDeltaXP,
            trialMightGained: trialMightGained,
            endgameCoinsGained: endgameCoinsGained
        )
        history.insert(entry, at: 0)

        // Update challenge progress based on the workout
        updateChallengeProgressFromWorkout(category: category, sets: storedSetCount, reps: validatedReps,
                                           totalReps: totalReps, weight: validatedWeight,
                                           durationMinutes: validatedDuration, distanceKm: validatedDistance)

        // Consistency earns streak freezes: one per full week of streak, max 3.
        let streak = currentStreak()
        if streak > 0, streak % 7 == 0, streak > user.lastFreezeEarnedAtStreak, user.streakFreezes < 3 {
            user.streakFreezes += 1
            user.lastFreezeEarnedAtStreak = streak
            pushToast(
                title: "Streak Freeze earned",
                subtitle: "\(streak)-day streak — one missed day is now covered",
                kind: .accent,
                symbol: .streakFreeze
            )
        }

        // Training banks might toward the Trial — the boss is the receipt
        // for work already done. Equipment sharpens the blow.
        applyTrialMightLedgerDelta(trialMightGained)

        // Companion bond deepens once per training day, deterministically.
        deepenCompanionBond()

        save()
        return entry
    }

    // Suppresses side-effect rewards (treasure chests) while history is being
    // replayed by recalculateStatsAndXP — otherwise every edit/delete would
    // re-mint a chest for each level regained.
    // Internal (not private): cross-file systems like the Trial banking
    // must also respect replay suppression.
    var isReplayingHistory = false

    func addXP(_ delta: Double) {
        guard user.level < StatEngine.maxLevel else {
            // Endgame: banked effort becomes coin income instead of vanishing.
            // Not replayed on recalculation — coins are a running balance.
            if !isReplayingHistory {
                let coinGain = Int((delta * 0.5).rounded())
                if coinGain > 0 { user.coins += coinGain }
            }
            return
        }
        user.xp += delta
        while user.level < StatEngine.maxLevel && user.xp >= user.nextLevelXP {
            user.xp -= user.nextLevelXP
            user.level += 1

            // Generate treasure chest for level up (not during history replay,
            // and never for a level that already minted one — closes the
            // log → delete → re-log farming loop)
            if !isReplayingHistory && user.level > user.chestHighWaterLevel {
                user.chestHighWaterLevel = user.level
                let newChest = StatEngine.generateTreasureChest(forLevel: user.level)
                user.treasureChests.append(newChest)
            }

            if user.level >= StatEngine.maxLevel {
                user.level = StatEngine.maxLevel
                // Lock progress bar at full
                user.xp = 1
                user.nextLevelXP = 1
            } else {
                user.nextLevelXP = StatEngine.xpNeeded(forNextLevel: user.level)
            }
        }
    }

    /// XP earned outside workouts (quests, chest bonuses). Recorded in a
    /// ledger so recalculation can replay it. Level-ups from bonus XP have no
    /// workout popup, so they celebrate through a toast instead.
    func grantBonusXP(_ amount: Double) {
        let levelBefore = user.level
        user.bonusXP += amount
        addXP(amount)
        if user.level > levelBefore, !isReplayingHistory {
            Haptics.success()
            pushToast(
                title: "Level Up!",
                subtitle: "You reached Level \(user.level)",
                kind: .gold,
                symbol: .rank
            )
        }
    }

    /// Commit a Weighing. Its PR/baseline seeds are permanent floors reapplied
    /// by history rebuilds, while bonus XP lives in its own replayable ledger.
    /// stats/level/xp/ranks are deliberately left alone here —
    /// recalculateStatsAndXP owns those derived values.
    var historyOwnedPlacementCategories: Set<ExerciseCategory> {
        Set(history.compactMap { entry in
            // This must mirror the built-in record-book fold in
            // `recalculateStatsAndXP`. A custom variation never owns its base
            // category, and a warm-up/incomplete row with no recordable metric
            // must not lock the player out of supplying a real first reading.
            guard entry.customExerciseID == nil else { return nil }
            let metric = StatEngine.placementMetric(
                category: entry.category,
                reps: entry.reps,
                weight: entry.weight,
                durationMin: entry.durationMinutes,
                distanceKm: entry.distanceKm,
                bodyweightKg: user.bodyweightKg
            )
            return (entry.est1RM ?? 0) > 0 || metric > 0 ? entry.category : nil
        })
    }

    func applyPlacement(record: PlacementRecord) {
        var record = record
        // The stored flag wins: a Settings re-run passes a freshly built record
        // whose flag is false, and the honesty bonus is once ever.
        if user.placement?.bonusGranted == true { record.bonusGranted = true }

        // Once real history owns a category, a later self-report can neither
        // create nor raise its permanent PR/baseline floor. Preserve the seed
        // that existed before that first logged set (if any), otherwise remove
        // the incoming claim entirely.
        let historyOwnedCategories = historyOwnedPlacementCategories
        for category in historyOwnedCategories {
            record.seeds[category] = user.placement?.seeds[category]
            record.baselineSeeds[category] = user.placement?.baselineSeeds[category]
        }

        // The stored record is the recalc fold-in's only seed source, so it may
        // never shrink: a re-run that reads fewer categories would leave the
        // older floors in best1RM until the next history edit wiped them.
        if let previous = user.placement {
            for (category, seed) in previous.seeds {
                record.seeds[category] = max(record.seeds[category] ?? 0, seed)
            }
            for (category, baseline) in previous.baselineSeeds {
                record.baselineSeeds[category] = max(record.baselineSeeds[category] ?? 0, baseline)
            }
        }

        // max-merge only — a seed can raise the floor, never lower a real PR.
        for (category, seed) in record.seeds where seed > 0 {
            user.best1RM[category] = max(user.best1RM[category] ?? 0, seed)
        }
        // Never clobber a live EMA: a logged category has already told the
        // truth about itself.
        for (category, baseline) in record.baselineSeeds where baseline > 0 {
            guard user.xpBaselines[category] == nil else { continue }
            guard !historyOwnedCategories.contains(category) else { continue }
            user.xpBaselines[category] = baseline
        }

        if !record.skipped && !record.bonusGranted {
            grantBonusXP(PlacementRite.honestyBonusXP)
            record.bonusGranted = true
        }

        user.placement = record
    }

    private static func endgameCoinReward(from xp: Double) -> Int {
        guard xp.isFinite, xp > 0 else { return 0 }
        return max(0, Int((xp * 0.5).rounded()))
    }

    /// Pre-v5 entries do not carry explicit coin attribution. `prevLevel` was
    /// already stored by the logger, so it reliably distinguishes workouts
    /// logged after reaching the cap from the workout that reached it.
    private func legacyEndgameCoinReward(for entry: WorkoutEntry) -> Int {
        guard entry.prevLevel == StatEngine.maxLevel else { return 0 }
        return Self.endgameCoinReward(from: entry.expGained)
    }

    private func attributedTrialMight(for entry: WorkoutEntry) -> Double {
        entry.trialMightGained ?? trialMightReward(
            from: entry.expGained,
            focus: entry.category.focus
        )
    }

    private func attributedEndgameCoins(for entry: WorkoutEntry) -> Int {
        entry.endgameCoinsGained ?? legacyEndgameCoinReward(for: entry)
    }

    /// Same debt semantics as Trial might: never make a visible balance
    /// negative or revoke a purchase, but make future capped-level training
    /// repay any deleted-workout shortfall before producing spendable coins.
    private func applyEndgameCoinLedgerDelta(_ delta: Int) {
        guard delta != 0 else { return }
        user.coins = max(0, user.coins)
        user.endgameCoinDebt = max(0, user.endgameCoinDebt)

        if delta > 0 {
            let repaid = min(user.endgameCoinDebt, delta)
            user.endgameCoinDebt -= repaid
            user.coins += delta - repaid
        } else {
            let reversal = -delta
            let reclaimed = min(user.coins, reversal)
            user.coins -= reclaimed
            user.endgameCoinDebt += reversal - reclaimed
        }
    }

    /// Reconcile only the workout-owned reward slice. Trial loot, chest
    /// coins, purchases, and other persistent economy state stay untouched.
    private func reconcileWorkoutRewardLedgers(previousHistory: [WorkoutEntry]) {
        let previousMight = previousHistory.reduce(0.0) { $0 + attributedTrialMight(for: $1) }
        let currentMight = history.reduce(0.0) { $0 + attributedTrialMight(for: $1) }
        let mightDelta = currentMight - previousMight
        if abs(mightDelta) > 0.000_001 {
            applyTrialMightLedgerDelta(mightDelta)
        }

        let previousCoins = previousHistory.reduce(0) { $0 + attributedEndgameCoins(for: $1) }
        let currentCoins = history.reduce(0) { $0 + attributedEndgameCoins(for: $1) }
        applyEndgameCoinLedgerDelta(currentCoins - previousCoins)
    }

    /// Replays the category EMA only up to the entry being edited. Using the
    /// finished, all-history baseline would price an old workout against its
    /// own result (and against workouts that happened later).
    private func baselineBeforeWorkout(
        _ workout: WorkoutEntry,
        for category: ExerciseCategory
    ) -> Double? {
        var baseline = user.placement?.baselineSeeds[category]
        var previousDate: Date?
        for entry in history.sorted(by: { $0.date < $1.date }) {
            if entry.id == workout.id { break }
            guard entry.category == category else { continue }

            if let base = baseline, let previousDate {
                let days = entry.date.timeIntervalSince(previousDate) / 86_400.0
                if days > 0 {
                    let rate = (entry.category.focus == .endurance || entry.category.focus == .mobility)
                        ? 0.04
                        : 0.02
                    baseline = base * pow(1.0 - rate, days / 7.0)
                }
            }

            let perf = StatEngine.placementMetric(
                category: entry.category,
                reps: entry.reps,
                weight: entry.weight,
                durationMin: entry.durationMinutes,
                distanceKm: entry.distanceKm,
                bodyweightKg: user.bodyweightKg
            )
            if perf > 0 {
                let base = baseline ?? perf
                let ratio = max(0.0001, perf / max(0.0001, base))
                let mu: Double = ratio >= 1.10 ? 0.50 : (ratio < 0.95 ? 0.10 : 0.25)
                baseline = base * (1.0 - mu) + perf * mu
            }
            previousDate = entry.date
        }
        return baseline
    }

    /// Single reward-calculation door for workout edits. The logging path has
    /// intentional random texture; edits use its deterministic mid-band curve
    /// so repeatedly saving the same correction cannot reroll XP.
    func recomputeEditedWorkoutRewards(
        _ workout: inout WorkoutEntry,
        replacing original: WorkoutEntry
    ) {
        let setCount = max(1, workout.sets ?? 1)
        let totalReps = workout.reps.map { $0 * setCount }
        let score = StatEngine.intensityScore(
            category: workout.category,
            reps: totalReps,
            weight: workout.weight,
            durationMin: workout.durationMinutes,
            distanceKm: workout.distanceKm
        )
        workout.statGains = StatEngine.statGains(
            for: workout.category,
            score: score
        ).scaled(10.0)

        let perf = StatEngine.placementMetric(
            category: workout.category,
            reps: workout.reps,
            weight: workout.weight,
            durationMin: workout.durationMinutes,
            distanceKm: workout.distanceKm,
            bodyweightKg: user.bodyweightKg
        )
        workout.expGained = (StatEngine.estimatedXP(
            category: workout.category,
            perf: perf,
            baseline: baselineBeforeWorkout(original, for: workout.category),
            sets: setCount
        ) * 10).rounded() / 10
        workout.totalProgressXP = workout.expGained

        if workout.customExerciseID == nil {
            let estimate = StatEngine.estimate1RM(
                category: workout.category,
                reps: workout.reps,
                weight: workout.weight
            )
            workout.est1RM = estimate > 0 ? estimate : nil
        }
    }

    // Delete workout from history
    func deleteWorkout(at offsets: IndexSet) {
        let previousHistory = history
        history.remove(atOffsets: offsets)
        reconcileWorkoutRewardLedgers(previousHistory: previousHistory)
        rebuildChallengeProgress()
        recalculateStatsAndXP()
        save()
    }

    // Update existing workout
    func updateWorkout(_ workout: WorkoutEntry) {
        if let index = history.firstIndex(where: { $0.id == workout.id }) {
            let previousHistory = history
            let original = history[index]
            var normalized = workout
            // Canonicalize before comparing: the edit sheet round-trips
            // sets nil↔1 and numbers through display formatting, and a
            // rename must never read as a performance change (it would
            // destroy the truthful per-set records below).
            func sameAmount(_ a: Double?, _ b: Double?) -> Bool {
                switch (a, b) {
                case (nil, nil): return true
                case let (x?, y?): return abs(x - y) < 0.05
                default: return false
                }
            }
            let performanceChanged = original.category != normalized.category ||
                max(1, original.sets ?? 1) != max(1, normalized.sets ?? 1) ||
                original.reps != normalized.reps ||
                !sameAmount(original.weight, normalized.weight) ||
                !sameAmount(original.durationMinutes, normalized.durationMinutes) ||
                !sameAmount(original.distanceKm, normalized.distanceKm)

            // Real set rows describe the old performance. Direct callers
            // receive the same protection as EditWorkoutView, while a
            // name/date-only edit keeps the truthful per-set history.
            if performanceChanged {
                normalized.performedSets = nil
                recomputeEditedWorkoutRewards(&normalized, replacing: original)
            }
            if normalized.customExerciseID != nil {
                normalized.est1RM = nil
                normalized.prevBest1RM = nil
            }

            // Edits can legitimately change XP. Preserve the equipment/class
            // multiplier the original workout earned instead of repricing old
            // training with today's loadout, then let the ledger reconcile the
            // balance (or debt) from the attributed delta.
            if performanceChanged || normalized.expGained != original.expGained {
                let originalMight = attributedTrialMight(for: original)
                let multiplier = original.expGained > 0
                    ? originalMight / original.expGained
                    : trialMightReward(from: 1, focus: normalized.category.focus)
                normalized.trialMightGained = max(0, normalized.expGained * multiplier)

                let wasEndgameWorkout = attributedEndgameCoins(for: original) > 0 ||
                    original.prevLevel == StatEngine.maxLevel
                normalized.endgameCoinsGained = wasEndgameWorkout
                    ? Self.endgameCoinReward(from: normalized.expGained)
                    : 0
            }

            history[index] = normalized
            reconcileWorkoutRewardLedgers(previousHistory: previousHistory)
            rebuildChallengeProgress()
            recalculateStatsAndXP()
            save()
        }
    }

    // Recalculate all stats and XP from history
    func recalculateStatsAndXP() {
        // Reset user stats and XP to initial state
        user.level = 1
        user.xp = 0
        user.nextLevelXP = StatEngine.xpNeeded(forNextLevel: 1)
        user.stats = .zero

        // Reset ranks
        user.ranks = StatRanks()

        // Reset personal bests — rebuilt below so deleting or editing an
        // entry actually removes the records it set.
        user.best1RM = [:]

        // Baselines are history-derived too. Begin with any permanent Weighing
        // seeds, then replay the EMA in chronological order below so an edited
        // or deleted outlier can no longer influence future relative XP.
        user.xpBaselines = user.placement?.baselineSeeds.filter { $0.value > 0 } ?? [:]

        // Recalculate from history (oldest to newest)
        let sortedHistory = history.sorted { $0.date < $1.date }

        isReplayingHistory = true
        defer { isReplayingHistory = false }

        // Re-credit XP earned from quests and chests — it lives in a ledger,
        // not in workout history.
        addXP(user.bonusXP)

        var lastBaselineDate: [ExerciseCategory: Date] = [:]
        for entry in sortedHistory {
            // Add XP
            addXP(entry.expGained)

            // Add stats
            user.stats.add(entry.statGains)

            // Update ranks based on exercise category
            let category = entry.category
            let perf = StatEngine.placementMetric(
                category: category,
                reps: entry.reps,
                weight: entry.weight,
                durationMin: entry.durationMinutes,
                distanceKm: entry.distanceKm,
                bodyweightKg: user.bodyweightKg
            )
            var decayedBaseline = user.xpBaselines[category]
            if let base = decayedBaseline, let previousDate = lastBaselineDate[category] {
                let days = entry.date.timeIntervalSince(previousDate) / 86_400.0
                if days > 0 {
                    let rate = (category.focus == .endurance || category.focus == .mobility) ? 0.04 : 0.02
                    decayedBaseline = base * pow(1.0 - rate, days / 7.0)
                }
            }
            if perf > 0 {
                let base = decayedBaseline ?? perf
                let ratio = max(0.0001, perf / max(0.0001, base))
                let mu: Double = ratio >= 1.10 ? 0.50 : (ratio < 0.95 ? 0.10 : 0.25)
                user.xpBaselines[category] = base * (1.0 - mu) + perf * mu
            }
            lastBaselineDate[category] = entry.date

            let candidate = StatEngine.placementLevelCandidate(
                category: category,
                reps: entry.reps,
                weight: entry.weight,
                durationMin: entry.durationMinutes,
                distanceKm: entry.distanceKm,
                bodyweightKg: user.bodyweightKg
            )
            let tier = max(1, min(10, Int(round(Double(candidate) / 10.0))))

            // Custom variations have their own identity and never enter the
            // built-in category's shared record slot, including when replaying
            // legacy entries that once carried pooled PR metadata.
            if entry.customExerciseID == nil {
                if let est = entry.est1RM, est > (user.best1RM[category] ?? 0) {
                    user.best1RM[category] = est
                }
                let perfMetric = StatEngine.placementMetric(
                    category: category,
                    reps: entry.reps,
                    weight: entry.weight,
                    durationMin: entry.durationMinutes,
                    distanceKm: entry.distanceKm,
                    bodyweightKg: user.bodyweightKg
                )
                if perfMetric > (user.best1RM[category] ?? 0) {
                    user.best1RM[category] = perfMetric
                }
            }

            switch category.focus {
            case .strength:
                if tier > user.ranks.strength { user.ranks.strength = tier }
            case .hypertrophy:
                if tier > user.ranks.size { user.ranks.size = tier }
            case .bodyweight:
                if tier > user.ranks.dexterity { user.ranks.dexterity = tier }
            case .explosive:
                if tier > user.ranks.agility { user.ranks.agility = tier }
            case .endurance:
                if tier > user.ranks.endurance { user.ranks.endurance = tier }
            case .mobility:
                if tier > user.ranks.vitality { user.ranks.vitality = tier }
            }
        }

        // Placement seeds are a floor, not history: the best1RM reset above
        // would otherwise let the first delete/edit erase the Weighing. Real
        // history that exceeds a seed wins here, so seeds retire silently.
        if let seeds = user.placement?.seeds {
            for (category, seed) in seeds where seed > 0 {
                user.best1RM[category] = max(user.best1RM[category] ?? 0, seed)
            }
        }
    }

    // Persistence
    private static var saveURL: URL? {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent("rpgfit_mvp_state.json")
    }

    private static var fallbackURL: URL? {
        guard let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent("rpgfit_mvp_fallback.json")
    }

    private static var backupURL: URL? {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent("rpgfit_mvp_backup.json")
    }

    @Published var persistenceError: String?
    /// Input-validation feedback — separate from persistenceError so a typo
    /// never surfaces "Restore Backup" recovery actions.
    @Published var inputWarning: String?

    // MARK: - Reward Toasts

    struct RewardToast: Identifiable, Equatable {
        enum Kind { case xp, gold, accent }
        let id: UUID
        let title: String
        let subtitle: String?
        let icon: String?
        let kind: Kind
        /// A branded game noun can opt into the custom symbol language while
        /// system events continue to use their familiar SF Symbol fallback.
        let symbol: RPGSymbol?
    }

    @Published var toasts: [RewardToast] = []

    /// Queues a small celebration banner (quest complete, level up from
    /// bonus XP, streak events). Auto-dismisses; newest stacks on top.
    func pushToast(title: String,
                   subtitle: String? = nil,
                   icon: String? = nil,
                   kind: RewardToast.Kind = .xp,
                   symbol: RPGSymbol? = nil) {
        let toast = RewardToast(
            id: UUID(),
            title: title,
            subtitle: subtitle,
            icon: icon,
            kind: kind,
            symbol: symbol
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.toasts.append(toast)
                if self.toasts.count > 3 { self.toasts.removeFirst(self.toasts.count - 3) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { [weak self] in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.toasts.removeAll { $0.id == toast.id }
                }
            }
        }
    }

    // MARK: - Training Streak

    /// Consecutive calendar days for one focus, newest day first. This is
    /// separate from the global freeze-aware streak: it powers the small
    /// endurance/mobility XP bonus and intentionally counts a training day
    /// once no matter how many exercises were logged in that session.
    func focusStreakInfo(
        for focus: FocusGroup,
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> (streak: Int, gapDays: Int) {
        let days = Set(
            history.lazy
                .filter { $0.category.focus == focus }
                .map { calendar.startOfDay(for: $0.date) }
        ).sorted(by: >)
        guard let latest = days.first else { return (0, .max) }

        let today = calendar.startOfDay(for: now)
        let gap = max(0, calendar.dateComponents([.day], from: latest, to: today).day ?? 0)
        var streak = 1
        var newerDay = latest
        for olderDay in days.dropFirst() {
            let separation = calendar.dateComponents([.day], from: olderDay, to: newerDay).day
            guard separation == 1 else { break }
            streak += 1
            newerDay = olderDay
        }
        return (streak, gap)
    }

    /// Consecutive training days ending today or yesterday. A day counts if
    /// any workout was logged on it or a streak freeze covered it. An
    /// untrained today doesn't break the chain — it just isn't counted yet.
    func currentStreak(asOf now: Date = Date()) -> Int {
        let cal = Calendar.current
        let workoutDays = Set(history.map { cal.startOfDay(for: $0.date) })
        let frozenDays = Set(user.freezeDaysUsed.map { cal.startOfDay(for: $0) })
        var streak = 0
        var day = cal.startOfDay(for: now)
        if workoutDays.contains(day) { streak += 1 }
        while true {
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
            if workoutDays.contains(day) || frozenDays.contains(day) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    /// Welcomes a lapsed adventurer back with a comeback quest — the
    /// anti-punishment mechanic. Mints at most once per absence (3+ idle
    /// days), gives 48 hours, and reads as a welcome, never a debt.
    func checkComebackQuest() {
        guard !history.isEmpty else { return }
        let cal = Calendar.current
        guard let lastWorkout = history.map(\.date).max() else { return }
        let idleDays = cal.dateComponents([.day], from: cal.startOfDay(for: lastWorkout), to: cal.startOfDay(for: Date())).day ?? 0
        guard idleDays >= 3 else { return }
        // One comeback per absence: if we already minted one after the last
        // workout, don't mint another until they train again.
        if let minted = user.lastComebackQuestDate, minted > lastWorkout { return }
        // Don't stack with a live comeback quest.
        guard !user.dailyChallenges.contains(where: { ($0.isComeback ?? false) && !$0.isExpired }) else { return }

        let focus = user.rpgClass?.focusCategories.first ?? .strength
        let quest = Challenge(
            id: UUID(),
            type: .daily,
            title: "The Return",
            description: "No penalties. No lost ground. Just pick up where you left off.",
            targetCategory: focus,
            targetAmount: 2,
            unit: .sets,
            expReward: 40,
            classType: user.rpgClass ?? .warrior,
            createdAt: Date(),
            expiresAt: cal.date(byAdding: .hour, value: 48, to: Date()) ?? Date().addingTimeInterval(172800),
            completedAt: nil,
            progress: 0,
            uniqueExercises: [],
            isComeback: true
        )
        user.dailyChallenges.append(quest)
        user.lastComebackQuestDate = Date()
        pushToast(title: "Welcome back, adventurer",
                  subtitle: "The road missed you. A comeback quest awaits — \(quest.expReward) XP.",
                  kind: .gold, symbol: .quest)
        save()
    }

    /// Spends a freeze on yesterday if it would otherwise break a streak.
    /// Called on launch/foreground — gentle by design: the companion never
    /// suffers, the streak just quietly holds.
    func maintainStreak() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
              let dayBefore = cal.date(byAdding: .day, value: -1, to: yesterday) else { return }
        let workoutDays = Set(history.map { cal.startOfDay(for: $0.date) })
        let frozenDays = Set(user.freezeDaysUsed.map { cal.startOfDay(for: $0) })
        guard !workoutDays.contains(yesterday), !frozenDays.contains(yesterday),
              workoutDays.contains(dayBefore) || frozenDays.contains(dayBefore),
              user.streakFreezes > 0 else { return }
        user.streakFreezes -= 1
        user.freezeDaysUsed.append(yesterday)
        pushToast(title: "Streak Freeze used",
                  subtitle: "Yesterday is covered — your streak holds",
                  kind: .accent, symbol: .streakFreeze)
        save()
    }

    /// Buys one streak freeze with coins (cap 3) — a permanent coin sink.
    @discardableResult
    func buyStreakFreeze() -> Bool {
        let price = 250
        guard user.streakFreezes < 3, user.coins >= price else { return false }
        user.coins -= price
        user.streakFreezes += 1
        Haptics.success()
        save()
        return true
    }

    /// Buys a companion egg with coins — only while the collection is
    /// incomplete, so the sink never turns into a dud purchase.
    @discardableResult
    func buyCompanionEgg() -> Bool {
        let price = 400
        guard user.hatchedCompanions.count < CompanionSpecies.allCases.count,
              user.coins >= price else { return false }
        user.coins -= price
        user.companionEggs += 1
        Haptics.success()
        save()
        return true
    }

    // MARK: - Export

    /// Writes the full workout history as CSV and returns the file URL.
    /// `set_detail` carries the true per-set data ("60x8 | 70x6 | W 40x10",
    /// kg) so the export never loses what the summary columns collapse.
    func exportHistoryCSV() -> URL? {
        var rows = ["date,exercise,category,focus,sets,reps,weight_kg,duration_min,distance_km,set_detail,xp"]
        let formatter = ISO8601DateFormatter()
        for entry in history.sorted(by: { $0.date < $1.date }) {
            func num(_ value: Double?) -> String { value.map { String(format: "%.2f", $0) } ?? "" }
            let name = entry.name.replacingOccurrences(of: "\"", with: "\"\"")
            let setDetail = (entry.performedSets ?? [])
                .map { set -> String in
                    let load = set.weightKg.map { AppState.fieldNumber($0) } ?? "bw"
                    let reps = set.reps.map(String.init) ?? "?"
                    return "\(set.isWarmup ? "W " : "")\(load)x\(reps)"
                }
                .joined(separator: " | ")
            rows.append([
                formatter.string(from: entry.date),
                "\"\(name)\"",
                entry.category.rawValue,
                entry.category.focus.displayName,
                entry.sets.map(String.init) ?? "",
                entry.reps.map(String.init) ?? "",
                num(entry.weight),
                num(entry.durationMinutes),
                num(entry.distanceKm),
                "\"\(setDetail)\"",
                String(format: "%.1f", entry.expGained)
            ].joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RPGFit-Workouts.csv")
        do {
            try rows.joined(separator: "\n").data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // Cache management
    private func clearCache() {
        cachedSortedHistory = nil
        cachedGroupedWorkouts = nil
        cacheValidationTime = nil
    }

    private func isCacheValid() -> Bool {
        guard let validationTime = cacheValidationTime else { return false }
        return Date().timeIntervalSince(validationTime) < cacheExpirationInterval
    }

    // Cached sorted history (most recent first)
    func getSortedHistory() -> [WorkoutEntry] {
        if let cached = cachedSortedHistory, isCacheValid() {
            return cached
        }

        let sorted = history.sorted { $0.date > $1.date }
        cachedSortedHistory = sorted
        cacheValidationTime = Date()
        return sorted
    }

    // Cached grouped workouts by date
    func getGroupedWorkouts() -> [(String, [WorkoutEntry])] {
        if let cached = cachedGroupedWorkouts, isCacheValid() {
            return cached
        }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: getSortedHistory()) { entry in
            calendar.dateInterval(of: .day, for: entry.date)?.start ?? entry.date
        }
        .sorted { $0.key > $1.key }
        .map { (key, value) in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return (formatter.string(from: key), value.sorted { $0.date > $1.date })
        }

        cachedGroupedWorkouts = grouped
        return grouped
    }

    // MARK: - Challenge System

    /// One canonical calendar-week window for minting, expiry, and replay.
    /// Using Calendar's interval also handles locale-specific week starts and
    /// daylight-saving transitions without assuming a fixed 168 hours.
    static func weeklyQuestInterval(
        containing date: Date,
        calendar: Calendar = .current
    ) -> DateInterval {
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return interval
        }
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start)
            ?? start.addingTimeInterval(7 * 86_400)
        return DateInterval(start: start, end: end)
    }

    /// Repairs rolling-seven-day legacy quests while retaining identity,
    /// completion state, and already-earned XP.
    private func normalizedWeeklyChallenge(_ challenge: Challenge) -> Challenge {
        guard challenge.type == .weekly else { return challenge }
        let interval = Self.weeklyQuestInterval(containing: challenge.createdAt)
        guard challenge.expiresAt != interval.end else { return challenge }
        return Challenge(
            id: challenge.id,
            type: challenge.type,
            title: challenge.title,
            description: challenge.description,
            targetCategory: challenge.targetCategory,
            targetAmount: challenge.targetAmount,
            unit: challenge.unit,
            expReward: challenge.expReward,
            classType: challenge.classType,
            createdAt: challenge.createdAt,
            expiresAt: interval.end,
            completedAt: challenge.completedAt,
            progress: challenge.progress,
            uniqueExercises: challenge.uniqueExercises,
            isComeback: challenge.isComeback
        )
    }

    func setRPGClass(_ classType: RPGClass) {
        user.rpgClass = classType
        generateDailyChallenges()
        generateWeeklyChallenges()
        save()
    }

    func changeRPGClassWithQuestReset(_ classType: RPGClass) {
        let newClassCategories = Set(classType.focusCategories)

        // Update class first
        user.rpgClass = classType

        // Handle daily challenges
        var newDailyChallenges: [Challenge] = []
        for challenge in user.dailyChallenges {
            if challenge.isCompleted {
                // Keep all completed challenges (preserve XP already earned)
                newDailyChallenges.append(challenge)
            } else if newClassCategories.contains(challenge.targetCategory) {
                // Keep active challenges that match new class categories (preserve progress)
                newDailyChallenges.append(challenge)
            }
            // Drop active challenges that don't match new class (lose progress as warned)
        }
        user.dailyChallenges = newDailyChallenges

        // Handle weekly challenges
        var newWeeklyChallenges: [Challenge] = []
        for challenge in user.weeklyChallenges {
            if challenge.isCompleted {
                // Keep all completed challenges (preserve XP already earned)
                newWeeklyChallenges.append(challenge)
            } else if newClassCategories.contains(challenge.targetCategory) {
                // Keep active challenges that match new class categories (preserve progress)
                newWeeklyChallenges.append(challenge)
            }
            // Drop active challenges that don't match new class (lose progress as warned)
        }
        user.weeklyChallenges = newWeeklyChallenges

        // Generate new challenges for missing categories
        generateMissingChallenges(for: classType)
        save()
    }

    private func generateMissingChallenges(for classType: RPGClass) {
        let now = Date()
        let currentWeek = Self.weeklyQuestInterval(containing: now)
        user.weeklyChallenges = user.weeklyChallenges
            .map(normalizedWeeklyChallenge)
            .filter {
                Self.weeklyQuestInterval(containing: $0.createdAt).start == currentWeek.start
            }
        let requiredCategories = Set(classType.focusCategories)

        // A category counts as covered if it has ANY quest for the current
        // period — active OR completed. Filtering on isActive alone let a
        // class switch re-mint fresh quests for categories whose quests were
        // already completed today: an unlimited bonus-XP loop.
        let existingDailyCategories = Set(user.dailyChallenges.filter { !$0.isExpired }.map { $0.targetCategory })
        let missingDailyCategories = requiredCategories.subtracting(existingDailyCategories)

        // Generate daily challenges for missing categories: 2 per missing category (amount + variety)
        for category in missingDailyCategories {
            // Amount challenge
            let amountChallenge = createDailyAmountChallenge(for: category, classType: classType)
            user.dailyChallenges.append(amountChallenge)

            // Variety challenge
            let varietyChallenge = createDailyVarietyChallenge(for: category, classType: classType)
            user.dailyChallenges.append(varietyChallenge)
        }

        // Same non-expired rule as dailies — completed weeklies still cover
        // their category until the week rolls over.
        let existingWeeklyCategories = Set(user.weeklyChallenges.filter { !$0.isExpired }.map { $0.targetCategory })
        let missingWeeklyCategories = requiredCategories.subtracting(existingWeeklyCategories)

        // Generate weekly challenges for missing categories: 1 per missing category
        for category in missingWeeklyCategories {
            let challenge = createWeeklyChallenge(for: category, classType: classType, asOf: now)
            user.weeklyChallenges.append(challenge)
        }

        // Update generation timestamps to prevent normal generation from running
        user.lastDailyChallengeGeneration = Date()
        user.lastWeeklyChallengeGeneration = now
    }

    func generateDailyChallenges() {
        guard let rpgClass = user.rpgClass else { return }

        // Check if we need to generate new dailies (once per day).
        // Completing every daily must NOT trigger a same-day regeneration,
        // so the guard depends only on the generation date.
        if let lastGeneration = user.lastDailyChallengeGeneration,
           Calendar.current.isDateInToday(lastGeneration) {
            return // Already generated today
        }

        // Clear old challenges
        user.dailyChallenges.removeAll { $0.isExpired }

        // Generate exactly 4 daily challenges: 2 per category (amount + variety).
        // Adaptive targeting: the class pair is the default, but real habits
        // outrank the character sheet — a focus group trained on 3+ of the
        // last 14 days takes the second slot.
        var categories = rpgClass.focusCategories.shuffled()
        if categories.count > 1, let habit = dominantOffClassFocus() {
            categories[1] = habit
        }

        // Create 2 challenges per category (amount + variety)
        for category in categories {
            // Amount challenge (reps/sets/minutes/etc.)
            let amountChallenge = createDailyAmountChallenge(for: category, classType: rpgClass)
            user.dailyChallenges.append(amountChallenge)

            // Variety challenge (number of different exercises)
            let varietyChallenge = createDailyVarietyChallenge(for: category, classType: rpgClass)
            user.dailyChallenges.append(varietyChallenge)
        }

        user.lastDailyChallengeGeneration = Date()
        // Credit work already logged today toward the fresh quests.
        for i in user.dailyChallenges.indices where !user.dailyChallenges[i].isExpired {
            applyQuestLedgerDelta(rebuildProgress(&user.dailyChallenges[i]))
        }
        save()
    }

    /// The focus group OUTSIDE the class pair that the user actually trains:
    /// 3+ distinct training days in the last 14. Deterministic tie-break so
    /// regeneration is stable within a day.
    func dominantOffClassFocus() -> FocusGroup? {
        guard let rpgClass = user.rpgClass else { return nil }
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        var daysByFocus: [FocusGroup: Set<DateComponents>] = [:]
        for entry in history where entry.date >= cutoff {
            let focus = entry.category.focus
            guard !rpgClass.focusCategories.contains(focus) else { continue }
            daysByFocus[focus, default: []]
                .insert(calendar.dateComponents([.year, .month, .day], from: entry.date))
        }
        return daysByFocus
            .filter { $0.value.count >= 3 }
            .sorted { ($0.value.count, $0.key.rawValue) > ($1.value.count, $1.key.rawValue) }
            .first?.key
    }

    func generateWeeklyChallenges(asOf now: Date = Date()) {
        guard let rpgClass = user.rpgClass else { return }

        let currentWeek = Self.weeklyQuestInterval(containing: now)
        // Normalize older saves and remove every prior-period quest before
        // checking the generation guard. This guarantees there is never an
        // active rolling-window quest beside the current calendar week.
        user.weeklyChallenges = user.weeklyChallenges
            .map(normalizedWeeklyChallenge)
            .filter {
                Self.weeklyQuestInterval(containing: $0.createdAt).start == currentWeek.start
            }

        // Check if we need to generate new weeklies (once per calendar week).
        // Same rule as dailies: completion must not trigger regeneration.
        // Calendar-week comparison (not a full 168h gap) so expired weeklies
        // don't sit dark for up to a day after the week rolls over.
        if let lastGeneration = user.lastWeeklyChallengeGeneration,
           currentWeek.contains(lastGeneration) {
            return // Already generated this week
        }

        // Generate 2 weekly challenges based on focus categories
        let categories = rpgClass.focusCategories.shuffled()
        let numChallenges = min(2, categories.count)

        for i in 0..<numChallenges {
            let category = categories[i]
            let challenge = createWeeklyChallenge(for: category, classType: rpgClass, asOf: now)
            user.weeklyChallenges.append(challenge)
        }

        user.lastWeeklyChallengeGeneration = now
        // Credit work already logged this week toward the fresh quests.
        for i in user.weeklyChallenges.indices where !user.weeklyChallenges[i].isExpired {
            applyQuestLedgerDelta(rebuildProgress(&user.weeklyChallenges[i]))
        }
        save()
    }

    private func createDailyAmountChallenge(for category: FocusGroup, classType: RPGClass) -> Challenge {
        let (title, amount, unit) = getDailyAmountChallengeDetails(for: category, classType: classType)
        let expReward = 25 // Consistent daily XP

        return Challenge(
            id: UUID(),
            type: .daily,
            title: title,
            description: "Complete this quest before the day ends!",
            targetCategory: category,
            targetAmount: amount,
            unit: unit,
            expReward: expReward,
            classType: classType,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        )
    }

    private func createDailyVarietyChallenge(for category: FocusGroup, classType: RPGClass) -> Challenge {
        let (title, amount, unit) = getDailyVarietyChallengeDetails(for: category, classType: classType)
        let expReward = 25 // Consistent daily XP

        return Challenge(
            id: UUID(),
            type: .daily,
            title: title,
            description: "Complete this quest before the day ends!",
            targetCategory: category,
            targetAmount: amount,
            unit: unit,
            expReward: expReward,
            classType: classType,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        )
    }

    private func createWeeklyChallenge(
        for category: FocusGroup,
        classType: RPGClass,
        asOf now: Date = Date()
    ) -> Challenge {
        let (title, amount, unit) = getWeeklyChallengeDetails(for: category, classType: classType)
        let expReward = 100 // Consistent weekly XP
        let interval = Self.weeklyQuestInterval(containing: now)

        return Challenge(
            id: UUID(),
            type: .weekly,
            title: title,
            description: "Complete this epic quest before the week ends!",
            targetCategory: category,
            targetAmount: amount,
            unit: unit,
            expReward: expReward,
            classType: classType,
            createdAt: now,
            expiresAt: interval.end
        )
    }

    // MARK: - Challenge Preference Helpers

    func getAvailablePreferences(for category: FocusGroup) -> [ChallengePreference] {
        switch category {
        case .endurance:
            return [.time, .distance]
        case .mobility:
            return [.frequency, .sets]
        case .explosive:
            return [.sets, .times]
        case .strength, .hypertrophy, .bodyweight:
            return [.sets, .reps]
        }
    }

    func getPreference(for category: FocusGroup) -> ChallengePreference {
        return user.challengePreferences[category] ?? getDefaultPreference(for: category)
    }

    func setPreference(_ preference: ChallengePreference, for category: FocusGroup) {
        user.challengePreferences[category] = preference
        save()
    }

    private func getDefaultPreference(for category: FocusGroup) -> ChallengePreference {
        switch category {
        case .endurance: return .time
        case .mobility: return .sets
        case .explosive: return .sets
        case .strength, .hypertrophy, .bodyweight: return .sets
        }
    }

    func getStatName(for category: FocusGroup) -> String {
        switch category {
        case .strength: return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .endurance: return "Endurance"
        case .explosive: return "Explosive"
        case .mobility: return "Mobility"
        case .bodyweight: return "Bodyweight"
        }
    }

    private func getAmountChallenge(statName: String, preference: ChallengePreference, baseAmount: Int) -> (String, Int, ChallengeUnit) {
        let title = "\(statName) \(preference.displayName)"
        return (title, baseAmount, preference.unit)
    }

    private func getWeeklyChallenge(statName: String, preference: ChallengePreference, baseAmount: Int) -> (String, Int, ChallengeUnit) {
        let title = "\(statName) Mastery"
        return (title, baseAmount, preference.unit)
    }

    private func getDailyAmountChallengeDetails(for category: FocusGroup, classType: RPGClass) -> (String, Int, ChallengeUnit) {
        let preference = getPreference(for: category)
        let statName = getStatName(for: category)

        // Targets are scaled per unit (like weeklies already were) so the
        // sets/reps preference toggle changes flavor, not difficulty. A set
        // is roughly 5-10 reps, so reps targets run ~6x the sets targets.
        switch category {
        case .strength:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: preference == .sets ? 6 : 30)
        case .hypertrophy:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: preference == .sets ? 9 : 60)
        case .endurance:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: preference == .time ? 20 : 5)
        case .explosive:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: preference == .sets ? 5 : 6)
        case .mobility:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: preference == .frequency ? 3 : 5)
        case .bodyweight:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: preference == .sets ? 6 : 40)
        }
    }

    private func getDailyVarietyChallengeDetails(for category: FocusGroup, classType: RPGClass) -> (String, Int, ChallengeUnit) {
        switch category {
        case .strength:
            return ("Strength Variety", 4, .exercises)
        case .hypertrophy:
            return ("Hypertrophy Mix", 4, .exercises)
        case .endurance:
            return ("Endurance Variety", 2, .exercises)
        case .explosive:
            return ("Explosive Variety", 3, .exercises)
        case .mobility:
            return ("Mobility Flow", 3, .exercises)
        case .bodyweight:
            return ("Bodyweight Mix", 4, .exercises)
        }
    }

    private func getWeeklyChallengeDetails(for category: FocusGroup, classType: RPGClass) -> (String, Int, ChallengeUnit) {
        let preference = getPreference(for: category)
        let statName = getStatName(for: category)

        switch category {
        case .strength:
            let amount = preference == .sets ? 25 : (preference == .reps ? 120 : 20)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        case .hypertrophy:
            let amount = preference == .sets ? 40 : (preference == .reps ? 200 : 18)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        case .endurance:
            let amount = preference == .time ? 90 : (preference == .distance ? 20 : 8)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        case .explosive:
            let amount = preference == .sets ? 20 : (preference == .times ? 25 : 12)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        case .mobility:
            let amount = preference == .frequency ? 10 : (preference == .sets ? 25 : 10)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        case .bodyweight:
            let amount = preference == .sets ? 30 : (preference == .reps ? 150 : 15)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        }
    }


    private func updateChallengeProgressFromWorkout(category: ExerciseCategory, sets: Int?, reps: Int?, totalReps: Int? = nil, weight: Double?, durationMinutes: Double?, distanceKm: Double?) {
        let focusGroup = category.focus
        let setCount = max(1, sets ?? 1)

        // Convert workout data to challenge progress based on type
        if let repTotal = totalReps ?? reps.map({ $0 * setCount }), repTotal > 0 {
            updateChallengeProgress(for: focusGroup, amount: repTotal, unit: .reps)
            updateChallengeProgress(for: focusGroup, amount: setCount, unit: .sets)
        }

        if let duration = durationMinutes, duration > 0 {
            updateChallengeProgress(for: focusGroup, amount: Int(ceil(duration)), unit: .minutes)
        }

        if let distance = distanceKm, distance > 0 {
            updateChallengeProgress(for: focusGroup, amount: Int(ceil(distance)), unit: .kilometers)
        }

        // Count explosive exercises as "times" for agility challenges
        if focusGroup == .explosive {
            updateChallengeProgress(for: focusGroup, amount: 1, unit: .times)
        }

        // Count mobility/recovery exercises as frequency (sessions)
        if focusGroup == .mobility {
            updateChallengeProgress(for: focusGroup, amount: 1, unit: .times) // frequency uses .times unit
        }

        // Count this exercise toward variety challenges (unique exercises in this focus group)
        updateExerciseVarietyProgress(for: focusGroup, exercise: category)
    }

    /// Marks a challenge completed, celebrates, and returns the XP to grant —
    /// the single door every quest completion goes through. Deliberately never
    /// touches `user`: callers hold an inout borrow of a challenge element
    /// inside `user`, and because `user` is @Published that borrow works on a
    /// whole-profile copy — any XP granted mid-borrow is erased when the copy
    /// writes back. Callers grant the returned XP after their loop ends.
    private func completeChallenge(_ challenge: inout Challenge) -> Double {
        challenge.completedAt = Date()
        pushToast(title: "Quest Complete",
                  subtitle: "\(challenge.title) · +\(challenge.expReward) XP",
                  kind: .xp, symbol: .quest)
        return Double(challenge.expReward)
    }

    /// Applies a quest ledger adjustment from `rebuildProgress`, clamping the
    /// ledger at zero per adjustment (a revoke never drives it negative).
    private func applyQuestLedgerDelta(_ delta: Double) {
        guard delta != 0 else { return }
        user.bonusXP = max(0, user.bonusXP + delta)
    }

    /// Recomputes every non-expired challenge's progress from history —
    /// called after a workout is edited or deleted so quests can't be
    /// double-counted by delete + re-log, and completions whose qualifying
    /// workout vanished are honestly revoked (XP ledger included).
    private func rebuildChallengeProgress() {
        for i in user.dailyChallenges.indices where !user.dailyChallenges[i].isExpired {
            applyQuestLedgerDelta(rebuildProgress(&user.dailyChallenges[i]))
        }
        for i in user.weeklyChallenges.indices where !user.weeklyChallenges[i].isExpired {
            applyQuestLedgerDelta(rebuildProgress(&user.weeklyChallenges[i]))
        }
    }

    /// Applies changed measurement preferences to active amount quests in
    /// place: same window and reward, new unit and target, with progress
    /// recomputed from work already logged. (The old "Done" button called
    /// the daily/weekly generators, which correctly no-op mid-period — so
    /// it silently did nothing.)
    func applyPreferenceChangesToActiveQuests() {
        guard let rpgClass = user.rpgClass else { return }

        func remade(_ old: Challenge) -> Challenge {
            let details = old.type == .daily
                ? getDailyAmountChallengeDetails(for: old.targetCategory, classType: rpgClass)
                : getWeeklyChallengeDetails(for: old.targetCategory, classType: rpgClass)
            var replacement = Challenge(
                id: UUID(),
                type: old.type,
                title: details.0,
                description: old.description,
                targetCategory: old.targetCategory,
                targetAmount: details.1,
                unit: details.2,
                expReward: old.expReward,
                classType: rpgClass,
                createdAt: old.createdAt,
                expiresAt: old.expiresAt,
                completedAt: nil
            )
            applyQuestLedgerDelta(rebuildProgress(&replacement))
            return replacement
        }

        for i in user.dailyChallenges.indices {
            let challenge = user.dailyChallenges[i]
            guard challenge.isActive, challenge.unit != .exercises,
                  challenge.unit != getPreference(for: challenge.targetCategory).unit else { continue }
            user.dailyChallenges[i] = remade(challenge)
        }
        for i in user.weeklyChallenges.indices {
            let challenge = user.weeklyChallenges[i]
            guard challenge.isActive, challenge.unit != .exercises,
                  challenge.unit != getPreference(for: challenge.targetCategory).unit else { continue }
            user.weeklyChallenges[i] = remade(challenge)
        }
        save()
    }

    /// Returns the XP-ledger delta (+reward on new completion, −reward on
    /// revoke, 0 otherwise) instead of adjusting `user.bonusXP` itself — most
    /// callers hold an inout borrow of a challenge element inside `user`, and
    /// mutating `user` mid-borrow is lost to the @Published writeback. Apply
    /// the returned delta via `applyQuestLedgerDelta` once the borrow ends.
    private func rebuildProgress(_ challenge: inout Challenge) -> Double {
        // The window is the challenge's PERIOD (the day / the week), not its
        // creation moment — a session logged this morning counts toward a
        // daily minted this afternoon. Comeback quests are the exception:
        // their whole point is work done AFTER the return.
        let weeklyInterval = challenge.type == .weekly
            ? Self.weeklyQuestInterval(containing: challenge.createdAt)
            : nil
        let windowStart = (challenge.isComeback ?? false)
            ? challenge.createdAt
            : weeklyInterval?.start
                ?? (Calendar.current.date(byAdding: .day, value: -1, to: challenge.expiresAt)
                    ?? challenge.createdAt)
        let windowEnd = weeklyInterval?.end ?? challenge.expiresAt
        let window = history.filter {
            $0.date >= windowStart && $0.date < windowEnd &&
            $0.category.focus == challenge.targetCategory
        }

        var progress = 0
        var unique = Set<String>()
        for entry in window {
            let workingSets = entry.performedSets?.filter { !$0.isWarmup }
            // Warm-up-only history is retained for routines and transparency,
            // but it must stay invisible to every quest unit during a rebuild.
            if entry.performedSets != nil, workingSets?.isEmpty == true {
                continue
            }

            let setCount = workingSets?.count ?? max(1, entry.sets ?? 1)
            switch challenge.unit {
            case .reps:
                if let workingSets {
                    progress += workingSets.compactMap(\.reps).reduce(0, +)
                } else if let r = entry.reps, r > 0 {
                    progress += r * setCount
                }
            case .sets:
                if let workingSets {
                    progress += workingSets.filter { ($0.reps ?? 0) > 0 }.count
                } else if let r = entry.reps, r > 0 {
                    progress += setCount
                }
            case .minutes:
                if let d = entry.durationMinutes, d > 0 { progress += Int(ceil(d)) }
            case .kilometers:
                if let d = entry.distanceKm, d > 0 { progress += Int(ceil(d)) }
            case .times:
                progress += 1
            case .exercises:
                unique.insert(entry.category.rawValue)
            }
        }
        if challenge.unit == .exercises {
            challenge.uniqueExercises = unique
            progress = unique.count
        }
        challenge.progress = progress

        let meetsTarget = progress >= challenge.targetAmount
        if meetsTarget && challenge.completedAt == nil {
            challenge.completedAt = Date()
            return Double(challenge.expReward)
        } else if !meetsTarget && challenge.completedAt != nil {
            // The workout that completed this quest is gone — revoke honestly.
            challenge.completedAt = nil
            return -Double(challenge.expReward)
        }
        return 0
    }

    func updateChallengeProgress(for category: FocusGroup, amount: Int, unit: ChallengeUnit) {
        var earnedXP = 0.0

        // Update daily challenges
        for i in 0..<user.dailyChallenges.count {
            if user.dailyChallenges[i].isActive &&
               user.dailyChallenges[i].targetCategory == category &&
               user.dailyChallenges[i].unit == unit {
                user.dailyChallenges[i].progress += amount

                // Check if completed
                if user.dailyChallenges[i].progress >= user.dailyChallenges[i].targetAmount &&
                   user.dailyChallenges[i].completedAt == nil {
                    earnedXP += completeChallenge(&user.dailyChallenges[i])
                }
            }
        }

        // Update weekly challenges
        for i in 0..<user.weeklyChallenges.count {
            if user.weeklyChallenges[i].isActive &&
               user.weeklyChallenges[i].targetCategory == category &&
               user.weeklyChallenges[i].unit == unit {
                user.weeklyChallenges[i].progress += amount

                // Check if completed
                if user.weeklyChallenges[i].progress >= user.weeklyChallenges[i].targetAmount &&
                   user.weeklyChallenges[i].completedAt == nil {
                    earnedXP += completeChallenge(&user.weeklyChallenges[i])
                }
            }
        }

        if earnedXP > 0 {
            grantBonusXP(earnedXP)
        }

        save()
    }

    private func updateExerciseVarietyProgress(for category: FocusGroup, exercise: ExerciseCategory) {
        let exerciseName = exercise.rawValue
        var earnedXP = 0.0

        // Update daily challenges
        for i in 0..<user.dailyChallenges.count {
            if user.dailyChallenges[i].isActive &&
               user.dailyChallenges[i].targetCategory == category &&
               user.dailyChallenges[i].unit == .exercises {

                // Add the exercise to the unique set
                let beforeCount = user.dailyChallenges[i].uniqueExercises.count
                user.dailyChallenges[i].uniqueExercises.insert(exerciseName)
                let afterCount = user.dailyChallenges[i].uniqueExercises.count

                // Update progress if we added a new unique exercise
                if afterCount > beforeCount {
                    user.dailyChallenges[i].progress = afterCount

                    // Check if completed
                    if user.dailyChallenges[i].uniqueExercises.count >= user.dailyChallenges[i].targetAmount &&
                       user.dailyChallenges[i].completedAt == nil {
                        earnedXP += completeChallenge(&user.dailyChallenges[i])
                    }
                }
            }
        }

        // Update weekly challenges
        for i in 0..<user.weeklyChallenges.count {
            if user.weeklyChallenges[i].isActive &&
               user.weeklyChallenges[i].targetCategory == category &&
               user.weeklyChallenges[i].unit == .exercises {

                // Add the exercise to the unique set
                let beforeCount = user.weeklyChallenges[i].uniqueExercises.count
                user.weeklyChallenges[i].uniqueExercises.insert(exerciseName)
                let afterCount = user.weeklyChallenges[i].uniqueExercises.count

                // Update progress if we added a new unique exercise
                if afterCount > beforeCount {
                    user.weeklyChallenges[i].progress = afterCount

                    // Check if completed
                    if user.weeklyChallenges[i].uniqueExercises.count >= user.weeklyChallenges[i].targetAmount &&
                       user.weeklyChallenges[i].completedAt == nil {
                        earnedXP += completeChallenge(&user.weeklyChallenges[i])
                    }
                }
            }
        }

        if earnedXP > 0 {
            grantBonusXP(earnedXP)
        }
    }

    func save(immediately: Bool = false) {
        guard persistenceEnabled else { return }

        let data = PersistedData(user: user, history: history)
        pendingSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.performSave(data)
        }
        pendingSaveWorkItem = workItem

        if immediately {
            persistenceQueue.async(execute: workItem)
        } else {
            persistenceQueue.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        }
    }

    func retrySave() {
        save(immediately: true)
    }

    /// Waits for every persistence operation already submitted by this state.
    /// Tests use this instead of timing guesses when verifying destructive
    /// reset behavior against the real save files.
    func flushPersistence() async {
        guard persistenceEnabled else { return }
        await withCheckedContinuation { continuation in
            persistenceQueue.async {
                continuation.resume()
            }
        }
    }

    var canRestoreBackup: Bool {
        guard persistenceEnabled else { return false }
        guard let backupURL = Self.backupURL else { return false }
        return FileManager.default.fileExists(atPath: backupURL.path)
    }

    func restoreFromBackup() {
        guard persistenceEnabled else { return }
        guard let backupURL = Self.backupURL else { return }

        persistenceQueue.async {
            do {
                let backupData = try Data(contentsOf: backupURL)
                DispatchQueue.main.async {
                    do {
                        try self.replaceState(withValidatedSave: backupData)
                    } catch {
                        self.persistenceError = "Failed to restore backup: \(error.localizedDescription)"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.persistenceError = "Failed to restore backup: \(error.localizedDescription)"
                }
            }
        }
    }

    private func performSave(_ data: PersistedData) {
        do {
            let encoded = try Self.jsonEncoder.encode(data)

            if let primaryURL = Self.saveURL {
                // Create backup before saving new data
                createBackup(from: primaryURL)

                try encoded.write(to: primaryURL, options: [.atomic])
                WidgetBridge.publish(user: data.user)
                DispatchQueue.main.async {
                    self.persistenceError = nil
                }
            } else if let fallbackURL = Self.fallbackURL {
                try encoded.write(to: fallbackURL, options: [.atomic])
                DispatchQueue.main.async {
                    self.persistenceError = "Using temporary storage - data may not persist"
                }
            } else {
                DispatchQueue.main.async {
                    self.persistenceError = "Unable to save data - storage unavailable"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.persistenceError = "Failed to save: \(error.localizedDescription)"
            }
        }
    }

    private func createBackup(from primaryURL: URL) {
        guard let backupURL = Self.backupURL,
              FileManager.default.fileExists(atPath: primaryURL.path) else { return }

        // Never rotate corrupt data over the only good backup
        if let data = try? Data(contentsOf: primaryURL), !Self.validateData(data) {
            return
        }

        let fileManager = FileManager.default
        let temporaryBackupURL = backupURL.appendingPathExtension("tmp")

        do {
            if fileManager.fileExists(atPath: temporaryBackupURL.path) {
                try fileManager.removeItem(at: temporaryBackupURL)
            }

            try fileManager.copyItem(at: primaryURL, to: temporaryBackupURL)

            if fileManager.fileExists(atPath: backupURL.path) {
                _ = try fileManager.replaceItemAt(backupURL, withItemAt: temporaryBackupURL)
            } else {
                try fileManager.moveItem(at: temporaryBackupURL, to: backupURL)
            }
        } catch {
            #if DEBUG
            print("Failed to create backup: \(error)")
            #endif
        }
    }

    /// Decodes and performs semantic validation before callers can mutate
    /// live state. This is shared by launch recovery, local restore, iCloud
    /// restore, and automatic-backup rotation.
    static func decodeValidatedSave(_ data: Data) throws -> PersistedData {
        let decoded = try jsonDecoder.decode(PersistedData.self, from: data)

        // Decode "success" isn't enough: a partially-corrupt file can decode
        // with a default (empty) profile. A fresh profile alongside history
        // that EARNED progress can only mean the profile was wiped — but
        // zero-XP entries are legitimate (a warm-up-only session grants
        // nothing on purpose), so only progress-bearing history disqualifies
        // a fresh profile.
        let profileLooksWiped = decoded.user.level == 1 &&
            decoded.user.xp == 0 &&
            decoded.user.coins == 0 &&
            decoded.user.stats.total == 0 &&
            decoded.user.bonusXP == 0
        let historyEarnedProgress = decoded.history.contains {
            $0.expGained > 0 || $0.statGains.total > 0
        }
        guard !profileLooksWiped || !historyEarnedProgress else {
            throw SaveValidationError.implausibleProfile
        }
        return decoded
    }

    private static func validateData(_ data: Data) -> Bool {
        (try? decodeValidatedSave(data)) != nil
    }

    private static func load() -> PersistedLoadResult? {
        // Try primary storage with validation
        if let primaryURL = saveURL {
            do {
                let data = try Data(contentsOf: primaryURL)
                let decoded = try decodeValidatedSave(data)
                return PersistedLoadResult(
                    data: decoded,
                    source: .primary,
                    requiresRewrite: decoded.schemaVersion < PersistedData.currentSchemaVersion
                )
            } catch {
                #if DEBUG
                print("Primary storage validation failed, trying backup: \(error)")
                #endif
            }
        }

        // Try backup if primary failed
        if let backupURL = backupURL {
            do {
                let data = try Data(contentsOf: backupURL)
                let decoded = try decodeValidatedSave(data)
                #if DEBUG
                print("Successfully loaded from backup")
                #endif
                return PersistedLoadResult(
                    data: decoded,
                    source: .backup,
                    requiresRewrite: true
                )
            } catch {
                #if DEBUG
                print("Failed to load from backup storage: \(error)")
                #endif
            }
        }

        // Try fallback (cache) storage
        if let fallbackURL = fallbackURL {
            do {
                let data = try Data(contentsOf: fallbackURL)
                let decoded = try decodeValidatedSave(data)
                return PersistedLoadResult(
                    data: decoded,
                    source: .fallback,
                    requiresRewrite: true
                )
            } catch {
                #if DEBUG
                print("Failed to load from fallback storage: \(error)")
                #endif
            }
        }

        return nil
    }
}
