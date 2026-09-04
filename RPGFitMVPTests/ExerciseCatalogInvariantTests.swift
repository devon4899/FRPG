import Foundation
import Testing
@testable import RPGFitMVP

/// Catalog-wide invariants.
///
/// The exercise catalog is an enum, so the compiler already forces `displayName`,
/// `focus`, `statWeights`, `firstTimeGrant`, `intensityScore` and `placementMetric`
/// to handle every case. What it cannot check is whether a new case was wired
/// *correctly* — several surfaces (`requiredEquipmentOptions`, `prefersDuration`,
/// `primaryDisplayCount`, `placementLevel`) fall through a `default:` clause, and a
/// miswired case fails silently: the user logs a session and banks zero XP.
///
/// These tests run over `ExerciseCategory.allCases`, so every exercise added from
/// here on is held to the same contract without anyone remembering to update a list.
struct ExerciseCatalogInvariantTests {

    // MARK: - Helpers

    /// A session shaped the way this exercise actually gets logged, so a
    /// rep-scored move receives reps and a timed move receives minutes.
    private static func plausibleInput(
        for category: ExerciseCategory
    ) -> (reps: Int?, weight: Double?, durationMin: Double?, distanceKm: Double?) {
        if category.prefersDuration {
            // Distance-capable modalities are scored on pace, so they need both.
            let metric = StatEngine.placementMetric(
                category: category, reps: nil, weight: nil,
                durationMin: 30, distanceKm: 5, bodyweightKg: 80
            )
            let needsDistance = metric > 0 && StatEngine.placementMetric(
                category: category, reps: nil, weight: nil,
                durationMin: 30, distanceKm: nil, bodyweightKg: 80
            ) == 0
            return (nil, nil, 30, needsDistance ? 5 : nil)
        }
        return (8, 60, nil, nil)
    }

    private static let statBands: [FocusGroup: ClosedRange<Double>] = [
        .strength: 2.4...3.2,
        .hypertrophy: 1.7...2.4,
        .bodyweight: 1.6...2.1,
        .explosive: 1.8...2.1,
        .endurance: 1.9...2.2,
        .mobility: 1.4...1.6,
    ]

    private static func total(_ b: StatBlock) -> Double {
        b.size + b.strength + b.dexterity + b.agility + b.endurance + b.vitality
    }

    // MARK: - Distribution invariants

    /// `statWeights` is a distribution handed to `StatEngine.distribute`, which
    /// exponentiates each weight and normalises by their sum. Weights that do not
    /// total 1.0 still "work" but silently shift how a session's stat budget splits,
    /// so the sum is the contract that keeps every exercise comparable.
    @Test func statWeightsFormADistribution() {
        for category in ExerciseCategory.allCases {
            let sum = Self.total(StatEngine.statWeights(for: category))
            #expect(
                abs(sum - 1.0) < 0.0001,
                "\(category.rawValue) statWeights sum to \(sum), expected 1.0"
            )
        }
    }

    @Test func statWeightsAreNeverNegative() {
        for category in ExerciseCategory.allCases {
            let w = StatEngine.statWeights(for: category)
            for (name, value) in [("size", w.size), ("strength", w.strength),
                                  ("dexterity", w.dexterity), ("agility", w.agility),
                                  ("endurance", w.endurance), ("vitality", w.vitality)] {
                #expect(value >= 0, "\(category.rawValue) has negative \(name) weight \(value)")
            }
        }
    }

    /// The one-time grant is the only stat award that bypasses the XP budget, so an
    /// out-of-band value hands out free progression. Bands are the observed min/max
    /// of each focus group, which is what keeps a curl from paying like a deadlift.
    @Test func firstTimeGrantStaysInsideItsFocusBand() {
        for category in ExerciseCategory.allCases {
            guard let band = Self.statBands[category.focus] else {
                Issue.record("no grant band defined for focus \(category.focus.rawValue)")
                continue
            }
            // Summing 2-decimal literals drifts (1.1 + 1.1 + 0.2 == 2.4000000000000004),
            // so compare against the band with a tolerance rather than exactly.
            let sum = Self.total(StatEngine.firstTimeGrant(for: category))
            #expect(
                sum >= band.lowerBound - 0.0001 && sum <= band.upperBound + 0.0001,
                "\(category.rawValue) (\(category.focus.rawValue)) grants \(sum), outside \(band)"
            )
        }
    }

    // MARK: - Scoring coherence
    //
    // The silent-failure class this suite exists for: `prefersDuration` decides
    // whether the logging UI shows a timed row or set rows, while `intensityScore`
    // and `placementMetric` decide what actually counts. If those disagree, the user
    // fills in the only fields offered and banks nothing.

    @Test func everyExerciseScoresFromTheInputItAsksFor() {
        for category in ExerciseCategory.allCases {
            let input = Self.plausibleInput(for: category)
            let score = StatEngine.intensityScore(
                category: category, reps: input.reps, weight: input.weight,
                durationMin: input.durationMin, distanceKm: input.distanceKm
            )
            #expect(
                score > 0,
                "\(category.rawValue) scores 0 from a \(category.prefersDuration ? "timed" : "set-based") log — prefersDuration disagrees with intensityScore"
            )
        }
    }

    @Test func everyExerciseProducesAPlacementMetricFromTheInputItAsksFor() {
        for category in ExerciseCategory.allCases {
            let input = Self.plausibleInput(for: category)
            let metric = StatEngine.placementMetric(
                category: category, reps: input.reps, weight: input.weight,
                durationMin: input.durationMin, distanceKm: input.distanceKm,
                bodyweightKg: 80
            )
            #expect(
                metric > 0,
                "\(category.rawValue) yields no placement metric from a \(category.prefersDuration ? "timed" : "set-based") log"
            )
        }
    }

    /// Placement is what seeds a lifter's level, and it is reached through exactly
    /// one entry point. A category that places at 0 from a real session would tell
    /// the user their effort was worthless.
    ///
    /// Mobility work is the deliberate exception: prehab is meant to feed the
    /// EMA, XP, attributes, quests, and streak logic rather than seed a starting
    /// level from one session.
    @Test func everyExercisePlacesAboveZero() {
        for category in ExerciseCategory.allCases
        where category.focus != .mobility {
            let input = Self.plausibleInput(for: category)
            let level = StatEngine.placementLevelCandidate(
                category: category, reps: input.reps, weight: input.weight,
                durationMin: input.durationMin, distanceKm: input.distanceKm,
                bodyweightKg: 80
            )
            #expect(level > 0, "\(category.rawValue) places at level 0 from a plausible session")
            #expect(level <= 100, "\(category.rawValue) places above the level cap at \(level)")
        }
    }

    @Test func placementLevelNeverExceedsTheCap() {
        for category in ExerciseCategory.allCases {
            let input = Self.plausibleInput(for: category)
            let level = StatEngine.placementLevelCandidate(
                category: category, reps: input.reps, weight: input.weight,
                durationMin: input.durationMin, distanceKm: input.distanceKm,
                bodyweightKg: 80
            )
            #expect((0...100).contains(level), "\(category.rawValue) places at \(level)")
        }
    }

    private static let conditioningScaleChecks: Set<ExerciseCategory> = [
        .sledPush, .hikingStairs, .battleRopes, .jumpRope, .sprint,
    ]

    /// Duration-led conditioning now places from the same normalized work score
    /// that the logger computes. A longer session must therefore be reachable and
    /// rank above a shorter session instead of comparing raw minutes against a
    /// work-score constant (or, for sprint, accidentally rewarding less time).
    @Test func conditioningPlacementIsReachableAndMonotonic() {
        for category in Self.conditioningScaleChecks {
            let short = StatEngine.placementLevelCandidate(
                category: category, reps: nil, weight: nil,
                durationMin: 10, distanceKm: nil, bodyweightKg: 80
            )
            let sustained = StatEngine.placementLevelCandidate(
                category: category, reps: nil, weight: nil,
                durationMin: 30, distanceKm: nil, bodyweightKg: 80
            )
            #expect(short > 0, "\(category.rawValue) cannot place from ten minutes")
            #expect(sustained > short,
                    "\(category.rawValue) does not scale with additional logged work")
            #expect(sustained < StatEngine.maxLevel,
                    "\(category.rawValue) saturates the level curve after thirty minutes")
        }
    }

    @Test func everyExerciseEarnsXP() {
        for category in ExerciseCategory.allCases {
            let input = Self.plausibleInput(for: category)
            let score = StatEngine.intensityScore(
                category: category, reps: input.reps, weight: input.weight,
                durationMin: input.durationMin, distanceKm: input.distanceKm
            )
            #expect(
                StatEngine.exp(for: category, score: score) > 0,
                "\(category.rawValue) earns no XP from a plausible session"
            )
        }
    }

    // MARK: - 1RM relevance

    /// `estimate1RM` gates on a hard-coded set. Announcing an estimated 1RM for a
    /// movement nobody maxes (or failing to announce one for a movement everybody
    /// does) is the visible half of that set drifting from the placement rules.
    @Test func oneRMEstimationMatchesTheLiftsThatUseIt() {
        for category in ExerciseCategory.allCases {
            let estimate = StatEngine.estimate1RM(category: category, reps: 5, weight: 100)
            guard estimate > 0 else { continue }
            // A lift with a real 1RM estimate must place off that estimate, not off
            // a volume or duration metric, or its level and its headline disagree.
            let metric = StatEngine.placementMetric(
                category: category, reps: 5, weight: 100,
                durationMin: nil, distanceKm: nil, bodyweightKg: 80
            )
            #expect(
                abs(metric - estimate) < 0.001,
                "\(category.rawValue) estimates a 1RM of \(estimate) but places off \(metric)"
            )
        }
    }

    // MARK: - Identity and presentation

    @Test func displayNamesAreUniqueAndPresentable() {
        var seen: [String: String] = [:]
        for category in ExerciseCategory.allCases {
            let name = category.displayName
            #expect(!name.isEmpty, "\(category.rawValue) has an empty display name")
            #expect(
                name != category.rawValue,
                "\(category.rawValue) has no human-readable display name"
            )
            let key = name.lowercased()
            if let owner = seen[key] {
                Issue.record("\(category.rawValue) shares the display name \"\(name)\" with \(owner)")
            }
            seen[key] = category.rawValue
        }
    }

    /// Raw values are the persistence keys for `bestPerf`, `best1RM`, `xpBaselines`
    /// and `firstStatGrantApplied`. A collision would silently merge two exercises'
    /// history; a rename would orphan it.
    @Test func rawValuesAreUnique() {
        let raws = ExerciseCategory.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count, "duplicate ExerciseCategory raw values")
    }

    @Test func everyFocusGroupHasExercises() {
        for focus in FocusGroup.allCases {
            let count = ExerciseCategory.allCases.filter { $0.focus == focus }.count
            #expect(count > 0, "focus group \(focus.rawValue) has no exercises")
        }
    }

    @Test func primaryDisplayCountIsRenderable() {
        for category in ExerciseCategory.allCases {
            let count = StatEngine.primaryDisplayCount(for: category)
            #expect((2...3).contains(count), "\(category.rawValue) displays \(count) primary stats")
        }
    }

    // MARK: - Equipment gating

    /// Gating hides an exercise outright from anyone without the gear, so an
    /// over-gated movement is invisible rather than merely inconvenient. The
    /// house rule is that gating is only for what is genuinely impossible.
    @Test func equipmentGatingUsesKnownKinds() {
        for category in ExerciseCategory.allCases {
            let options = category.requiredEquipmentOptions
            #expect(
                Set(options).count == options.count,
                "\(category.rawValue) lists a duplicate equipment kind"
            )
        }
    }

    /// A bodyweight-only trainee must retain a usable catalog in every focus group
    /// they can actually train, or the picker strands them on an empty screen.
    @Test func bodyweightOnlyTraineeKeepsAUsableCatalog() {
        let state = AppState(persistenceEnabled: false)
        state.configuredEquipment = []
        let available = ExerciseCategory.allCases.filter { state.isAvailable($0) }
        let share = Double(available.count) / Double(ExerciseCategory.allCases.count)
        #expect(
            share >= 0.4,
            "only \(available.count) of \(ExerciseCategory.allCases.count) exercises survive a bodyweight-only setup"
        )

        for focus in [FocusGroup.bodyweight, .mobility, .endurance] {
            let inFocus = available.filter { $0.focus == focus }
            #expect(!inFocus.isEmpty, "bodyweight-only trainee has no \(focus.rawValue) exercises")
        }
    }

    /// Mobility and prehab work is the catalog's floor — it should never require
    /// equipment a beginner is unlikely to own.
    @Test func mobilityWorkStaysAvailableWithoutAGym() {
        let state = AppState(persistenceEnabled: false)
        state.configuredEquipment = []
        let mobility = ExerciseCategory.allCases.filter { $0.focus == .mobility }
        let available = mobility.filter { state.isAvailable($0) }
        #expect(
            Double(available.count) / Double(mobility.count) >= 0.6,
            "only \(available.count) of \(mobility.count) mobility exercises work without equipment"
        )
    }

    // MARK: - Rest timing

    @Test func everyExerciseHasAUsableRestDefault() {
        for category in ExerciseCategory.allCases {
            let rest = category.defaultRestSeconds
            #expect((30...300).contains(rest), "\(category.rawValue) rests \(rest)s between sets")
        }
    }
}
