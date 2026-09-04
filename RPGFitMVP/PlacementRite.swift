import SwiftUI
import Foundation

// MARK: - The Weighing at the Ledgerstone
//
// A tap-only placement rite run once during onboarding. It writes only what
// it can verify: self-reported ladders map to FIXED levels (never through the
// engine, whose low-end anchors clamp beginners upward), while exact numbers
// typed into the drawer go through StatEngine so they inherit the same curves
// the rest of the app is scored on.
//
// Nothing here touches stats/level/xp/ranks — recalculateStatsAndXP hard-resets
// all four from history. Only best1RM (re-applied by the recalc fold-in),
// xpBaselines (never touched by recalc) and the bonusXP ledger survive edits,
// so those are the only channels the rite is allowed to write.

/// Where an attribute stands on the campaign map. Raw values are ordered and
/// persisted, so new bands may only be appended.
enum PlacementBand: Int, Codable, Comparable, CaseIterable {
    case unwritten = 0, gate = 1, kindlingVale = 2, ashenPasses = 3,
         stormreach = 4, crownOfDawn = 5, elderWilds = 6

    static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }

    static func from(level: Int) -> PlacementBand {
        switch level {
        case ..<15: return .gate
        case 15..<35: return .kindlingVale
        case 35..<60: return .ashenPasses
        case 60..<80: return .stormreach
        case 80..<95: return .crownOfDawn
        default: return .elderWilds
        }
    }

    /// Used in ledger rows: "Strength — walks the Ashen Passes".
    var phrase: String {
        switch self {
        case .unwritten: return "Unwritten"
        case .gate: return "stands At the Gate"
        case .kindlingVale: return "walks the Kindling Vale"
        case .ashenPasses: return "walks the Ashen Passes"
        case .stormreach: return "walks the Stormreach"
        case .crownOfDawn: return "walks the Crown of Dawn"
        case .elderWilds: return "roams the Elder Wilds"
        }
    }

    /// Filled waypoint diamonds on a ledger row (0–5, Elder Wilds shares the
    /// top mark — the map has five named regions, not six).
    var waypoints: Int { min(5, rawValue) }
}

// MARK: - Staged answers

/// Staged onboarding state. Nothing here is written until the final CTA fires,
/// so back-navigation re-derives the whole verdict. It is Codable only so the
/// sealed record can carry the answers verbatim: a band cannot be reversed into
/// the rung that wrote it (two rungs share the Gate) and a drawer-derived band
/// belongs to no rung at all.
struct WeighingAnswers: Equatable, Codable {
    var fireIndex: Int? = nil          // 0..3
    var strIndex: Int? = nil           // 0..4 barbell ladder
    var dexIndex: Int? = nil           // 0..4 push-up ladder
    var endIndex: Int? = nil           // 0..4 running ladder
    // Drawer (exact numbers) — all optional, override the matching ladder when valid.
    var drawerLift: ExerciseCategory? = nil        // .squat/.benchPress/.deadlift/.overheadPress
    var drawerWeightKg: Double? = nil              // canonical kg
    var drawerReps: Int = 5                        // stepper 1...12
    var drawerPushUps: Int? = nil                  // 0...200
    var drawerRunMinutes: Double? = nil            // 3...360
    var drawerRunKm: Double? = nil                 // 0.5...42.2 (canonical km)
    var skipped: Bool = false

    var anythingAnswered: Bool {
        strIndex != nil || dexIndex != nil || endIndex != nil || fireIndex != nil
    }

    /// The drawer is only offered to people whose fire is at least warm —
    /// asking a total beginner for exact numbers is the failure mode this
    /// whole rite exists to avoid.
    var drawerAvailable: Bool {
        guard let i = fireIndex, PlacementRite.fireLadder.indices.contains(i) else { return false }
        return PlacementRite.fireLadder[i].opensDrawer
    }
}

// MARK: - The persisted record

/// The recalc-proof persisted record. Every field decodes with a default so a
/// corrupt blob degrades to "never weighed" instead of discarding the profile.
struct PlacementRecord: Codable {
    var epithet: String                           // includes "the " prefix, e.g. "the Quiet Anvil"
    var bands: [String: Int]                      // Stat.abbreviation ("STR"…"VIT") -> PlacementBand.rawValue
    var seeds: [ExerciseCategory: Double]         // discounted best1RM-store seeds
    var baselineSeeds: [ExerciseCategory: Double] // the 0.90× metrics applied to xpBaselines
    var receipts: [String]                        // verbatim drawer receipt lines for re-display
    var fireIndex: Int                            // -1 if unanswered
    var usedDrawer: Bool
    var skipped: Bool
    var bonusGranted: Bool                        // honesty-XP idempotence
    var date: Date
    var version: Int
    /// What the player actually said, kept so a re-run prefills the answers
    /// instead of guessing them back out of the bands.
    var answers: WeighingAnswers?

    init(epithet: String,
         bands: [String: Int],
         seeds: [ExerciseCategory: Double],
         baselineSeeds: [ExerciseCategory: Double],
         receipts: [String],
         fireIndex: Int,
         usedDrawer: Bool,
         skipped: Bool,
         bonusGranted: Bool,
         answers: WeighingAnswers? = nil,
         date: Date = Date(),
         version: Int = PlacementRecord.currentVersion) {
        self.epithet = epithet
        self.bands = bands
        self.seeds = seeds
        self.baselineSeeds = baselineSeeds
        self.receipts = receipts
        self.fireIndex = fireIndex
        self.usedDrawer = usedDrawer
        self.skipped = skipped
        self.bonusGranted = bonusGranted
        self.answers = answers
        self.date = date
        self.version = version
    }

    static let currentVersion = 1

    enum CodingKeys: String, CodingKey {
        case epithet
        case bands
        case seeds
        case baselineSeeds
        case receipts
        case fireIndex
        case usedDrawer
        case skipped
        case bonusGranted
        case date
        case version
        case answers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        epithet = c.placementValue(String.self, forKey: .epithet, default: PlacementRite.unwrittenEpithet.name)
        bands = c.placementValue([String: Int].self, forKey: .bands, default: [:])
        seeds = c.placementValue([ExerciseCategory: Double].self, forKey: .seeds, default: [:])
        baselineSeeds = c.placementValue([ExerciseCategory: Double].self, forKey: .baselineSeeds, default: [:])
        receipts = c.placementValue([String].self, forKey: .receipts, default: [])
        fireIndex = c.placementValue(Int.self, forKey: .fireIndex, default: -1)
        usedDrawer = c.placementValue(Bool.self, forKey: .usedDrawer, default: false)
        skipped = c.placementValue(Bool.self, forKey: .skipped, default: false)
        // A record whose grant flag is lost must not pay the honesty bonus a
        // second time, so an unreadable flag reads as "already granted".
        bonusGranted = c.placementValue(Bool.self, forKey: .bonusGranted, default: true)
        date = c.placementValue(Date.self, forKey: .date, default: Date())
        version = c.placementValue(Int.self, forKey: .version, default: PlacementRecord.currentVersion)
        // An unreadable blob degrades to "no prefill", never to a fabricated
        // answer — the seeds and bands above stand on their own.
        answers = (try? c.decodeIfPresent(WeighingAnswers.self, forKey: .answers)) ?? nil
    }

    /// The band this record wrote for a stat, for the header/identity line.
    func band(for stat: Stat) -> PlacementBand {
        PlacementBand(rawValue: bands[stat.abbreviation] ?? 0) ?? .unwritten
    }
}

private extension KeyedDecodingContainer {
    func placementValue<T: Decodable>(_ type: T.Type, forKey key: Key, default defaultValue: @autoclosure () -> T) -> T {
        (try? decodeIfPresent(type, forKey: key)) ?? defaultValue()
    }
}

// MARK: - Tables, math and copy

enum PlacementRite {

    // MARK: Tuning constants

    /// Seeded best1RM sits below assessed ability so an honest first session at
    /// true strength still rings the first-PR bell instead of landing under a
    /// seed that was already at 100%.
    static let seedFactor: Double = 0.85
    /// Seeded xpBaselines sit below assessed ability so a sub-baseline first
    /// session still pays 10–13 XP rather than the 8–9 floor.
    static let baselineFactor: Double = 0.90
    /// Flat, once ever, performance-independent: a Stormreach walker and a Gate
    /// walker earn the same, so there is zero incentive to inflate.
    static let honestyBonusXP: Double = 10

    // MARK: The Fire

    struct FireRung {
        let copy: String
        /// Seed multiplier. Bands are never discounted — the stone remembers
        /// what you were; the seeds respect what you are.
        let seedMultiplier: Double
        let opensDrawer: Bool
    }

    static let fireLadder: [FireRung] = [
        FireRung(copy: "It hasn't. Not yet.", seedMultiplier: 0.0, opensDrawer: false),
        FireRung(copy: "Years ago. Another life.", seedMultiplier: 0.7, opensDrawer: false),
        FireRung(copy: "Months. The embers are warm.", seedMultiplier: 1.0, opensDrawer: true),
        FireRung(copy: "It burns now.", seedMultiplier: 1.0, opensDrawer: true)
    ]

    /// An unanswered fire makes no claim about detraining, so it carries no
    /// discount — the 0.85 seed factor is already the conservative floor.
    static func fireSeedMultiplier(_ index: Int?) -> Double {
        guard let i = index, fireLadder.indices.contains(i) else { return 1.0 }
        return fireLadder[i].seedMultiplier
    }

    // MARK: The three measured ladders

    /// What a rung implies about performance. Only determinate claims seed:
    /// a single at a stated bodyweight ratio, or a stated rep count.
    enum LadderSample: Equatable {
        case none
        /// Implied squat 1RM = max(floorKg, ratio × bodyweight).
        case oneRMRatio(ratio: Double, floorKg: Double)
        /// Implied strict push-up reps.
        case pushUpReps(Int)
    }

    struct LadderRung: Identifiable {
        let copy: String
        /// Direct band level — deliberately not routed through the engine,
        /// whose lowest anchors would over-place every beginner.
        let level: Int
        let sample: LadderSample

        var band: PlacementBand { PlacementBand.from(level: level) }
        var id: String { copy }
    }

    struct Ladder: Identifiable {
        let stat: Stat
        let prompt: String
        let rungs: [LadderRung]

        /// Derived, never stored: a ladder wears its attribute's semantic mark,
        /// and the ledger two pages later draws the same one from that source.
        var rpgSymbol: RPGSymbol { stat.rpgSymbol }
        var id: String { stat.rawValue }
    }

    /// Self-report tops out at Stormreach by construction: the Crown of Dawn is
    /// reachable only through drawer exact numbers, the Elder Wilds only by
    /// logging real work.
    static let ironLadder = Ladder(
        stat: .strength,
        prompt: "The loaded barbell —",
        rungs: [
            LadderRung(copy: "We haven't met.", level: 5, sample: .none),
            LadderRung(copy: "I move the empty bar, with respect.", level: 8,
                       sample: .oneRMRatio(ratio: 0.45, floorKg: 20)),
            LadderRung(copy: "About my own bodyweight, for a clean single.", level: 25,
                       sample: .oneRMRatio(ratio: 1.00, floorKg: 0)),
            LadderRung(copy: "Well past my bodyweight.", level: 45,
                       sample: .oneRMRatio(ratio: 1.50, floorKg: 0)),
            LadderRung(copy: "Plates run out before I do.", level: 62,
                       sample: .oneRMRatio(ratio: 1.90, floorKg: 0))
        ]
    )

    static let bodyLadder = Ladder(
        stat: .dexterity,
        prompt: "Push-ups from the floor. Honest ones —",
        rungs: [
            // Zero is a first-class answer, not a failure: it writes a band and
            // seeds nothing.
            LadderRung(copy: "The floor wins, for now.", level: 2, sample: .pushUpReps(0)),
            LadderRung(copy: "A handful.", level: 8, sample: .pushUpReps(4)),
            LadderRung(copy: "A steady dozen.", level: 20, sample: .pushUpReps(12)),
            LadderRung(copy: "Twenty-five and climbing.", level: 38, sample: .pushUpReps(25)),
            LadderRung(copy: "The floor stopped counting.", level: 62, sample: .pushUpReps(45))
        ]
    )

    /// The road never seeds: minutes without distance underdetermine both
    /// placementLevelCandidate and placementMetric, and any assumed pace would
    /// be an invented constant. Endurance seeds only from the drawer.
    static let roadLadder = Ladder(
        stat: .endurance,
        prompt: "Without stopping, you can run —",
        rungs: [
            LadderRung(copy: "I walk. And I own that.", level: 5, sample: .none),
            LadderRung(copy: "A few hard minutes.", level: 15, sample: .none),
            LadderRung(copy: "About ten minutes.", level: 25, sample: .none),
            LadderRung(copy: "Half an hour, steady.", level: 45, sample: .none),
            LadderRung(copy: "An hour holds no fear.", level: 65, sample: .none)
        ]
    )

    static let ladders: [Ladder] = [ironLadder, bodyLadder, roadLadder]

    static func rung(_ ladder: Ladder, _ index: Int?) -> LadderRung? {
        guard let i = index, ladder.rungs.indices.contains(i) else { return nil }
        return ladder.rungs[i]
    }

    // MARK: Push-up anchors

    /// ACSM-style strict-rep norms, set at the untrained-male/trained-female
    /// midpoint because the app collects no sex anywhere — keep it that way, and
    /// keep the bands wide enough that nobody is over-ranked.
    /// StatEngine.interpLevel is private, and pushUp falls into its kg-scaled
    /// default branch (30 reps would price at ~level 6), so both the table and
    /// the interpolation live here.
    static let pushUpAnchors: [(Double, Int)] = [
        (0, 0), (5, 8), (12, 20), (20, 32), (30, 45), (45, 62), (60, 78), (80, 92)
    ]

    static func pushUpLevel(reps: Int) -> Int {
        interpolate(x: Double(max(0, reps)), anchors: pushUpAnchors)
    }

    private static func interpolate(x: Double, anchors: [(Double, Int)]) -> Int {
        guard let first = anchors.first, let last = anchors.last else { return 0 }
        if x <= first.0 { return clampLevel(first.1) }
        if x >= last.0 { return clampLevel(last.1) }
        for i in 0..<(anchors.count - 1) {
            let (x0, y0) = anchors[i]
            let (x1, y1) = anchors[i + 1]
            if x >= x0 && x <= x1 {
                let t = (x - x0) / max(1e-9, x1 - x0)
                return clampLevel(Int(round(Double(y0) + t * Double(y1 - y0))))
            }
        }
        return 0
    }

    private static func clampLevel(_ v: Int) -> Int { max(0, min(100, v)) }

    // MARK: Drawer ranges and clamps

    static let drawerLifts: [ExerciseCategory] = [.squat, .benchPress, .deadlift, .overheadPress]
    static let weightRangeKg: ClosedRange<Double> = 2.5...400
    /// Brzycki is only defined to 15 reps and estimate1RM returns 0 above it —
    /// capping the stepper at 12 means the drawer can never silently zero.
    static let repsRange: ClosedRange<Int> = 1...12
    static let pushUpRange: ClosedRange<Int> = 0...200
    static let runMinutesRange: ClosedRange<Double> = 3...360
    static let runKmRange: ClosedRange<Double> = 0.5...42.2
    static let runSpeedRangeKPH: ClosedRange<Double> = 4...23
    /// Below this the engine's lowest running anchor (8 km/h → L25) clamps
    /// every walker up to the Kindling Vale.
    static let walkerSpeedKPH: Double = 7.5
    static let walkerLevelCap: Int = 12

    /// Plausible est-1RM / bodyweight ceilings. Beyond these the stone writes a
    /// cautious number instead of refusing the entry.
    static func ratioCap(for lift: ExerciseCategory) -> Double {
        switch lift {
        case .squat: return 3.0
        case .deadlift: return 3.5
        case .benchPress: return 2.3
        case .overheadPress: return 1.5
        default: return 3.0
        }
    }

    static func shortName(for lift: ExerciseCategory) -> String {
        switch lift {
        case .squat: return "Squat"
        case .benchPress: return "Bench"
        case .deadlift: return "Deadlift"
        case .overheadPress: return "Press"
        default: return lift.displayName
        }
    }

    // MARK: Drawer readings

    /// Every rejection is visible inline text, never a silent no-op.
    enum DrawerIssue: Equatable {
        case weightOutOfRange
        case unreadableLift
        case pushUpsOutOfRange
        case durationOutOfRange
        case distanceOutOfRange
        case paceImplausible

        func message(units: Units) -> String {
            switch self {
            case .weightOutOfRange:
                return PlacementCopy.trustedRange(
                    lo: PlacementCopy.number(units.fromKg(PlacementRite.weightRangeKg.lowerBound), decimals: 1),
                    hi: PlacementCopy.number(units.fromKg(PlacementRite.weightRangeKg.upperBound), decimals: 0),
                    suffix: units.displayName)
            case .unreadableLift:
                return "The stone cannot read that lift. Choose one."
            case .pushUpsOutOfRange:
                return PlacementCopy.trustedRange(
                    lo: "\(PlacementRite.pushUpRange.lowerBound)",
                    hi: "\(PlacementRite.pushUpRange.upperBound)",
                    suffix: nil)
            case .durationOutOfRange:
                return PlacementCopy.trustedRange(
                    lo: PlacementCopy.number(PlacementRite.runMinutesRange.lowerBound, decimals: 0),
                    hi: PlacementCopy.number(PlacementRite.runMinutesRange.upperBound, decimals: 0),
                    suffix: "min")
            case .distanceOutOfRange:
                return PlacementCopy.trustedRange(
                    lo: PlacementCopy.number(units.fromKm(PlacementRite.runKmRange.lowerBound), decimals: 1),
                    hi: PlacementCopy.number(units.fromKm(PlacementRite.runKmRange.upperBound), decimals: 1),
                    suffix: units.distanceDisplayName)
            case .paceImplausible:
                return PlacementCopy.doubtfulPace
            }
        }
    }

    enum Outcome<T> {
        case unanswered
        case issue(DrawerIssue)
        case reading(T)

        var value: T? { if case .reading(let v) = self { return v }; return nil }
        var problem: DrawerIssue? { if case .issue(let i) = self { return i }; return nil }
    }

    struct IronReading {
        let lift: ExerciseCategory
        /// After the sanity clamp — this is what gets seeded.
        let estKg: Double
        let rawEstKg: Double
        let level: Int
        let band: PlacementBand
        let clamped: Bool
        let receipt: String
    }

    struct BodyReading {
        let reps: Int
        let level: Int
        let band: PlacementBand
        let receipt: String
    }

    struct RoadReading {
        let minutes: Double
        let km: Double
        let speedKPH: Double
        let level: Int
        let band: PlacementBand
        let metric: Double
        let receipt: String
    }

    static func ironReading(lift: ExerciseCategory?,
                            weightKg: Double?,
                            reps: Int,
                            bodyweightKg: Double?,
                            units: Units) -> Outcome<IronReading> {
        guard let lift else { return .unanswered }
        guard drawerLifts.contains(lift) else { return .issue(.unreadableLift) }
        guard let w = weightKg, w.isFinite else { return .unanswered }
        guard weightRangeKg.contains(w) else { return .issue(.weightOutOfRange) }
        let r = min(repsRange.upperBound, max(repsRange.lowerBound, reps))
        let rawEst = StatEngine.estimate1RM(category: lift, reps: r, weight: w)
        guard rawEst > 0 else { return .issue(.unreadableLift) }

        let bw = effectiveBodyweight(bodyweightKg)
        let cap = ratioCap(for: lift) * bw
        let clamped = rawEst > cap
        let est = clamped ? cap : rawEst

        // The band reads the entry as typed; only the seed is clamped — the
        // clamp guards the XP economy, not the compliment.
        let level = StatEngine.placementLevelCandidate(category: lift,
                                                       reps: r, weight: w,
                                                       durationMin: nil, distanceKm: nil,
                                                       bodyweightKg: bw)
        let receipt = PlacementCopy.ironReceipt(lift: lift, weightKg: w, reps: r,
                                                estKg: est, bodyweightKg: bw, units: units)
        return .reading(IronReading(lift: lift, estKg: est, rawEstKg: rawEst,
                                    level: level, band: PlacementBand.from(level: level),
                                    clamped: clamped, receipt: receipt))
    }

    static func bodyReading(pushUps: Int?) -> Outcome<BodyReading> {
        guard let n = pushUps else { return .unanswered }
        guard pushUpRange.contains(n) else { return .issue(.pushUpsOutOfRange) }
        let level = pushUpLevel(reps: n)
        return .reading(BodyReading(reps: n, level: level,
                                    band: PlacementBand.from(level: level),
                                    receipt: PlacementCopy.bodyReceipt(reps: n)))
    }

    static func roadReading(minutes: Double?,
                            km: Double?,
                            bodyweightKg: Double?,
                            units: Units) -> Outcome<RoadReading> {
        guard let t = minutes, let d = km, t.isFinite, d.isFinite else { return .unanswered }
        guard runMinutesRange.contains(t) else { return .issue(.durationOutOfRange) }
        guard runKmRange.contains(d) else { return .issue(.distanceOutOfRange) }
        let speed = d / (t / 60.0)
        guard runSpeedRangeKPH.contains(speed) else { return .issue(.paceImplausible) }

        let bw = effectiveBodyweight(bodyweightKg)
        var level = StatEngine.placementLevelCandidate(category: .run,
                                                       reps: nil, weight: nil,
                                                       durationMin: t, distanceKm: d,
                                                       bodyweightKg: bw)
        // The engine's lowest running anchor is 8 km/h → L25, and interpLevel
        // returns the first anchor for anything below it. Walkers would place
        // in the Kindling Vale on a walk.
        if speed < walkerSpeedKPH { level = min(level, walkerLevelCap) }

        let metric = StatEngine.placementMetric(category: .run,
                                                reps: nil, weight: nil,
                                                durationMin: t, distanceKm: d,
                                                bodyweightKg: bw)
        return .reading(RoadReading(minutes: t, km: d, speedKPH: speed, level: level,
                                    band: PlacementBand.from(level: level),
                                    metric: metric,
                                    receipt: PlacementCopy.roadReceipt(minutes: t, km: d, units: units)))
    }

    /// placementMetric defaults to 70 kg when bodyweight is unknown; match it so
    /// bands and seeds can never disagree about the same body.
    static func effectiveBodyweight(_ kg: Double?) -> Double {
        let bw = kg ?? 70.0
        return bw.isFinite && bw > 0 ? bw : 70.0
    }

    // MARK: Copy — aphorism grid

    /// Keyed stat × band. Crown of Dawn and the Elder Wilds share a line: past
    /// the Crown the stone has run out of map, not out of respect.
    static let aphorisms: [Stat: [PlacementBand: String]] = [
        .strength: [
            .gate: "Every plate you will ever lift is still ahead of you. Lucky.",
            .kindlingVale: "The bar has learned your name. It will not forget.",
            .ashenPasses: "Built in weeks nobody watched.",
            .stormreach: "Iron argued. Iron lost.",
            .crownOfDawn: "Heavy things agree to move for you.",
            .elderWilds: "Heavy things agree to move for you."
        ],
        .dexterity: [
            .gate: "The floor wins, for now. It will not win long.",
            .kindlingVale: "Your own weight is the first opponent. You two have met.",
            .ashenPasses: "The floor has stopped winning.",
            .stormreach: "You carry yourself lightly. That is the whole trick.",
            .crownOfDawn: "The floor pushed back. It stopped.",
            .elderWilds: "The floor pushed back. It stopped."
        ],
        .endurance: [
            .gate: "The road is long. So is the year.",
            .kindlingVale: "You have learned the mile's first secret: another mile.",
            .ashenPasses: "It burns slow on purpose.",
            .stormreach: "The valley's shadow gave up at mile three.",
            .crownOfDawn: "The horizon keeps moving. So do you.",
            .elderWilds: "The horizon keeps moving. So do you."
        ]
    ]

    static let sizeInferredLine = "Weighed by inference. The stone is old, not blind."
    // The band phrase line above these already says "Unwritten" — repeating it
    // here would stutter both on screen and in the composed VoiceOver line.
    static let agilityLine = "Speed is proven in flight, not on scales."
    static let vitalityLine = "The oak breaks; the willow trains mobility. The stone will watch."
    static let unwrittenRowLine = "Empty is not a verdict."

    /// The three ladders measure three attributes. A sixty-second stone cannot
    /// measure six; pretending it could is the cliché this feature beats.
    static let measurableStats: [Stat] = [.strength, .dexterity, .endurance]
    static let ledgerOrder: [Stat] = [.strength, .size, .dexterity, .agility, .endurance, .vitality]

    static func aphorism(for stat: Stat, band: PlacementBand) -> String {
        switch stat {
        case .size:
            return band == .unwritten ? unwrittenRowLine : sizeInferredLine
        case .agility:
            return agilityLine
        case .vitality:
            return vitalityLine
        default:
            guard band != .unwritten else { return unwrittenRowLine }
            return aphorisms[stat]?[band] ?? unwrittenRowLine
        }
    }

    // MARK: Copy — epithets

    struct Epithet: Equatable {
        let name: String        // includes the "the " prefix
        let aphorism: String
    }

    static let unwrittenEpithet = Epithet(
        name: "the Unwritten",
        aphorism: "The stone found no words. It is patient. It will write when you do.")
    static let unlitEmberEpithet = Epithet(
        name: "the Unlit Ember",
        aphorism: "Even the Ember Wisp began unlit.")
    static let rekindledEpithet = Epithet(
        name: "the Rekindled",
        aphorism: "The fire remembers the wood.")
    static let evenFlameEpithet = Epithet(
        name: "the Even Flame",
        aphorism: "No gift outshines the other. The stone respects that.")

    /// Vanguard stat × vanguard band. Gate never appears: an all-Gate weighing
    /// is caught by the Unlit Ember override before the grid is consulted.
    static let epithetGrid: [Stat: [PlacementBand: Epithet]] = [
        .strength: [
            .kindlingVale: Epithet(name: "the Quiet Anvil", aphorism: "It does not boast. It rings when struck."),
            .ashenPasses: Epithet(name: "the Loadbearer", aphorism: "Heavy things agree to move for you."),
            .stormreach: Epithet(name: "the Unbowed", aphorism: "Iron argued. Iron lost."),
            .crownOfDawn: Epithet(name: "the Mountain's Equal", aphorism: "The mountain has no summit. You've been climbing anyway."),
            .elderWilds: Epithet(name: "the Mountain's Equal", aphorism: "The mountain has no summit. You've been climbing anyway.")
        ],
        .dexterity: [
            .kindlingVale: Epithet(name: "the Steady Hand", aphorism: "The floor has stopped winning."),
            .ashenPasses: Epithet(name: "the Unburdened", aphorism: "You carry yourself lightly. That is the whole trick."),
            .stormreach: Epithet(name: "the Wall-Walker", aphorism: "Gravity files no complaint. It knows better."),
            .crownOfDawn: Epithet(name: "the Weightless", aphorism: "The floor pushed back. It stopped."),
            .elderWilds: Epithet(name: "the Weightless", aphorism: "The floor pushed back. It stopped.")
        ],
        .endurance: [
            .kindlingVale: Epithet(name: "the Long Road", aphorism: "You have learned the mile's first secret: another mile."),
            .ashenPasses: Epithet(name: "the Pacekeeper", aphorism: "It burns slow on purpose."),
            .stormreach: Epithet(name: "the Stormchaser", aphorism: "The valley's shadow gave up at mile three."),
            .crownOfDawn: Epithet(name: "the Horizon-Eater", aphorism: "The horizon keeps moving. So do you."),
            .elderWilds: Epithet(name: "the Horizon-Eater", aphorism: "The horizon keeps moving. So do you.")
        ]
    ]

    /// The measured stat with the highest band. Ties prefer the class's own
    /// attributes (first trained stat outranks second), then STR > END > DEX.
    static func vanguard(bands: [Stat: PlacementBand], rpgClass: RPGClass?) -> Stat? {
        let measured = measurableStats.compactMap { stat -> (Stat, PlacementBand)? in
            guard let b = bands[stat], b != .unwritten else { return nil }
            return (stat, b)
        }
        guard let best = measured.map(\.1).max() else { return nil }
        let top = measured.filter { $0.1 == best }.map(\.0)
        if top.count == 1 { return top[0] }
        if let cls = rpgClass {
            for stat in cls.trainedStats where top.contains(stat) { return stat }
        }
        for stat in [Stat.strength, .endurance, .dexterity] where top.contains(stat) { return stat }
        return top.first
    }

    /// Precedence is first-match-wins, and the order is load-bearing: a skipper
    /// must never be told they are unlit, and a returning lifter's story beats
    /// the grid's.
    static func selectEpithet(bands: [Stat: PlacementBand],
                              fireIndex: Int?,
                              skipped: Bool,
                              rpgClass: RPGClass?) -> Epithet {
        let measured = measurableStats.compactMap { stat -> (Stat, PlacementBand)? in
            guard let b = bands[stat], b != .unwritten else { return nil }
            return (stat, b)
        }
        if skipped || measured.isEmpty { return unwrittenEpithet }
        if measured.allSatisfy({ $0.1 <= .gate }) { return unlitEmberEpithet }
        if fireIndex == 1, measured.contains(where: { $0.1 >= .kindlingVale }) { return rekindledEpithet }
        if let cls = rpgClass {
            let trained = cls.trainedStats
            if trained.count == 2,
               let a = bands[trained[0]], let b = bands[trained[1]],
               a != .unwritten, a == b, a >= .kindlingVale {
                return evenFlameEpithet
            }
        }
        guard let van = vanguard(bands: bands, rpgClass: rpgClass),
              let band = bands[van],
              let epithet = epithetGrid[van]?[band] else { return unwrittenEpithet }
        return epithet
    }
}

// MARK: - Stone copy

/// Every string the rite speaks, in one place — the UI reads, never invents.
enum PlacementCopy {
    static let weighingHeading = "The Weighing"
    static let namingHeading = "The Naming"
    static let weighingSubline = "The stone writes only what it can verify. Every mile after this is measured against what you say now."
    static let firePrompt = "When did the fire last burn?"
    static let drawerLink = "Speak plainly to the stone."
    static let drawerCaption = "Exact numbers, for those who keep them."
    static let approachCTA = "Approach the Ledgerstone"
    static let skipCTA = "Pass the Stone Unread"
    static let commitCTA = "Set Your Hand"
    static let settingsRow = "Return to the Stone"
    static let lockedCategory = "That page is already written — in your own hand."
    static let eyebrow = "The stone raises an eyebrow, and writes a cautious number."
    static let doubtfulPace = "The stone doubts this pace. Check the numbers."
    static let readingCaption = "The stone reads your hand…"

    static let closingDefault = "What is written walks ahead. What is unwritten follows. It always does."
    static let closingAllGate = "Even the Ember Wisp began unlit."
    static let closingSkip = "The ledger has blank pages older than kingdoms. Everyone the Vale remembers stood here once, empty-handed. Walk on."

    static func trustedRange(lo: String, hi: String, suffix: String?) -> String {
        let l = suffix.map { "\(lo) \($0)" } ?? lo
        let h = suffix.map { "\(hi) \($0)" } ?? hi
        return "The stone trusts numbers between \(l) and \(h)."
    }

    /// Drops a trailing ".0" so ranges read as prose, not as telemetry.
    static func number(_ value: Double, decimals: Int) -> String {
        let s = String(format: "%.\(max(0, decimals))f", value)
        guard s.contains(".") else { return s }
        var trimmed = s
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }

    // People who typed numbers deserve numbers back — the one place the verdict
    // page is allowed to show any.
    static func ironReceipt(lift: ExerciseCategory, weightKg: Double, reps: Int,
                            estKg: Double, bodyweightKg: Double, units: Units) -> String {
        let w = number(units.fromKg(weightKg), decimals: 1)
        let e = number(units.fromKg(estKg), decimals: 0)
        let ratio = number(estKg / max(1, bodyweightKg), decimals: 2)
        return "\(PlacementRite.shortName(for: lift)) \(w) \(units.displayName) × \(reps) → est. \(e) \(units.displayName). \(ratio)× your body."
    }

    static func bodyReceipt(reps: Int) -> String {
        "Push-ups × \(reps). Counted from the floor."
    }

    static func roadReceipt(minutes: Double, km: Double, units: Units) -> String {
        let d = number(units.fromKm(km), decimals: 2)
        let t = number(minutes, decimals: 0)
        let speed = number(units.fromKm(km) / max(0.0001, minutes / 60.0), decimals: 1)
        let unit = units.distanceDisplayName
        return "\(d) \(unit) in \(t) min — \(speed) \(unit)/h."
    }
}

// MARK: - The verdict

/// Pure function of staged answers + bodyweight + class. Recomputed on every
/// entry to the Naming page, so changing bodyweight or goals upstream can never
/// leave the verdict stale.
struct PlacementVerdict {

    struct Row: Identifiable {
        let stat: Stat
        let band: PlacementBand
        let aphorism: String
        let receipt: String?
        /// SIZ is derived from STR, never measured — the row says so in italics.
        let inferred: Bool

        var id: String { stat.rawValue }
        var isUnwritten: Bool { band == .unwritten }

        /// "Strength, walks the Ashen Passes. Built in weeks nobody watched."
        var accessibilityLine: String {
            "\(stat.name), \(band.phrase). \(aphorism)"
        }
    }

    let rows: [Row]
    let bands: [Stat: PlacementBand]
    let epithet: PlacementRite.Epithet
    let headline: String
    let closingLine: String
    let vanguard: Stat?
    let isSkip: Bool
    /// The stone found something to read, whether or not the player has since
    /// chosen to pass unread. The morphing CTA reads this, not the staged
    /// fields, so it can never promise a reading the rite would discard.
    let hasReading: Bool
    let usedDrawer: Bool
    let fireIndex: Int
    let seeds: [ExerciseCategory: Double]
    let baselineSeeds: [ExerciseCategory: Double]
    let receipts: [String]
    /// True when the sanity clamp rewrote the drawer's iron claim.
    let ironClamped: Bool
    /// Carried into the record so a Settings re-run restores what was said.
    let answers: WeighingAnswers

    static func make(answers: WeighingAnswers,
                     bodyweightKg: Double?,
                     rpgClass: RPGClass?,
                     units: Units) -> PlacementVerdict {
        let bw = PlacementRite.effectiveBodyweight(bodyweightKg)
        let fire = answers.fireIndex
        let multiplier = PlacementRite.fireSeedMultiplier(fire)

        var bands: [Stat: PlacementBand] = [:]
        var receipts: [Stat: String] = [:]
        // Undiscounted assessed performance per category. best1RM stores est1RM
        // for the 1RM lifts and placementMetric for everything else — and for
        // these categories the two coincide, so one number serves both writes.
        var assessed: [ExerciseCategory: Double] = [:]
        var usedDrawer = false
        var ironClamped = false

        // Iron — drawer overrides the ladder and redirects the seed to the
        // lift actually named.
        var ironFromDrawer = false
        if answers.drawerAvailable,
           let iron = PlacementRite.ironReading(lift: answers.drawerLift,
                                                weightKg: answers.drawerWeightKg,
                                                reps: answers.drawerReps,
                                                bodyweightKg: bw,
                                                units: units).value {
            bands[.strength] = iron.band
            assessed[iron.lift] = iron.estKg
            receipts[.strength] = iron.receipt
            ironClamped = iron.clamped
            ironFromDrawer = true
            usedDrawer = true
        }
        if !ironFromDrawer, let rung = PlacementRite.rung(PlacementRite.ironLadder, answers.strIndex) {
            bands[.strength] = rung.band
            if case .oneRMRatio(let ratio, let floor) = rung.sample {
                assessed[.squat] = max(floor, ratio * bw)
            }
        }

        // Body
        var bodyFromDrawer = false
        if answers.drawerAvailable,
           let body = PlacementRite.bodyReading(pushUps: answers.drawerPushUps).value {
            bands[.dexterity] = body.band
            if body.reps > 0 {
                assessed[.pushUp] = StatEngine.placementMetric(category: .pushUp,
                                                               reps: body.reps, weight: nil,
                                                               durationMin: nil, distanceKm: nil,
                                                               bodyweightKg: bw)
            }
            receipts[.dexterity] = body.receipt
            bodyFromDrawer = true
            usedDrawer = true
        }
        if !bodyFromDrawer, let rung = PlacementRite.rung(PlacementRite.bodyLadder, answers.dexIndex) {
            bands[.dexterity] = rung.band
            if case .pushUpReps(let reps) = rung.sample, reps > 0 {
                assessed[.pushUp] = StatEngine.placementMetric(category: .pushUp,
                                                               reps: reps, weight: nil,
                                                               durationMin: nil, distanceKm: nil,
                                                               bodyweightKg: bw)
            }
        }

        // Road — the drawer is the only endurance seed source.
        var roadFromDrawer = false
        if answers.drawerAvailable,
           let road = PlacementRite.roadReading(minutes: answers.drawerRunMinutes,
                                                km: answers.drawerRunKm,
                                                bodyweightKg: bw,
                                                units: units).value {
            bands[.endurance] = road.band
            assessed[.run] = road.metric
            receipts[.endurance] = road.receipt
            roadFromDrawer = true
            usedDrawer = true
        }
        if !roadFromDrawer, let rung = PlacementRite.rung(PlacementRite.roadLadder, answers.endIndex) {
            bands[.endurance] = rung.band
        }

        // Size is inferred one band below strength and never seeds anything —
        // a discount on a squat claim is fiction, not evidence.
        if let str = bands[.strength], str != .unwritten {
            bands[.size] = PlacementBand(rawValue: max(PlacementBand.gate.rawValue, str.rawValue - 1)) ?? .gate
        }

        let measured = PlacementRite.measurableStats.compactMap { bands[$0] }.filter { $0 != .unwritten }
        let isSkip = answers.skipped || measured.isEmpty

        let rows: [Row] = PlacementRite.ledgerOrder.map { stat in
            let band = bands[stat] ?? .unwritten
            return Row(stat: stat,
                       band: band,
                       aphorism: PlacementRite.aphorism(for: stat, band: band),
                       receipt: receipts[stat],
                       inferred: stat == .size && band != .unwritten)
        }

        let epithet = PlacementRite.selectEpithet(bands: bands,
                                                  fireIndex: fire,
                                                  skipped: isSkip,
                                                  rpgClass: rpgClass)

        let closing: String
        if isSkip {
            closing = PlacementCopy.closingSkip
        } else if measured.allSatisfy({ $0 <= .gate }) {
            closing = PlacementCopy.closingAllGate
        } else {
            closing = PlacementCopy.closingDefault
        }

        var seeds: [ExerciseCategory: Double] = [:]
        var baselineSeeds: [ExerciseCategory: Double] = [:]
        if !isSkip {
            for (cat, value) in assessed where value > 0 {
                let seed = PlacementRite.seedFactor * multiplier * value
                if seed > 0 { seeds[cat] = seed }
                let baseline = PlacementRite.baselineFactor * multiplier * value
                if baseline > 0 { baselineSeeds[cat] = baseline }
            }
        }

        return PlacementVerdict(
            rows: rows,
            bands: bands,
            epithet: epithet,
            headline: rpgClass.map { "\($0.displayName), \(epithet.name)" } ?? epithet.name,
            closingLine: closing,
            vanguard: PlacementRite.vanguard(bands: bands, rpgClass: rpgClass),
            isSkip: isSkip,
            hasReading: !measured.isEmpty,
            usedDrawer: usedDrawer && !isSkip,
            fireIndex: fire ?? -1,
            seeds: seeds,
            baselineSeeds: baselineSeeds,
            receipts: PlacementRite.ledgerOrder.compactMap { receipts[$0] },
            ironClamped: ironClamped,
            answers: answers
        )
    }

    /// One VoiceOver narration for the whole ceremony. It must say exactly what
    /// is on screen: the skip rite renders no ledger, so reading six rows there
    /// would narrate content that does not exist.
    var narration: String {
        let parts = isSkip
            ? [headline, epithet.aphorism, closingLine]
            : [headline] + rows.map(\.accessibilityLine) + [closingLine]
        return parts.joined(separator: " ")
    }

    /// `previous` carries the honesty-XP flag across a Settings re-run so the
    /// bonus can never be granted twice.
    func makeRecord(carryingOver previous: PlacementRecord? = nil) -> PlacementRecord {
        var bandCodes: [String: Int] = [:]
        for row in rows { bandCodes[row.stat.abbreviation] = row.band.rawValue }
        return PlacementRecord(epithet: epithet.name,
                               bands: bandCodes,
                               seeds: seeds,
                               baselineSeeds: baselineSeeds,
                               receipts: receipts,
                               fireIndex: fireIndex,
                               usedDrawer: usedDrawer,
                               skipped: isSkip,
                               bonusGranted: previous?.bonusGranted ?? false,
                               answers: answers)
    }
}

// MARK: - The stone

/// The Ledgerstone's semantic mark. It stays still and glow-free; the one-shot
/// flare is a brass ring that widens and fades, Reduce-Motion gated like every
/// other flourish.
struct LedgerstoneView: View {
    var size: CGFloat = 120
    /// Kept for call-site compatibility; the stone no longer loops.
    var animated: Bool = true
    /// One-shot rune flare — a screen's single flourish. Flip it true once.
    var flare: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RPGSymbolIcon(
                symbol: .ledgerstone,
                size: size,
                presentation: .standard,
                palette: .adaptive
            )

            // The flare rides above the mark and is driven by its own spring.
            if flare && !reduceMotion {
                RuneFlare(diameter: size * 0.34)
                    .offset(y: -size * 0.04)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A brass hairline ring that widens once and is gone — rendered only while
/// its parent asks for a flare, so its `onAppear` is the one-shot trigger.
private struct RuneFlare: View {
    let diameter: CGFloat
    @State private var bloomed = false

    var body: some View {
        Circle()
            .strokeBorder(RPGTheme.artGold.opacity(0.8), lineWidth: 1)
            .frame(width: diameter, height: diameter)
            .scaleEffect(bloomed ? 2.1 : 0.6)
            .opacity(bloomed ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { bloomed = true }
            }
    }
}

// MARK: - Page 5 — The Weighing

/// Four tap-only ladders plus the exact-numbers drawer. Standalone by design:
/// onboarding and the Settings re-run sheet present the same form.
struct WeighingFormView: View {
    @Binding var answers: WeighingAnswers
    let units: Units
    let bodyweightKg: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Categories already written by real training. Their drawer fields show
    /// locked — a logged page is written in the player's own hand.
    var lockedCategories: Set<ExerciseCategory> = []

    @State private var drawerOpen = false
    @State private var weightText = ""
    @State private var pushUpText = ""
    @State private var minutesText = ""
    @State private var distanceText = ""

    private var allLaddersAnswered: Bool {
        answers.fireIndex != nil && answers.strIndex != nil
            && answers.dexIndex != nil && answers.endIndex != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(PlacementCopy.weighingHeading)
                        .font(RPGTheme.heading(.title2, weight: .bold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(PlacementCopy.weighingSubline)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                LedgerstoneView(size: 64, animated: false, flare: allLaddersAnswered)
            }

            fireGroup

            ForEach(PlacementRite.ladders) { ladder in
                ladderGroup(ladder)
            }

            if answers.drawerAvailable {
                drawerSection
            }
        }
        .onAppear { restoreFieldText(for: units) }
        // The staged answers are canonical kg/km; only the visible strings
        // need converting when the player flips units mid-flow.
        .onChangeCompat(of: units) { _, newUnits in
            restoreFieldText(for: newUnits)
        }
    }

    // MARK: Ladders

    private var fireGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            ladderHeader(symbol: .placementRite,
                         tint: RPGTheme.gold,
                         prompt: PlacementCopy.firePrompt)

            VStack(spacing: 8) {
                ForEach(Array(PlacementRite.fireLadder.enumerated()), id: \.offset) { index, rung in
                    LadderCard(copy: rung.copy,
                               isSelected: answers.fireIndex == index) {
                        answers.fireIndex = (answers.fireIndex == index) ? nil : index
                    }
                }
            }
        }
    }

    private func ladderGroup(_ ladder: PlacementRite.Ladder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ladderHeader(symbol: ladder.rpgSymbol,
                         tint: ladder.stat.color,
                         prompt: ladder.prompt)

            VStack(spacing: 8) {
                ForEach(Array(ladder.rungs.enumerated()), id: \.offset) { index, rung in
                    LadderCard(copy: rung.copy,
                               isSelected: selection(for: ladder.stat) == index) {
                        let current = selection(for: ladder.stat)
                        select(index: current == index ? nil : index, for: ladder.stat)
                    }
                }
            }
        }
    }

    private func ladderHeader(symbol: RPGSymbol, tint: Color, prompt: String) -> some View {
        HStack(spacing: 8) {
            RPGSymbolIcon(
                symbol: symbol,
                size: 18,
                presentation: .compact,
                palette: .monochrome(tint)
            )

            Text(prompt)
                .font(RPGTheme.heading(.subheadline, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func selection(for stat: Stat) -> Int? {
        switch stat {
        case .strength: return answers.strIndex
        case .dexterity: return answers.dexIndex
        default: return answers.endIndex
        }
    }

    private func select(index: Int?, for stat: Stat) {
        switch stat {
        case .strength: answers.strIndex = index
        case .dexterity: answers.dexIndex = index
        default: answers.endIndex = index
        }
    }

    // MARK: Drawer

    private var drawerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                if reduceMotion {
                    drawerOpen.toggle()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        drawerOpen.toggle()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    RPGSymbolIcon(
                        symbol: .placementRite,
                        size: 18,
                        presentation: .compact,
                        palette: .monochrome(RPGTheme.gold)
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(PlacementCopy.drawerLink)
                            .font(RPGTheme.heading(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(PlacementCopy.drawerCaption)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: drawerOpen ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(drawerOpen ? [.isButton, .isSelected] : .isButton)

            if drawerOpen {
                VStack(alignment: .leading, spacing: 20) {
                    ironDrawer
                    HairlineRule()
                    bodyDrawer
                    HairlineRule()
                    roadDrawer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .rpgCard(padding: 16)
            }
        }
    }

    /// Every barbell page already written by real training. Asking for a weight
    /// here would demand a lift chip that no longer exists to tap.
    private var ironAllLocked: Bool {
        PlacementRite.drawerLifts.allSatisfy { lockedCategories.contains($0) }
    }

    /// A restored Settings answer may name a lift the player has logged since
    /// the original Weighing. Keep the old receipt visible, but do not leave
    /// its weight or rep controls editable behind a disabled lift chip.
    private var selectedIronLiftIsLocked: Bool {
        guard let lift = answers.drawerLift else { return false }
        return lockedCategories.contains(lift)
    }

    private var ironDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            ladderHeader(symbol: Stat.strength.rpgSymbol,
                         tint: Stat.strength.color,
                         prompt: "One honest set of iron")

            if ironAllLocked {
                Text(PlacementCopy.lockedCategory)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(PlacementRite.drawerLifts) { lift in
                        liftChip(lift)
                    }
                }

                if PlacementRite.drawerLifts.contains(where: { lockedCategories.contains($0) }) {
                    Text(PlacementCopy.lockedCategory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    TextField(units == .kg ? "e.g. 100" : "e.g. 225", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(ModernTextFieldStyle())
                        .accessibilityLabel("Weight lifted, \(units.displayName)")
                        .onChangeCompat(of: weightText) { _, text in
                            answers.drawerWeightKg = flexibleDouble(text).map { units.toKg($0) }
                        }

                    Text(units.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .disabled(selectedIronLiftIsLocked)
                .opacity(selectedIronLiftIsLocked ? 0.55 : 1)

                Stepper(value: $answers.drawerReps, in: PlacementRite.repsRange) {
                    Text("Reps: \(answers.drawerReps)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }
                .accessibilityValue("\(answers.drawerReps) reps")
                .frame(minHeight: 44)
                .disabled(selectedIronLiftIsLocked)
                .opacity(selectedIronLiftIsLocked ? 0.55 : 1)

                if let issue = ironIssue {
                    inlineIssue(issue)
                } else if ironClamped {
                    Text(PlacementCopy.eyebrow)
                        .font(.caption)
                        .foregroundColor(RPGTheme.goldDeep)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var bodyDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            ladderHeader(symbol: Stat.dexterity.rpgSymbol,
                         tint: Stat.dexterity.color,
                         prompt: "Push-ups, exactly")

            if lockedCategories.contains(.pushUp) {
                Text(PlacementCopy.lockedCategory)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                TextField("e.g. 24", text: $pushUpText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(ModernTextFieldStyle())
                    .accessibilityLabel("Push-up count")
                    .onChangeCompat(of: pushUpText) { _, text in
                        answers.drawerPushUps = Int(text.trimmingCharacters(in: .whitespaces))
                    }

                if let issue = PlacementRite.bodyReading(pushUps: answers.drawerPushUps).problem {
                    inlineIssue(issue.message(units: units))
                } else if !pushUpText.isEmpty && answers.drawerPushUps == nil {
                    inlineIssue(PlacementRite.DrawerIssue.pushUpsOutOfRange.message(units: units))
                }
            }
        }
    }

    private var roadDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            ladderHeader(symbol: Stat.endurance.rpgSymbol,
                         tint: Stat.endurance.color,
                         prompt: "One run you have actually done")

            if lockedCategories.contains(.run) {
                Text(PlacementCopy.lockedCategory)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 12) {
                    TextField("minutes", text: $minutesText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(ModernTextFieldStyle())
                        .accessibilityLabel("Run duration in minutes")
                        .onChangeCompat(of: minutesText) { _, text in
                            answers.drawerRunMinutes = flexibleDouble(text)
                        }

                    TextField(units.distanceDisplayName, text: $distanceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(ModernTextFieldStyle())
                        .accessibilityLabel("Run distance in \(units.distanceDisplayName)")
                        .onChangeCompat(of: distanceText) { _, text in
                            answers.drawerRunKm = flexibleDouble(text).map { units.toKm($0) }
                        }
                }

                if let issue = roadIssue {
                    inlineIssue(issue)
                }
            }
        }
    }

    private func liftChip(_ lift: ExerciseCategory) -> some View {
        let locked = lockedCategories.contains(lift)
        let selected = answers.drawerLift == lift
        return Button {
            Haptics.tap()
            answers.drawerLift = selected ? nil : lift
        } label: {
            Text(PlacementRite.shortName(for: lift))
                .font(.subheadline.weight(.medium))
                .foregroundColor(selected ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                        .fill(selected ? RPGTheme.accentFill : RPGTheme.surfaceInner)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                        .strokeBorder(RPGTheme.frame.opacity(selected ? 0 : RPGTheme.hairline), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .opacity(locked ? 0.45 : 1)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// Rejections are always visible text — the CTA never silently no-ops.
    private func inlineIssue(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(RPGTheme.errorText)
                .accessibilityHidden(true)

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundColor(RPGTheme.errorText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ironReading: PlacementRite.Outcome<PlacementRite.IronReading> {
        PlacementRite.ironReading(lift: answers.drawerLift,
                                  weightKg: answers.drawerWeightKg,
                                  reps: answers.drawerReps,
                                  bodyweightKg: bodyweightKg,
                                  units: units)
    }

    private var ironClamped: Bool { ironReading.value?.clamped ?? false }

    private var ironIssue: String? {
        if !weightText.isEmpty && answers.drawerLift == nil {
            return PlacementRite.DrawerIssue.unreadableLift.message(units: units)
        }
        if !weightText.isEmpty && flexibleDouble(weightText) == nil {
            return PlacementRite.DrawerIssue.weightOutOfRange.message(units: units)
        }
        return ironReading.problem?.message(units: units)
    }

    private var roadIssue: String? {
        // Half a pair is a work in progress, not a mistake — roadReading stays
        // silent until both numbers are in.
        if !minutesText.isEmpty && answers.drawerRunMinutes == nil {
            return PlacementRite.DrawerIssue.durationOutOfRange.message(units: units)
        }
        if !distanceText.isEmpty && answers.drawerRunKm == nil {
            return PlacementRite.DrawerIssue.distanceOutOfRange.message(units: units)
        }
        return PlacementRite.roadReading(minutes: answers.drawerRunMinutes,
                                         km: answers.drawerRunKm,
                                         bodyweightKg: bodyweightKg,
                                         units: units).problem?.message(units: units)
    }

    private func restoreFieldText(for displayUnits: Units) {
        if let kg = answers.drawerWeightKg {
            weightText = PlacementCopy.number(displayUnits.fromKg(kg), decimals: 1)
        }
        if let reps = answers.drawerPushUps {
            pushUpText = "\(reps)"
        }
        if let minutes = answers.drawerRunMinutes {
            // The field writes this string straight back into the staged value,
            // so whole minutes here would quietly re-time a 7.5-minute mile.
            minutesText = PlacementCopy.number(minutes, decimals: 1)
        }
        if let km = answers.drawerRunKm {
            distanceText = PlacementCopy.number(displayUnits.fromKm(km), decimals: 2)
        }
        if answers.drawerWeightKg != nil || answers.drawerPushUps != nil || answers.drawerRunKm != nil {
            drawerOpen = true
        }
    }
}

/// One rung: a hairline-bordered row on the panel surface, filled deep brass
/// with white text when chosen. A tap deselects, and the whole row is one
/// VoiceOver button. Text stays at full opacity in both states.
private struct LadderCard: View {
    let copy: String
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            Text(copy)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .white : .primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                .fill(isSelected ? RPGTheme.accentFill : RPGTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                .strokeBorder(RPGTheme.frame.opacity(isSelected ? 0 : RPGTheme.hairline), lineWidth: 1)
        )
        // No drop shadow and no scale: a full-width row's shadow bitmap bleeds
        // past the scroll viewport's clip, and the fill change is the feedback.
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: isSelected
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Page 6 — The Naming

/// The etching ceremony. Fixed beats, one guard flag, tap skips forward, and
/// Reduce Motion lands on the final frame immediately.
struct NamingCeremonyView: View {
    let verdict: PlacementVerdict
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var etched = 0                 // ledger rows written so far
    @State private var runeFlare = false
    @State private var showHeadline = false
    @State private var sparksLit = false
    @State private var sparksOut = false
    @State private var showClosing = false
    @State private var finished = false

    var body: some View {
        VStack(spacing: 22) {
            LedgerstoneView(size: 132, flare: runeFlare)

            Text(PlacementCopy.readingCaption)
                .font(RPGTheme.heading(.subheadline, weight: .semibold))
                .foregroundColor(.secondary)
                .opacity(showHeadline ? 0 : 1)

            if !verdict.isSkip {
                ledgerCard
            }

            if showHeadline {
                headlineBlock
                    .transition(.opacity)
            }

            if showClosing {
                Text(verdict.closingLine)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear { runCeremony() }
        // Cancel delayed beats when Back removes this ceremony. Without this,
        // the old off-screen run can call its parent completion after re-entry
        // and enable the new ceremony's CTA early.
        .onDisappear { finished = true }
        // One narration element while the rite plays — and the CTA below is
        // disabled for exactly that long, so the modal trait strands nothing.
        // Once written, the ledger opens up row by row.
        .accessibilityElement(children: finished ? .contain : .ignore)
        .accessibilityLabel(finished ? "" : verdict.narration)
        .accessibilityAddTraits(finished ? [] : .isModal)
        .accessibilityAction(.escape) { finish() }
    }

    private var ledgerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(verdict.rows.enumerated()), id: \.element.id) { index, row in
                if index < etched {
                    if index > 0 {
                        HairlineRule()
                            .transition(.opacity)
                    }
                    LedgerRowView(row: row, isVanguard: row.stat == verdict.vanguard)
                        .padding(.vertical, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rpgCard(padding: 16, ornate: true)
    }

    private var headlineBlock: some View {
        ZStack {
            if sparksLit && !reduceMotion {
                ForEach(0..<8, id: \.self) { index in
                    GlyphIcon(glyph: .spark, size: 14, tint: RPGTheme.gold.opacity(0.85))
                        .offset(y: sparksOut ? -86 : -20)
                        .rotationEffect(.degrees(Double(index) * 45))
                        .opacity(sparksOut ? 0 : 1)
                        .animation(.easeOut(duration: 0.9).delay(Double(index) * 0.03), value: sparksOut)
                        .accessibilityHidden(true)
                }
            }

            VStack(spacing: 10) {
                // Etched in gold once the ledger is written; a passed stone
                // stays quiet ink.
                Text(verdict.headline)
                    .font(RPGTheme.heading(34))
                    .foregroundColor(verdict.isSkip ? .secondary : RPGTheme.gold)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)

                OrnateDivider()
                    .frame(maxWidth: 160)

                Text(verdict.epithet.aphorism)
                    .font(RPGTheme.heading(.caption))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
        }
    }

    // MARK: Timeline

    private func runCeremony() {
        guard !finished else { return }
        if reduceMotion {
            finish()
            return
        }
        Haptics.tap()

        // The skip rite is short and quiet: no etching, no sparks.
        guard !verdict.isSkip else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                guard !finished else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showHeadline = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { finish() }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard !finished else { return }
            runeFlare = true
        }
        for index in verdict.rows.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3 + Double(index) * 0.35) {
                guard !finished, etched <= index else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { etched = index + 1 }
                if !verdict.rows[index].isUnwritten { Haptics.tap() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            guard !finished else { return }
            reveal()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { finish() }
    }

    private func reveal() {
        guard !showHeadline else { return }
        etched = verdict.rows.count
        runeFlare = true
        if reduceMotion {
            showHeadline = true
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showHeadline = true
            }
        }
        if verdict.isSkip {
            Haptics.tap()
        } else {
            Haptics.success()
            if !reduceMotion {
                sparksLit = true
                // The burst must animate from a state change after insertion,
                // never from its own first frame.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { sparksOut = true }
            }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        reveal()
        if reduceMotion {
            showClosing = true
        } else {
            withAnimation(.easeIn(duration: 0.3)) {
                showClosing = true
            }
        }
        onFinished()
    }
}

/// One attribute's line in the ledger: symbol, name, waypoints, band phrase,
/// aphorism, and — only for numbers the player typed — a receipt.
private struct LedgerRowView: View {
    let row: PlacementVerdict.Row
    let isVanguard: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // An unwritten row is faint in its decoration only: dimming the copy
            // too would multiply against .secondary and drop real text below the
            // 4.5:1 the light-mode palette is tuned to.
            RPGSymbolIcon(
                symbol: row.stat.rpgSymbol,
                size: 18,
                presentation: .compact,
                palette: .monochrome(row.stat.color)
            )
                .padding(.top, 3)
                .opacity(row.isUnwritten ? 0.4 : 1.0)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // The vanguard's name is the one gilded word on the page.
                    Text(row.stat.name)
                        .font(RPGTheme.heading(.subheadline, weight: .semibold))
                        .foregroundColor(isVanguard ? RPGTheme.gold : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 4)

                    WaypointRow(filled: row.band.waypoints,
                                tint: isVanguard ? RPGTheme.gold : RPGTheme.frame)
                        .opacity(row.isUnwritten ? 0.4 : 1.0)
                }

                Text(row.band.phrase)
                    .font(.subheadline)
                    .foregroundColor(row.isUnwritten ? .secondary : RPGTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)

                Text(row.aphorism)
                    .font(row.inferred ? .caption.italic() : .caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let receipt = row.receipt {
                    Text(receipt)
                        .font(RPGTheme.display(11, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.receipt.map { "\(row.accessibilityLine) \($0)" } ?? row.accessibilityLine)
    }
}

/// Five map waypoints; the filled ones say how far along the band sits before
/// the player has ever opened the campaign map. Brass diamonds: filled ones
/// solid, empty ones a hairline outline.
private struct WaypointRow: View {
    let filled: Int
    var tint: Color = RPGTheme.frame

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(index < filled ? tint : Color.clear)
                    .overlay(Rectangle().strokeBorder(tint.opacity(index < filled ? 1 : 0.45), lineWidth: 0.8))
                    .frame(width: 6, height: 6)
                    .rotationEffect(.degrees(45))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Returning to the stone

extension WeighingAnswers {
    /// Prefill for a Settings re-run, read from the answers the record kept.
    /// Bands are never reversed into rungs: two rungs of every ladder share the
    /// Gate, and a drawer-derived band belongs to no rung at all — guessing one
    /// would put a claim in the player's mouth and seed a lift they never named.
    init(restoring record: PlacementRecord) {
        if let stored = record.answers {
            self = stored
            // A re-run starts unsealed; passing unread is decided again.
            skipped = false
            return
        }
        // A record from before the answers were kept restores only the fire,
        // which is stored in its own right.
        self.init()
        fireIndex = PlacementRite.fireLadder.indices.contains(record.fireIndex) ? record.fireIndex : nil
    }
}

/// The Settings re-run: the same form and the same ceremony, committing
/// through `applyPlacement` so seeds max-merge and the honesty bonus stays
/// once ever.
struct ReturnToTheStoneView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var answers = WeighingAnswers()
    @State private var showNaming = false
    @State private var ceremonyDone = false

    /// Seed the form before its first render. Restoring in `onAppear` races the
    /// child form's own `onAppear`, which can leave its exact-number text fields
    /// blank even though the bound answers were restored a moment later.
    init(initialRecord: PlacementRecord?) {
        _answers = State(initialValue: initialRecord.map(WeighingAnswers.init(restoring:))
                         ?? WeighingAnswers())
    }

    private var lockedCategories: Set<ExerciseCategory> {
        state.historyOwnedPlacementCategories
    }

    /// The Fire alone is not a measurement, and neither is a drawer value the
    /// fire has since shut away — the CTA must not promise a reading the rite
    /// would discard.
    private var measured: Bool { verdict.hasReading }

    private var verdict: PlacementVerdict {
        PlacementVerdict.make(answers: answers,
                              bodyweightKg: state.user.bodyweightKg,
                              rpgClass: state.user.rpgClass,
                              units: state.user.units)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            if showNaming {
                                NamingCeremonyView(verdict: verdict) { ceremonyDone = true }
                            } else {
                                WeighingFormView(answers: $answers,
                                                 units: state.user.units,
                                                 bodyweightKg: state.user.bodyweightKg,
                                                 lockedCategories: lockedCategories)
                            }
                        }
                        .screenColumn()
                        .padding(.vertical, 20)
                    }

                    // The one action on the screen lives in the dock, in thumb
                    // reach, and morphs with the rite's state.
                    DockBar {
                        Button {
                            if showNaming {
                                commit()
                            } else {
                                answers.skipped = !measured
                                if reduceMotion {
                                    showNaming = true
                                } else {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                        showNaming = true
                                    }
                                }
                            }
                        } label: {
                            Text(showNaming ? "Seal the Ledger"
                                            : (measured ? PlacementCopy.commitCTA : PlacementCopy.skipCTA))
                        }
                        .buttonStyle(RPGPrimaryButtonStyle())
                        .disabled(showNaming && !ceremonyDone)
                    }
                }
            }
            .navigationTitle(PlacementCopy.settingsRow)
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func commit() {
        state.applyPlacement(record: verdict.makeRecord(carryingOver: state.user.placement))
        state.save(immediately: true)
        dismiss()
    }
}
