// Semantic, layered iconography for RPGFit.
//
// `RPGGlyph` remains the persistence-compatible, single-stroke legacy set.
// This file adds a domain vocabulary above it: callers ask for a meaning
// (`.training`, `.streak`, `.companionBond`) and the renderer chooses detailed
// or compact artwork without exposing drawing or palette decisions.

import SwiftUI
import UIKit

// MARK: - Semantic catalog

enum RPGSymbol: String, CaseIterable {
    // App destinations
    case character
    case training
    case journey
    case progress

    // Character attributes
    case statSize
    case statStrength
    case statDexterity
    case statAgility
    case statEndurance
    case statVitality

    // Character classes. Each class owns one crest instead of compositing two
    // tiny attribute marks, so identity survives at row and badge sizes.
    case classWarrior
    case classDuelist
    case classBerserker
    case classPaladin
    case classAssassin
    case classMonk
    case classRanger
    case classScout
    case classTank
    case classBrawler
    case classTitan
    case classJuggernaut
    case classSpartan
    case classDruid
    case classHealer

    // Training focuses
    case focusStrength
    case focusHypertrophy
    case focusBodyweight
    case focusExplosive
    case focusEndurance
    case focusMobility

    // Training measurements (content, never control state)
    case metricRepetitions
    case metricLoad
    case metricDuration
    case metricDistance

    // Training state
    case rest
    case repeatSession
    case plateCalculator
    case exerciseSwap
    case superset
    case setWarmup
    case setWorking
    case completionSeal

    // Equipment taxonomy
    case equipmentArms
    case equipmentGuard
    case equipmentRelic
    case equipped

    // Loot taxonomy and authored rewards
    case lootConsumable
    case lootEquipment
    case lootMaterial
    case lootCollectible
    case lootBuckler
    case lootTonic
    case lootMap
    case lootDice
    case lootRuneFragment
    case lootPhoenixFeather
    case lootChalice
    case lootTome
    case lootTrophy
    case lootWand
    case lootCrown

    // Journey regions and rites
    case regionKindlingVale
    case regionAshenPasses
    case regionStormreach
    case regionCrownOfDawn
    case regionElderWilds
    case ledgerstone
    case placementRite

    // Product concepts
    case quickLog
    case routine
    case quest
    case campaign
    case trial
    case chronicle
    case personalRecord
    case rank
    case rankBronze
    case rankSilver
    case rankGold
    case rankPlatinum
    case rankDiamond
    case rankMaster
    case rankGrandmaster
    case rankIndependent
    case rankCurrent
    case streak
    case streakFreeze
    case satchel
    case chest
    case companion
    case companionBond
    case companionEgg
    case xp
    case might
    case coin
}

enum RPGSymbolPresentation: Equatable {
    /// Compact below 24 points, otherwise standard. It never opts into glow.
    case automatic
    /// Simplified, single-rail artwork for tabs, chips, and dense rows.
    case compact
    /// Layered artwork with no atmospheric effects.
    case standard
    /// Full layered artwork; may receive a restrained dark-mode halo.
    case hero
    /// Full layered artwork with a slightly brighter celebratory treatment.
    case reward
}

enum RPGSymbolPalette {
    /// Ink and deep gold on parchment; ivory and warm gold in the dark keep.
    case adaptive
    /// High-contrast treatment for forest, gold, or class-colored plates.
    case onPlate
    /// One-color rendering for utility surfaces and caller-owned semantics.
    case monochrome(Color)
    /// A caller-owned semantic hue. Compact marks are fully monochrome;
    /// larger artwork keeps the hue on its main rail with branded engraving.
    case themed(Color)
}

// MARK: - Artwork model

/// All geometry is authored in a shared 100×100 coordinate space. Separate
/// paths let a symbol keep its meaning in monochrome while gaining ivory rails,
/// gold engraving, and a small semantic jewel at display sizes.
private struct RPGSymbolArtwork {
    let primary: Path
    let detail: Path
    let accent: Path
    let accentFill: Path
    let compact: Path

    /// Per-glyph optical correction in design-space units.
    let opticalScale: CGFloat
    let opticalOffset: CGSize

    init(
        primary: Path,
        detail: Path = Path(),
        accent: Path = Path(),
        accentFill: Path = Path(),
        compact: Path? = nil,
        opticalScale: CGFloat = 1,
        opticalOffset: CGSize = .zero
    ) {
        self.primary = primary
        self.detail = detail
        self.accent = accent
        self.accentFill = accentFill
        self.compact = compact ?? primary
        self.opticalScale = opticalScale
        self.opticalOffset = opticalOffset
    }
}

private enum RPGSymbolArtworkFactory {
    private static let designRect = CGRect(x: 0, y: 0, width: 100, height: 100)

    static func artwork(for symbol: RPGSymbol) -> RPGSymbolArtwork {
        switch symbol {
        case .character:
            return characterArtwork()
        case .training:
            return trainingArtwork()
        case .journey:
            return journeyArtwork()
        case .progress:
            return progressArtwork()

        case .statSize:
            return statSizeArtwork()
        case .statStrength:
            return statStrengthArtwork()
        case .statDexterity:
            return statDexterityArtwork()
        case .statAgility:
            return statAgilityArtwork()
        case .statEndurance:
            return statEnduranceArtwork()
        case .statVitality:
            return statVitalityArtwork()

        case .classWarrior:
            return classWarriorArtwork()
        case .classDuelist:
            return classDuelistArtwork()
        case .classBerserker:
            return classBerserkerArtwork()
        case .classPaladin:
            return classPaladinArtwork()
        case .classAssassin:
            return classAssassinArtwork()
        case .classMonk:
            return classMonkArtwork()
        case .classRanger:
            return classRangerArtwork()
        case .classScout:
            return classScoutArtwork()
        case .classTank:
            return classTankArtwork()
        case .classBrawler:
            return classBrawlerArtwork()
        case .classTitan:
            return classTitanArtwork()
        case .classJuggernaut:
            return classJuggernautArtwork()
        case .classSpartan:
            return classSpartanArtwork()
        case .classDruid:
            return classDruidArtwork()
        case .classHealer:
            return classHealerArtwork()

        case .focusStrength:
            return focusStrengthArtwork()
        case .focusHypertrophy:
            return focusHypertrophyArtwork()
        case .focusBodyweight:
            return focusBodyweightArtwork()
        case .focusExplosive:
            return focusExplosiveArtwork()
        case .focusEndurance:
            return focusEnduranceArtwork()
        case .focusMobility:
            return focusMobilityArtwork()

        case .metricRepetitions:
            return metricRepetitionsArtwork()
        case .metricLoad:
            return metricLoadArtwork()
        case .metricDuration:
            return metricDurationArtwork()
        case .metricDistance:
            return metricDistanceArtwork()

        case .rest:
            return restArtwork()
        case .repeatSession:
            return repeatSessionArtwork()
        case .plateCalculator:
            return plateCalculatorArtwork()
        case .exerciseSwap:
            return exerciseSwapArtwork()
        case .superset:
            return supersetArtwork()
        case .setWarmup:
            return setWarmupArtwork()
        case .setWorking:
            return setWorkingArtwork()
        case .completionSeal:
            return completionSealArtwork()

        case .equipmentArms:
            return equipmentArmsArtwork()
        case .equipmentGuard:
            return equipmentGuardArtwork()
        case .equipmentRelic:
            return equipmentRelicArtwork()
        case .equipped:
            return equippedArtwork()

        case .lootConsumable:
            return lootConsumableArtwork()
        case .lootEquipment:
            return lootEquipmentArtwork()
        case .lootMaterial:
            return lootMaterialArtwork()
        case .lootCollectible:
            return lootCollectibleArtwork()
        case .lootBuckler:
            return lootBucklerArtwork()
        case .lootTonic:
            return lootTonicArtwork()
        case .lootMap:
            return lootMapArtwork()
        case .lootDice:
            return lootDiceArtwork()
        case .lootRuneFragment:
            return lootRuneFragmentArtwork()
        case .lootPhoenixFeather:
            return lootPhoenixFeatherArtwork()
        case .lootChalice:
            return lootChaliceArtwork()
        case .lootTome:
            return lootTomeArtwork()
        case .lootTrophy:
            return lootTrophyArtwork()
        case .lootWand:
            return lootWandArtwork()
        case .lootCrown:
            return lootCrownArtwork()

        case .regionKindlingVale:
            return regionKindlingValeArtwork()
        case .regionAshenPasses:
            return regionAshenPassesArtwork()
        case .regionStormreach:
            return regionStormreachArtwork()
        case .regionCrownOfDawn:
            return regionCrownOfDawnArtwork()
        case .regionElderWilds:
            return regionElderWildsArtwork()
        case .ledgerstone:
            return ledgerstoneArtwork()
        case .placementRite:
            return placementRiteArtwork()

        case .quickLog:
            return quickLogArtwork()
        case .routine:
            return routineArtwork()
        case .quest:
            return questArtwork()
        case .campaign:
            return campaignArtwork()
        case .trial:
            return trialArtwork()
        case .chronicle:
            return chronicleArtwork()
        case .personalRecord:
            return personalRecordArtwork()
        case .rank:
            return rankArtwork()
        case .rankBronze:
            return rankBronzeArtwork()
        case .rankSilver:
            return rankSilverArtwork()
        case .rankGold:
            return rankGoldArtwork()
        case .rankPlatinum:
            return rankPlatinumArtwork()
        case .rankDiamond:
            return rankDiamondArtwork()
        case .rankMaster:
            return rankMasterArtwork()
        case .rankGrandmaster:
            return rankGrandmasterArtwork()
        case .rankIndependent:
            return rankIndependentArtwork()
        case .rankCurrent:
            return rankCurrentArtwork()
        case .streak:
            return streakArtwork()
        case .streakFreeze:
            return streakFreezeArtwork()
        case .satchel:
            return satchelArtwork()
        case .chest:
            return chestArtwork()
        case .companion:
            return companionArtwork()
        case .companionBond:
            return companionBondArtwork()
        case .companionEgg:
            return companionEggArtwork()
        case .xp:
            return xpArtwork()
        case .might:
            return mightArtwork()
        case .coin:
            return coinArtwork()
        }
    }

    // MARK: Shared drawing helpers

    private static func make(_ drawing: (inout Path) -> Void) -> Path {
        var path = Path()
        drawing(&path)
        return path
    }

    private static func legacy(_ glyph: RPGGlyph) -> Path {
        GlyphShape(glyph: glyph).path(in: designRect)
    }

    private static func diamond(_ path: inout Path, center: CGPoint, radius: CGFloat) {
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
        path.closeSubpath()
    }

    private static func fourPointStar(_ path: inout Path, center: CGPoint, long: CGFloat, short: CGFloat) {
        path.move(to: CGPoint(x: center.x, y: center.y - long))
        path.addLine(to: CGPoint(x: center.x + short, y: center.y - short))
        path.addLine(to: CGPoint(x: center.x + long, y: center.y))
        path.addLine(to: CGPoint(x: center.x + short, y: center.y + short))
        path.addLine(to: CGPoint(x: center.x, y: center.y + long))
        path.addLine(to: CGPoint(x: center.x - short, y: center.y + short))
        path.addLine(to: CGPoint(x: center.x - long, y: center.y))
        path.addLine(to: CGPoint(x: center.x - short, y: center.y - short))
        path.closeSubpath()
    }

    private static func plus(_ path: inout Path, center: CGPoint, arm: CGFloat) {
        path.move(to: CGPoint(x: center.x - arm, y: center.y))
        path.addLine(to: CGPoint(x: center.x + arm, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - arm))
        path.addLine(to: CGPoint(x: center.x, y: center.y + arm))
    }

    private static func combined(_ paths: Path...) -> Path {
        var result = Path()
        for path in paths {
            result.addPath(path)
        }
        return result
    }

    // MARK: Core destinations

    /// A forward-facing wolf crest: alert ears, angular cheek rails, calm eyes.
    private static func characterArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 17, y: 17))
            p.addLine(to: CGPoint(x: 38, y: 29))
            p.addLine(to: CGPoint(x: 50, y: 16))
            p.addLine(to: CGPoint(x: 62, y: 29))
            p.addLine(to: CGPoint(x: 83, y: 17))
            p.addLine(to: CGPoint(x: 76, y: 57))
            p.addCurve(to: CGPoint(x: 50, y: 91),
                       control1: CGPoint(x: 73, y: 75),
                       control2: CGPoint(x: 61, y: 86))
            p.addCurve(to: CGPoint(x: 24, y: 57),
                       control1: CGPoint(x: 39, y: 86),
                       control2: CGPoint(x: 27, y: 75))
            p.closeSubpath()
            p.move(to: CGPoint(x: 27, y: 38))
            p.addLine(to: CGPoint(x: 43, y: 47))
            p.move(to: CGPoint(x: 73, y: 38))
            p.addLine(to: CGPoint(x: 57, y: 47))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 31, y: 62))
            p.addLine(to: CGPoint(x: 43, y: 55))
            p.addLine(to: CGPoint(x: 50, y: 69))
            p.addLine(to: CGPoint(x: 57, y: 55))
            p.addLine(to: CGPoint(x: 69, y: 62))
            p.move(to: CGPoint(x: 40, y: 77))
            p.addLine(to: CGPoint(x: 50, y: 82))
            p.addLine(to: CGPoint(x: 60, y: 77))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 69), radius: 4) }
        return RPGSymbolArtwork(
            primary: primary,
            detail: detail,
            accentFill: accentFill,
            compact: legacy(.crest),
            opticalScale: 0.92,
            opticalOffset: CGSize(width: 0, height: 1)
        )
    }

    /// A plate-loaded barbell with small rune punctuation above and below.
    private static func trainingArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 27, y: 50))
            p.addLine(to: CGPoint(x: 73, y: 50))
            for x in [CGFloat(18), 27, 73, 82] {
                let height: CGFloat = (x == 18 || x == 82) ? 27 : 43
                p.move(to: CGPoint(x: x, y: 50 - height / 2))
                p.addLine(to: CGPoint(x: x, y: 50 + height / 2))
            }
            p.move(to: CGPoint(x: 10, y: 39))
            p.addLine(to: CGPoint(x: 10, y: 61))
            p.move(to: CGPoint(x: 90, y: 39))
            p.addLine(to: CGPoint(x: 90, y: 61))
            p.move(to: CGPoint(x: 10, y: 39))
            p.addLine(to: CGPoint(x: 18, y: 39))
            p.move(to: CGPoint(x: 10, y: 61))
            p.addLine(to: CGPoint(x: 18, y: 61))
            p.move(to: CGPoint(x: 82, y: 39))
            p.addLine(to: CGPoint(x: 90, y: 39))
            p.move(to: CGPoint(x: 82, y: 61))
            p.addLine(to: CGPoint(x: 90, y: 61))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 34, y: 43))
            p.addLine(to: CGPoint(x: 66, y: 43))
            p.move(to: CGPoint(x: 34, y: 57))
            p.addLine(to: CGPoint(x: 66, y: 57))
            diamond(&p, center: CGPoint(x: 50, y: 18), radius: 8)
            diamond(&p, center: CGPoint(x: 50, y: 82), radius: 8)
        }
        let accent = make { p in
            p.move(to: CGPoint(x: 50, y: 26))
            p.addLine(to: CGPoint(x: 50, y: 36))
            p.move(to: CGPoint(x: 50, y: 64))
            p.addLine(to: CGPoint(x: 50, y: 74))
        }
        return RPGSymbolArtwork(
            primary: primary,
            detail: detail,
            accent: accent,
            compact: legacy(.dumbbell),
            opticalScale: 0.96
        )
    }

    /// A hanging road banner: mountain objective above a winding path.
    private static func journeyArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 13, y: 18))
            p.addLine(to: CGPoint(x: 87, y: 18))
            p.move(to: CGPoint(x: 20, y: 13))
            p.addLine(to: CGPoint(x: 13, y: 18))
            p.addLine(to: CGPoint(x: 20, y: 23))
            p.move(to: CGPoint(x: 80, y: 13))
            p.addLine(to: CGPoint(x: 87, y: 18))
            p.addLine(to: CGPoint(x: 80, y: 23))
            p.move(to: CGPoint(x: 24, y: 18))
            p.addLine(to: CGPoint(x: 24, y: 85))
            p.addLine(to: CGPoint(x: 50, y: 72))
            p.addLine(to: CGPoint(x: 76, y: 85))
            p.addLine(to: CGPoint(x: 76, y: 18))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 30, y: 56))
            p.addLine(to: CGPoint(x: 43, y: 41))
            p.addLine(to: CGPoint(x: 51, y: 50))
            p.addLine(to: CGPoint(x: 61, y: 34))
            p.addLine(to: CGPoint(x: 70, y: 56))
            p.move(to: CGPoint(x: 60, y: 78))
            p.addCurve(to: CGPoint(x: 39, y: 58),
                       control1: CGPoint(x: 43, y: 73),
                       control2: CGPoint(x: 64, y: 66))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 18), radius: 5) }
        return RPGSymbolArtwork(
            primary: primary,
            detail: detail,
            accentFill: accentFill,
            compact: legacy(.compass),
            opticalScale: 0.91,
            opticalOffset: CGSize(width: 0, height: 1)
        )
    }

    /// An open training chronicle whose central marks climb like a chart.
    private static func progressArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 50, y: 25))
            p.addCurve(to: CGPoint(x: 14, y: 21),
                       control1: CGPoint(x: 39, y: 16),
                       control2: CGPoint(x: 25, y: 17))
            p.addLine(to: CGPoint(x: 14, y: 75))
            p.addCurve(to: CGPoint(x: 50, y: 86),
                       control1: CGPoint(x: 28, y: 72),
                       control2: CGPoint(x: 40, y: 77))
            p.addCurve(to: CGPoint(x: 86, y: 75),
                       control1: CGPoint(x: 60, y: 77),
                       control2: CGPoint(x: 72, y: 72))
            p.addLine(to: CGPoint(x: 86, y: 21))
            p.addCurve(to: CGPoint(x: 50, y: 25),
                       control1: CGPoint(x: 75, y: 17),
                       control2: CGPoint(x: 61, y: 16))
            p.move(to: CGPoint(x: 50, y: 25))
            p.addLine(to: CGPoint(x: 50, y: 86))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 27, y: 44))
            p.addLine(to: CGPoint(x: 38, y: 55))
            p.addLine(to: CGPoint(x: 46, y: 43))
            p.move(to: CGPoint(x: 54, y: 62))
            p.addLine(to: CGPoint(x: 63, y: 51))
            p.addLine(to: CGPoint(x: 72, y: 38))
            p.move(to: CGPoint(x: 57, y: 70))
            p.addLine(to: CGPoint(x: 76, y: 70))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 18), radius: 5) }
        return RPGSymbolArtwork(
            primary: primary,
            detail: detail,
            accentFill: accentFill,
            compact: legacy(.chart),
            opticalScale: 0.92,
            opticalOffset: CGSize(width: 0, height: 2)
        )
    }

    // MARK: Attributes

    /// A broad, stepped massif. The tiered contour reads as accumulated mass,
    /// while the offset summit keeps it distinct from the Journey mountains.
    private static func statSizeArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 8, y: 83))
            p.addLine(to: CGPoint(x: 30, y: 51))
            p.addLine(to: CGPoint(x: 41, y: 63))
            p.addLine(to: CGPoint(x: 59, y: 29))
            p.addLine(to: CGPoint(x: 69, y: 49))
            p.addLine(to: CGPoint(x: 79, y: 37))
            p.addLine(to: CGPoint(x: 92, y: 83))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 19, y: 83))
            p.addLine(to: CGPoint(x: 34, y: 65))
            p.addLine(to: CGPoint(x: 43, y: 75))
            p.move(to: CGPoint(x: 48, y: 83))
            p.addLine(to: CGPoint(x: 60, y: 57))
            p.addLine(to: CGPoint(x: 68, y: 69))
            p.addLine(to: CGPoint(x: 77, y: 58))
            p.move(to: CGPoint(x: 14, y: 90))
            p.addLine(to: CGPoint(x: 86, y: 90))
            diamond(&p, center: CGPoint(x: 59, y: 18), radius: 6)
        }
        let compact = combined(primary, make { p in
            p.move(to: CGPoint(x: 16, y: 88))
            p.addLine(to: CGPoint(x: 84, y: 88))
        })
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: compact,
                                opticalScale: 0.92, opticalOffset: CGSize(width: 0, height: -1))
    }

    /// A plate-headed rune hammer replaces the generic sword. Its weight is
    /// visible in silhouette even before the internal metalwork appears.
    private static func statStrengthArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 16, y: 22))
            p.addLine(to: CGPoint(x: 27, y: 22))
            p.addLine(to: CGPoint(x: 27, y: 15))
            p.addLine(to: CGPoint(x: 73, y: 15))
            p.addLine(to: CGPoint(x: 73, y: 22))
            p.addLine(to: CGPoint(x: 84, y: 22))
            p.addLine(to: CGPoint(x: 84, y: 43))
            p.addLine(to: CGPoint(x: 58, y: 43))
            p.addLine(to: CGPoint(x: 55, y: 84))
            p.addLine(to: CGPoint(x: 45, y: 84))
            p.addLine(to: CGPoint(x: 42, y: 43))
            p.addLine(to: CGPoint(x: 16, y: 43))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 28, y: 30))
            p.addLine(to: CGPoint(x: 72, y: 30))
            p.move(to: CGPoint(x: 35, y: 36))
            p.addLine(to: CGPoint(x: 65, y: 36))
            p.move(to: CGPoint(x: 46, y: 58))
            p.addLine(to: CGPoint(x: 54, y: 58))
            diamond(&p, center: CGPoint(x: 50, y: 90), radius: 5)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: primary,
                                opticalScale: 0.91, opticalOffset: CGSize(width: 0, height: -1))
    }

    /// A taut angular bow and one nocked arrow: precision, tension, release.
    private static func statDexterityArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 29, y: 11))
            p.addCurve(to: CGPoint(x: 57, y: 50),
                       control1: CGPoint(x: 44, y: 21),
                       control2: CGPoint(x: 52, y: 36))
            p.addCurve(to: CGPoint(x: 29, y: 89),
                       control1: CGPoint(x: 52, y: 64),
                       control2: CGPoint(x: 44, y: 79))
            p.move(to: CGPoint(x: 29, y: 11))
            p.addLine(to: CGPoint(x: 57, y: 50))
            p.addLine(to: CGPoint(x: 29, y: 89))
            p.move(to: CGPoint(x: 13, y: 50))
            p.addLine(to: CGPoint(x: 88, y: 50))
            p.move(to: CGPoint(x: 88, y: 50))
            p.addLine(to: CGPoint(x: 77, y: 42))
            p.move(to: CGPoint(x: 88, y: 50))
            p.addLine(to: CGPoint(x: 77, y: 58))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 19, y: 50))
            p.addLine(to: CGPoint(x: 10, y: 41))
            p.move(to: CGPoint(x: 19, y: 50))
            p.addLine(to: CGPoint(x: 10, y: 59))
            p.move(to: CGPoint(x: 38, y: 25))
            p.addLine(to: CGPoint(x: 48, y: 31))
            p.move(to: CGPoint(x: 38, y: 75))
            p.addLine(to: CGPoint(x: 48, y: 69))
            diamond(&p, center: CGPoint(x: 57, y: 50), radius: 4)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: primary,
                                opticalScale: 0.91, opticalOffset: CGSize(width: -1, height: 0))
    }

    /// A winged boot with three trailing rails. It keeps the old wing cue but
    /// turns it into an active, directional mark rather than a loose feather.
    private static func statAgilityArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 42, y: 16))
            p.addLine(to: CGPoint(x: 48, y: 35))
            p.addLine(to: CGPoint(x: 50, y: 57))
            p.addLine(to: CGPoint(x: 75, y: 66))
            p.addLine(to: CGPoint(x: 88, y: 78))
            p.addLine(to: CGPoint(x: 77, y: 87))
            p.addLine(to: CGPoint(x: 42, y: 79))
            p.addLine(to: CGPoint(x: 30, y: 64))
            p.addLine(to: CGPoint(x: 36, y: 45))
            p.closeSubpath()
            p.move(to: CGPoint(x: 38, y: 24))
            p.addLine(to: CGPoint(x: 18, y: 14))
            p.addLine(to: CGPoint(x: 25, y: 34))
            p.addLine(to: CGPoint(x: 10, y: 31))
            p.addLine(to: CGPoint(x: 28, y: 52))
            p.addLine(to: CGPoint(x: 36, y: 45))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 44, y: 33))
            p.addLine(to: CGPoint(x: 30, y: 27))
            p.move(to: CGPoint(x: 44, y: 43))
            p.addLine(to: CGPoint(x: 26, y: 38))
            p.move(to: CGPoint(x: 42, y: 72))
            p.addLine(to: CGPoint(x: 78, y: 80))
            p.move(to: CGPoint(x: 25, y: 60))
            p.addLine(to: CGPoint(x: 10, y: 60))
            p.move(to: CGPoint(x: 22, y: 70))
            p.addLine(to: CGPoint(x: 7, y: 70))
            p.move(to: CGPoint(x: 25, y: 80))
            p.addLine(to: CGPoint(x: 13, y: 80))
        }
        let compact = combined(primary, make { p in
            p.move(to: CGPoint(x: 24, y: 65))
            p.addLine(to: CGPoint(x: 9, y: 65))
            p.move(to: CGPoint(x: 25, y: 77))
            p.addLine(to: CGPoint(x: 12, y: 77))
        })
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: compact,
                                opticalScale: 0.90)
    }

    /// A heart-shaped shield crossed by a steady pulse. The closed outer rail
    /// communicates staying power; the pulse prevents it reading as defense.
    private static func statEnduranceArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 50, y: 88))
            p.addCurve(to: CGPoint(x: 16, y: 48),
                       control1: CGPoint(x: 37, y: 76),
                       control2: CGPoint(x: 16, y: 65))
            p.addCurve(to: CGPoint(x: 33, y: 18),
                       control1: CGPoint(x: 16, y: 30),
                       control2: CGPoint(x: 25, y: 18))
            p.addCurve(to: CGPoint(x: 50, y: 31),
                       control1: CGPoint(x: 42, y: 18),
                       control2: CGPoint(x: 47, y: 25))
            p.addCurve(to: CGPoint(x: 67, y: 18),
                       control1: CGPoint(x: 53, y: 25),
                       control2: CGPoint(x: 58, y: 18))
            p.addCurve(to: CGPoint(x: 84, y: 48),
                       control1: CGPoint(x: 75, y: 18),
                       control2: CGPoint(x: 84, y: 30))
            p.addCurve(to: CGPoint(x: 50, y: 88),
                       control1: CGPoint(x: 84, y: 65),
                       control2: CGPoint(x: 63, y: 76))
            p.closeSubpath()
        }
        let pulse = make { p in
            p.move(to: CGPoint(x: 23, y: 52))
            p.addLine(to: CGPoint(x: 36, y: 52))
            p.addLine(to: CGPoint(x: 43, y: 39))
            p.addLine(to: CGPoint(x: 52, y: 65))
            p.addLine(to: CGPoint(x: 59, y: 52))
            p.addLine(to: CGPoint(x: 76, y: 52))
        }
        let detail = combined(pulse, make { p in
            p.move(to: CGPoint(x: 50, y: 76))
            p.addLine(to: CGPoint(x: 50, y: 68))
            diamond(&p, center: CGPoint(x: 50, y: 14), radius: 4)
        })
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                compact: combined(primary, pulse), opticalScale: 0.90)
    }

    /// A crescent protects a living sprout. Vitality alone receives the green
    /// jewel, preserving that rare accent as a literal sign of life.
    private static func statVitalityArtwork() -> RPGSymbolArtwork {
        let crescent = make { p in
            p.move(to: CGPoint(x: 69, y: 14))
            p.addCurve(to: CGPoint(x: 22, y: 29),
                       control1: CGPoint(x: 48, y: 13),
                       control2: CGPoint(x: 29, y: 18))
            p.addCurve(to: CGPoint(x: 20, y: 70),
                       control1: CGPoint(x: 13, y: 42),
                       control2: CGPoint(x: 13, y: 59))
            p.addCurve(to: CGPoint(x: 69, y: 86),
                       control1: CGPoint(x: 30, y: 84),
                       control2: CGPoint(x: 50, y: 90))
            p.addCurve(to: CGPoint(x: 42, y: 68),
                       control1: CGPoint(x: 52, y: 79),
                       control2: CGPoint(x: 45, y: 74))
            p.addCurve(to: CGPoint(x: 43, y: 32),
                       control1: CGPoint(x: 34, y: 56),
                       control2: CGPoint(x: 35, y: 42))
            p.addCurve(to: CGPoint(x: 69, y: 14),
                       control1: CGPoint(x: 48, y: 25),
                       control2: CGPoint(x: 56, y: 19))
        }
        let sprout = make { p in
            p.move(to: CGPoint(x: 53, y: 75))
            p.addLine(to: CGPoint(x: 53, y: 43))
            p.addCurve(to: CGPoint(x: 35, y: 34),
                       control1: CGPoint(x: 47, y: 35),
                       control2: CGPoint(x: 40, y: 32))
            p.addCurve(to: CGPoint(x: 53, y: 52),
                       control1: CGPoint(x: 35, y: 44),
                       control2: CGPoint(x: 42, y: 51))
            p.move(to: CGPoint(x: 53, y: 48))
            p.addCurve(to: CGPoint(x: 72, y: 36),
                       control1: CGPoint(x: 59, y: 39),
                       control2: CGPoint(x: 66, y: 35))
            p.addCurve(to: CGPoint(x: 53, y: 57),
                       control1: CGPoint(x: 73, y: 48),
                       control2: CGPoint(x: 66, y: 56))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 42, y: 79))
            p.addCurve(to: CGPoint(x: 64, y: 79),
                       control1: CGPoint(x: 48, y: 74),
                       control2: CGPoint(x: 58, y: 74))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 53, y: 61), radius: 4.5) }
        return RPGSymbolArtwork(primary: crescent, detail: combined(sprout, detail),
                                accentFill: accentFill, compact: combined(crescent, sprout),
                                opticalScale: 0.91)
    }

    // MARK: Character classes

    /// Strength + Size — a greatsword whose crossguard carries visible plates.
    private static func classWarriorArtwork() -> RPGSymbolArtwork {
        let blade = make { p in
            p.move(to: CGPoint(x: 50, y: 8))
            p.addLine(to: CGPoint(x: 59, y: 48))
            p.addLine(to: CGPoint(x: 50, y: 60))
            p.addLine(to: CGPoint(x: 41, y: 48))
            p.closeSubpath()
            p.move(to: CGPoint(x: 50, y: 60))
            p.addLine(to: CGPoint(x: 50, y: 88))
            diamond(&p, center: CGPoint(x: 50, y: 91), radius: 5)
        }
        let loadedGuard = make { p in
            p.move(to: CGPoint(x: 21, y: 60))
            p.addLine(to: CGPoint(x: 79, y: 60))
            p.move(to: CGPoint(x: 20, y: 49))
            p.addLine(to: CGPoint(x: 20, y: 71))
            p.move(to: CGPoint(x: 29, y: 45))
            p.addLine(to: CGPoint(x: 29, y: 75))
            p.move(to: CGPoint(x: 71, y: 45))
            p.addLine(to: CGPoint(x: 71, y: 75))
            p.move(to: CGPoint(x: 80, y: 49))
            p.addLine(to: CGPoint(x: 80, y: 71))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 46, y: 29))
            p.addLine(to: CGPoint(x: 54, y: 29))
            p.move(to: CGPoint(x: 36, y: 54))
            p.addLine(to: CGPoint(x: 64, y: 54))
        }
        return RPGSymbolArtwork(primary: combined(blade, loadedGuard), detail: detail,
                                compact: combined(blade, loadedGuard), opticalScale: 0.88)
    }

    /// Strength + Dexterity — a slim rapier held inside a taut bow.
    private static func classDuelistArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 25, y: 13))
            p.addCurve(to: CGPoint(x: 61, y: 50),
                       control1: CGPoint(x: 43, y: 19),
                       control2: CGPoint(x: 55, y: 35))
            p.addCurve(to: CGPoint(x: 25, y: 87),
                       control1: CGPoint(x: 55, y: 65),
                       control2: CGPoint(x: 43, y: 81))
            p.move(to: CGPoint(x: 25, y: 13))
            p.addLine(to: CGPoint(x: 61, y: 50))
            p.addLine(to: CGPoint(x: 25, y: 87))
            p.move(to: CGPoint(x: 30, y: 82))
            p.addLine(to: CGPoint(x: 74, y: 20))
            p.addLine(to: CGPoint(x: 79, y: 12))
            p.addLine(to: CGPoint(x: 76, y: 26))
            p.addLine(to: CGPoint(x: 36, y: 86))
            p.move(to: CGPoint(x: 24, y: 72))
            p.addLine(to: CGPoint(x: 43, y: 85))
        }
        let detail = make { p in
            p.addEllipse(in: CGRect(x: 30, y: 71, width: 15, height: 15))
            p.move(to: CGPoint(x: 17, y: 50))
            p.addLine(to: CGPoint(x: 86, y: 50))
            p.move(to: CGPoint(x: 86, y: 50))
            p.addLine(to: CGPoint(x: 77, y: 43))
            p.move(to: CGPoint(x: 86, y: 50))
            p.addLine(to: CGPoint(x: 77, y: 57))
        }
        let compact = combined(primary, make { p in
            p.move(to: CGPoint(x: 18, y: 50))
            p.addLine(to: CGPoint(x: 85, y: 50))
        })
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: compact,
                                opticalScale: 0.89, opticalOffset: CGSize(width: 1, height: 0))
    }

    /// Strength + Agility — a split axe head wrapped around a lightning rail.
    private static func classBerserkerArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 48, y: 24))
            p.addLine(to: CGPoint(x: 27, y: 12))
            p.addLine(to: CGPoint(x: 10, y: 31))
            p.addLine(to: CGPoint(x: 31, y: 50))
            p.addLine(to: CGPoint(x: 47, y: 40))
            p.move(to: CGPoint(x: 52, y: 24))
            p.addLine(to: CGPoint(x: 73, y: 12))
            p.addLine(to: CGPoint(x: 90, y: 31))
            p.addLine(to: CGPoint(x: 69, y: 50))
            p.addLine(to: CGPoint(x: 53, y: 40))
            p.move(to: CGPoint(x: 50, y: 37))
            p.addLine(to: CGPoint(x: 50, y: 88))
            p.move(to: CGPoint(x: 41, y: 88))
            p.addLine(to: CGPoint(x: 59, y: 88))
        }
        let lightning = make { p in
            p.move(to: CGPoint(x: 59, y: 18))
            p.addLine(to: CGPoint(x: 44, y: 49))
            p.addLine(to: CGPoint(x: 57, y: 49))
            p.addLine(to: CGPoint(x: 42, y: 78))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 20, y: 30))
            p.addLine(to: CGPoint(x: 34, y: 39))
            p.move(to: CGPoint(x: 80, y: 30))
            p.addLine(to: CGPoint(x: 66, y: 39))
        }
        return RPGSymbolArtwork(primary: primary, detail: combined(detail, lightning),
                                compact: combined(primary, lightning), opticalScale: 0.89)
    }

    /// Strength + Vitality — a leaf-guarded sun blade inside a protective seal.
    private static func classPaladinArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 50, y: 8))
            p.addLine(to: CGPoint(x: 58, y: 50))
            p.addLine(to: CGPoint(x: 50, y: 61))
            p.addLine(to: CGPoint(x: 42, y: 50))
            p.closeSubpath()
            p.move(to: CGPoint(x: 50, y: 61))
            p.addLine(to: CGPoint(x: 50, y: 89))
            p.move(to: CGPoint(x: 21, y: 55))
            p.addLine(to: CGPoint(x: 79, y: 55))
            p.move(to: CGPoint(x: 18, y: 24))
            p.addLine(to: CGPoint(x: 18, y: 14))
            p.addLine(to: CGPoint(x: 28, y: 14))
            p.move(to: CGPoint(x: 72, y: 14))
            p.addLine(to: CGPoint(x: 82, y: 14))
            p.addLine(to: CGPoint(x: 82, y: 24))
        }
        let detail = make { p in
            p.addEllipse(in: CGRect(x: 29, y: 29, width: 42, height: 42))
            p.move(to: CGPoint(x: 28, y: 55))
            p.addCurve(to: CGPoint(x: 45, y: 69),
                       control1: CGPoint(x: 29, y: 65),
                       control2: CGPoint(x: 37, y: 69))
            p.move(to: CGPoint(x: 72, y: 55))
            p.addCurve(to: CGPoint(x: 55, y: 69),
                       control1: CGPoint(x: 71, y: 65),
                       control2: CGPoint(x: 63, y: 69))
            fourPointStar(&p, center: CGPoint(x: 50, y: 33), long: 9, short: 3)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 55), radius: 4.5) }
        let compact = combined(primary, make { p in
            p.addEllipse(in: CGRect(x: 30, y: 30, width: 40, height: 40))
        })
        return RPGSymbolArtwork(primary: primary, detail: detail, accentFill: accentFill,
                                compact: compact, opticalScale: 0.88)
    }

    /// Dexterity + Agility — a downward precision blade beneath an angular hood.
    private static func classAssassinArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 50, y: 11))
            p.addLine(to: CGPoint(x: 24, y: 28))
            p.addLine(to: CGPoint(x: 15, y: 62))
            p.addLine(to: CGPoint(x: 38, y: 54))
            p.addLine(to: CGPoint(x: 50, y: 71))
            p.addLine(to: CGPoint(x: 62, y: 54))
            p.addLine(to: CGPoint(x: 85, y: 62))
            p.addLine(to: CGPoint(x: 76, y: 28))
            p.closeSubpath()
            p.move(to: CGPoint(x: 50, y: 40))
            p.addLine(to: CGPoint(x: 50, y: 90))
            p.move(to: CGPoint(x: 50, y: 90))
            p.addLine(to: CGPoint(x: 42, y: 75))
            p.move(to: CGPoint(x: 50, y: 90))
            p.addLine(to: CGPoint(x: 58, y: 75))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 31, y: 41))
            p.addLine(to: CGPoint(x: 43, y: 46))
            p.move(to: CGPoint(x: 69, y: 41))
            p.addLine(to: CGPoint(x: 57, y: 46))
            p.move(to: CGPoint(x: 13, y: 72))
            p.addLine(to: CGPoint(x: 29, y: 68))
            p.move(to: CGPoint(x: 10, y: 82))
            p.addLine(to: CGPoint(x: 31, y: 76))
        }
        let compact = combined(primary, make { p in
            p.move(to: CGPoint(x: 12, y: 74))
            p.addLine(to: CGPoint(x: 31, y: 69))
        })
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: compact,
                                opticalScale: 0.89)
    }

    /// Dexterity + Vitality — paired training rings resolving into a lotus.
    private static func classMonkArtwork() -> RPGSymbolArtwork {
        let rings = make { p in
            p.addEllipse(in: CGRect(x: 17, y: 13, width: 30, height: 30))
            p.addEllipse(in: CGRect(x: 53, y: 13, width: 30, height: 30))
            p.move(to: CGPoint(x: 32, y: 43))
            p.addLine(to: CGPoint(x: 42, y: 59))
            p.move(to: CGPoint(x: 68, y: 43))
            p.addLine(to: CGPoint(x: 58, y: 59))
        }
        let lotus = make { p in
            p.move(to: CGPoint(x: 50, y: 89))
            p.addCurve(to: CGPoint(x: 31, y: 61),
                       control1: CGPoint(x: 37, y: 83),
                       control2: CGPoint(x: 30, y: 73))
            p.addCurve(to: CGPoint(x: 50, y: 76),
                       control1: CGPoint(x: 41, y: 61),
                       control2: CGPoint(x: 47, y: 67))
            p.addCurve(to: CGPoint(x: 69, y: 61),
                       control1: CGPoint(x: 53, y: 67),
                       control2: CGPoint(x: 59, y: 61))
            p.addCurve(to: CGPoint(x: 50, y: 89),
                       control1: CGPoint(x: 70, y: 73),
                       control2: CGPoint(x: 63, y: 83))
            p.move(to: CGPoint(x: 50, y: 76))
            p.addCurve(to: CGPoint(x: 50, y: 52),
                       control1: CGPoint(x: 40, y: 67),
                       control2: CGPoint(x: 43, y: 58))
            p.addCurve(to: CGPoint(x: 50, y: 76),
                       control1: CGPoint(x: 57, y: 58),
                       control2: CGPoint(x: 60, y: 67))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 24, y: 52))
            p.addLine(to: CGPoint(x: 36, y: 58))
            p.move(to: CGPoint(x: 76, y: 52))
            p.addLine(to: CGPoint(x: 64, y: 58))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 76), radius: 4) }
        return RPGSymbolArtwork(primary: combined(rings, lotus), detail: detail,
                                accentFill: accentFill, compact: combined(rings, lotus),
                                opticalScale: 0.88)
    }

    /// Endurance + Dexterity — a bow-shaped shield carrying one true arrow.
    private static func classRangerArtwork() -> RPGSymbolArtwork {
        let shield = make { p in
            p.move(to: CGPoint(x: 18, y: 18))
            p.addLine(to: CGPoint(x: 82, y: 18))
            p.addLine(to: CGPoint(x: 76, y: 61))
            p.addCurve(to: CGPoint(x: 50, y: 89),
                       control1: CGPoint(x: 71, y: 75),
                       control2: CGPoint(x: 61, y: 84))
            p.addCurve(to: CGPoint(x: 24, y: 61),
                       control1: CGPoint(x: 39, y: 84),
                       control2: CGPoint(x: 29, y: 75))
            p.closeSubpath()
        }
        let bowArrow = make { p in
            p.move(to: CGPoint(x: 30, y: 27))
            p.addCurve(to: CGPoint(x: 64, y: 53),
                       control1: CGPoint(x: 43, y: 30),
                       control2: CGPoint(x: 57, y: 40))
            p.addCurve(to: CGPoint(x: 36, y: 76),
                       control1: CGPoint(x: 56, y: 64),
                       control2: CGPoint(x: 46, y: 72))
            p.move(to: CGPoint(x: 30, y: 27))
            p.addLine(to: CGPoint(x: 64, y: 53))
            p.addLine(to: CGPoint(x: 36, y: 76))
            p.move(to: CGPoint(x: 27, y: 64))
            p.addLine(to: CGPoint(x: 75, y: 43))
            p.move(to: CGPoint(x: 75, y: 43))
            p.addLine(to: CGPoint(x: 66, y: 41))
            p.move(to: CGPoint(x: 75, y: 43))
            p.addLine(to: CGPoint(x: 70, y: 51))
        }
        return RPGSymbolArtwork(primary: shield, detail: bowArrow,
                                compact: combined(shield, bowArrow), opticalScale: 0.88)
    }

    /// Agility + Endurance — a route arrow with a wing and waypoint diamond.
    private static func classScoutArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 18, y: 79))
            p.addLine(to: CGPoint(x: 45, y: 52))
            p.addLine(to: CGPoint(x: 45, y: 34))
            p.addLine(to: CGPoint(x: 76, y: 16))
            p.addLine(to: CGPoint(x: 84, y: 24))
            p.addLine(to: CGPoint(x: 66, y: 55))
            p.addLine(to: CGPoint(x: 50, y: 55))
            p.addLine(to: CGPoint(x: 25, y: 86))
            p.closeSubpath()
            p.move(to: CGPoint(x: 43, y: 51))
            p.addLine(to: CGPoint(x: 21, y: 42))
            p.addLine(to: CGPoint(x: 31, y: 57))
            p.addLine(to: CGPoint(x: 13, y: 55))
            p.addLine(to: CGPoint(x: 25, y: 69))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 14, y: 30))
            p.addLine(to: CGPoint(x: 35, y: 38))
            p.move(to: CGPoint(x: 9, y: 19))
            p.addLine(to: CGPoint(x: 38, y: 30))
            diamond(&p, center: CGPoint(x: 82, y: 55), radius: 6)
            p.move(to: CGPoint(x: 82, y: 61))
            p.addLine(to: CGPoint(x: 82, y: 76))
        }
        let compact = combined(primary, make { p in
            diamond(&p, center: CGPoint(x: 82, y: 55), radius: 5)
        })
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: compact,
                                opticalScale: 0.88, opticalOffset: CGSize(width: 0, height: 1))
    }

    /// Size + Vitality — a crenellated tower whose foundation becomes roots.
    private static func classTankArtwork() -> RPGSymbolArtwork {
        let tower = make { p in
            p.move(to: CGPoint(x: 19, y: 16))
            p.addLine(to: CGPoint(x: 33, y: 16))
            p.addLine(to: CGPoint(x: 33, y: 28))
            p.addLine(to: CGPoint(x: 43, y: 28))
            p.addLine(to: CGPoint(x: 43, y: 16))
            p.addLine(to: CGPoint(x: 57, y: 16))
            p.addLine(to: CGPoint(x: 57, y: 28))
            p.addLine(to: CGPoint(x: 67, y: 28))
            p.addLine(to: CGPoint(x: 67, y: 16))
            p.addLine(to: CGPoint(x: 81, y: 16))
            p.addLine(to: CGPoint(x: 75, y: 74))
            p.addLine(to: CGPoint(x: 50, y: 89))
            p.addLine(to: CGPoint(x: 25, y: 74))
            p.closeSubpath()
        }
        let roots = make { p in
            p.move(to: CGPoint(x: 50, y: 84))
            p.addCurve(to: CGPoint(x: 29, y: 66),
                       control1: CGPoint(x: 39, y: 84),
                       control2: CGPoint(x: 31, y: 77))
            p.addCurve(to: CGPoint(x: 50, y: 75),
                       control1: CGPoint(x: 39, y: 65),
                       control2: CGPoint(x: 46, y: 69))
            p.addCurve(to: CGPoint(x: 71, y: 66),
                       control1: CGPoint(x: 54, y: 69),
                       control2: CGPoint(x: 61, y: 65))
            p.addCurve(to: CGPoint(x: 50, y: 84),
                       control1: CGPoint(x: 69, y: 77),
                       control2: CGPoint(x: 61, y: 84))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 32, y: 43))
            p.addLine(to: CGPoint(x: 68, y: 43))
            p.move(to: CGPoint(x: 29, y: 56))
            p.addLine(to: CGPoint(x: 71, y: 56))
            p.addRoundedRect(in: CGRect(x: 43, y: 39, width: 14, height: 27),
                             cornerSize: CGSize(width: 5, height: 5))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 70), radius: 4.5) }
        return RPGSymbolArtwork(primary: tower, detail: combined(detail, roots),
                                accentFill: accentFill, compact: combined(tower, roots),
                                opticalScale: 0.89)
    }

    /// Size + Dexterity — an armored fist with a row of plate-like knuckles.
    private static func classBrawlerArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 20, y: 25))
            p.addRoundedRect(in: CGRect(x: 20, y: 18, width: 16, height: 28),
                             cornerSize: CGSize(width: 5, height: 5))
            p.addRoundedRect(in: CGRect(x: 36, y: 13, width: 16, height: 31),
                             cornerSize: CGSize(width: 5, height: 5))
            p.addRoundedRect(in: CGRect(x: 52, y: 15, width: 16, height: 30),
                             cornerSize: CGSize(width: 5, height: 5))
            p.addRoundedRect(in: CGRect(x: 68, y: 22, width: 14, height: 27),
                             cornerSize: CGSize(width: 5, height: 5))
            p.move(to: CGPoint(x: 22, y: 43))
            p.addLine(to: CGPoint(x: 22, y: 66))
            p.addCurve(to: CGPoint(x: 48, y: 89),
                       control1: CGPoint(x: 24, y: 79),
                       control2: CGPoint(x: 36, y: 88))
            p.addLine(to: CGPoint(x: 70, y: 85))
            p.addLine(to: CGPoint(x: 80, y: 59))
            p.addLine(to: CGPoint(x: 66, y: 48))
            p.addLine(to: CGPoint(x: 47, y: 55))
            p.addLine(to: CGPoint(x: 38, y: 45))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 29, y: 53))
            p.addLine(to: CGPoint(x: 45, y: 69))
            p.addLine(to: CGPoint(x: 66, y: 61))
            p.move(to: CGPoint(x: 27, y: 73))
            p.addLine(to: CGPoint(x: 66, y: 82))
            p.move(to: CGPoint(x: 29, y: 24))
            p.addLine(to: CGPoint(x: 29, y: 39))
            p.move(to: CGPoint(x: 44, y: 20))
            p.addLine(to: CGPoint(x: 44, y: 38))
            p.move(to: CGPoint(x: 60, y: 21))
            p.addLine(to: CGPoint(x: 60, y: 39))
            p.move(to: CGPoint(x: 75, y: 28))
            p.addLine(to: CGPoint(x: 75, y: 43))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: primary,
                                opticalScale: 0.88, opticalOffset: CGSize(width: 0, height: 1))
    }

    /// Size + Agility — a stepped mountain cleaved by one lightning stroke.
    private static func classTitanArtwork() -> RPGSymbolArtwork {
        let mountain = make { p in
            p.move(to: CGPoint(x: 8, y: 85))
            p.addLine(to: CGPoint(x: 26, y: 61))
            p.addLine(to: CGPoint(x: 37, y: 69))
            p.addLine(to: CGPoint(x: 55, y: 24))
            p.addLine(to: CGPoint(x: 66, y: 53))
            p.addLine(to: CGPoint(x: 76, y: 44))
            p.addLine(to: CGPoint(x: 92, y: 85))
            p.closeSubpath()
        }
        let lightning = make { p in
            p.move(to: CGPoint(x: 68, y: 8))
            p.addLine(to: CGPoint(x: 49, y: 45))
            p.addLine(to: CGPoint(x: 62, y: 45))
            p.addLine(to: CGPoint(x: 43, y: 82))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 18, y: 85))
            p.addLine(to: CGPoint(x: 31, y: 69))
            p.addLine(to: CGPoint(x: 41, y: 77))
            p.move(to: CGPoint(x: 65, y: 66))
            p.addLine(to: CGPoint(x: 76, y: 58))
            p.addLine(to: CGPoint(x: 85, y: 85))
            p.move(to: CGPoint(x: 15, y: 91))
            p.addLine(to: CGPoint(x: 85, y: 91))
        }
        return RPGSymbolArtwork(primary: mountain, detail: combined(detail, lightning),
                                compact: combined(mountain, lightning),
                                opticalScale: 0.89, opticalOffset: CGSize(width: 0, height: -1))
    }

    /// Size + Endurance — a horned fortress shield with heavy armor courses.
    private static func classJuggernautArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 24, y: 27))
            p.addCurve(to: CGPoint(x: 8, y: 11),
                       control1: CGPoint(x: 16, y: 25),
                       control2: CGPoint(x: 10, y: 19))
            p.addCurve(to: CGPoint(x: 34, y: 25),
                       control1: CGPoint(x: 14, y: 12),
                       control2: CGPoint(x: 24, y: 16))
            p.move(to: CGPoint(x: 76, y: 27))
            p.addCurve(to: CGPoint(x: 92, y: 11),
                       control1: CGPoint(x: 84, y: 25),
                       control2: CGPoint(x: 90, y: 19))
            p.addCurve(to: CGPoint(x: 66, y: 25),
                       control1: CGPoint(x: 86, y: 12),
                       control2: CGPoint(x: 76, y: 16))
            p.move(to: CGPoint(x: 21, y: 24))
            p.addLine(to: CGPoint(x: 79, y: 24))
            p.addLine(to: CGPoint(x: 75, y: 67))
            p.addCurve(to: CGPoint(x: 50, y: 91),
                       control1: CGPoint(x: 70, y: 79),
                       control2: CGPoint(x: 60, y: 87))
            p.addCurve(to: CGPoint(x: 25, y: 67),
                       control1: CGPoint(x: 40, y: 87),
                       control2: CGPoint(x: 30, y: 79))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 26, y: 41))
            p.addLine(to: CGPoint(x: 74, y: 41))
            p.move(to: CGPoint(x: 28, y: 56))
            p.addLine(to: CGPoint(x: 72, y: 56))
            p.move(to: CGPoint(x: 34, y: 70))
            p.addLine(to: CGPoint(x: 66, y: 70))
            diamond(&p, center: CGPoint(x: 50, y: 55), radius: 7)
        }
        let compact = combined(primary, make { p in
            p.move(to: CGPoint(x: 27, y: 47))
            p.addLine(to: CGPoint(x: 73, y: 47))
            p.move(to: CGPoint(x: 31, y: 63))
            p.addLine(to: CGPoint(x: 69, y: 63))
        })
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: compact,
                                opticalScale: 0.88)
    }

    /// Strength + Endurance — a centered spear through a round shield.
    private static func classSpartanArtwork() -> RPGSymbolArtwork {
        let shield = make { p in
            p.addEllipse(in: CGRect(x: 17, y: 20, width: 66, height: 66))
            p.addEllipse(in: CGRect(x: 27, y: 30, width: 46, height: 46))
        }
        let spear = make { p in
            p.move(to: CGPoint(x: 50, y: 7))
            p.addLine(to: CGPoint(x: 58, y: 23))
            p.addLine(to: CGPoint(x: 52, y: 27))
            p.addLine(to: CGPoint(x: 52, y: 93))
            p.move(to: CGPoint(x: 48, y: 27))
            p.addLine(to: CGPoint(x: 48, y: 93))
            p.move(to: CGPoint(x: 41, y: 93))
            p.addLine(to: CGPoint(x: 59, y: 93))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 30, y: 28))
            p.addCurve(to: CGPoint(x: 70, y: 28),
                       control1: CGPoint(x: 40, y: 12),
                       control2: CGPoint(x: 60, y: 12))
            p.move(to: CGPoint(x: 34, y: 57))
            p.addLine(to: CGPoint(x: 43, y: 47))
            p.addLine(to: CGPoint(x: 43, y: 68))
        }
        return RPGSymbolArtwork(primary: combined(shield, spear), detail: detail,
                                compact: combined(shield, spear), opticalScale: 0.88)
    }

    /// Agility + Vitality — a wind crescent cradling a three-leaf sprout.
    private static func classDruidArtwork() -> RPGSymbolArtwork {
        let crescent = make { p in
            p.move(to: CGPoint(x: 72, y: 12))
            p.addCurve(to: CGPoint(x: 20, y: 29),
                       control1: CGPoint(x: 49, y: 11),
                       control2: CGPoint(x: 29, y: 18))
            p.addCurve(to: CGPoint(x: 19, y: 72),
                       control1: CGPoint(x: 11, y: 42),
                       control2: CGPoint(x: 11, y: 61))
            p.addCurve(to: CGPoint(x: 72, y: 88),
                       control1: CGPoint(x: 30, y: 87),
                       control2: CGPoint(x: 52, y: 92))
            p.addCurve(to: CGPoint(x: 42, y: 67),
                       control1: CGPoint(x: 54, y: 81),
                       control2: CGPoint(x: 46, y: 74))
            p.addCurve(to: CGPoint(x: 43, y: 33),
                       control1: CGPoint(x: 34, y: 56),
                       control2: CGPoint(x: 35, y: 43))
            p.addCurve(to: CGPoint(x: 72, y: 12),
                       control1: CGPoint(x: 50, y: 23),
                       control2: CGPoint(x: 59, y: 17))
        }
        let sprout = make { p in
            p.move(to: CGPoint(x: 55, y: 76))
            p.addLine(to: CGPoint(x: 55, y: 43))
            p.addCurve(to: CGPoint(x: 37, y: 35),
                       control1: CGPoint(x: 48, y: 36),
                       control2: CGPoint(x: 42, y: 34))
            p.addCurve(to: CGPoint(x: 55, y: 53),
                       control1: CGPoint(x: 37, y: 46),
                       control2: CGPoint(x: 44, y: 52))
            p.move(to: CGPoint(x: 55, y: 48))
            p.addCurve(to: CGPoint(x: 74, y: 37),
                       control1: CGPoint(x: 61, y: 40),
                       control2: CGPoint(x: 68, y: 36))
            p.addCurve(to: CGPoint(x: 55, y: 58),
                       control1: CGPoint(x: 75, y: 49),
                       control2: CGPoint(x: 67, y: 57))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 11, y: 79))
            p.addLine(to: CGPoint(x: 30, y: 79))
            p.move(to: CGPoint(x: 14, y: 89))
            p.addLine(to: CGPoint(x: 38, y: 89))
            fourPointStar(&p, center: CGPoint(x: 82, y: 24), long: 7, short: 2.5)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 55, y: 61), radius: 4.5) }
        return RPGSymbolArtwork(primary: crescent, detail: combined(sprout, detail),
                                accentFill: accentFill, compact: combined(crescent, sprout),
                                opticalScale: 0.89)
    }

    /// Endurance + Vitality — a heart shield carrying a living staff and pulse.
    private static func classHealerArtwork() -> RPGSymbolArtwork {
        let heart = make { p in
            p.move(to: CGPoint(x: 50, y: 90))
            p.addCurve(to: CGPoint(x: 15, y: 47),
                       control1: CGPoint(x: 37, y: 77),
                       control2: CGPoint(x: 15, y: 64))
            p.addCurve(to: CGPoint(x: 33, y: 17),
                       control1: CGPoint(x: 15, y: 29),
                       control2: CGPoint(x: 25, y: 17))
            p.addCurve(to: CGPoint(x: 50, y: 31),
                       control1: CGPoint(x: 42, y: 17),
                       control2: CGPoint(x: 47, y: 25))
            p.addCurve(to: CGPoint(x: 67, y: 17),
                       control1: CGPoint(x: 53, y: 25),
                       control2: CGPoint(x: 58, y: 17))
            p.addCurve(to: CGPoint(x: 85, y: 47),
                       control1: CGPoint(x: 75, y: 17),
                       control2: CGPoint(x: 85, y: 29))
            p.addCurve(to: CGPoint(x: 50, y: 90),
                       control1: CGPoint(x: 85, y: 64),
                       control2: CGPoint(x: 63, y: 77))
            p.closeSubpath()
        }
        let staff = make { p in
            p.move(to: CGPoint(x: 50, y: 78))
            p.addLine(to: CGPoint(x: 50, y: 34))
            p.move(to: CGPoint(x: 37, y: 48))
            p.addLine(to: CGPoint(x: 63, y: 48))
            p.move(to: CGPoint(x: 50, y: 42))
            p.addCurve(to: CGPoint(x: 36, y: 31),
                       control1: CGPoint(x: 45, y: 34),
                       control2: CGPoint(x: 40, y: 31))
            p.addCurve(to: CGPoint(x: 50, y: 50),
                       control1: CGPoint(x: 36, y: 41),
                       control2: CGPoint(x: 42, y: 47))
            p.move(to: CGPoint(x: 50, y: 42))
            p.addCurve(to: CGPoint(x: 64, y: 31),
                       control1: CGPoint(x: 55, y: 34),
                       control2: CGPoint(x: 60, y: 31))
            p.addCurve(to: CGPoint(x: 50, y: 50),
                       control1: CGPoint(x: 64, y: 41),
                       control2: CGPoint(x: 58, y: 47))
        }
        let pulse = make { p in
            p.move(to: CGPoint(x: 23, y: 62))
            p.addLine(to: CGPoint(x: 35, y: 62))
            p.addLine(to: CGPoint(x: 41, y: 54))
            p.addLine(to: CGPoint(x: 48, y: 70))
            p.addLine(to: CGPoint(x: 57, y: 58))
            p.addLine(to: CGPoint(x: 65, y: 62))
            p.addLine(to: CGPoint(x: 77, y: 62))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 48), radius: 4) }
        return RPGSymbolArtwork(primary: heart, detail: combined(staff, pulse),
                                accentFill: accentFill, compact: combined(heart, staff),
                                opticalScale: 0.88)
    }

    // MARK: Training focuses

    /// Crossed sword and loaded handle: strength as practiced, not abstracted.
    private static func focusStrengthArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 19, y: 81))
            p.addLine(to: CGPoint(x: 70, y: 30))
            p.addLine(to: CGPoint(x: 82, y: 18))
            p.addLine(to: CGPoint(x: 77, y: 35))
            p.addLine(to: CGPoint(x: 27, y: 85))
            p.move(to: CGPoint(x: 30, y: 27))
            p.addLine(to: CGPoint(x: 79, y: 76))
            p.move(to: CGPoint(x: 21, y: 34))
            p.addLine(to: CGPoint(x: 35, y: 20))
            p.move(to: CGPoint(x: 17, y: 26))
            p.addLine(to: CGPoint(x: 29, y: 14))
            p.move(to: CGPoint(x: 71, y: 86))
            p.addLine(to: CGPoint(x: 86, y: 71))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 15, y: 68))
            p.addLine(to: CGPoint(x: 32, y: 85))
            p.move(to: CGPoint(x: 65, y: 76))
            p.addLine(to: CGPoint(x: 78, y: 63))
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 6)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 3.5) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: legacy(.sword),
                                opticalScale: 0.89)
    }

    /// An ornate barbell with outward rails conveys growth and accumulated load.
    private static func focusHypertrophyArtwork() -> RPGSymbolArtwork {
        var art = trainingArtwork()
        let accent = make { p in
            p.move(to: CGPoint(x: 32, y: 29))
            p.addLine(to: CGPoint(x: 22, y: 19))
            p.move(to: CGPoint(x: 22, y: 19))
            p.addLine(to: CGPoint(x: 22, y: 27))
            p.move(to: CGPoint(x: 22, y: 19))
            p.addLine(to: CGPoint(x: 30, y: 19))
            p.move(to: CGPoint(x: 68, y: 29))
            p.addLine(to: CGPoint(x: 78, y: 19))
            p.move(to: CGPoint(x: 78, y: 19))
            p.addLine(to: CGPoint(x: 70, y: 19))
            p.move(to: CGPoint(x: 78, y: 19))
            p.addLine(to: CGPoint(x: 78, y: 27))
        }
        art = RPGSymbolArtwork(primary: art.primary, detail: art.detail,
                               accent: accent, accentFill: art.accentFill,
                               compact: legacy(.dumbbell), opticalScale: art.opticalScale,
                               opticalOffset: art.opticalOffset)
        return art
    }

    /// A controlled athlete suspended between rings.
    private static func focusBodyweightArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.addEllipse(in: CGRect(x: 13, y: 14, width: 20, height: 20))
            p.addEllipse(in: CGRect(x: 67, y: 14, width: 20, height: 20))
            p.move(to: CGPoint(x: 23, y: 34))
            p.addLine(to: CGPoint(x: 23, y: 50))
            p.move(to: CGPoint(x: 77, y: 34))
            p.addLine(to: CGPoint(x: 77, y: 50))
            p.addEllipse(in: CGRect(x: 43, y: 25, width: 14, height: 14))
            p.move(to: CGPoint(x: 50, y: 40))
            p.addLine(to: CGPoint(x: 50, y: 66))
            p.move(to: CGPoint(x: 50, y: 45))
            p.addLine(to: CGPoint(x: 25, y: 50))
            p.move(to: CGPoint(x: 50, y: 45))
            p.addLine(to: CGPoint(x: 75, y: 50))
            p.move(to: CGPoint(x: 50, y: 66))
            p.addLine(to: CGPoint(x: 34, y: 86))
            p.move(to: CGPoint(x: 50, y: 66))
            p.addLine(to: CGPoint(x: 66, y: 86))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 39, y: 57))
            p.addLine(to: CGPoint(x: 61, y: 57))
            diamond(&p, center: CGPoint(x: 50, y: 66), radius: 5)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 66), radius: 3) }
        let compact = make { p in
            p.addEllipse(in: CGRect(x: 42, y: 19, width: 16, height: 16))
            p.move(to: CGPoint(x: 50, y: 37))
            p.addLine(to: CGPoint(x: 50, y: 66))
            p.move(to: CGPoint(x: 50, y: 45))
            p.addLine(to: CGPoint(x: 22, y: 35))
            p.move(to: CGPoint(x: 50, y: 45))
            p.addLine(to: CGPoint(x: 78, y: 35))
            p.move(to: CGPoint(x: 50, y: 66))
            p.addLine(to: CGPoint(x: 32, y: 86))
            p.move(to: CGPoint(x: 50, y: 66))
            p.addLine(to: CGPoint(x: 68, y: 86))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.91)
    }

    /// A faceted runner with speed rails, matching the angular fantasy language.
    private static func focusExplosiveArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            diamond(&p, center: CGPoint(x: 75, y: 19), radius: 7)
            p.move(to: CGPoint(x: 66, y: 29))
            p.addLine(to: CGPoint(x: 52, y: 42))
            p.addLine(to: CGPoint(x: 65, y: 54))
            p.addLine(to: CGPoint(x: 84, y: 43))
            p.move(to: CGPoint(x: 52, y: 42))
            p.addLine(to: CGPoint(x: 37, y: 59))
            p.addLine(to: CGPoint(x: 18, y: 82))
            p.move(to: CGPoint(x: 64, y: 54))
            p.addLine(to: CGPoint(x: 48, y: 68))
            p.addLine(to: CGPoint(x: 67, y: 86))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 46, y: 35))
            p.addLine(to: CGPoint(x: 20, y: 35))
            p.move(to: CGPoint(x: 38, y: 47))
            p.addLine(to: CGPoint(x: 12, y: 47))
            p.move(to: CGPoint(x: 30, y: 59))
            p.addLine(to: CGPoint(x: 8, y: 59))
        }
        let accent = make { p in
            p.move(to: CGPoint(x: 44, y: 67))
            p.addLine(to: CGPoint(x: 32, y: 81))
            p.move(to: CGPoint(x: 59, y: 61))
            p.addLine(to: CGPoint(x: 72, y: 74))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 75, y: 19), radius: 3.5) }
        return RPGSymbolArtwork(primary: primary, detail: detail, accent: accent,
                                accentFill: accentFill, compact: legacy(.wing),
                                opticalScale: 0.91, opticalOffset: CGSize(width: 1, height: 0))
    }

    /// A heart-shaped endurance rail with a central pulse and route point.
    private static func focusEnduranceArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 50, y: 85))
            p.addCurve(to: CGPoint(x: 14, y: 43),
                       control1: CGPoint(x: 31, y: 69),
                       control2: CGPoint(x: 14, y: 58))
            p.addCurve(to: CGPoint(x: 50, y: 27),
                       control1: CGPoint(x: 14, y: 20),
                       control2: CGPoint(x: 40, y: 16))
            p.addCurve(to: CGPoint(x: 86, y: 43),
                       control1: CGPoint(x: 60, y: 16),
                       control2: CGPoint(x: 86, y: 20))
            p.addCurve(to: CGPoint(x: 50, y: 85),
                       control1: CGPoint(x: 86, y: 58),
                       control2: CGPoint(x: 69, y: 69))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 23, y: 51))
            p.addLine(to: CGPoint(x: 37, y: 51))
            p.addLine(to: CGPoint(x: 44, y: 38))
            p.addLine(to: CGPoint(x: 55, y: 65))
            p.addLine(to: CGPoint(x: 63, y: 51))
            p.addLine(to: CGPoint(x: 77, y: 51))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 51), radius: 4) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: legacy(.shield),
                                opticalScale: 0.92)
    }

    /// A circular recovery path surrounding a new sprout.
    private static func focusMobilityArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 63, y: 15))
            p.addCurve(to: CGPoint(x: 20, y: 71),
                       control1: CGPoint(x: 25, y: 16),
                       control2: CGPoint(x: 10, y: 43))
            p.addCurve(to: CGPoint(x: 75, y: 78),
                       control1: CGPoint(x: 35, y: 93),
                       control2: CGPoint(x: 61, y: 90))
            p.move(to: CGPoint(x: 68, y: 14))
            p.addLine(to: CGPoint(x: 79, y: 18))
            p.addLine(to: CGPoint(x: 72, y: 28))
            p.move(to: CGPoint(x: 37, y: 65))
            p.addLine(to: CGPoint(x: 50, y: 82))
            p.addLine(to: CGPoint(x: 63, y: 65))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 50, y: 72))
            p.addLine(to: CGPoint(x: 50, y: 44))
            p.addCurve(to: CGPoint(x: 34, y: 36),
                       control1: CGPoint(x: 43, y: 44),
                       control2: CGPoint(x: 36, y: 42))
            p.addCurve(to: CGPoint(x: 50, y: 51),
                       control1: CGPoint(x: 34, y: 46),
                       control2: CGPoint(x: 42, y: 51))
            p.addCurve(to: CGPoint(x: 66, y: 36),
                       control1: CGPoint(x: 58, y: 44),
                       control2: CGPoint(x: 64, y: 42))
            p.addCurve(to: CGPoint(x: 50, y: 51),
                       control1: CGPoint(x: 66, y: 46),
                       control2: CGPoint(x: 58, y: 51))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 44), radius: 3.5) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: legacy(.potion),
                                opticalScale: 0.91)
    }

    // MARK: Training measurements

    /// Two counted work rows: the repeated rails read as sets while their
    /// engraved notches read as reps, without borrowing an arithmetic glyph.
    private static func metricRepetitionsArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 17, y: 17))
            p.addLine(to: CGPoint(x: 83, y: 17))
            p.addLine(to: CGPoint(x: 83, y: 40))
            p.addLine(to: CGPoint(x: 17, y: 40))
            p.closeSubpath()
            p.move(to: CGPoint(x: 17, y: 60))
            p.addLine(to: CGPoint(x: 83, y: 60))
            p.addLine(to: CGPoint(x: 83, y: 83))
            p.addLine(to: CGPoint(x: 17, y: 83))
            p.closeSubpath()
        }
        let detail = make { p in
            for x in [CGFloat(34), 50, 66] {
                p.move(to: CGPoint(x: x, y: 23))
                p.addLine(to: CGPoint(x: x, y: 34))
                p.move(to: CGPoint(x: x, y: 66))
                p.addLine(to: CGPoint(x: x, y: 77))
            }
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 5)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 3) }
        let compact = make { p in
            p.move(to: CGPoint(x: 15, y: 16))
            p.addLine(to: CGPoint(x: 85, y: 16))
            p.addLine(to: CGPoint(x: 85, y: 41))
            p.addLine(to: CGPoint(x: 15, y: 41))
            p.closeSubpath()
            p.move(to: CGPoint(x: 15, y: 59))
            p.addLine(to: CGPoint(x: 85, y: 59))
            p.addLine(to: CGPoint(x: 85, y: 84))
            p.addLine(to: CGPoint(x: 15, y: 84))
            p.closeSubpath()
            p.move(to: CGPoint(x: 39, y: 22))
            p.addLine(to: CGPoint(x: 39, y: 35))
            p.move(to: CGPoint(x: 61, y: 22))
            p.addLine(to: CGPoint(x: 61, y: 35))
            p.move(to: CGPoint(x: 39, y: 65))
            p.addLine(to: CGPoint(x: 39, y: 78))
            p.move(to: CGPoint(x: 61, y: 65))
            p.addLine(to: CGPoint(x: 61, y: 78))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.89)
    }

    /// A balanced load scale keeps weight distinct from the training barbell
    /// and from Might's lightning-bolt reward currency.
    private static func metricLoadArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 14, y: 34))
            p.addLine(to: CGPoint(x: 86, y: 34))
            p.move(to: CGPoint(x: 50, y: 18))
            p.addLine(to: CGPoint(x: 50, y: 78))
            p.move(to: CGPoint(x: 35, y: 87))
            p.addLine(to: CGPoint(x: 65, y: 87))
            p.move(to: CGPoint(x: 24, y: 34))
            p.addLine(to: CGPoint(x: 24, y: 57))
            p.move(to: CGPoint(x: 76, y: 34))
            p.addLine(to: CGPoint(x: 76, y: 57))
            p.move(to: CGPoint(x: 10, y: 57))
            p.addCurve(to: CGPoint(x: 38, y: 57),
                       control1: CGPoint(x: 14, y: 72),
                       control2: CGPoint(x: 34, y: 72))
            p.move(to: CGPoint(x: 62, y: 57))
            p.addCurve(to: CGPoint(x: 90, y: 57),
                       control1: CGPoint(x: 66, y: 72),
                       control2: CGPoint(x: 86, y: 72))
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 34), radius: 8)
            p.move(to: CGPoint(x: 17, y: 52))
            p.addLine(to: CGPoint(x: 31, y: 52))
            p.move(to: CGPoint(x: 69, y: 52))
            p.addLine(to: CGPoint(x: 83, y: 52))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 34), radius: 3.5) }
        let compact = make { p in
            p.move(to: CGPoint(x: 12, y: 32))
            p.addLine(to: CGPoint(x: 88, y: 32))
            p.move(to: CGPoint(x: 50, y: 16))
            p.addLine(to: CGPoint(x: 50, y: 80))
            p.move(to: CGPoint(x: 33, y: 88))
            p.addLine(to: CGPoint(x: 67, y: 88))
            p.move(to: CGPoint(x: 24, y: 32))
            p.addLine(to: CGPoint(x: 24, y: 57))
            p.move(to: CGPoint(x: 76, y: 32))
            p.addLine(to: CGPoint(x: 76, y: 57))
            p.move(to: CGPoint(x: 9, y: 57))
            p.addCurve(to: CGPoint(x: 39, y: 57),
                       control1: CGPoint(x: 14, y: 73),
                       control2: CGPoint(x: 34, y: 73))
            p.move(to: CGPoint(x: 61, y: 57))
            p.addCurve(to: CGPoint(x: 91, y: 57),
                       control1: CGPoint(x: 66, y: 73),
                       control2: CGPoint(x: 86, y: 73))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    /// An angular hourglass makes elapsed work readable without introducing
    /// the circular-arrow language reserved for controls.
    private static func metricDurationArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 23, y: 12))
            p.addLine(to: CGPoint(x: 77, y: 12))
            p.move(to: CGPoint(x: 23, y: 88))
            p.addLine(to: CGPoint(x: 77, y: 88))
            p.move(to: CGPoint(x: 28, y: 13))
            p.addCurve(to: CGPoint(x: 43, y: 49),
                       control1: CGPoint(x: 29, y: 31),
                       control2: CGPoint(x: 39, y: 42))
            p.addCurve(to: CGPoint(x: 28, y: 87),
                       control1: CGPoint(x: 39, y: 57),
                       control2: CGPoint(x: 29, y: 68))
            p.move(to: CGPoint(x: 72, y: 13))
            p.addCurve(to: CGPoint(x: 57, y: 49),
                       control1: CGPoint(x: 71, y: 31),
                       control2: CGPoint(x: 61, y: 42))
            p.addCurve(to: CGPoint(x: 72, y: 87),
                       control1: CGPoint(x: 61, y: 57),
                       control2: CGPoint(x: 71, y: 68))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 35, y: 27))
            p.addLine(to: CGPoint(x: 65, y: 27))
            p.addLine(to: CGPoint(x: 50, y: 47))
            p.closeSubpath()
            p.move(to: CGPoint(x: 35, y: 77))
            p.addCurve(to: CGPoint(x: 65, y: 77),
                       control1: CGPoint(x: 42, y: 60),
                       control2: CGPoint(x: 58, y: 60))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 52), radius: 3.5) }
        let compact = make { p in
            p.move(to: CGPoint(x: 21, y: 11))
            p.addLine(to: CGPoint(x: 79, y: 11))
            p.move(to: CGPoint(x: 21, y: 89))
            p.addLine(to: CGPoint(x: 79, y: 89))
            p.move(to: CGPoint(x: 27, y: 13))
            p.addCurve(to: CGPoint(x: 43, y: 49),
                       control1: CGPoint(x: 28, y: 31),
                       control2: CGPoint(x: 39, y: 42))
            p.addCurve(to: CGPoint(x: 27, y: 87),
                       control1: CGPoint(x: 39, y: 57),
                       control2: CGPoint(x: 28, y: 69))
            p.move(to: CGPoint(x: 73, y: 13))
            p.addCurve(to: CGPoint(x: 57, y: 49),
                       control1: CGPoint(x: 72, y: 31),
                       control2: CGPoint(x: 61, y: 42))
            p.addCurve(to: CGPoint(x: 73, y: 87),
                       control1: CGPoint(x: 61, y: 57),
                       control2: CGPoint(x: 72, y: 69))
            p.move(to: CGPoint(x: 35, y: 76))
            p.addCurve(to: CGPoint(x: 65, y: 76),
                       control1: CGPoint(x: 42, y: 60),
                       control2: CGPoint(x: 58, y: 60))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.89)
    }

    /// A measured trail between two runestones represents distance as an
    /// achieved span, rather than as navigation or a map destination.
    private static func metricDistanceArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            diamond(&p, center: CGPoint(x: 19, y: 80), radius: 10)
            diamond(&p, center: CGPoint(x: 81, y: 20), radius: 10)
            p.move(to: CGPoint(x: 27, y: 73))
            p.addCurve(to: CGPoint(x: 73, y: 27),
                       control1: CGPoint(x: 76, y: 67),
                       control2: CGPoint(x: 24, y: 34))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 35, y: 61))
            p.addLine(to: CGPoint(x: 28, y: 54))
            p.move(to: CGPoint(x: 50, y: 51))
            p.addLine(to: CGPoint(x: 43, y: 44))
            p.move(to: CGPoint(x: 65, y: 39))
            p.addLine(to: CGPoint(x: 58, y: 32))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 4) }
        let compact = make { p in
            diamond(&p, center: CGPoint(x: 18, y: 81), radius: 10)
            diamond(&p, center: CGPoint(x: 82, y: 19), radius: 10)
            p.move(to: CGPoint(x: 26, y: 74))
            p.addCurve(to: CGPoint(x: 74, y: 26),
                       control1: CGPoint(x: 77, y: 68),
                       control2: CGPoint(x: 23, y: 33))
            p.move(to: CGPoint(x: 36, y: 61))
            p.addLine(to: CGPoint(x: 29, y: 54))
            p.move(to: CGPoint(x: 64, y: 39))
            p.addLine(to: CGPoint(x: 57, y: 32))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    // MARK: Training state

    /// A banked ember rests in an open ceremonial cradle beneath the tapered
    /// upper half of an hourglass. The broken lower silhouette separates rest
    /// from elapsed duration while remaining legible as recovery at 16 points.
    private static func restArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            // Heraldic canopy: time narrows toward a quiet central point.
            p.move(to: CGPoint(x: 21, y: 14))
            p.addLine(to: CGPoint(x: 79, y: 14))
            p.move(to: CGPoint(x: 27, y: 17))
            p.addLine(to: CGPoint(x: 31, y: 29))
            p.addLine(to: CGPoint(x: 44, y: 44))
            p.addLine(to: CGPoint(x: 50, y: 49))
            p.addLine(to: CGPoint(x: 56, y: 44))
            p.addLine(to: CGPoint(x: 69, y: 29))
            p.addLine(to: CGPoint(x: 73, y: 17))

            // An open cradle banks the ember rather than measuring it.
            p.move(to: CGPoint(x: 20, y: 64))
            p.addLine(to: CGPoint(x: 29, y: 76))
            p.addLine(to: CGPoint(x: 50, y: 85))
            p.addLine(to: CGPoint(x: 71, y: 76))
            p.addLine(to: CGPoint(x: 80, y: 64))
        }
        let detail = make { p in
            // A low flame: symmetrical enough to feel heraldic, asymmetric
            // enough to read as an ember rather than another sand chamber.
            p.move(to: CGPoint(x: 50, y: 45))
            p.addCurve(to: CGPoint(x: 63, y: 63),
                       control1: CGPoint(x: 61, y: 49),
                       control2: CGPoint(x: 65, y: 56))
            p.addCurve(to: CGPoint(x: 50, y: 76),
                       control1: CGPoint(x: 62, y: 71),
                       control2: CGPoint(x: 56, y: 76))
            p.addCurve(to: CGPoint(x: 37, y: 63),
                       control1: CGPoint(x: 44, y: 76),
                       control2: CGPoint(x: 38, y: 71))
            p.addCurve(to: CGPoint(x: 50, y: 45),
                       control1: CGPoint(x: 35, y: 56),
                       control2: CGPoint(x: 45, y: 53))

            p.move(to: CGPoint(x: 35, y: 27))
            p.addLine(to: CGPoint(x: 44, y: 38))
            p.move(to: CGPoint(x: 65, y: 27))
            p.addLine(to: CGPoint(x: 56, y: 38))
        }
        let accent = make { p in
            p.move(to: CGPoint(x: 11, y: 64))
            p.addLine(to: CGPoint(x: 17, y: 64))
            p.move(to: CGPoint(x: 83, y: 64))
            p.addLine(to: CGPoint(x: 89, y: 64))
        }
        let accentFill = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 63), radius: 4)
        }
        let compact = make { p in
            p.move(to: CGPoint(x: 20, y: 14))
            p.addLine(to: CGPoint(x: 80, y: 14))
            p.move(to: CGPoint(x: 27, y: 17))
            p.addLine(to: CGPoint(x: 33, y: 31))
            p.addLine(to: CGPoint(x: 50, y: 49))
            p.addLine(to: CGPoint(x: 67, y: 31))
            p.addLine(to: CGPoint(x: 73, y: 17))
            p.move(to: CGPoint(x: 20, y: 64))
            p.addLine(to: CGPoint(x: 30, y: 77))
            p.addLine(to: CGPoint(x: 50, y: 86))
            p.addLine(to: CGPoint(x: 70, y: 77))
            p.addLine(to: CGPoint(x: 80, y: 64))
            diamond(&p, center: CGPoint(x: 50, y: 63), radius: 7)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accent: accent, accentFill: accentFill,
                                compact: compact, opticalScale: 0.90,
                                opticalOffset: CGSize(width: 0, height: 0.5))
    }

    /// Two angular passes around a pair of set rails read as repeating a
    /// training session, rather than the generic history/undo arrow it replaces.
    private static func repeatSessionArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 18, y: 44))
            p.addLine(to: CGPoint(x: 18, y: 29))
            p.addLine(to: CGPoint(x: 33, y: 14))
            p.addLine(to: CGPoint(x: 68, y: 14))
            p.addLine(to: CGPoint(x: 82, y: 29))
            p.move(to: CGPoint(x: 66, y: 27))
            p.addLine(to: CGPoint(x: 82, y: 29))
            p.addLine(to: CGPoint(x: 79, y: 45))

            p.move(to: CGPoint(x: 82, y: 56))
            p.addLine(to: CGPoint(x: 82, y: 71))
            p.addLine(to: CGPoint(x: 67, y: 86))
            p.addLine(to: CGPoint(x: 32, y: 86))
            p.addLine(to: CGPoint(x: 18, y: 71))
            p.move(to: CGPoint(x: 34, y: 73))
            p.addLine(to: CGPoint(x: 18, y: 71))
            p.addLine(to: CGPoint(x: 21, y: 55))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 35, y: 43))
            p.addLine(to: CGPoint(x: 65, y: 43))
            p.move(to: CGPoint(x: 35, y: 57))
            p.addLine(to: CGPoint(x: 65, y: 57))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 4) }
        return RPGSymbolArtwork(
            primary: primary,
            detail: detail,
            accentFill: accentFill,
            compact: combined(primary, detail),
            opticalScale: 0.88
        )
    }

    /// A loaded bar with a central counting rune. Plate stacks, not a scale,
    /// make this specific to calculating barbell plates.
    private static func plateCalculatorArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 9, y: 50))
            p.addLine(to: CGPoint(x: 91, y: 50))
            p.addRoundedRect(in: CGRect(x: 16, y: 27, width: 12, height: 46),
                             cornerSize: CGSize(width: 3, height: 3))
            p.addRoundedRect(in: CGRect(x: 30, y: 34, width: 10, height: 32),
                             cornerSize: CGSize(width: 3, height: 3))
            p.addRoundedRect(in: CGRect(x: 72, y: 27, width: 12, height: 46),
                             cornerSize: CGSize(width: 3, height: 3))
            p.addRoundedRect(in: CGRect(x: 60, y: 34, width: 10, height: 32),
                             cornerSize: CGSize(width: 3, height: 3))
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 9)
            p.move(to: CGPoint(x: 43, y: 21))
            p.addLine(to: CGPoint(x: 57, y: 21))
            p.move(to: CGPoint(x: 50, y: 14))
            p.addLine(to: CGPoint(x: 50, y: 28))
            p.move(to: CGPoint(x: 43, y: 79))
            p.addLine(to: CGPoint(x: 57, y: 79))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 9, y: 50))
            p.addLine(to: CGPoint(x: 91, y: 50))
            p.addRoundedRect(in: CGRect(x: 17, y: 25, width: 13, height: 50),
                             cornerSize: CGSize(width: 3, height: 3))
            p.addRoundedRect(in: CGRect(x: 70, y: 25, width: 13, height: 50),
                             cornerSize: CGSize(width: 3, height: 3))
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 10)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.89)
    }

    /// Paired opposing rails describe replacing one exercise with another;
    /// the center jewel keeps the exchange inside the RPGFit vocabulary.
    private static func exerciseSwapArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 13, y: 32))
            p.addLine(to: CGPoint(x: 78, y: 32))
            p.move(to: CGPoint(x: 63, y: 18))
            p.addLine(to: CGPoint(x: 79, y: 32))
            p.addLine(to: CGPoint(x: 63, y: 46))

            p.move(to: CGPoint(x: 87, y: 68))
            p.addLine(to: CGPoint(x: 22, y: 68))
            p.move(to: CGPoint(x: 37, y: 54))
            p.addLine(to: CGPoint(x: 21, y: 68))
            p.addLine(to: CGPoint(x: 37, y: 82))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 50, y: 39))
            p.addLine(to: CGPoint(x: 50, y: 61))
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 8)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 3.5) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill,
                                compact: combined(primary, detail),
                                opticalScale: 0.88)
    }

    /// Two interlocked faceted loops stand for exercises performed as one
    /// coordinated set, without borrowing the platform's generic chain link.
    private static func supersetArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 12, y: 50))
            p.addLine(to: CGPoint(x: 34, y: 27))
            p.addLine(to: CGPoint(x: 59, y: 52))
            p.addLine(to: CGPoint(x: 37, y: 75))
            p.closeSubpath()

            p.move(to: CGPoint(x: 41, y: 48))
            p.addLine(to: CGPoint(x: 63, y: 25))
            p.addLine(to: CGPoint(x: 88, y: 50))
            p.addLine(to: CGPoint(x: 66, y: 73))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 27, y: 50))
            p.addLine(to: CGPoint(x: 42, y: 35))
            p.move(to: CGPoint(x: 58, y: 65))
            p.addLine(to: CGPoint(x: 73, y: 50))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 4) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill,
                                compact: primary, opticalScale: 0.86)
    }

    /// A low ember rises through three load-in rails. It reads as preparation
    /// and ramping, while the taller streak flame remains an achievement mark.
    private static func setWarmupArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 18, y: 84))
            p.addLine(to: CGPoint(x: 82, y: 84))
            p.move(to: CGPoint(x: 27, y: 72))
            p.addLine(to: CGPoint(x: 73, y: 72))
            p.move(to: CGPoint(x: 36, y: 60))
            p.addLine(to: CGPoint(x: 64, y: 60))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 50, y: 15))
            p.addCurve(to: CGPoint(x: 64, y: 42),
                       control1: CGPoint(x: 60, y: 25),
                       control2: CGPoint(x: 64, y: 32))
            p.addCurve(to: CGPoint(x: 50, y: 57),
                       control1: CGPoint(x: 64, y: 51),
                       control2: CGPoint(x: 57, y: 57))
            p.addCurve(to: CGPoint(x: 36, y: 42),
                       control1: CGPoint(x: 43, y: 57),
                       control2: CGPoint(x: 36, y: 51))
            p.addCurve(to: CGPoint(x: 50, y: 15),
                       control1: CGPoint(x: 36, y: 31),
                       control2: CGPoint(x: 46, y: 27))
            p.closeSubpath()
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 43), radius: 4) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill,
                                compact: combined(primary, detail),
                                opticalScale: 0.87,
                                opticalOffset: CGSize(width: 0, height: 1))
    }

    /// The forge anvil is the working-set counterpart to the warm-up ember:
    /// preparation becomes deliberate loaded work without borrowing a rep,
    /// timer, or generic confirmation mark.
    private static func setWorkingArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 12, y: 24))
            p.addLine(to: CGPoint(x: 88, y: 24))
            p.addLine(to: CGPoint(x: 79, y: 42))
            p.addLine(to: CGPoint(x: 62, y: 50))
            p.addLine(to: CGPoint(x: 59, y: 67))
            p.addLine(to: CGPoint(x: 72, y: 82))
            p.addLine(to: CGPoint(x: 28, y: 82))
            p.addLine(to: CGPoint(x: 41, y: 67))
            p.addLine(to: CGPoint(x: 38, y: 50))
            p.addLine(to: CGPoint(x: 21, y: 42))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 27, y: 36))
            p.addLine(to: CGPoint(x: 73, y: 36))
            diamond(&p, center: CGPoint(x: 50, y: 59), radius: 8)
        }
        let accentFill = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 59), radius: 3.5)
        }
        let compact = make { p in
            p.move(to: CGPoint(x: 12, y: 25))
            p.addLine(to: CGPoint(x: 88, y: 25))
            p.addLine(to: CGPoint(x: 78, y: 43))
            p.addLine(to: CGPoint(x: 61, y: 51))
            p.addLine(to: CGPoint(x: 59, y: 67))
            p.addLine(to: CGPoint(x: 72, y: 82))
            p.addLine(to: CGPoint(x: 28, y: 82))
            p.addLine(to: CGPoint(x: 41, y: 67))
            p.addLine(to: CGPoint(x: 39, y: 51))
            p.addLine(to: CGPoint(x: 22, y: 43))
            p.closeSubpath()
            diamond(&p, center: CGPoint(x: 50, y: 58), radius: 7)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.86,
                                opticalOffset: CGSize(width: 0, height: 1))
    }

    /// A faceted seal carries its own hand-drawn completion stroke. This is
    /// reserved for branded milestones; ordinary confirmation controls stay SF.
    private static func completionSealArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 50, y: 10))
            p.addLine(to: CGPoint(x: 62, y: 19))
            p.addLine(to: CGPoint(x: 77, y: 19))
            p.addLine(to: CGPoint(x: 81, y: 34))
            p.addLine(to: CGPoint(x: 90, y: 50))
            p.addLine(to: CGPoint(x: 81, y: 66))
            p.addLine(to: CGPoint(x: 77, y: 81))
            p.addLine(to: CGPoint(x: 62, y: 81))
            p.addLine(to: CGPoint(x: 50, y: 90))
            p.addLine(to: CGPoint(x: 38, y: 81))
            p.addLine(to: CGPoint(x: 23, y: 81))
            p.addLine(to: CGPoint(x: 19, y: 66))
            p.addLine(to: CGPoint(x: 10, y: 50))
            p.addLine(to: CGPoint(x: 19, y: 34))
            p.addLine(to: CGPoint(x: 23, y: 19))
            p.addLine(to: CGPoint(x: 38, y: 19))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 28, y: 51))
            p.addLine(to: CGPoint(x: 44, y: 67))
            p.addLine(to: CGPoint(x: 73, y: 34))
        }
        let accent = make { p in fourPointStar(&p, center: CGPoint(x: 75, y: 23), long: 7, short: 2.5) }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 75, y: 23), radius: 3) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accent: accent, accentFill: accentFill,
                                compact: combined(primary, detail),
                                opticalScale: 0.86)
    }

    // MARK: Equipment taxonomy

    /// Crossed blade and polearm distinguish the broad arms category from a
    /// single strength sword and from the trial's enclosed rune.
    private static func equipmentArmsArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 18, y: 84))
            p.addLine(to: CGPoint(x: 69, y: 33))
            p.addLine(to: CGPoint(x: 82, y: 13))
            p.addLine(to: CGPoint(x: 75, y: 36))
            p.addLine(to: CGPoint(x: 24, y: 87))
            p.closeSubpath()
            p.move(to: CGPoint(x: 78, y: 86))
            p.addLine(to: CGPoint(x: 29, y: 37))
            p.move(to: CGPoint(x: 20, y: 28))
            p.addLine(to: CGPoint(x: 29, y: 13))
            p.addLine(to: CGPoint(x: 38, y: 28))
            p.addLine(to: CGPoint(x: 29, y: 37))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 14, y: 69))
            p.addLine(to: CGPoint(x: 31, y: 86))
            p.move(to: CGPoint(x: 68, y: 77))
            p.addLine(to: CGPoint(x: 78, y: 67))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 51, y: 52), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 19, y: 84))
            p.addLine(to: CGPoint(x: 76, y: 27))
            p.addLine(to: CGPoint(x: 82, y: 14))
            p.addLine(to: CGPoint(x: 69, y: 20))
            p.move(to: CGPoint(x: 79, y: 85))
            p.addLine(to: CGPoint(x: 29, y: 35))
            diamond(&p, center: CGPoint(x: 24, y: 29), radius: 10)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    /// A crested helm creates a guard silhouette without borrowing a shield.
    private static func equipmentGuardArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 19, y: 51))
            p.addCurve(to: CGPoint(x: 50, y: 14),
                       control1: CGPoint(x: 20, y: 30),
                       control2: CGPoint(x: 32, y: 17))
            p.addCurve(to: CGPoint(x: 81, y: 51),
                       control1: CGPoint(x: 68, y: 17),
                       control2: CGPoint(x: 80, y: 32))
            p.addLine(to: CGPoint(x: 71, y: 83))
            p.addLine(to: CGPoint(x: 59, y: 72))
            p.addLine(to: CGPoint(x: 50, y: 88))
            p.addLine(to: CGPoint(x: 41, y: 72))
            p.addLine(to: CGPoint(x: 29, y: 83))
            p.closeSubpath()
            p.move(to: CGPoint(x: 50, y: 14))
            p.addLine(to: CGPoint(x: 50, y: 69))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 27, y: 51))
            p.addLine(to: CGPoint(x: 43, y: 56))
            p.move(to: CGPoint(x: 73, y: 51))
            p.addLine(to: CGPoint(x: 57, y: 56))
            p.move(to: CGPoint(x: 37, y: 34))
            p.addLine(to: CGPoint(x: 63, y: 34))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 32), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 19, y: 52))
            p.addCurve(to: CGPoint(x: 50, y: 15),
                       control1: CGPoint(x: 20, y: 30),
                       control2: CGPoint(x: 34, y: 16))
            p.addCurve(to: CGPoint(x: 81, y: 52),
                       control1: CGPoint(x: 66, y: 16),
                       control2: CGPoint(x: 80, y: 30))
            p.addLine(to: CGPoint(x: 69, y: 83))
            p.addLine(to: CGPoint(x: 50, y: 69))
            p.addLine(to: CGPoint(x: 31, y: 83))
            p.closeSubpath()
            p.move(to: CGPoint(x: 50, y: 15))
            p.addLine(to: CGPoint(x: 50, y: 69))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.89)
    }

    /// An arched chain suspends a faceted relic rather than reading as coinage.
    private static func equipmentRelicArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 20, y: 40))
            p.addCurve(to: CGPoint(x: 50, y: 16),
                       control1: CGPoint(x: 27, y: 23),
                       control2: CGPoint(x: 38, y: 16))
            p.addCurve(to: CGPoint(x: 80, y: 40),
                       control1: CGPoint(x: 62, y: 16),
                       control2: CGPoint(x: 73, y: 23))
            p.move(to: CGPoint(x: 20, y: 40))
            p.addLine(to: CGPoint(x: 42, y: 54))
            p.move(to: CGPoint(x: 80, y: 40))
            p.addLine(to: CGPoint(x: 58, y: 54))
            diamond(&p, center: CGPoint(x: 50, y: 68), radius: 20)
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 68), radius: 10)
            p.move(to: CGPoint(x: 35, y: 29))
            p.addLine(to: CGPoint(x: 42, y: 36))
            p.move(to: CGPoint(x: 65, y: 29))
            p.addLine(to: CGPoint(x: 58, y: 36))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 68), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 22, y: 39))
            p.addCurve(to: CGPoint(x: 50, y: 15),
                       control1: CGPoint(x: 29, y: 22),
                       control2: CGPoint(x: 40, y: 15))
            p.addCurve(to: CGPoint(x: 78, y: 39),
                       control1: CGPoint(x: 60, y: 15),
                       control2: CGPoint(x: 71, y: 22))
            p.addLine(to: CGPoint(x: 57, y: 53))
            diamond(&p, center: CGPoint(x: 50, y: 70), radius: 18)
            p.addLine(to: CGPoint(x: 43, y: 53))
            p.addLine(to: CGPoint(x: 22, y: 39))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.89, opticalOffset: CGSize(width: 0, height: 1))
    }

    /// A closed strap and faceted clasp denote gear that is actively fitted.
    /// The small confirmation stroke survives as a secondary cue at badge size.
    private static func equippedArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 9, y: 38))
            p.addLine(to: CGPoint(x: 31, y: 38))
            p.move(to: CGPoint(x: 9, y: 62))
            p.addLine(to: CGPoint(x: 31, y: 62))
            p.move(to: CGPoint(x: 69, y: 38))
            p.addLine(to: CGPoint(x: 91, y: 38))
            p.move(to: CGPoint(x: 69, y: 62))
            p.addLine(to: CGPoint(x: 91, y: 62))
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 28)
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 37, y: 50))
            p.addLine(to: CGPoint(x: 47, y: 60))
            p.addLine(to: CGPoint(x: 66, y: 39))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 3.5) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill,
                                compact: combined(primary, detail),
                                opticalScale: 0.86)
    }

    // MARK: Loot taxonomy

    private static func lootConsumableArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.addRoundedRect(in: CGRect(x: 39, y: 10, width: 22, height: 14),
                             cornerSize: CGSize(width: 3, height: 3))
            p.move(to: CGPoint(x: 42, y: 24))
            p.addLine(to: CGPoint(x: 42, y: 36))
            p.addLine(to: CGPoint(x: 31, y: 47))
            p.addLine(to: CGPoint(x: 35, y: 88))
            p.addLine(to: CGPoint(x: 65, y: 88))
            p.addLine(to: CGPoint(x: 69, y: 47))
            p.addLine(to: CGPoint(x: 58, y: 36))
            p.addLine(to: CGPoint(x: 58, y: 24))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 34, y: 58))
            p.addLine(to: CGPoint(x: 66, y: 58))
            plus(&p, center: CGPoint(x: 50, y: 72), arm: 7)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 72), radius: 3) }
        let compact = make { p in
            p.move(to: CGPoint(x: 40, y: 11))
            p.addLine(to: CGPoint(x: 60, y: 11))
            p.addLine(to: CGPoint(x: 60, y: 34))
            p.addLine(to: CGPoint(x: 69, y: 46))
            p.addLine(to: CGPoint(x: 65, y: 88))
            p.addLine(to: CGPoint(x: 35, y: 88))
            p.addLine(to: CGPoint(x: 31, y: 46))
            p.addLine(to: CGPoint(x: 40, y: 34))
            p.closeSubpath()
            plus(&p, center: CGPoint(x: 50, y: 67), arm: 8)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    private static func lootEquipmentArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 35, y: 17))
            p.addLine(to: CGPoint(x: 18, y: 29))
            p.addLine(to: CGPoint(x: 25, y: 48))
            p.addLine(to: CGPoint(x: 32, y: 42))
            p.addLine(to: CGPoint(x: 31, y: 84))
            p.addLine(to: CGPoint(x: 69, y: 84))
            p.addLine(to: CGPoint(x: 68, y: 42))
            p.addLine(to: CGPoint(x: 75, y: 48))
            p.addLine(to: CGPoint(x: 82, y: 29))
            p.addLine(to: CGPoint(x: 65, y: 17))
            p.addCurve(to: CGPoint(x: 35, y: 17),
                       control1: CGPoint(x: 61, y: 36),
                       control2: CGPoint(x: 39, y: 36))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 37, y: 48))
            p.addLine(to: CGPoint(x: 63, y: 48))
            p.move(to: CGPoint(x: 50, y: 38))
            p.addLine(to: CGPoint(x: 50, y: 76))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 54), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 34, y: 16))
            p.addLine(to: CGPoint(x: 17, y: 29))
            p.addLine(to: CGPoint(x: 27, y: 49))
            p.addLine(to: CGPoint(x: 34, y: 42))
            p.addLine(to: CGPoint(x: 32, y: 85))
            p.addLine(to: CGPoint(x: 68, y: 85))
            p.addLine(to: CGPoint(x: 66, y: 42))
            p.addLine(to: CGPoint(x: 73, y: 49))
            p.addLine(to: CGPoint(x: 83, y: 29))
            p.addLine(to: CGPoint(x: 66, y: 16))
            p.addCurve(to: CGPoint(x: 34, y: 16),
                       control1: CGPoint(x: 61, y: 38),
                       control2: CGPoint(x: 39, y: 38))
            p.closeSubpath()
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    private static func lootMaterialArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 10, y: 77))
            p.addLine(to: CGPoint(x: 27, y: 43))
            p.addLine(to: CGPoint(x: 43, y: 59))
            p.addLine(to: CGPoint(x: 50, y: 16))
            p.addLine(to: CGPoint(x: 66, y: 54))
            p.addLine(to: CGPoint(x: 78, y: 36))
            p.addLine(to: CGPoint(x: 91, y: 77))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 27, y: 43))
            p.addLine(to: CGPoint(x: 34, y: 77))
            p.move(to: CGPoint(x: 50, y: 16))
            p.addLine(to: CGPoint(x: 54, y: 77))
            p.move(to: CGPoint(x: 78, y: 36))
            p.addLine(to: CGPoint(x: 72, y: 77))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 54, y: 61), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 10, y: 78))
            p.addLine(to: CGPoint(x: 28, y: 42))
            p.addLine(to: CGPoint(x: 42, y: 58))
            p.addLine(to: CGPoint(x: 50, y: 15))
            p.addLine(to: CGPoint(x: 66, y: 54))
            p.addLine(to: CGPoint(x: 79, y: 35))
            p.addLine(to: CGPoint(x: 91, y: 78))
            p.closeSubpath()
            p.move(to: CGPoint(x: 50, y: 15))
            p.addLine(to: CGPoint(x: 54, y: 78))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88, opticalOffset: CGSize(width: 0, height: 2))
    }

    private static func lootCollectibleArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.addEllipse(in: CGRect(x: 22, y: 13, width: 56, height: 56))
            p.move(to: CGPoint(x: 32, y: 61))
            p.addLine(to: CGPoint(x: 27, y: 91))
            p.addLine(to: CGPoint(x: 49, y: 76))
            p.move(to: CGPoint(x: 68, y: 61))
            p.addLine(to: CGPoint(x: 73, y: 91))
            p.addLine(to: CGPoint(x: 51, y: 76))
        }
        let detail = make { p in
            fourPointStar(&p, center: CGPoint(x: 50, y: 41), long: 18, short: 6)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 41), radius: 4) }
        let compact = make { p in
            p.addEllipse(in: CGRect(x: 23, y: 12, width: 54, height: 54))
            p.move(to: CGPoint(x: 31, y: 59))
            p.addLine(to: CGPoint(x: 27, y: 90))
            p.addLine(to: CGPoint(x: 50, y: 76))
            p.addLine(to: CGPoint(x: 73, y: 90))
            p.addLine(to: CGPoint(x: 69, y: 59))
            fourPointStar(&p, center: CGPoint(x: 50, y: 39), long: 14, short: 5)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.89, opticalOffset: CGSize(width: 0, height: 1))
    }

    // MARK: Authored loot

    private static func lootBucklerArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.addEllipse(in: CGRect(x: 17, y: 17, width: 66, height: 66))
            p.move(to: CGPoint(x: 50, y: 10))
            p.addLine(to: CGPoint(x: 50, y: 22))
            p.move(to: CGPoint(x: 50, y: 78))
            p.addLine(to: CGPoint(x: 50, y: 90))
            p.move(to: CGPoint(x: 10, y: 50))
            p.addLine(to: CGPoint(x: 22, y: 50))
            p.move(to: CGPoint(x: 78, y: 50))
            p.addLine(to: CGPoint(x: 90, y: 50))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 28, y: 28))
            p.addLine(to: CGPoint(x: 72, y: 72))
            p.move(to: CGPoint(x: 72, y: 28))
            p.addLine(to: CGPoint(x: 28, y: 72))
            p.addEllipse(in: CGRect(x: 40, y: 40, width: 20, height: 20))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 4) }
        let compact = make { p in
            p.addEllipse(in: CGRect(x: 18, y: 18, width: 64, height: 64))
            p.move(to: CGPoint(x: 50, y: 8))
            p.addLine(to: CGPoint(x: 50, y: 22))
            p.move(to: CGPoint(x: 50, y: 78))
            p.addLine(to: CGPoint(x: 50, y: 92))
            p.move(to: CGPoint(x: 8, y: 50))
            p.addLine(to: CGPoint(x: 22, y: 50))
            p.move(to: CGPoint(x: 78, y: 50))
            p.addLine(to: CGPoint(x: 92, y: 50))
            p.addEllipse(in: CGRect(x: 42, y: 42, width: 16, height: 16))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    private static func lootTonicArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 39, y: 12))
            p.addLine(to: CGPoint(x: 61, y: 12))
            p.move(to: CGPoint(x: 43, y: 12))
            p.addLine(to: CGPoint(x: 43, y: 32))
            p.addCurve(to: CGPoint(x: 24, y: 63),
                       control1: CGPoint(x: 31, y: 39),
                       control2: CGPoint(x: 24, y: 50))
            p.addCurve(to: CGPoint(x: 50, y: 89),
                       control1: CGPoint(x: 24, y: 79),
                       control2: CGPoint(x: 37, y: 89))
            p.addCurve(to: CGPoint(x: 76, y: 63),
                       control1: CGPoint(x: 63, y: 89),
                       control2: CGPoint(x: 76, y: 79))
            p.addCurve(to: CGPoint(x: 57, y: 32),
                       control1: CGPoint(x: 76, y: 50),
                       control2: CGPoint(x: 69, y: 39))
            p.addLine(to: CGPoint(x: 57, y: 12))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 27, y: 61))
            p.addCurve(to: CGPoint(x: 73, y: 61),
                       control1: CGPoint(x: 40, y: 54),
                       control2: CGPoint(x: 60, y: 68))
            p.move(to: CGPoint(x: 50, y: 45))
            p.addCurve(to: CGPoint(x: 50, y: 70),
                       control1: CGPoint(x: 36, y: 57),
                       control2: CGPoint(x: 43, y: 70))
            p.addCurve(to: CGPoint(x: 50, y: 45),
                       control1: CGPoint(x: 57, y: 70),
                       control2: CGPoint(x: 64, y: 57))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 61), radius: 3.5) }
        let compact = make { p in
            p.move(to: CGPoint(x: 39, y: 11))
            p.addLine(to: CGPoint(x: 61, y: 11))
            p.move(to: CGPoint(x: 43, y: 12))
            p.addLine(to: CGPoint(x: 43, y: 32))
            p.addCurve(to: CGPoint(x: 24, y: 63),
                       control1: CGPoint(x: 31, y: 40),
                       control2: CGPoint(x: 24, y: 51))
            p.addCurve(to: CGPoint(x: 50, y: 89),
                       control1: CGPoint(x: 24, y: 79),
                       control2: CGPoint(x: 37, y: 89))
            p.addCurve(to: CGPoint(x: 76, y: 63),
                       control1: CGPoint(x: 63, y: 89),
                       control2: CGPoint(x: 76, y: 79))
            p.addCurve(to: CGPoint(x: 57, y: 32),
                       control1: CGPoint(x: 76, y: 51),
                       control2: CGPoint(x: 69, y: 40))
            p.addLine(to: CGPoint(x: 57, y: 12))
            p.move(to: CGPoint(x: 50, y: 44))
            p.addLine(to: CGPoint(x: 42, y: 61))
            p.addLine(to: CGPoint(x: 50, y: 73))
            p.addLine(to: CGPoint(x: 58, y: 61))
            p.closeSubpath()
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.89)
    }

    private static func lootMapArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 13, y: 23))
            p.addLine(to: CGPoint(x: 37, y: 14))
            p.addLine(to: CGPoint(x: 63, y: 24))
            p.addLine(to: CGPoint(x: 87, y: 15))
            p.addLine(to: CGPoint(x: 87, y: 77))
            p.addLine(to: CGPoint(x: 63, y: 86))
            p.addLine(to: CGPoint(x: 37, y: 76))
            p.addLine(to: CGPoint(x: 13, y: 85))
            p.closeSubpath()
            p.move(to: CGPoint(x: 37, y: 14))
            p.addLine(to: CGPoint(x: 37, y: 76))
            p.move(to: CGPoint(x: 63, y: 24))
            p.addLine(to: CGPoint(x: 63, y: 86))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 22, y: 66))
            p.addCurve(to: CGPoint(x: 75, y: 33),
                       control1: CGPoint(x: 50, y: 76),
                       control2: CGPoint(x: 43, y: 35))
            p.move(to: CGPoint(x: 70, y: 28))
            p.addLine(to: CGPoint(x: 80, y: 38))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 75, y: 33), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 12, y: 23))
            p.addLine(to: CGPoint(x: 37, y: 14))
            p.addLine(to: CGPoint(x: 63, y: 24))
            p.addLine(to: CGPoint(x: 88, y: 15))
            p.addLine(to: CGPoint(x: 88, y: 77))
            p.addLine(to: CGPoint(x: 63, y: 86))
            p.addLine(to: CGPoint(x: 37, y: 76))
            p.addLine(to: CGPoint(x: 12, y: 85))
            p.closeSubpath()
            p.move(to: CGPoint(x: 37, y: 14))
            p.addLine(to: CGPoint(x: 37, y: 76))
            p.move(to: CGPoint(x: 63, y: 24))
            p.addLine(to: CGPoint(x: 63, y: 86))
            p.move(to: CGPoint(x: 22, y: 65))
            p.addCurve(to: CGPoint(x: 75, y: 33),
                       control1: CGPoint(x: 51, y: 75),
                       control2: CGPoint(x: 43, y: 35))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    private static func lootDiceArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 50, y: 10))
            p.addLine(to: CGPoint(x: 87, y: 32))
            p.addLine(to: CGPoint(x: 87, y: 70))
            p.addLine(to: CGPoint(x: 50, y: 91))
            p.addLine(to: CGPoint(x: 13, y: 70))
            p.addLine(to: CGPoint(x: 13, y: 32))
            p.closeSubpath()
            p.move(to: CGPoint(x: 13, y: 32))
            p.addLine(to: CGPoint(x: 50, y: 53))
            p.addLine(to: CGPoint(x: 87, y: 32))
            p.move(to: CGPoint(x: 50, y: 53))
            p.addLine(to: CGPoint(x: 50, y: 91))
        }
        let detail = make { p in
            p.addEllipse(in: CGRect(x: 46, y: 27, width: 8, height: 8))
            p.addEllipse(in: CGRect(x: 28, y: 53, width: 7, height: 7))
            p.addEllipse(in: CGRect(x: 65, y: 53, width: 7, height: 7))
            p.addEllipse(in: CGRect(x: 65, y: 69, width: 7, height: 7))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 53), radius: 3.5) }
        let compact = make { p in
            p.move(to: CGPoint(x: 50, y: 10))
            p.addLine(to: CGPoint(x: 87, y: 32))
            p.addLine(to: CGPoint(x: 87, y: 70))
            p.addLine(to: CGPoint(x: 50, y: 91))
            p.addLine(to: CGPoint(x: 13, y: 70))
            p.addLine(to: CGPoint(x: 13, y: 32))
            p.closeSubpath()
            p.move(to: CGPoint(x: 13, y: 32))
            p.addLine(to: CGPoint(x: 50, y: 53))
            p.addLine(to: CGPoint(x: 87, y: 32))
            p.move(to: CGPoint(x: 50, y: 53))
            p.addLine(to: CGPoint(x: 50, y: 91))
            p.addEllipse(in: CGRect(x: 46, y: 27, width: 8, height: 8))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    private static func lootRuneFragmentArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 49, y: 9))
            p.addLine(to: CGPoint(x: 84, y: 43))
            p.addLine(to: CGPoint(x: 61, y: 50))
            p.addLine(to: CGPoint(x: 73, y: 84))
            p.addLine(to: CGPoint(x: 48, y: 91))
            p.addLine(to: CGPoint(x: 17, y: 61))
            p.addLine(to: CGPoint(x: 39, y: 51))
            p.addLine(to: CGPoint(x: 26, y: 19))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 49, y: 9))
            p.addLine(to: CGPoint(x: 39, y: 51))
            p.move(to: CGPoint(x: 61, y: 50))
            p.addLine(to: CGPoint(x: 48, y: 91))
            p.move(to: CGPoint(x: 28, y: 64))
            p.addLine(to: CGPoint(x: 40, y: 76))
            p.move(to: CGPoint(x: 64, y: 25))
            p.addLine(to: CGPoint(x: 75, y: 36))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 51), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 48, y: 8))
            p.addLine(to: CGPoint(x: 84, y: 43))
            p.addLine(to: CGPoint(x: 61, y: 50))
            p.addLine(to: CGPoint(x: 74, y: 85))
            p.addLine(to: CGPoint(x: 48, y: 92))
            p.addLine(to: CGPoint(x: 16, y: 61))
            p.addLine(to: CGPoint(x: 39, y: 50))
            p.addLine(to: CGPoint(x: 25, y: 18))
            p.closeSubpath()
            p.move(to: CGPoint(x: 48, y: 8))
            p.addLine(to: CGPoint(x: 39, y: 50))
            p.move(to: CGPoint(x: 61, y: 50))
            p.addLine(to: CGPoint(x: 48, y: 92))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.87)
    }

    private static func lootPhoenixFeatherArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 22, y: 88))
            p.addCurve(to: CGPoint(x: 71, y: 13),
                       control1: CGPoint(x: 25, y: 51),
                       control2: CGPoint(x: 48, y: 18))
            p.addCurve(to: CGPoint(x: 80, y: 45),
                       control1: CGPoint(x: 86, y: 21),
                       control2: CGPoint(x: 86, y: 34))
            p.addLine(to: CGPoint(x: 63, y: 42))
            p.addLine(to: CGPoint(x: 70, y: 58))
            p.addLine(to: CGPoint(x: 51, y: 54))
            p.addLine(to: CGPoint(x: 56, y: 71))
            p.addLine(to: CGPoint(x: 37, y: 66))
            p.addCurve(to: CGPoint(x: 22, y: 88),
                       control1: CGPoint(x: 33, y: 76),
                       control2: CGPoint(x: 28, y: 83))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 22, y: 88))
            p.addCurve(to: CGPoint(x: 73, y: 20),
                       control1: CGPoint(x: 41, y: 65),
                       control2: CGPoint(x: 58, y: 42))
            p.move(to: CGPoint(x: 37, y: 78))
            p.addLine(to: CGPoint(x: 25, y: 70))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 52, y: 50), radius: 3.5) }
        let compact = make { p in
            p.move(to: CGPoint(x: 21, y: 89))
            p.addCurve(to: CGPoint(x: 71, y: 12),
                       control1: CGPoint(x: 24, y: 51),
                       control2: CGPoint(x: 49, y: 17))
            p.addCurve(to: CGPoint(x: 80, y: 45),
                       control1: CGPoint(x: 87, y: 21),
                       control2: CGPoint(x: 86, y: 35))
            p.addLine(to: CGPoint(x: 63, y: 42))
            p.addLine(to: CGPoint(x: 70, y: 58))
            p.addLine(to: CGPoint(x: 51, y: 54))
            p.addLine(to: CGPoint(x: 56, y: 71))
            p.addLine(to: CGPoint(x: 37, y: 66))
            p.addCurve(to: CGPoint(x: 21, y: 89),
                       control1: CGPoint(x: 33, y: 76),
                       control2: CGPoint(x: 27, y: 84))
            p.move(to: CGPoint(x: 21, y: 89))
            p.addLine(to: CGPoint(x: 73, y: 20))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    private static func lootChaliceArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 25, y: 22))
            p.addLine(to: CGPoint(x: 75, y: 22))
            p.addCurve(to: CGPoint(x: 50, y: 60),
                       control1: CGPoint(x: 74, y: 46),
                       control2: CGPoint(x: 63, y: 60))
            p.addCurve(to: CGPoint(x: 25, y: 22),
                       control1: CGPoint(x: 37, y: 60),
                       control2: CGPoint(x: 26, y: 46))
            p.move(to: CGPoint(x: 50, y: 60))
            p.addLine(to: CGPoint(x: 50, y: 80))
            p.move(to: CGPoint(x: 31, y: 88))
            p.addCurve(to: CGPoint(x: 69, y: 88),
                       control1: CGPoint(x: 39, y: 78),
                       control2: CGPoint(x: 61, y: 78))
            p.move(to: CGPoint(x: 25, y: 28))
            p.addCurve(to: CGPoint(x: 14, y: 46),
                       control1: CGPoint(x: 12, y: 29),
                       control2: CGPoint(x: 12, y: 39))
            p.addCurve(to: CGPoint(x: 34, y: 50),
                       control1: CGPoint(x: 18, y: 55),
                       control2: CGPoint(x: 27, y: 54))
            p.move(to: CGPoint(x: 75, y: 28))
            p.addCurve(to: CGPoint(x: 86, y: 46),
                       control1: CGPoint(x: 88, y: 29),
                       control2: CGPoint(x: 88, y: 39))
            p.addCurve(to: CGPoint(x: 66, y: 50),
                       control1: CGPoint(x: 82, y: 55),
                       control2: CGPoint(x: 73, y: 54))
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 11), radius: 6)
            p.move(to: CGPoint(x: 34, y: 35))
            p.addCurve(to: CGPoint(x: 66, y: 35),
                       control1: CGPoint(x: 44, y: 42),
                       control2: CGPoint(x: 56, y: 28))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 38), radius: 4) }
        let compact = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 11), radius: 6)
            p.move(to: CGPoint(x: 24, y: 23))
            p.addLine(to: CGPoint(x: 76, y: 23))
            p.addCurve(to: CGPoint(x: 50, y: 61),
                       control1: CGPoint(x: 75, y: 48),
                       control2: CGPoint(x: 63, y: 61))
            p.addCurve(to: CGPoint(x: 24, y: 23),
                       control1: CGPoint(x: 37, y: 61),
                       control2: CGPoint(x: 25, y: 48))
            p.move(to: CGPoint(x: 50, y: 61))
            p.addLine(to: CGPoint(x: 50, y: 80))
            p.move(to: CGPoint(x: 31, y: 89))
            p.addCurve(to: CGPoint(x: 69, y: 89),
                       control1: CGPoint(x: 40, y: 79),
                       control2: CGPoint(x: 60, y: 79))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88, opticalOffset: CGSize(width: 0, height: 1))
    }

    private static func lootTomeArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.addRoundedRect(in: CGRect(x: 18, y: 18, width: 64, height: 67),
                             cornerSize: CGSize(width: 6, height: 6))
            p.move(to: CGPoint(x: 31, y: 18))
            p.addLine(to: CGPoint(x: 31, y: 85))
            p.move(to: CGPoint(x: 68, y: 18))
            p.addLine(to: CGPoint(x: 68, y: 85))
            p.move(to: CGPoint(x: 75, y: 28))
            p.addLine(to: CGPoint(x: 88, y: 33))
            p.addLine(to: CGPoint(x: 88, y: 70))
            p.addLine(to: CGPoint(x: 75, y: 75))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 43, y: 38))
            p.addLine(to: CGPoint(x: 59, y: 38))
            p.move(to: CGPoint(x: 43, y: 64))
            p.addLine(to: CGPoint(x: 59, y: 64))
            diamond(&p, center: CGPoint(x: 51, y: 51), radius: 8)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 51, y: 51), radius: 3.5) }
        let compact = make { p in
            p.move(to: CGPoint(x: 14, y: 28))
            p.addLine(to: CGPoint(x: 64, y: 15))
            p.addLine(to: CGPoint(x: 86, y: 72))
            p.addLine(to: CGPoint(x: 36, y: 86))
            p.closeSubpath()
            p.move(to: CGPoint(x: 27, y: 25))
            p.addLine(to: CGPoint(x: 48, y: 83))
            p.move(to: CGPoint(x: 72, y: 27))
            p.addLine(to: CGPoint(x: 83, y: 57))
            diamond(&p, center: CGPoint(x: 60, y: 52), radius: 8)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.89, opticalOffset: CGSize(width: -1, height: 1))
    }

    private static func lootTrophyArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 25, y: 18))
            p.addLine(to: CGPoint(x: 75, y: 18))
            p.addLine(to: CGPoint(x: 68, y: 48))
            p.addCurve(to: CGPoint(x: 50, y: 60),
                       control1: CGPoint(x: 65, y: 56),
                       control2: CGPoint(x: 58, y: 60))
            p.addCurve(to: CGPoint(x: 32, y: 48),
                       control1: CGPoint(x: 42, y: 60),
                       control2: CGPoint(x: 35, y: 56))
            p.closeSubpath()
            p.move(to: CGPoint(x: 25, y: 25))
            p.addCurve(to: CGPoint(x: 13, y: 38),
                       control1: CGPoint(x: 11, y: 24),
                       control2: CGPoint(x: 10, y: 32))
            p.addCurve(to: CGPoint(x: 34, y: 48),
                       control1: CGPoint(x: 17, y: 49),
                       control2: CGPoint(x: 26, y: 49))
            p.move(to: CGPoint(x: 75, y: 25))
            p.addCurve(to: CGPoint(x: 87, y: 38),
                       control1: CGPoint(x: 89, y: 24),
                       control2: CGPoint(x: 90, y: 32))
            p.addCurve(to: CGPoint(x: 66, y: 48),
                       control1: CGPoint(x: 83, y: 49),
                       control2: CGPoint(x: 74, y: 49))
            p.move(to: CGPoint(x: 50, y: 60))
            p.addLine(to: CGPoint(x: 50, y: 77))
            p.move(to: CGPoint(x: 34, y: 77))
            p.addLine(to: CGPoint(x: 66, y: 77))
            p.addLine(to: CGPoint(x: 73, y: 90))
            p.addLine(to: CGPoint(x: 27, y: 90))
            p.closeSubpath()
        }
        let detail = make { p in
            fourPointStar(&p, center: CGPoint(x: 50, y: 38), long: 12, short: 4)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 38), radius: 3.5) }
        let compact = make { p in
            p.move(to: CGPoint(x: 25, y: 18))
            p.addLine(to: CGPoint(x: 75, y: 18))
            p.addLine(to: CGPoint(x: 68, y: 48))
            p.addCurve(to: CGPoint(x: 50, y: 60),
                       control1: CGPoint(x: 65, y: 56),
                       control2: CGPoint(x: 58, y: 60))
            p.addCurve(to: CGPoint(x: 32, y: 48),
                       control1: CGPoint(x: 42, y: 60),
                       control2: CGPoint(x: 35, y: 56))
            p.closeSubpath()
            p.move(to: CGPoint(x: 25, y: 25))
            p.addCurve(to: CGPoint(x: 13, y: 38),
                       control1: CGPoint(x: 11, y: 24),
                       control2: CGPoint(x: 10, y: 32))
            p.addCurve(to: CGPoint(x: 34, y: 48),
                       control1: CGPoint(x: 17, y: 49),
                       control2: CGPoint(x: 26, y: 49))
            p.move(to: CGPoint(x: 75, y: 25))
            p.addCurve(to: CGPoint(x: 87, y: 38),
                       control1: CGPoint(x: 89, y: 24),
                       control2: CGPoint(x: 90, y: 32))
            p.addCurve(to: CGPoint(x: 66, y: 48),
                       control1: CGPoint(x: 83, y: 49),
                       control2: CGPoint(x: 74, y: 49))
            p.move(to: CGPoint(x: 50, y: 60))
            p.addLine(to: CGPoint(x: 50, y: 78))
            p.move(to: CGPoint(x: 31, y: 89))
            p.addLine(to: CGPoint(x: 69, y: 89))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    private static func lootWandArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 16, y: 86))
            p.addLine(to: CGPoint(x: 66, y: 36))
            p.move(to: CGPoint(x: 22, y: 92))
            p.addLine(to: CGPoint(x: 72, y: 42))
            p.move(to: CGPoint(x: 16, y: 86))
            p.addLine(to: CGPoint(x: 22, y: 92))
            fourPointStar(&p, center: CGPoint(x: 75, y: 25), long: 18, short: 6)
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 33, y: 66))
            p.addLine(to: CGPoint(x: 39, y: 72))
            p.move(to: CGPoint(x: 45, y: 54))
            p.addLine(to: CGPoint(x: 51, y: 60))
            diamond(&p, center: CGPoint(x: 25, y: 31), radius: 6)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 75, y: 25), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 17, y: 87))
            p.addLine(to: CGPoint(x: 67, y: 37))
            p.move(to: CGPoint(x: 23, y: 93))
            p.addLine(to: CGPoint(x: 73, y: 43))
            p.move(to: CGPoint(x: 17, y: 87))
            p.addLine(to: CGPoint(x: 23, y: 93))
            fourPointStar(&p, center: CGPoint(x: 76, y: 24), long: 18, short: 6)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    private static func lootCrownArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.addEllipse(in: CGRect(x: 10, y: 10, width: 80, height: 80))
            p.move(to: CGPoint(x: 22, y: 43))
            p.addLine(to: CGPoint(x: 33, y: 68))
            p.addLine(to: CGPoint(x: 67, y: 68))
            p.addLine(to: CGPoint(x: 78, y: 43))
            p.addLine(to: CGPoint(x: 62, y: 53))
            p.addLine(to: CGPoint(x: 50, y: 31))
            p.addLine(to: CGPoint(x: 38, y: 53))
            p.closeSubpath()
            p.move(to: CGPoint(x: 31, y: 76))
            p.addLine(to: CGPoint(x: 69, y: 76))
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 59), radius: 7)
            p.move(to: CGPoint(x: 22, y: 28))
            p.addLine(to: CGPoint(x: 30, y: 34))
            p.move(to: CGPoint(x: 78, y: 28))
            p.addLine(to: CGPoint(x: 70, y: 34))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 59), radius: 3.5) }
        let compact = make { p in
            p.addEllipse(in: CGRect(x: 10, y: 10, width: 80, height: 80))
            p.move(to: CGPoint(x: 22, y: 42))
            p.addLine(to: CGPoint(x: 33, y: 69))
            p.addLine(to: CGPoint(x: 67, y: 69))
            p.addLine(to: CGPoint(x: 78, y: 42))
            p.addLine(to: CGPoint(x: 62, y: 53))
            p.addLine(to: CGPoint(x: 50, y: 30))
            p.addLine(to: CGPoint(x: 38, y: 53))
            p.closeSubpath()
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.87)
    }

    // MARK: Journey regions and rites

    private static func regionKindlingValeArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 50, y: 9))
            p.addCurve(to: CGPoint(x: 80, y: 57),
                       control1: CGPoint(x: 52, y: 30),
                       control2: CGPoint(x: 79, y: 35))
            p.addCurve(to: CGPoint(x: 50, y: 91),
                       control1: CGPoint(x: 81, y: 77),
                       control2: CGPoint(x: 66, y: 91))
            p.addCurve(to: CGPoint(x: 20, y: 57),
                       control1: CGPoint(x: 34, y: 91),
                       control2: CGPoint(x: 19, y: 77))
            p.addCurve(to: CGPoint(x: 39, y: 31),
                       control1: CGPoint(x: 19, y: 41),
                       control2: CGPoint(x: 31, y: 37))
            p.addCurve(to: CGPoint(x: 50, y: 9),
                       control1: CGPoint(x: 44, y: 24),
                       control2: CGPoint(x: 47, y: 16))
            p.closeSubpath()
            p.move(to: CGPoint(x: 27, y: 61))
            p.addLine(to: CGPoint(x: 42, y: 48))
            p.addLine(to: CGPoint(x: 50, y: 57))
            p.addLine(to: CGPoint(x: 60, y: 43))
            p.addLine(to: CGPoint(x: 73, y: 61))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 50, y: 75))
            p.addLine(to: CGPoint(x: 50, y: 55))
            p.addCurve(to: CGPoint(x: 38, y: 51),
                       control1: CGPoint(x: 44, y: 55),
                       control2: CGPoint(x: 39, y: 54))
            p.addCurve(to: CGPoint(x: 50, y: 63),
                       control1: CGPoint(x: 38, y: 59),
                       control2: CGPoint(x: 43, y: 63))
            p.addCurve(to: CGPoint(x: 62, y: 51),
                       control1: CGPoint(x: 56, y: 55),
                       control2: CGPoint(x: 61, y: 54))
            p.addCurve(to: CGPoint(x: 50, y: 63),
                       control1: CGPoint(x: 62, y: 59),
                       control2: CGPoint(x: 57, y: 63))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 57), radius: 3.5) }
        let compact = make { p in
            p.move(to: CGPoint(x: 50, y: 8))
            p.addCurve(to: CGPoint(x: 80, y: 57),
                       control1: CGPoint(x: 52, y: 30),
                       control2: CGPoint(x: 79, y: 35))
            p.addCurve(to: CGPoint(x: 50, y: 92),
                       control1: CGPoint(x: 81, y: 78),
                       control2: CGPoint(x: 66, y: 92))
            p.addCurve(to: CGPoint(x: 20, y: 57),
                       control1: CGPoint(x: 34, y: 92),
                       control2: CGPoint(x: 19, y: 78))
            p.addCurve(to: CGPoint(x: 39, y: 31),
                       control1: CGPoint(x: 19, y: 41),
                       control2: CGPoint(x: 31, y: 37))
            p.addCurve(to: CGPoint(x: 50, y: 8),
                       control1: CGPoint(x: 44, y: 23),
                       control2: CGPoint(x: 47, y: 15))
            p.closeSubpath()
            p.move(to: CGPoint(x: 27, y: 63))
            p.addLine(to: CGPoint(x: 43, y: 48))
            p.addLine(to: CGPoint(x: 50, y: 58))
            p.addLine(to: CGPoint(x: 61, y: 43))
            p.addLine(to: CGPoint(x: 73, y: 63))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.87)
    }

    private static func regionAshenPassesArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 8, y: 84))
            p.addLine(to: CGPoint(x: 34, y: 45))
            p.addLine(to: CGPoint(x: 47, y: 62))
            p.addLine(to: CGPoint(x: 65, y: 35))
            p.addLine(to: CGPoint(x: 92, y: 84))
            p.closeSubpath()
            p.move(to: CGPoint(x: 34, y: 45))
            p.addLine(to: CGPoint(x: 31, y: 84))
            p.move(to: CGPoint(x: 65, y: 35))
            p.addLine(to: CGPoint(x: 70, y: 84))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 31, y: 34))
            p.addCurve(to: CGPoint(x: 42, y: 17),
                       control1: CGPoint(x: 25, y: 25),
                       control2: CGPoint(x: 35, y: 23))
            p.addCurve(to: CGPoint(x: 33, y: 8),
                       control1: CGPoint(x: 48, y: 12),
                       control2: CGPoint(x: 41, y: 8))
            p.move(to: CGPoint(x: 62, y: 27))
            p.addCurve(to: CGPoint(x: 72, y: 13),
                       control1: CGPoint(x: 58, y: 20),
                       control2: CGPoint(x: 66, y: 19))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 68), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 8, y: 85))
            p.addLine(to: CGPoint(x: 34, y: 45))
            p.addLine(to: CGPoint(x: 47, y: 62))
            p.addLine(to: CGPoint(x: 65, y: 35))
            p.addLine(to: CGPoint(x: 92, y: 85))
            p.closeSubpath()
            p.move(to: CGPoint(x: 31, y: 34))
            p.addCurve(to: CGPoint(x: 42, y: 17),
                       control1: CGPoint(x: 25, y: 25),
                       control2: CGPoint(x: 35, y: 23))
            p.addCurve(to: CGPoint(x: 33, y: 8),
                       control1: CGPoint(x: 48, y: 12),
                       control2: CGPoint(x: 41, y: 8))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88, opticalOffset: CGSize(width: 0, height: 1))
    }

    private static func regionStormreachArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 20, y: 87))
            p.addLine(to: CGPoint(x: 35, y: 73))
            p.addLine(to: CGPoint(x: 39, y: 35))
            p.addLine(to: CGPoint(x: 50, y: 19))
            p.addLine(to: CGPoint(x: 61, y: 35))
            p.addLine(to: CGPoint(x: 65, y: 73))
            p.addLine(to: CGPoint(x: 80, y: 87))
            p.closeSubpath()
            p.move(to: CGPoint(x: 34, y: 73))
            p.addLine(to: CGPoint(x: 66, y: 73))
            p.move(to: CGPoint(x: 50, y: 19))
            p.addLine(to: CGPoint(x: 50, y: 73))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 77, y: 8))
            p.addLine(to: CGPoint(x: 60, y: 35))
            p.addLine(to: CGPoint(x: 76, y: 35))
            p.addLine(to: CGPoint(x: 62, y: 61))
            p.move(to: CGPoint(x: 24, y: 29))
            p.addLine(to: CGPoint(x: 35, y: 29))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 51), radius: 3.5) }
        let compact = make { p in
            p.move(to: CGPoint(x: 19, y: 88))
            p.addLine(to: CGPoint(x: 35, y: 73))
            p.addLine(to: CGPoint(x: 39, y: 35))
            p.addLine(to: CGPoint(x: 50, y: 19))
            p.addLine(to: CGPoint(x: 61, y: 35))
            p.addLine(to: CGPoint(x: 65, y: 73))
            p.addLine(to: CGPoint(x: 81, y: 88))
            p.closeSubpath()
            p.move(to: CGPoint(x: 78, y: 7))
            p.addLine(to: CGPoint(x: 61, y: 34))
            p.addLine(to: CGPoint(x: 77, y: 34))
            p.addLine(to: CGPoint(x: 63, y: 60))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.87)
    }

    private static func regionCrownOfDawnArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 16, y: 69))
            p.addCurve(to: CGPoint(x: 84, y: 69),
                       control1: CGPoint(x: 20, y: 28),
                       control2: CGPoint(x: 80, y: 28))
            p.move(to: CGPoint(x: 13, y: 78))
            p.addLine(to: CGPoint(x: 87, y: 78))
            p.move(to: CGPoint(x: 27, y: 62))
            p.addLine(to: CGPoint(x: 35, y: 73))
            p.addLine(to: CGPoint(x: 65, y: 73))
            p.addLine(to: CGPoint(x: 73, y: 62))
            p.addLine(to: CGPoint(x: 61, y: 67))
            p.addLine(to: CGPoint(x: 50, y: 51))
            p.addLine(to: CGPoint(x: 39, y: 67))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 50, y: 17))
            p.addLine(to: CGPoint(x: 50, y: 31))
            p.move(to: CGPoint(x: 23, y: 26))
            p.addLine(to: CGPoint(x: 33, y: 37))
            p.move(to: CGPoint(x: 77, y: 26))
            p.addLine(to: CGPoint(x: 67, y: 37))
            diamond(&p, center: CGPoint(x: 50, y: 61), radius: 5)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 61), radius: 3) }
        let compact = make { p in
            p.move(to: CGPoint(x: 15, y: 70))
            p.addCurve(to: CGPoint(x: 85, y: 70),
                       control1: CGPoint(x: 20, y: 27),
                       control2: CGPoint(x: 80, y: 27))
            p.move(to: CGPoint(x: 12, y: 79))
            p.addLine(to: CGPoint(x: 88, y: 79))
            p.move(to: CGPoint(x: 27, y: 62))
            p.addLine(to: CGPoint(x: 35, y: 73))
            p.addLine(to: CGPoint(x: 65, y: 73))
            p.addLine(to: CGPoint(x: 73, y: 62))
            p.addLine(to: CGPoint(x: 61, y: 67))
            p.addLine(to: CGPoint(x: 50, y: 51))
            p.addLine(to: CGPoint(x: 39, y: 67))
            p.closeSubpath()
            p.move(to: CGPoint(x: 50, y: 16))
            p.addLine(to: CGPoint(x: 50, y: 31))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88, opticalOffset: CGSize(width: 0, height: 1))
    }

    private static func regionElderWildsArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 50, y: 91))
            p.addLine(to: CGPoint(x: 50, y: 31))
            p.move(to: CGPoint(x: 50, y: 49))
            p.addLine(to: CGPoint(x: 29, y: 29))
            p.addLine(to: CGPoint(x: 17, y: 15))
            p.move(to: CGPoint(x: 29, y: 29))
            p.addLine(to: CGPoint(x: 24, y: 43))
            p.move(to: CGPoint(x: 50, y: 49))
            p.addLine(to: CGPoint(x: 71, y: 29))
            p.addLine(to: CGPoint(x: 83, y: 15))
            p.move(to: CGPoint(x: 71, y: 29))
            p.addLine(to: CGPoint(x: 76, y: 43))
            p.move(to: CGPoint(x: 50, y: 65))
            p.addLine(to: CGPoint(x: 33, y: 52))
            p.move(to: CGPoint(x: 50, y: 65))
            p.addLine(to: CGPoint(x: 67, y: 52))
            p.move(to: CGPoint(x: 34, y: 91))
            p.addCurve(to: CGPoint(x: 66, y: 91),
                       control1: CGPoint(x: 40, y: 80),
                       control2: CGPoint(x: 60, y: 80))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 10, y: 45))
            p.addCurve(to: CGPoint(x: 20, y: 57),
                       control1: CGPoint(x: 8, y: 47),
                       control2: CGPoint(x: 11, y: 56))
            p.addCurve(to: CGPoint(x: 37, y: 61),
                       control1: CGPoint(x: 25, y: 63),
                       control2: CGPoint(x: 31, y: 62))
            p.move(to: CGPoint(x: 80, y: 57))
            p.addCurve(to: CGPoint(x: 63, y: 61),
                       control1: CGPoint(x: 75, y: 63),
                       control2: CGPoint(x: 69, y: 62))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 49), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 50, y: 92))
            p.addLine(to: CGPoint(x: 50, y: 31))
            p.move(to: CGPoint(x: 50, y: 49))
            p.addLine(to: CGPoint(x: 29, y: 29))
            p.addLine(to: CGPoint(x: 17, y: 14))
            p.move(to: CGPoint(x: 29, y: 29))
            p.addLine(to: CGPoint(x: 24, y: 44))
            p.move(to: CGPoint(x: 50, y: 49))
            p.addLine(to: CGPoint(x: 71, y: 29))
            p.addLine(to: CGPoint(x: 83, y: 14))
            p.move(to: CGPoint(x: 71, y: 29))
            p.addLine(to: CGPoint(x: 76, y: 44))
            p.move(to: CGPoint(x: 50, y: 66))
            p.addLine(to: CGPoint(x: 32, y: 52))
            p.move(to: CGPoint(x: 50, y: 66))
            p.addLine(to: CGPoint(x: 68, y: 52))
            p.move(to: CGPoint(x: 34, y: 92))
            p.addCurve(to: CGPoint(x: 66, y: 92),
                       control1: CGPoint(x: 40, y: 80),
                       control2: CGPoint(x: 60, y: 80))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    private static func ledgerstoneArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 25, y: 11))
            p.addLine(to: CGPoint(x: 75, y: 11))
            p.addLine(to: CGPoint(x: 84, y: 23))
            p.addLine(to: CGPoint(x: 80, y: 89))
            p.addLine(to: CGPoint(x: 20, y: 89))
            p.addLine(to: CGPoint(x: 16, y: 23))
            p.closeSubpath()
            p.move(to: CGPoint(x: 25, y: 11))
            p.addLine(to: CGPoint(x: 16, y: 23))
            p.move(to: CGPoint(x: 75, y: 11))
            p.addLine(to: CGPoint(x: 84, y: 23))
        }
        let detail = make { p in
            for y in [CGFloat(35), 51, 67] {
                diamond(&p, center: CGPoint(x: 34, y: y), radius: 3)
                p.move(to: CGPoint(x: 45, y: y))
                p.addLine(to: CGPoint(x: 69, y: y))
            }
            p.move(to: CGPoint(x: 20, y: 76))
            p.addLine(to: CGPoint(x: 30, y: 68))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 34, y: 51), radius: 3) }
        let compact = make { p in
            p.move(to: CGPoint(x: 25, y: 10))
            p.addLine(to: CGPoint(x: 75, y: 10))
            p.addLine(to: CGPoint(x: 85, y: 23))
            p.addLine(to: CGPoint(x: 80, y: 90))
            p.addLine(to: CGPoint(x: 20, y: 90))
            p.addLine(to: CGPoint(x: 15, y: 23))
            p.closeSubpath()
            p.move(to: CGPoint(x: 31, y: 35))
            p.addLine(to: CGPoint(x: 69, y: 35))
            p.move(to: CGPoint(x: 31, y: 51))
            p.addLine(to: CGPoint(x: 69, y: 51))
            p.move(to: CGPoint(x: 31, y: 67))
            p.addLine(to: CGPoint(x: 69, y: 67))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.89)
    }

    private static func placementRiteArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            fourPointStar(&p, center: CGPoint(x: 50, y: 50), long: 38, short: 11)
            p.move(to: CGPoint(x: 14, y: 31))
            p.addLine(to: CGPoint(x: 14, y: 14))
            p.addLine(to: CGPoint(x: 31, y: 14))
            p.move(to: CGPoint(x: 69, y: 14))
            p.addLine(to: CGPoint(x: 86, y: 14))
            p.addLine(to: CGPoint(x: 86, y: 31))
            p.move(to: CGPoint(x: 86, y: 69))
            p.addLine(to: CGPoint(x: 86, y: 86))
            p.addLine(to: CGPoint(x: 69, y: 86))
            p.move(to: CGPoint(x: 31, y: 86))
            p.addLine(to: CGPoint(x: 14, y: 86))
            p.addLine(to: CGPoint(x: 14, y: 69))
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 10)
            p.move(to: CGPoint(x: 32, y: 50))
            p.addLine(to: CGPoint(x: 68, y: 50))
            p.move(to: CGPoint(x: 50, y: 32))
            p.addLine(to: CGPoint(x: 50, y: 68))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 5) }
        let compact = make { p in
            fourPointStar(&p, center: CGPoint(x: 50, y: 50), long: 37, short: 11)
            p.move(to: CGPoint(x: 14, y: 32))
            p.addLine(to: CGPoint(x: 14, y: 14))
            p.addLine(to: CGPoint(x: 32, y: 14))
            p.move(to: CGPoint(x: 68, y: 14))
            p.addLine(to: CGPoint(x: 86, y: 14))
            p.addLine(to: CGPoint(x: 86, y: 32))
            p.move(to: CGPoint(x: 86, y: 68))
            p.addLine(to: CGPoint(x: 86, y: 86))
            p.addLine(to: CGPoint(x: 68, y: 86))
            p.move(to: CGPoint(x: 32, y: 86))
            p.addLine(to: CGPoint(x: 14, y: 86))
            p.addLine(to: CGPoint(x: 14, y: 68))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.88)
    }

    // MARK: Product-domain symbols

    private static func quickLogArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            fourPointStar(&p, center: CGPoint(x: 50, y: 50), long: 38, short: 13)
        }
        let detail = make { p in plus(&p, center: CGPoint(x: 50, y: 50), arm: 13) }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 5) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: combined(primary, detail),
                                opticalScale: 0.90)
    }

    private static func routineArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.addRoundedRect(in: CGRect(x: 18, y: 17, width: 64, height: 68),
                             cornerSize: CGSize(width: 9, height: 9))
            p.move(to: CGPoint(x: 29, y: 17))
            p.addLine(to: CGPoint(x: 29, y: 85))
        }
        let detail = make { p in
            for y in [35.0, 50.0, 65.0] {
                diamond(&p, center: CGPoint(x: 42, y: y), radius: 3)
                p.move(to: CGPoint(x: 51, y: y))
                p.addLine(to: CGPoint(x: 70, y: y))
            }
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 29, y: 50), radius: 4) }
        let compact = make { p in
            p.addRoundedRect(in: CGRect(x: 22, y: 16, width: 58, height: 70),
                             cornerSize: CGSize(width: 8, height: 8))
            p.move(to: CGPoint(x: 34, y: 16))
            p.addLine(to: CGPoint(x: 34, y: 86))
            p.move(to: CGPoint(x: 47, y: 39))
            p.addLine(to: CGPoint(x: 68, y: 39))
            p.move(to: CGPoint(x: 47, y: 61))
            p.addLine(to: CGPoint(x: 68, y: 61))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.91)
    }

    private static func questArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 22, y: 18))
            p.addCurve(to: CGPoint(x: 34, y: 30),
                       control1: CGPoint(x: 34, y: 18),
                       control2: CGPoint(x: 34, y: 23))
            p.addLine(to: CGPoint(x: 34, y: 80))
            p.move(to: CGPoint(x: 22, y: 18))
            p.addLine(to: CGPoint(x: 70, y: 18))
            p.addCurve(to: CGPoint(x: 82, y: 30),
                       control1: CGPoint(x: 82, y: 18),
                       control2: CGPoint(x: 82, y: 23))
            p.addLine(to: CGPoint(x: 82, y: 80))
            p.addLine(to: CGPoint(x: 34, y: 80))
        }
        let detail = make { p in
            for y in [39.0, 53.0, 67.0] {
                diamond(&p, center: CGPoint(x: 46, y: y), radius: 3)
                p.move(to: CGPoint(x: 55, y: y))
                p.addLine(to: CGPoint(x: 72, y: y))
            }
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 70, y: 18), radius: 5) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: legacy(.scroll),
                                opticalScale: 0.91, opticalOffset: CGSize(width: -1, height: 0))
    }

    private static func campaignArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            // Two crossed pennants read as a coordinated multi-stage effort,
            // while the journey mark remains a solitary road/compass.
            p.move(to: CGPoint(x: 26, y: 13))
            p.addLine(to: CGPoint(x: 26, y: 86))
            p.move(to: CGPoint(x: 74, y: 13))
            p.addLine(to: CGPoint(x: 74, y: 86))
            p.move(to: CGPoint(x: 26, y: 18))
            p.addLine(to: CGPoint(x: 58, y: 27))
            p.addLine(to: CGPoint(x: 26, y: 43))
            p.closeSubpath()
            p.move(to: CGPoint(x: 74, y: 18))
            p.addLine(to: CGPoint(x: 42, y: 27))
            p.addLine(to: CGPoint(x: 74, y: 43))
            p.closeSubpath()
            p.move(to: CGPoint(x: 26, y: 86))
            p.addLine(to: CGPoint(x: 74, y: 55))
            p.move(to: CGPoint(x: 74, y: 86))
            p.addLine(to: CGPoint(x: 26, y: 55))
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 70), radius: 8)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 70), radius: 4) }
        let compact = make { p in
            p.move(to: CGPoint(x: 27, y: 14))
            p.addLine(to: CGPoint(x: 27, y: 86))
            p.move(to: CGPoint(x: 27, y: 19))
            p.addLine(to: CGPoint(x: 73, y: 32))
            p.addLine(to: CGPoint(x: 27, y: 49))
            p.closeSubpath()
            p.move(to: CGPoint(x: 27, y: 86))
            p.addLine(to: CGPoint(x: 75, y: 55))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.90)
    }

    private static func trialArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 38)
            p.move(to: CGPoint(x: 50, y: 23))
            p.addLine(to: CGPoint(x: 50, y: 77))
            p.move(to: CGPoint(x: 32, y: 50))
            p.addLine(to: CGPoint(x: 68, y: 50))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 24, y: 76))
            p.addLine(to: CGPoint(x: 76, y: 24))
            p.move(to: CGPoint(x: 24, y: 24))
            p.addLine(to: CGPoint(x: 76, y: 76))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 5) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: primary,
                                opticalScale: 0.88)
    }

    private static func chronicleArtwork() -> RPGSymbolArtwork {
        let primary = legacy(.book)
        let detail = make { p in
            p.move(to: CGPoint(x: 29, y: 39))
            p.addLine(to: CGPoint(x: 42, y: 43))
            p.move(to: CGPoint(x: 29, y: 53))
            p.addLine(to: CGPoint(x: 42, y: 57))
            p.move(to: CGPoint(x: 58, y: 43))
            p.addLine(to: CGPoint(x: 71, y: 39))
            p.move(to: CGPoint(x: 58, y: 57))
            p.addLine(to: CGPoint(x: 71, y: 53))
            p.move(to: CGPoint(x: 50, y: 26))
            p.addLine(to: CGPoint(x: 50, y: 86))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 78), radius: 4) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: legacy(.book),
                                opticalScale: 0.92, opticalOffset: CGSize(width: 0, height: 1))
    }

    private static func personalRecordArtwork() -> RPGSymbolArtwork {
        let primary = legacy(.chalice)
        let detail = make { p in fourPointStar(&p, center: CGPoint(x: 50, y: 34), long: 10, short: 3.5) }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 34), radius: 3.5) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: legacy(.chalice),
                                opticalScale: 0.92)
    }

    private static func rankArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 16, y: 76))
            p.addLine(to: CGPoint(x: 16, y: 50))
            p.addLine(to: CGPoint(x: 34, y: 63))
            p.addLine(to: CGPoint(x: 50, y: 21))
            p.addLine(to: CGPoint(x: 66, y: 63))
            p.addLine(to: CGPoint(x: 84, y: 50))
            p.addLine(to: CGPoint(x: 84, y: 76))
            p.closeSubpath()
            p.move(to: CGPoint(x: 20, y: 84))
            p.addLine(to: CGPoint(x: 80, y: 84))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 24, y: 68))
            p.addLine(to: CGPoint(x: 76, y: 68))
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 7)
            p.move(to: CGPoint(x: 13, y: 35))
            p.addLine(to: CGPoint(x: 25, y: 42))
            p.move(to: CGPoint(x: 87, y: 35))
            p.addLine(to: CGPoint(x: 75, y: 42))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 4) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: primary,
                                opticalScale: 0.90, opticalOffset: CGSize(width: 0, height: 1))
    }

    /// Bronze begins with one rising chevron and a grounded base rail.
    private static func rankBronzeArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 19, y: 68))
            p.addLine(to: CGPoint(x: 50, y: 43))
            p.addLine(to: CGPoint(x: 81, y: 68))
            p.move(to: CGPoint(x: 22, y: 82))
            p.addLine(to: CGPoint(x: 78, y: 82))
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 62), radius: 6)
            p.move(to: CGPoint(x: 34, y: 88))
            p.addLine(to: CGPoint(x: 66, y: 88))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: primary,
                                opticalScale: 0.91, opticalOffset: CGSize(width: 0, height: 2))
    }

    /// Silver adds a second course; progression is visible without its tint.
    private static func rankSilverArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 17, y: 64))
            p.addLine(to: CGPoint(x: 50, y: 39))
            p.addLine(to: CGPoint(x: 83, y: 64))
            p.move(to: CGPoint(x: 17, y: 83))
            p.addLine(to: CGPoint(x: 50, y: 58))
            p.addLine(to: CGPoint(x: 83, y: 83))
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 52), radius: 5)
            p.move(to: CGPoint(x: 28, y: 90))
            p.addLine(to: CGPoint(x: 72, y: 90))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: primary,
                                opticalScale: 0.90, opticalOffset: CGSize(width: 0, height: 1))
    }

    /// Gold completes the three-course coronet used by the early ranks.
    private static func rankGoldArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            for y in [CGFloat(42), 62, 82] {
                p.move(to: CGPoint(x: 18, y: y))
                p.addLine(to: CGPoint(x: 50, y: y - 20))
                p.addLine(to: CGPoint(x: 82, y: y))
            }
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 24, y: 91))
            p.addLine(to: CGPoint(x: 76, y: 91))
            diamond(&p, center: CGPoint(x: 50, y: 14), radius: 5)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: primary,
                                opticalScale: 0.89, opticalOffset: CGSize(width: 0, height: 1))
    }

    /// Platinum graduates from chevrons into a guarded standard and lozenge.
    private static func rankPlatinumArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 22, y: 17))
            p.addLine(to: CGPoint(x: 78, y: 17))
            p.addLine(to: CGPoint(x: 74, y: 62))
            p.addLine(to: CGPoint(x: 50, y: 87))
            p.addLine(to: CGPoint(x: 26, y: 62))
            p.closeSubpath()
            diamond(&p, center: CGPoint(x: 50, y: 49), radius: 15)
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 34, y: 25))
            p.addLine(to: CGPoint(x: 66, y: 25))
            p.move(to: CGPoint(x: 50, y: 34))
            p.addLine(to: CGPoint(x: 50, y: 64))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: primary,
                                opticalScale: 0.90)
    }

    /// Diamond is one large faceted stone — unmistakable at thirteen points.
    private static func rankDiamondArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 20, y: 35))
            p.addLine(to: CGPoint(x: 34, y: 17))
            p.addLine(to: CGPoint(x: 66, y: 17))
            p.addLine(to: CGPoint(x: 80, y: 35))
            p.addLine(to: CGPoint(x: 50, y: 86))
            p.closeSubpath()
            p.move(to: CGPoint(x: 20, y: 35))
            p.addLine(to: CGPoint(x: 80, y: 35))
            p.move(to: CGPoint(x: 34, y: 17))
            p.addLine(to: CGPoint(x: 43, y: 35))
            p.addLine(to: CGPoint(x: 50, y: 86))
            p.move(to: CGPoint(x: 66, y: 17))
            p.addLine(to: CGPoint(x: 57, y: 35))
            p.addLine(to: CGPoint(x: 50, y: 86))
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 51), radius: 6)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: primary,
                                opticalScale: 0.90)
    }

    /// Master is a fixed compass star: reach in four directions, held at center.
    private static func rankMasterArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            fourPointStar(&p, center: CGPoint(x: 50, y: 50), long: 40, short: 12)
            p.move(to: CGPoint(x: 9, y: 50))
            p.addLine(to: CGPoint(x: 23, y: 50))
            p.move(to: CGPoint(x: 77, y: 50))
            p.addLine(to: CGPoint(x: 91, y: 50))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 20, y: 20))
            p.addLine(to: CGPoint(x: 29, y: 29))
            p.move(to: CGPoint(x: 80, y: 20))
            p.addLine(to: CGPoint(x: 71, y: 29))
            p.move(to: CGPoint(x: 20, y: 80))
            p.addLine(to: CGPoint(x: 29, y: 71))
            p.move(to: CGPoint(x: 80, y: 80))
            p.addLine(to: CGPoint(x: 71, y: 71))
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 7)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: primary,
                                opticalScale: 0.89)
    }

    /// Grandmaster carries the final lozenge between radiant crown wings.
    private static func rankGrandmasterArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 52), radius: 20)
            p.move(to: CGPoint(x: 29, y: 50))
            p.addLine(to: CGPoint(x: 15, y: 37))
            p.addLine(to: CGPoint(x: 9, y: 51))
            p.addLine(to: CGPoint(x: 26, y: 66))
            p.move(to: CGPoint(x: 71, y: 50))
            p.addLine(to: CGPoint(x: 85, y: 37))
            p.addLine(to: CGPoint(x: 91, y: 51))
            p.addLine(to: CGPoint(x: 74, y: 66))
            p.move(to: CGPoint(x: 32, y: 30))
            p.addLine(to: CGPoint(x: 39, y: 13))
            p.addLine(to: CGPoint(x: 50, y: 27))
            p.addLine(to: CGPoint(x: 61, y: 13))
            p.addLine(to: CGPoint(x: 68, y: 30))
            p.move(to: CGPoint(x: 31, y: 79))
            p.addLine(to: CGPoint(x: 69, y: 79))
        }
        let detail = make { p in
            fourPointStar(&p, center: CGPoint(x: 50, y: 52), long: 12, short: 4)
            p.move(to: CGPoint(x: 12, y: 72))
            p.addLine(to: CGPoint(x: 26, y: 68))
            p.move(to: CGPoint(x: 88, y: 72))
            p.addLine(to: CGPoint(x: 74, y: 68))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail, compact: primary,
                                opticalScale: 0.88)
    }

    /// Three deliberately disconnected standards show that every attribute
    /// owns its rank instead of inheriting one overall character tier.
    private static func rankIndependentArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            for (x, top) in [(CGFloat(22), CGFloat(49)), (50, 25), (78, 39)] {
                p.move(to: CGPoint(x: x - 8, y: 84))
                p.addLine(to: CGPoint(x: x - 8, y: top))
                p.addLine(to: CGPoint(x: x, y: top - 9))
                p.addLine(to: CGPoint(x: x + 8, y: top))
                p.addLine(to: CGPoint(x: x + 8, y: 84))
                p.addLine(to: CGPoint(x: x - 8, y: 84))
            }
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 22, y: 61), radius: 4)
            diamond(&p, center: CGPoint(x: 50, y: 39), radius: 4)
            diamond(&p, center: CGPoint(x: 78, y: 52), radius: 4)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 39), radius: 3) }
        let compact = make { p in
            for (x, top) in [(CGFloat(24), CGFloat(48)), (50, 25), (76, 39)] {
                p.move(to: CGPoint(x: x, y: 82))
                p.addLine(to: CGPoint(x: x, y: top))
                p.move(to: CGPoint(x: x - 7, y: top + 8))
                p.addLine(to: CGPoint(x: x, y: top))
                p.addLine(to: CGPoint(x: x + 7, y: top + 8))
            }
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill,
                                compact: compact,
                                opticalScale: 0.88,
                                opticalOffset: CGSize(width: 0, height: 1))
    }

    /// A stepped rank rail terminating in a live jewel conveys that standings
    /// are recomputed from the latest logged work, not fixed at onboarding.
    private static func rankCurrentArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 13, y: 79))
            p.addLine(to: CGPoint(x: 32, y: 60))
            p.addLine(to: CGPoint(x: 45, y: 70))
            p.addLine(to: CGPoint(x: 75, y: 36))
            p.move(to: CGPoint(x: 59, y: 37))
            p.addLine(to: CGPoint(x: 77, y: 34))
            p.addLine(to: CGPoint(x: 75, y: 52))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 20, y: 86))
            p.addLine(to: CGPoint(x: 39, y: 67))
            p.move(to: CGPoint(x: 51, y: 62))
            p.addLine(to: CGPoint(x: 68, y: 43))
            diamond(&p, center: CGPoint(x: 79, y: 24), radius: 8)
        }
        let accent = make { p in fourPointStar(&p, center: CGPoint(x: 79, y: 24), long: 10, short: 3) }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 79, y: 24), radius: 3.5) }
        let compact = make { p in
            p.move(to: CGPoint(x: 14, y: 80))
            p.addLine(to: CGPoint(x: 33, y: 60))
            p.addLine(to: CGPoint(x: 46, y: 70))
            p.addLine(to: CGPoint(x: 76, y: 35))
            p.move(to: CGPoint(x: 59, y: 37))
            p.addLine(to: CGPoint(x: 78, y: 34))
            p.addLine(to: CGPoint(x: 75, y: 53))
            diamond(&p, center: CGPoint(x: 79, y: 23), radius: 8)
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accent: accent, accentFill: accentFill,
                                compact: compact, opticalScale: 0.88)
    }

    private static func streakArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 50, y: 10))
            p.addCurve(to: CGPoint(x: 79, y: 61),
                       control1: CGPoint(x: 53, y: 31),
                       control2: CGPoint(x: 78, y: 38))
            p.addCurve(to: CGPoint(x: 50, y: 91),
                       control1: CGPoint(x: 79, y: 79),
                       control2: CGPoint(x: 65, y: 91))
            p.addCurve(to: CGPoint(x: 21, y: 61),
                       control1: CGPoint(x: 35, y: 91),
                       control2: CGPoint(x: 21, y: 79))
            p.addCurve(to: CGPoint(x: 38, y: 31),
                       control1: CGPoint(x: 20, y: 44),
                       control2: CGPoint(x: 32, y: 38))
            p.addCurve(to: CGPoint(x: 50, y: 10),
                       control1: CGPoint(x: 43, y: 24),
                       control2: CGPoint(x: 46, y: 16))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 50, y: 42))
            p.addCurve(to: CGPoint(x: 64, y: 67),
                       control1: CGPoint(x: 59, y: 50),
                       control2: CGPoint(x: 64, y: 57))
            p.addCurve(to: CGPoint(x: 50, y: 82),
                       control1: CGPoint(x: 64, y: 76),
                       control2: CGPoint(x: 57, y: 82))
            p.addCurve(to: CGPoint(x: 36, y: 67),
                       control1: CGPoint(x: 43, y: 82),
                       control2: CGPoint(x: 36, y: 76))
            p.addCurve(to: CGPoint(x: 50, y: 42),
                       control1: CGPoint(x: 36, y: 55),
                       control2: CGPoint(x: 45, y: 51))
            p.closeSubpath()
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 65), radius: 4) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: primary,
                                opticalScale: 0.88)
    }

    private static func streakFreezeArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            for angle in stride(from: CGFloat.zero, to: .pi, by: .pi / 3) {
                let dx = cos(angle) * 38
                let dy = sin(angle) * 38
                p.move(to: CGPoint(x: 50 - dx, y: 50 - dy))
                p.addLine(to: CGPoint(x: 50 + dx, y: 50 + dy))
            }
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 50, y: 50), radius: 9)
            for angle in stride(from: CGFloat.zero, to: .pi * 2, by: .pi / 3) {
                let x = 50 + cos(angle) * 25
                let y = 50 + sin(angle) * 25
                diamond(&p, center: CGPoint(x: x, y: y), radius: 3.5)
            }
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 4) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: combined(primary, detail),
                                opticalScale: 0.89)
    }

    private static func satchelArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.addRoundedRect(in: CGRect(x: 22, y: 25, width: 56, height: 63),
                             cornerSize: CGSize(width: 9, height: 9))
            p.addRoundedRect(in: CGRect(x: 32, y: 10, width: 36, height: 25),
                             cornerSize: CGSize(width: 12, height: 12))
            p.move(to: CGPoint(x: 22, y: 44))
            p.addLine(to: CGPoint(x: 11, y: 49))
            p.addLine(to: CGPoint(x: 11, y: 75))
            p.addLine(to: CGPoint(x: 22, y: 79))
            p.move(to: CGPoint(x: 78, y: 44))
            p.addLine(to: CGPoint(x: 89, y: 49))
            p.addLine(to: CGPoint(x: 89, y: 75))
            p.addLine(to: CGPoint(x: 78, y: 79))
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 28, y: 45))
            p.addLine(to: CGPoint(x: 72, y: 45))
            p.move(to: CGPoint(x: 35, y: 31))
            p.addLine(to: CGPoint(x: 35, y: 80))
            p.move(to: CGPoint(x: 65, y: 31))
            p.addLine(to: CGPoint(x: 65, y: 80))
            diamond(&p, center: CGPoint(x: 50, y: 46), radius: 7)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 46), radius: 3.5) }
        let compact = make { p in
            p.addRoundedRect(in: CGRect(x: 24, y: 27, width: 52, height: 61),
                             cornerSize: CGSize(width: 8, height: 8))
            p.addRoundedRect(in: CGRect(x: 35, y: 11, width: 30, height: 27),
                             cornerSize: CGSize(width: 12, height: 12))
            p.move(to: CGPoint(x: 24, y: 49))
            p.addLine(to: CGPoint(x: 76, y: 49))
            p.move(to: CGPoint(x: 42, y: 49))
            p.addLine(to: CGPoint(x: 42, y: 88))
            p.move(to: CGPoint(x: 58, y: 49))
            p.addLine(to: CGPoint(x: 58, y: 88))
        }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: compact,
                                opticalScale: 0.90, opticalOffset: CGSize(width: 0, height: 1))
    }

    private static func chestArtwork() -> RPGSymbolArtwork {
        let detail = make { p in
            p.move(to: CGPoint(x: 20, y: 48))
            p.addLine(to: CGPoint(x: 80, y: 48))
            diamond(&p, center: CGPoint(x: 50, y: 60), radius: 5)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 60), radius: 3) }
        return RPGSymbolArtwork(primary: legacy(.chest), detail: detail,
                                accentFill: accentFill, compact: legacy(.chest),
                                opticalScale: 0.93)
    }

    private static func companionArtwork() -> RPGSymbolArtwork {
        // Side-profile companion head: deliberately asymmetric against the
        // player's centered crest so both survive a monochrome 18-point tab.
        let primary = make { p in
            p.move(to: CGPoint(x: 17, y: 75))
            p.addLine(to: CGPoint(x: 29, y: 54))
            p.addLine(to: CGPoint(x: 25, y: 27))
            p.addLine(to: CGPoint(x: 43, y: 38))
            p.addCurve(to: CGPoint(x: 69, y: 44),
                       control1: CGPoint(x: 52, y: 35),
                       control2: CGPoint(x: 62, y: 37))
            p.addLine(to: CGPoint(x: 87, y: 58))
            p.addLine(to: CGPoint(x: 69, y: 69))
            p.addCurve(to: CGPoint(x: 43, y: 71),
                       control1: CGPoint(x: 59, y: 76),
                       control2: CGPoint(x: 50, y: 76))
            p.addLine(to: CGPoint(x: 34, y: 87))
            p.addLine(to: CGPoint(x: 17, y: 75))
            p.closeSubpath()
        }
        let detail = make { p in
            p.move(to: CGPoint(x: 28, y: 56))
            p.addLine(to: CGPoint(x: 18, y: 49))
            p.move(to: CGPoint(x: 30, y: 65))
            p.addLine(to: CGPoint(x: 19, y: 64))
        }
        let accent = make { p in
            fourPointStar(&p, center: CGPoint(x: 76, y: 23), long: 8, short: 2.5)
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 58, y: 49), radius: 3.5) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accent: accent, accentFill: accentFill,
                                compact: primary, opticalScale: 0.90,
                                opticalOffset: CGSize(width: 0, height: 1))
    }

    private static func companionBondArtwork() -> RPGSymbolArtwork {
        let endurance = focusEnduranceArtwork()
        let detail = make { p in
            p.move(to: CGPoint(x: 50, y: 72))
            p.addLine(to: CGPoint(x: 50, y: 39))
            p.move(to: CGPoint(x: 50, y: 48))
            p.addLine(to: CGPoint(x: 35, y: 34))
            p.move(to: CGPoint(x: 50, y: 48))
            p.addLine(to: CGPoint(x: 65, y: 34))
            diamond(&p, center: CGPoint(x: 50, y: 55), radius: 7)
        }
        let accent = make { p in plus(&p, center: CGPoint(x: 50, y: 55), arm: 5) }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 55), radius: 2.5) }
        return RPGSymbolArtwork(primary: endurance.primary, detail: detail,
                                accent: accent, accentFill: accentFill,
                                compact: combined(endurance.primary, detail),
                                opticalScale: 0.92)
    }

    private static func companionEggArtwork() -> RPGSymbolArtwork {
        let detail = make { p in
            p.move(to: CGPoint(x: 34, y: 56))
            p.addLine(to: CGPoint(x: 43, y: 47))
            p.addLine(to: CGPoint(x: 51, y: 57))
            p.addLine(to: CGPoint(x: 59, y: 47))
            p.addLine(to: CGPoint(x: 67, y: 56))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 51, y: 57), radius: 3.5) }
        return RPGSymbolArtwork(primary: legacy(.egg), detail: detail,
                                accentFill: accentFill, compact: legacy(.egg),
                                opticalScale: 0.91)
    }

    private static func xpArtwork() -> RPGSymbolArtwork {
        let primary = make { p in fourPointStar(&p, center: CGPoint(x: 50, y: 50), long: 40, short: 12) }
        let detail = make { p in
            p.move(to: CGPoint(x: 22, y: 22))
            p.addLine(to: CGPoint(x: 31, y: 31))
            p.move(to: CGPoint(x: 78, y: 22))
            p.addLine(to: CGPoint(x: 69, y: 31))
            p.move(to: CGPoint(x: 22, y: 78))
            p.addLine(to: CGPoint(x: 31, y: 69))
            p.move(to: CGPoint(x: 78, y: 78))
            p.addLine(to: CGPoint(x: 69, y: 69))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 6) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: legacy(.spark),
                                opticalScale: 0.90)
    }

    private static func mightArtwork() -> RPGSymbolArtwork {
        let primary = make { p in
            p.move(to: CGPoint(x: 58, y: 8))
            p.addLine(to: CGPoint(x: 24, y: 55))
            p.addLine(to: CGPoint(x: 45, y: 55))
            p.addLine(to: CGPoint(x: 36, y: 92))
            p.addLine(to: CGPoint(x: 77, y: 42))
            p.addLine(to: CGPoint(x: 55, y: 42))
            p.closeSubpath()
        }
        let detail = make { p in
            diamond(&p, center: CGPoint(x: 76, y: 21), radius: 7)
            p.move(to: CGPoint(x: 18, y: 71))
            p.addLine(to: CGPoint(x: 29, y: 71))
        }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 76, y: 21), radius: 3.5) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: primary,
                                opticalScale: 0.89)
    }

    private static func coinArtwork() -> RPGSymbolArtwork {
        let primary = legacy(.coin)
        let detail = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 13) }
        let accentFill = make { p in diamond(&p, center: CGPoint(x: 50, y: 50), radius: 4) }
        return RPGSymbolArtwork(primary: primary, detail: detail,
                                accentFill: accentFill, compact: legacy(.coin),
                                opticalScale: 0.91)
    }
}

private extension RPGSymbol {
    var artwork: RPGSymbolArtwork {
        RPGSymbolArtworkFactory.artwork(for: self)
    }
}

// MARK: - SwiftUI renderer

private struct RPGSymbolPathShape: Shape {
    let source: Path
    let opticalScale: CGFloat
    let opticalOffset: CGSize

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100 * opticalScale
        let dx = rect.midX - 50 * scale + opticalOffset.width * scale
        let dy = rect.midY - 50 * scale + opticalOffset.height * scale
        let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: dx, ty: dy)
        return source.applying(transform)
    }
}

private struct RPGSymbolResolvedPalette {
    let primary: Color
    let detail: Color
    let accent: Color
    let accentFill: Color
    let glow: Color
    let isMonochrome: Bool
}

struct RPGSymbolIcon: View {
    let symbol: RPGSymbol
    var size: CGFloat = 20
    var presentation: RPGSymbolPresentation = .automatic
    var palette: RPGSymbolPalette = .adaptive

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    init(
        symbol: RPGSymbol,
        size: CGFloat = 20,
        presentation: RPGSymbolPresentation = .automatic,
        palette: RPGSymbolPalette = .adaptive
    ) {
        self.symbol = symbol
        self.size = size
        self.presentation = presentation
        self.palette = palette
    }

    private var resolvedPresentation: RPGSymbolPresentation {
        switch presentation {
        case .automatic:
            return size < 24 ? .compact : .standard
        default:
            return presentation
        }
    }

    private var resolvedPalette: RPGSymbolResolvedPalette {
        let base: RPGSymbolResolvedPalette
        switch palette {
        case .adaptive:
            base = RPGSymbolResolvedPalette(
                primary: RPGTheme.symbolPrimary,
                detail: RPGTheme.symbolSecondary,
                accent: RPGTheme.symbolAccent,
                accentFill: RPGTheme.symbolAccent,
                glow: RPGTheme.symbolGlow,
                isMonochrome: false
            )
        case .onPlate:
            base = RPGSymbolResolvedPalette(
                primary: RPGTheme.onPlate,
                detail: RPGTheme.symbolSecondary,
                accent: RPGTheme.symbolAccent,
                accentFill: RPGTheme.symbolAccent,
                glow: RPGTheme.symbolGlow,
                isMonochrome: false
            )
        case .monochrome(let color):
            base = RPGSymbolResolvedPalette(
                primary: color,
                detail: color,
                accent: color,
                accentFill: color,
                glow: color,
                isMonochrome: true
            )
        case .themed(let color):
            if usesCompactArtwork {
                base = RPGSymbolResolvedPalette(
                    primary: color,
                    detail: color,
                    accent: color,
                    accentFill: color,
                    glow: color,
                    isMonochrome: true
                )
            } else {
                base = RPGSymbolResolvedPalette(
                    primary: color,
                    detail: RPGTheme.symbolSecondary,
                    accent: RPGTheme.symbolAccent,
                    accentFill: RPGTheme.symbolAccent,
                    glow: color,
                    isMonochrome: false
                )
            }
        }

        guard differentiateWithoutColor, !base.isMonochrome else { return base }
        // The jewel remains a distinct filled shape with a crisp outline, but
        // no state or meaning relies on green versus gold alone.
        return RPGSymbolResolvedPalette(
            primary: base.primary,
            detail: base.detail,
            accent: base.primary,
            accentFill: base.primary,
            glow: base.glow,
            isMonochrome: false
        )
    }

    private var usesCompactArtwork: Bool {
        resolvedPresentation == .compact
    }

    private var contrastMultiplier: CGFloat {
        colorSchemeContrast == .increased ? 1.18 : 1
    }

    private var primaryLineWidth: CGFloat {
        let fraction: CGFloat
        switch resolvedPresentation {
        case .compact: fraction = 0.088
        case .standard, .automatic: fraction = 0.068
        case .hero: fraction = 0.064
        case .reward: fraction = 0.069
        }
        return max(colorSchemeContrast == .increased ? 1.35 : 1, size * fraction * contrastMultiplier)
    }

    private var detailLineWidth: CGFloat {
        max(1, size * 0.041 * contrastMultiplier)
    }

    private var accentLineWidth: CGFloat {
        max(1, size * 0.047 * contrastMultiplier)
    }

    private var allowsGlow: Bool {
        guard colorScheme == .dark,
              !reduceTransparency,
              !resolvedPalette.isMonochrome else { return false }
        return resolvedPresentation == .hero || resolvedPresentation == .reward
    }

    var body: some View {
        let artwork = symbol.artwork
        let colors = resolvedPalette
        let shapeScale = artwork.opticalScale
        let shapeOffset = artwork.opticalOffset

        ZStack {
            if allowsGlow {
                RPGSymbolPathShape(source: artwork.primary,
                                   opticalScale: shapeScale,
                                   opticalOffset: shapeOffset)
                    .stroke(colors.glow.opacity(resolvedPresentation == .reward ? 0.42 : 0.30),
                            style: StrokeStyle(lineWidth: primaryLineWidth * 1.65,
                                               lineCap: .round,
                                               lineJoin: .round))
                    .blur(radius: max(1.5, size * 0.055))
            }

            if usesCompactArtwork {
                RPGSymbolPathShape(source: artwork.compact,
                                   opticalScale: shapeScale,
                                   opticalOffset: shapeOffset)
                    .stroke(colors.primary,
                            style: StrokeStyle(lineWidth: primaryLineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))
            } else {
                RPGSymbolPathShape(source: artwork.primary,
                                   opticalScale: shapeScale,
                                   opticalOffset: shapeOffset)
                    .stroke(colors.primary,
                            style: StrokeStyle(lineWidth: primaryLineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))

                RPGSymbolPathShape(source: artwork.detail,
                                   opticalScale: shapeScale,
                                   opticalOffset: shapeOffset)
                    .stroke(colors.detail,
                            style: StrokeStyle(lineWidth: detailLineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))

                RPGSymbolPathShape(source: artwork.accent,
                                   opticalScale: shapeScale,
                                   opticalOffset: shapeOffset)
                    .stroke(colors.accent,
                            style: StrokeStyle(lineWidth: accentLineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))

                RPGSymbolPathShape(source: artwork.accentFill,
                                   opticalScale: shapeScale,
                                   opticalOffset: shapeOffset)
                    .fill(colors.accentFill)

                // A shape boundary means the accent remains identifiable when
                // Differentiate Without Color removes the chromatic distinction.
                RPGSymbolPathShape(source: artwork.accentFill,
                                   opticalScale: shapeScale,
                                   opticalOffset: shapeOffset)
                    .stroke(differentiateWithoutColor ? colors.detail : colors.primary.opacity(0.72),
                            style: StrokeStyle(lineWidth: max(0.8, detailLineWidth * 0.52),
                                               lineCap: .round,
                                               lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .accessibilityHidden(true)
    }
}

/// A semantic Label that also survives UIKit-owned menu and context-menu
/// surfaces. The compact artwork is rendered as a template so the platform
/// can apply its normal menu tint without substituting an SF Symbol.
struct RPGSymbolLabel: View {
    let title: String
    let symbol: RPGSymbol
    var pointSize: CGFloat = 17

    init(_ title: String, symbol: RPGSymbol, pointSize: CGFloat = 17) {
        self.title = title
        self.symbol = symbol
        self.pointSize = pointSize
    }

    var body: some View {
        Label {
            Text(LocalizedStringKey(title))
        } icon: {
            Image(uiImage: symbol.uiImage(pointSize: pointSize))
                .renderingMode(.template)
        }
    }
}

// MARK: - UIKit template rendering

extension RPGSymbol {
    private static let templateImageCache = NSCache<NSString, UIImage>()

    /// Compact, one-color rendering for UIKit-owned surfaces such as TabView.
    /// It intentionally omits detail colors and glow because UIKit applies tint
    /// to template images after rendering.
    func uiImage(pointSize: CGFloat) -> UIImage {
        let safePointSize = max(1, pointSize)
        let key = "\(rawValue)-\(safePointSize)" as NSString
        if let cached = Self.templateImageCache.object(forKey: key) {
            return cached
        }

        let artwork = artwork
        let renderSize = CGSize(width: safePointSize, height: safePointSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        let image = renderer.image { context in
            let inset = safePointSize * 0.07
            let rect = CGRect(origin: .zero, size: renderSize).insetBy(dx: inset, dy: inset)
            let path = RPGSymbolPathShape(
                source: artwork.compact,
                opticalScale: artwork.opticalScale,
                opticalOffset: artwork.opticalOffset
            ).path(in: rect)

            let bezier = UIBezierPath(cgPath: path.cgPath)
            bezier.lineWidth = max(1, safePointSize * 0.085)
            bezier.lineCapStyle = .round
            bezier.lineJoinStyle = .round
            UIColor.black.setStroke()
            context.cgContext.setAllowsAntialiasing(true)
            bezier.stroke()
        }.withRenderingMode(.alwaysTemplate)

        Self.templateImageCache.setObject(image, forKey: key)
        return image
    }
}

// MARK: - Model mappings

extension Stat {
    var rpgSymbol: RPGSymbol {
        switch self {
        case .size: return .statSize
        case .strength: return .statStrength
        case .dexterity: return .statDexterity
        case .agility: return .statAgility
        case .endurance: return .statEndurance
        case .vitality: return .statVitality
        }
    }
}

extension RankTier {
    /// Rank color communicates material; rank shape communicates progression.
    /// Keeping both prevents the seven tiers from collapsing for color-blind
    /// users and in monochrome widgets, menus, or screenshots.
    var rpgSymbol: RPGSymbol {
        switch self {
        case .bronze: return .rankBronze
        case .silver: return .rankSilver
        case .gold: return .rankGold
        case .platinum: return .rankPlatinum
        case .diamond: return .rankDiamond
        case .master: return .rankMaster
        case .grandmaster: return .rankGrandmaster
        }
    }
}

extension RPGClass {
    /// Persisted class identity remains unchanged; the legacy `.quality` case
    /// intentionally maps to the user-facing Duelist crest.
    var rpgSymbol: RPGSymbol {
        switch self {
        case .warrior: return .classWarrior
        case .quality: return .classDuelist
        case .berserker: return .classBerserker
        case .paladin: return .classPaladin
        case .assassin: return .classAssassin
        case .monk: return .classMonk
        case .ranger: return .classRanger
        case .scout: return .classScout
        case .tank: return .classTank
        case .brawler: return .classBrawler
        case .titan: return .classTitan
        case .juggernaut: return .classJuggernaut
        case .spartan: return .classSpartan
        case .druid: return .classDruid
        case .healer: return .classHealer
        }
    }
}

extension FocusGroup {
    var rpgSymbol: RPGSymbol {
        switch self {
        case .strength: return .focusStrength
        case .hypertrophy: return .focusHypertrophy
        case .bodyweight: return .focusBodyweight
        case .explosive: return .focusExplosive
        case .endurance: return .focusEndurance
        case .mobility: return .focusMobility
        }
    }
}

// MARK: - Visual QA

#if DEBUG
private struct RPGSymbolPreviewGallery: View {
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 20) {
                gallery(for: .light)
                gallery(for: .dark)
            }
            .padding(20)
        }
        .background(Color.gray.opacity(0.14))
    }

    private func gallery(for scheme: ColorScheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scheme == .dark ? "Dark" : "Light")
                .font(.headline)

            ForEach(RPGSymbol.allCases, id: \.rawValue) { symbol in
                HStack(spacing: 14) {
                    RPGSymbolIcon(symbol: symbol, size: 18, presentation: .compact)
                        .frame(width: 28)
                    RPGSymbolIcon(symbol: symbol, size: 30, presentation: .standard)
                        .frame(width: 40)
                    RPGSymbolIcon(symbol: symbol, size: 54, presentation: .hero)
                        .frame(width: 64)
                    Text(symbol.rawValue)
                        .font(.caption.monospaced())
                        .frame(width: 140, alignment: .leading)
                }
                .frame(minHeight: 62)
            }
        }
        .padding(18)
        .foregroundStyle(scheme == .dark ? Color.white : Color.black)
        .background(RPGTheme.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.colorScheme, scheme)
    }
}

#Preview("RPG Symbol Matrix") {
    RPGSymbolPreviewGallery()
        .frame(height: 900)
}
#endif
