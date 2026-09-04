import SwiftUI

// MARK: - The Trial
//
// The playable payoff, built on the one combat pattern users actually praise:
// async, banked resolution. Every logged workout banks "might" (its XP, sharpened
// by equipment). When banked might exceeds the boss's endurance, the user may
// resolve the Trial whenever they choose — a short, watchable ceremony that
// pays out loot. The boss never attacks, never punishes absence, and never
// expires: it is the receipt for training already done, not an obligation.
//
// Design guardrails (from the verification research):
//  - No real-time or skill combat: resolution is a staged vignette.
//  - No XP from Trials: loot is coins/items/eggs, so the XP economy that
//    levels attributes stays anchored to real training alone.
//  - Might is a spendable balance, but each workout owns the amount it
//    minted. Removing already-spent training creates debt that future
//    training repays, rather than clawing back resolved loot.

enum TrialArchetype: String, Codable {
    case wisp, golem, beast, drake
}

struct TrialBoss: Identifiable {
    let rung: Int
    let name: String
    let epithet: String
    let archetype: TrialArchetype
    let body: Color
    let accent: Color
    let flavor: String

    var id: Int { rung }

    /// Endurance grows ~32%/rung through the authored ladder (rung 0 falls in
    /// three or four sessions), then eases to ~15%/rung in the Elder cycle so
    /// late bosses stay reachable on a steady week.
    var hp: Double {
        if rung <= 11 {
            return (60.0 * pow(1.32, Double(rung))).rounded()
        }
        let base = 60.0 * pow(1.32, 11.0)
        return (base * pow(1.15, Double(rung - 11))).rounded()
    }

    var lootCoins: Int { 40 + rung * 15 }

    var lootRarity: TreasureChestType {
        switch rung {
        case 0...2: return .uncommon
        case 3...5: return .rare
        case 6...8: return .epic
        case 9...10: return .mythic // legendary maps onto epic/mythic chest tiers
        default: return .mythic
        }
    }

    /// Eggs drop on a fixed cadence (rungs 3, 7, 11, then every 4th) —
    /// deterministic, so the chase never feels rigged.
    var dropsEgg: Bool { rung % 4 == 3 }
}

enum TrialLadder {
    /// The authored ladder. Past the end, Elder variants cycle with rising
    /// endurance — the mountain has no summit, only higher camps.
    private static let authored: [(String, String, TrialArchetype, Color, Color, String)] = [
        ("Ember Wisp", "the First Flicker", .wisp,
         Color(red: 0.86, green: 0.42, blue: 0.16), Color(red: 0.98, green: 0.76, blue: 0.35),
         "Every journey starts by catching something small and bright."),
        ("Mossback Golem", "the Sleeping Hill", .golem,
         Color(red: 0.45, green: 0.50, blue: 0.36), Color(red: 0.33, green: 0.55, blue: 0.30),
         "It has not moved in a hundred years. Neither had you, once."),
        ("Gloom Hound", "the Valley's Shadow", .beast,
         Color(red: 0.35, green: 0.36, blue: 0.48), Color(red: 0.55, green: 0.55, blue: 0.75),
         "It feeds on skipped sessions. It looks thin lately."),
        ("Cinder Drake", "the Ash Kite", .drake,
         Color(red: 0.70, green: 0.25, blue: 0.18), Color(red: 0.95, green: 0.55, blue: 0.25),
         "Born from burnt-out plans. Show it a plan that kept burning."),
        ("Frostbone Golem", "the Winter Door", .golem,
         Color(red: 0.45, green: 0.58, blue: 0.70), Color(red: 0.75, green: 0.88, blue: 0.95),
         "The cold season took many streaks. It will not take yours."),
        ("Howling Alpha", "the Pack's Crown", .beast,
         Color(red: 0.42, green: 0.40, blue: 0.38), Color(red: 0.85, green: 0.72, blue: 0.40),
         "It leads by strength alone. So can you."),
        ("Storm Wisp", "the Split Sky", .wisp,
         Color(red: 0.36, green: 0.36, blue: 0.72), Color(red: 0.65, green: 0.70, blue: 0.98),
         "Lightning is just effort that stopped hesitating."),
        ("Iron Drake", "the Forge's Envy", .drake,
         Color(red: 0.42, green: 0.44, blue: 0.50), Color(red: 0.72, green: 0.75, blue: 0.80),
         "Forged plates envy the ones you keep adding to the bar."),
        ("Marrow Golem", "the Old King's Wall", .golem,
         Color(red: 0.72, green: 0.66, blue: 0.54), Color(red: 0.85, green: 0.72, blue: 0.40),
         "Built from the bones of abandoned routines. Yours are not in it."),
        ("Night Alpha", "the Moonless Hunt", .beast,
         Color(red: 0.28, green: 0.24, blue: 0.40), Color(red: 0.62, green: 0.45, blue: 0.85),
         "It hunts in the dark hours — the ones where you trained anyway."),
        ("Sun Wisp", "the Daybreak Herald", .wisp,
         Color(red: 0.83, green: 0.62, blue: 0.20), Color(red: 0.98, green: 0.85, blue: 0.45),
         "It only appears to those who kept showing up. Hello."),
        ("Aurelian Drake", "the Last Trial", .drake,
         Color(red: 0.66, green: 0.50, blue: 0.10), Color(red: 0.80, green: 0.20, blue: 0.16),
         "The end of the ladder. The beginning of the legend."),
    ]

    static func boss(atRung rung: Int) -> TrialBoss {
        if rung < authored.count {
            let a = authored[rung]
            return TrialBoss(rung: rung, name: a.0, epithet: a.1, archetype: a.2,
                             body: a.3, accent: a.4, flavor: a.5)
        }
        // Elder cycle: same beasts, older, patient, tougher.
        let a = authored[rung % authored.count]
        return TrialBoss(rung: rung, name: "Elder \(a.0)", epithet: "\(a.1), returned", archetype: a.2,
                         body: a.3, accent: a.4,
                         flavor: "It remembers you. It trained too.")
    }
}

/// What a resolved Trial pays out.
struct TrialSpoils: Identifiable {
    let id = UUID()
    let boss: TrialBoss
    let coins: Int
    let itemInfo: ItemInfo?
    let eggGranted: Bool
}

// MARK: - State

extension AppState {
    /// Deterministic amount attributed to a workout at log time. Persisting
    /// the result on WorkoutEntry means later gear/class changes cannot alter
    /// what that historical workout earned.
    func trialMightReward(from xp: Double, focus: FocusGroup? = nil) -> Double {
        guard xp.isFinite, xp > 0 else { return 0 }
        var multiplier = 1.0 + Double(equipmentMight) / 100.0
        if let focus, let rpgClass = user.rpgClass,
           rpgClass.focusCategories.contains(focus) {
            multiplier *= 1.10
        }
        return xp * multiplier
    }

    /// Called from logWorkout: training banks might, equipment sharpens it,
    /// and class affinity lives HERE (decision D5) — training your class's
    /// focus pair hits the boss +10% harder, while the XP number stays an
    /// honest measure of the training itself.
    func bankTrialMight(from xp: Double, focus: FocusGroup? = nil) {
        guard !isReplayingHistory else { return }
        applyTrialMightLedgerDelta(trialMightReward(from: xp, focus: focus))
    }

    /// Positive history-backed rewards pay deleted-workout debt first.
    /// Negative adjustments reclaim only the unspent balance and carry any
    /// shortfall as debt, so resolved Trials and their loot remain intact.
    func applyTrialMightLedgerDelta(_ delta: Double) {
        guard delta.isFinite, delta != 0 else { return }
        user.trialMight = max(0, user.trialMight)
        user.trialMightDebt = max(0, user.trialMightDebt)

        if delta > 0 {
            let repaid = min(user.trialMightDebt, delta)
            user.trialMightDebt -= repaid
            user.trialMight += delta - repaid
        } else {
            let reversal = -delta
            let reclaimed = min(user.trialMight, reversal)
            user.trialMight -= reclaimed
            user.trialMightDebt += reversal - reclaimed
        }
    }

    var currentTrialBoss: TrialBoss { TrialLadder.boss(atRung: user.trialRung) }

    var canResolveTrial: Bool { user.trialMight >= currentTrialBoss.hp }

    /// Spends banked might, records the victory, and returns the spoils.
    /// Loot is coins/items/eggs only — never XP — so attribute progression
    /// stays anchored to real training.
    func resolveTrial() -> TrialSpoils? {
        let boss = currentTrialBoss
        guard user.trialMight >= boss.hp else { return nil }
        user.trialMight -= boss.hp
        user.trialRung += 1
        user.trialVictories.append(TrialVictory(rung: boss.rung, bossName: boss.name, date: Date()))

        user.coins += boss.lootCoins
        let itemInfo = Self.trialLoot(rarity: boss.lootRarity)
        if let itemInfo {
            grantItem(from: itemInfo)
        }
        if boss.dropsEgg {
            user.companionEggs += 1
        }
        Haptics.success()
        save()
        return TrialSpoils(boss: boss, coins: boss.lootCoins, itemInfo: itemInfo, eggGranted: boss.dropsEgg)
    }

    private static func trialLoot(rarity: TreasureChestType) -> ItemInfo? {
        switch rarity {
        case .common, .uncommon:
            return UncommonTierItem.allCases.randomElement().map(ItemInfo.uncommon)
        case .rare:
            return RareTierItem.allCases.randomElement().map(ItemInfo.rare)
        case .epic:
            return EpicTierItem.allCases.randomElement().map(ItemInfo.epic)
        case .mythic:
            // Split the top tier between legendary and mythic loot.
            if Bool.random() {
                return LegendaryTierItem.allCases.randomElement().map(ItemInfo.legendary)
            }
            return MythicTierItem.allCases.randomElement().map(ItemInfo.mythic)
        }
    }
}

// MARK: - Boss art
//
// Four Canvas archetypes in the app's sticker style — flat rarity-keyed
// bodies, cream outline, simple geometry — so every rung gets a portrait
// with no image assets.

struct TrialBossView: View {
    let boss: TrialBoss
    var size: CGFloat = 100
    var animated: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    portrait(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                portrait(time: 0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func portrait(time t: Double) -> some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 100
            let bob = t == 0 ? 0 : sin(t * 1.6 + Double(boss.rung)) * 2.0
            context.translateBy(x: 0, y: bob * s)

            let sticker = Color(red: 0.98, green: 0.96, blue: 0.90)
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            switch boss.archetype {
            case .wisp:
                // Teardrop flame with an inner lick and wandering eyes.
                var flame = Path()
                flame.move(to: P(50, 8))
                flame.addQuadCurve(to: P(82, 58), control: P(84, 26))
                flame.addQuadCurve(to: P(50, 92), control: P(82, 88))
                flame.addQuadCurve(to: P(18, 58), control: P(18, 88))
                flame.addQuadCurve(to: P(50, 8), control: P(16, 26))
                context.stroke(flame, with: .color(sticker), style: StrokeStyle(lineWidth: 7 * s, lineJoin: .round))
                context.fill(flame, with: .color(boss.body))

                var inner = Path()
                inner.move(to: P(50, 32))
                inner.addQuadCurve(to: P(66, 62), control: P(68, 42))
                inner.addQuadCurve(to: P(50, 80), control: P(66, 78))
                inner.addQuadCurve(to: P(34, 62), control: P(34, 78))
                inner.addQuadCurve(to: P(50, 32), control: P(32, 42))
                context.fill(inner, with: .color(boss.accent))

                eyes(context: context, s: s, leftX: 42, rightX: 58, y: 58, t: t)

            case .golem:
                // Stacked stones with rune-lit eyes and a mossy cap.
                let base = Path(roundedRect: CGRect(x: 20 * s, y: 58 * s, width: 60 * s, height: 32 * s), cornerRadius: 10 * s)
                let torso = Path(roundedRect: CGRect(x: 26 * s, y: 34 * s, width: 48 * s, height: 34 * s), cornerRadius: 9 * s)
                let head = Path(roundedRect: CGRect(x: 33 * s, y: 12 * s, width: 34 * s, height: 28 * s), cornerRadius: 8 * s)
                for stone in [base, torso, head] {
                    context.stroke(stone, with: .color(sticker), style: StrokeStyle(lineWidth: 7 * s))
                    context.fill(stone, with: .color(boss.body))
                }
                // Moss/ice cap on the head
                var cap = Path()
                cap.move(to: P(33, 20))
                cap.addQuadCurve(to: P(67, 20), control: P(50, 8))
                cap.addLine(to: P(67, 24))
                cap.addQuadCurve(to: P(33, 24), control: P(50, 14))
                cap.closeSubpath()
                context.fill(cap, with: .color(boss.accent))
                // Rune eyes pulse (opacity only — no blur layers)
                let pulse = t == 0 ? 1.0 : 0.75 + 0.25 * sin(t * 2.4)
                for x in [42.0, 58.0] {
                    let eye = Path(ellipseIn: CGRect(x: (x - 4) * s, y: 24 * s, width: 8 * s, height: 6 * s))
                    context.fill(eye, with: .color(boss.accent.opacity(pulse)))
                }
                // Arm slabs
                for (x, w) in [(12.0, 12.0), (76.0, 12.0)] {
                    let arm = Path(roundedRect: CGRect(x: x * s, y: 40 * s, width: w * s, height: 26 * s), cornerRadius: 6 * s)
                    context.stroke(arm, with: .color(sticker), style: StrokeStyle(lineWidth: 6 * s))
                    context.fill(arm, with: .color(boss.body.opacity(0.9)))
                }

            case .beast:
                // Horned head-on beast: round skull, muzzle, fangs.
                let skull = Path(ellipseIn: CGRect(x: 18 * s, y: 20 * s, width: 64 * s, height: 56 * s))
                context.stroke(skull, with: .color(sticker), style: StrokeStyle(lineWidth: 7 * s))
                context.fill(skull, with: .color(boss.body))
                // Horns
                for dir in [-1.0, 1.0] {
                    var horn = Path()
                    horn.move(to: P(50 + 24 * dir, 26))
                    horn.addQuadCurve(to: P(50 + 42 * dir, 6), control: P(50 + 44 * dir, 24))
                    horn.addQuadCurve(to: P(50 + 30 * dir, 20), control: P(50 + 34 * dir, 8))
                    horn.closeSubpath()
                    context.stroke(horn, with: .color(sticker), style: StrokeStyle(lineWidth: 5 * s, lineJoin: .round))
                    context.fill(horn, with: .color(boss.accent))
                }
                // Ears
                for dir in [-1.0, 1.0] {
                    let ear = Path(ellipseIn: CGRect(x: (50 + 26 * dir - 6) * s, y: 30 * s, width: 12 * s, height: 16 * s))
                    context.fill(ear, with: .color(boss.body.opacity(0.9)))
                }
                // Muzzle + nose + fangs
                let muzzle = Path(ellipseIn: CGRect(x: 36 * s, y: 52 * s, width: 28 * s, height: 22 * s))
                context.fill(muzzle, with: .color(boss.accent.opacity(0.85)))
                let nose = Path(ellipseIn: CGRect(x: 46 * s, y: 56 * s, width: 8 * s, height: 6 * s))
                context.fill(nose, with: .color(sticker))
                for dir in [-1.0, 1.0] {
                    var fang = Path()
                    fang.move(to: P(50 + 8 * dir, 70))
                    fang.addLine(to: P(50 + 10 * dir, 78))
                    fang.addLine(to: P(50 + 4 * dir, 71))
                    fang.closeSubpath()
                    context.fill(fang, with: .color(sticker))
                }
                eyes(context: context, s: s, leftX: 38, rightX: 62, y: 42, t: t)

            case .drake:
                // Winged serpent: S-coil, one raised wing, arrow tail.
                var coil = Path()
                coil.move(to: P(16, 74))
                coil.addCurve(to: P(52, 52), control1: P(18, 52), control2: P(34, 46))
                coil.addCurve(to: P(84, 34), control1: P(72, 58), control2: P(86, 52))
                context.stroke(coil, with: .color(sticker), style: StrokeStyle(lineWidth: 21 * s, lineCap: .round))
                context.stroke(coil, with: .color(boss.body), style: StrokeStyle(lineWidth: 14 * s, lineCap: .round))
                // Wing
                var wing = Path()
                wing.move(to: P(44, 52))
                wing.addQuadCurve(to: P(24, 16), control: P(20, 34))
                wing.addQuadCurve(to: P(44, 34), control: P(38, 20))
                wing.addQuadCurve(to: P(56, 44), control: P(52, 34))
                wing.closeSubpath()
                context.stroke(wing, with: .color(sticker), style: StrokeStyle(lineWidth: 5 * s, lineJoin: .round))
                context.fill(wing, with: .color(boss.accent))
                // Head
                let head = Path(ellipseIn: CGRect(x: 72 * s, y: 20 * s, width: 22 * s, height: 20 * s))
                context.stroke(head, with: .color(sticker), style: StrokeStyle(lineWidth: 6 * s))
                context.fill(head, with: .color(boss.body))
                // Snout + eye
                var snout = Path()
                snout.move(to: P(90, 26))
                snout.addLine(to: P(99, 30))
                snout.addLine(to: P(90, 34))
                snout.closeSubpath()
                context.fill(snout, with: .color(boss.accent))
                let eye = Path(ellipseIn: CGRect(x: 80 * s, y: 26 * s, width: 5 * s, height: 5 * s))
                context.fill(eye, with: .color(.black.opacity(0.75)))
                // Tail arrow
                var tail = Path()
                tail.move(to: P(16, 74))
                tail.addLine(to: P(6, 68))
                tail.addLine(to: P(12, 80))
                tail.closeSubpath()
                context.fill(tail, with: .color(boss.accent))
            }
        }
    }

    /// Shared live eyes: dark pupils that drift and blink.
    private func eyes(context: GraphicsContext, s: CGFloat, leftX: CGFloat, rightX: CGFloat, y: CGFloat, t: Double) {
        let blink = t == 0 ? false : (t.truncatingRemainder(dividingBy: 4.3) < 0.12)
        let drift = t == 0 ? 0 : sin(t * 0.8) * 1.5
        for x in [leftX, rightX] {
            if blink {
                var lid = Path()
                lid.move(to: CGPoint(x: (x - 4) * s, y: y * s))
                lid.addLine(to: CGPoint(x: (x + 4) * s, y: y * s))
                context.stroke(lid, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
            } else {
                let white = Path(ellipseIn: CGRect(x: (x - 5) * s, y: (y - 5) * s, width: 10 * s, height: 10 * s))
                context.fill(white, with: .color(.white))
                let pupil = Path(ellipseIn: CGRect(x: (x - 2 + drift) * s, y: (y - 2) * s, width: 4.5 * s, height: 4.5 * s))
                context.fill(pupil, with: .color(.black.opacity(0.85)))
            }
        }
    }
}

// MARK: - Trial card (Journey tab)
//
// The thing that stands in the road. Journey's region banner owns the
// Campaign Map entry, so this panel is only the foe, the banked might, and
// — once the might is there — the one action that spends it.

struct TrialCard: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var spoils: TrialSpoils? = nil

    var body: some View {
        let boss = state.currentTrialBoss
        let banked = state.user.trialMight
        let ready = banked >= boss.hp
        let progress = min(1.0, banked / max(1, boss.hp))
        let felled = state.user.trialVictories.count

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                PillTag(text: "The Trial", tint: RPGTheme.gold)
                if felled > 0 {
                    Text("· \(felled) felled")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            portrait(boss)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("The Trial: \(boss.name), \(boss.epithet). \(boss.flavor)")

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Might")
                        .font(RPGTheme.label(11, weight: .semibold))
                        .tracking(1.0)
                        .foregroundColor(.secondary)
                    Text("\(Int(banked)) / \(Int(boss.hp))")
                        .font(RPGTheme.display(15))
                        .monospacedDigit()
                        .foregroundColor(ready ? RPGTheme.xp : .primary)
                    Spacer(minLength: 6)
                    if state.equipmentMight > 0 {
                        Text("+\(state.equipmentMight)% from gear")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(RPGTheme.gold)
                            .fixedSize()
                    }
                }
                .accessibilityElement(children: .combine)
                OrnateProgressBar(progress: progress,
                                  tint: ready ? RPGTheme.xp : RPGTheme.accent,
                                  height: 8, label: "Might banked")
            }

            if ready {
                Button {
                    guard let result = state.resolveTrial() else { return }
                    spoils = result
                } label: {
                    HStack(spacing: 8) {
                        RPGSymbolIcon(
                            symbol: .trial,
                            size: 17,
                            presentation: .compact,
                            palette: .onPlate
                        )
                        Text("Face the Trial")
                    }
                }
                .buttonStyle(RPGPrimaryButtonStyle())
                .accessibilityLabel("Face the Trial")
                .accessibilityHint("Begins the Trial battle")
            } else {
                Text("Train to build might — every logged set strikes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .rpgCard(padding: 16, accent: ready ? RPGTheme.gold : nil, ornate: ready)
        .fullScreenCover(item: $spoils) { result in
            TrialResolveView(spoils: result)
                .environmentObject(state)
        }
        .accessibilityElement(children: .contain)
    }

    /// Boss art inside a thin brass ring beside its name, epithet and
    /// flavor line. Stacks vertically at accessibility text sizes.
    @ViewBuilder
    private func portrait(_ boss: TrialBoss) -> some View {
        let art = TrialBossView(boss: boss, size: 84)
            .padding(6)
            .overlay(
                Circle()
                    .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline + 0.14), lineWidth: 1)
            )

        let identity = VStack(alignment: .leading, spacing: 3) {
            Text(boss.name)
                .font(RPGTheme.heading(.title3, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(boss.epithet)
                .font(.caption.italic())
                .foregroundColor(.secondary)
            Text(boss.flavor)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                art
                identity
            }
        } else {
            HStack(alignment: .top, spacing: 14) {
                art
                identity
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Resolve ceremony

/// The banked-might payoff: three strikes, a fall, and the spoils. The
/// outcome is already decided by training — this is theater, and it says so
/// through restraint: no misses, no health scares, no timers.
struct TrialResolveView: View {
    let spoils: TrialSpoils
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var strikes = 0          // 0...3
    @State private var bossFallen = false
    @State private var showSpoils = false
    @State private var lunge = false

    private var hpFraction: Double { max(0, 1.0 - Double(strikes) / 3.0) }

    var body: some View {
        ZStack {
            RPGTheme.canvas.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    if !bossFallen {
                        TrialBossView(boss: spoils.boss, size: 170, animated: !showSpoils)
                            .scaleEffect(lunge ? 0.94 : 1.0)
                            .offset(x: lunge ? 6 : 0)
                    } else {
                        // Fallen: the boss dissolves into gold sparks.
                        ForEach(0..<10, id: \.self) { index in
                            GlyphIcon(glyph: .spark, size: 14, tint: RPGTheme.gold)
                                .offset(x: cos(Double(index) / 10 * 2 * .pi) * 70,
                                        y: sin(Double(index) / 10 * 2 * .pi) * 70)
                                .opacity(showSpoils ? 0 : 1)
                                .animation(.easeOut(duration: 0.8), value: showSpoils)
                                .accessibilityHidden(true)
                        }
                    }

                    // The companion lunges in with each strike.
                    if let species = state.activeCompanionSpecies, !bossFallen {
                        CompanionSpriteView(species: species, size: 64, accessory: state.accessory(for: species))
                            .offset(x: lunge ? 26 : -96, y: 42)
                            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: lunge)
                    }
                }
                .frame(height: 210)

                VStack(spacing: 10) {
                    PillTag(text: "The Trial", tint: RPGTheme.gold)
                        .accessibilityHidden(true)

                    Text(bossFallen ? "\(spoils.boss.name) falls!" : spoils.boss.name)
                        .font(RPGTheme.heading(.title, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if !bossFallen {
                        // Endurance bar draining strike by strike
                        OrnateProgressBar(progress: hpFraction, tint: RPGTheme.accent, height: 8, label: "Boss endurance")
                            .frame(width: 220)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: strikes)

                        Text("Your training strikes true.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("The road is clear. Take your spoils.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if showSpoils {
                    VStack(spacing: 4) {
                        SectionLabel("Spoils", tint: RPGTheme.gold)
                            .padding(.bottom, 6)
                        spoilRow(symbol: .coin, tint: RPGTheme.gold, text: "\(spoils.coins) Gold Coins")
                        if let item = spoils.itemInfo {
                            spoilRowItem(item)
                        }
                        if spoils.eggGranted {
                            spoilRow(symbol: .companionEgg, tint: RPGTheme.gold, text: "Companion Egg")
                        }
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: AppLayout.contentMaxWidth)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                Text(showSpoils ? "Tap anywhere to continue" : " ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if showSpoils {
                dismiss()
            } else {
                finishSequence() // impatient taps skip to the spoils
            }
        }
        .onAppear { runSequence() }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { dismiss() }
        .accessibilityLabel("Trial resolved: \(spoils.boss.name) defeated. Spoils: \(spoils.coins) coins\(spoils.itemInfo.map { ", \($0.displayName)" } ?? "")\(spoils.eggGranted ? ", companion egg" : "").")
    }

    private func runSequence() {
        if reduceMotion {
            finishSequence()
            return
        }
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + Double(i - 1) * 0.75) {
                guard !showSpoils else { return }
                Haptics.tap()
                withAnimation { strikes = i }
                lunge = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { lunge = false }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + 2.6) {
            finishSequence()
        }
    }

    private func finishSequence() {
        guard !showSpoils else { return }
        strikes = 3
        Haptics.success()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            bossFallen = true
            showSpoils = true
        }
    }

    @ViewBuilder
    private func spoilRow(symbol: RPGSymbol, tint: Color = RPGTheme.gold, text: String) -> some View {
        HStack(spacing: 10) {
            RPGSymbolIcon(
                symbol: symbol,
                size: 18,
                presentation: .compact,
                palette: .monochrome(tint)
            )
            Text(text)
                .font(RPGTheme.heading(.subheadline, weight: .semibold))
                .foregroundColor(.primary)
                .monospacedDigit()
            Spacer()
        }
        .frame(minHeight: 44)
        .rpgInset()
        .overlay(
            RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func spoilRowItem(_ item: ItemInfo) -> some View {
        HStack(spacing: 10) {
            RPGSymbolIcon(
                symbol: item.rpgSymbol,
                size: 16,
                presentation: .compact,
                palette: .themed(item.iconColor)
            )
            Text(item.displayName)
                .font(RPGTheme.heading(.subheadline, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            PillTag(text: item.rarity, tint: item.rarityColor)
        }
        .frame(minHeight: 44)
        .rpgInset()
        .overlay(
            RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
