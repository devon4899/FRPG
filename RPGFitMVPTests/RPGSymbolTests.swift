import Foundation
import Testing
import UIKit
@testable import RPGFitMVP

@Suite("RPG symbol system")
struct RPGSymbolTests {
    @Test func semanticCatalogIsCompleteAndStable() {
        #expect(RPGSymbol.allCases.count == 96)
        #expect(Set(RPGSymbol.allCases.map(\.rawValue)).count == RPGSymbol.allCases.count)
    }

    @Test func legacyPersistedGlyphIdentifiersRemainStable() {
        let persistedIdentifiers = [
            "sword", "mountains", "bow", "wing", "shield", "potion",
            "crest", "dumbbell", "scroll", "book", "chest", "compass",
            "chart", "rune", "chalice", "egg", "coin", "spark", "crown"
        ]

        #expect(RPGGlyph.allCases.map(\.rawValue) == persistedIdentifiers)
        #expect(persistedIdentifiers.allSatisfy { RPGGlyph(rawValue: $0) != nil })
    }

    @Test func modelMeaningsMapToDedicatedSymbols() {
        #expect(Stat.allCases.map(\.rpgSymbol) == [
            .statSize, .statStrength, .statDexterity,
            .statAgility, .statEndurance, .statVitality
        ])
        #expect(FocusGroup.allCases.map(\.rpgSymbol) == [
            .focusStrength, .focusHypertrophy, .focusEndurance,
            .focusExplosive, .focusMobility, .focusBodyweight
        ])
        #expect(RankTier.allCases.map(\.rpgSymbol) == [
            .rankBronze, .rankSilver, .rankGold, .rankPlatinum,
            .rankDiamond, .rankMaster, .rankGrandmaster
        ])
        #expect(RPGClass.allCases.map(\.rpgSymbol) == [
            .classWarrior, .classDuelist, .classBerserker, .classPaladin,
            .classAssassin, .classMonk, .classRanger, .classScout,
            .classTank, .classBrawler, .classTitan, .classJuggernaut,
            .classSpartan, .classDruid, .classHealer
        ])

        #expect(EquipSlot.allCases.map(\.rpgSymbol) == [
            .equipmentArms, .equipmentGuard, .equipmentRelic
        ])
        #expect(InventoryItemType.allCases.map(\.rpgSymbol) == [
            .lootConsumable, .lootEquipment, .lootMaterial, .lootCollectible
        ])
        #expect(CampaignRegion.all.map(\.rpgSymbol) == [
            .regionKindlingVale, .regionAshenPasses, .regionStormreach,
            .regionCrownOfDawn
        ])
        #expect(
            CampaignRegion(name: "The Elder Wilds", flavor: "", rungs: 12...14).rpgSymbol
                == .regionElderWilds
        )
    }

    @Test func persistedLootIdentifiersRemainStableWhileMeaningsAreSemantic() {
        #expect(EquipSlot.allCases.map(\.rawValue) == ["arms", "guardSlot", "relic"])
        #expect(InventoryItemType.allCases.map(\.rawValue) == [
            "consumable", "equipment", "material", "collectible"
        ])

        let loot: [(String, RPGSymbol)] = [
            (UncommonTierItem.soccerball.iconName, .lootBuckler),
            (UncommonTierItem.basketball.iconName, .lootTonic),
            (UncommonTierItem.volleyball.iconName, .lootMap),
            (RareTierItem.dice.iconName, .lootDice),
            (RareTierItem.puzzlepiece.iconName, .lootRuneFragment),
            (RareTierItem.balloon.iconName, .lootPhoenixFeather),
            (EpicTierItem.birthdaycake.iconName, .lootChalice),
            (EpicTierItem.gamecontroller.iconName, .lootTome),
            (LegendaryTierItem.trophy.iconName, .lootTrophy),
            (LegendaryTierItem.wand.iconName, .lootWand),
            (MythicTierItem.teddybear.iconName, .lootCrown)
        ]
        #expect(loot.map(\.0) == [
            "glyph:shield", "glyph:potion", "glyph:scroll",
            "dice.fill", "glyph:rune", "glyph:wing",
            "glyph:chalice", "glyph:book", "trophy.fill",
            "wand.and.stars", "glyph:crown"
        ])

        let semanticLoot: [RPGSymbol] = [
            ItemInfo.uncommon(.soccerball).rpgSymbol,
            ItemInfo.uncommon(.basketball).rpgSymbol,
            ItemInfo.uncommon(.volleyball).rpgSymbol,
            ItemInfo.rare(.dice).rpgSymbol,
            ItemInfo.rare(.puzzlepiece).rpgSymbol,
            ItemInfo.rare(.balloon).rpgSymbol,
            ItemInfo.epic(.birthdaycake).rpgSymbol,
            ItemInfo.epic(.gamecontroller).rpgSymbol,
            ItemInfo.legendary(.trophy).rpgSymbol,
            ItemInfo.legendary(.wand).rpgSymbol,
            ItemInfo.mythic(.teddybear).rpgSymbol
        ]
        #expect(semanticLoot == loot.map(\.1))
    }

    @MainActor
    @Test func tabSymbolsRenderAsDistinctTemplateImages() throws {
        let symbols: [RPGSymbol] = [.character, .training, .journey, .progress]
        let images = symbols.map { $0.uiImage(pointSize: 26) }

        #expect(images.allSatisfy { $0.size == CGSize(width: 26, height: 26) })
        #expect(images.allSatisfy { $0.renderingMode == .alwaysTemplate })
        let encoded = try images.map { try #require($0.pngData()) }
        #expect(Set(encoded).count == symbols.count)
    }

    @MainActor
    @Test func denseProductSymbolsKeepDistinctSilhouettes() throws {
        let pairs: [(RPGSymbol, RPGSymbol)] = [
            (.routine, .quest),
            (.journey, .campaign),
            (.progress, .chronicle),
            (.focusStrength, .trial),
            (.character, .companion),
            (.satchel, .chest)
        ]

        for (left, right) in pairs {
            let leftData = try #require(left.uiImage(pointSize: 18).pngData())
            let rightData = try #require(right.uiImage(pointSize: 18).pngData())
            #expect(leftData != rightData, "\(left.rawValue) and \(right.rawValue) collapse at compact size")
        }
    }

    @MainActor
    @Test func newSymbolFamiliesRemainDistinctAtCompactSize() throws {
        let families: [[RPGSymbol]] = [
            [.rest, .metricDuration, .streak],
            [
                .repeatSession, .plateCalculator, .exerciseSwap,
                .superset, .setWarmup, .setWorking, .completionSeal
            ],
            [.equipmentArms, .equipmentGuard, .equipmentRelic, .equipped],
            [.rank, .rankIndependent, .rankCurrent],
            [
                .rankBronze, .rankSilver, .rankGold, .rankPlatinum,
                .rankDiamond, .rankMaster, .rankGrandmaster
            ],
            [
                .classWarrior, .classDuelist, .classBerserker, .classPaladin,
                .classAssassin, .classMonk, .classRanger, .classScout,
                .classTank, .classBrawler, .classTitan, .classJuggernaut,
                .classSpartan, .classDruid, .classHealer
            ],
            [.lootConsumable, .lootEquipment, .lootMaterial, .lootCollectible],
            [
                .lootBuckler, .lootTonic, .lootMap, .lootDice,
                .lootRuneFragment, .lootPhoenixFeather, .lootChalice,
                .lootTome, .lootTrophy, .lootWand, .lootCrown
            ],
            [
                .regionKindlingVale, .regionAshenPasses, .regionStormreach,
                .regionCrownOfDawn, .regionElderWilds
            ],
            [.ledgerstone, .placementRite],
            [.metricRepetitions, .metricLoad, .metricDuration, .metricDistance]
        ]

        for family in families {
            let encoded = try family.map {
                try #require($0.uiImage(pointSize: 18).pngData())
            }
            #expect(Set(encoded).count == family.count)
        }
    }

    @MainActor
    @Test func relatedMeaningsStayDistinctAtBadgeAndMenuSizes() throws {
        let pairs: [(RPGSymbol, RPGSymbol)] = [
            (.training, .plateCalculator),
            (.streak, .setWarmup),
            (.setWarmup, .setWorking),
            (.metricRepetitions, .setWorking),
            (.completionSeal, .equipped)
        ]

        for pointSize in [CGFloat(14), 16] {
            for (left, right) in pairs {
                let leftData = try #require(left.uiImage(pointSize: pointSize).pngData())
                let rightData = try #require(right.uiImage(pointSize: pointSize).pngData())
                #expect(leftData != rightData,
                        "\(left.rawValue) and \(right.rawValue) collapse at \(pointSize) points")
            }
        }
    }

    @MainActor
    @Test func identityFamiliesSurviveSmallRealWorldSizes() throws {
        let attributes = Stat.allCases.map(\.rpgSymbol)
        let ranks = RankTier.allCases.map(\.rpgSymbol)
        let classes = RPGClass.allCases.map(\.rpgSymbol)

        for pointSize in [CGFloat(11), 13, 18] {
            for family in [attributes, ranks, classes] {
                let encoded = try family.map {
                    try #require($0.uiImage(pointSize: pointSize).pngData())
                }
                #expect(
                    Set(encoded).count == family.count,
                    "A semantic identity family collapses at \(pointSize) points"
                )
            }

            let approximatePairs: [(RPGSymbol, RPGSymbol)] = [
                (.statStrength, .focusStrength),
                (.statAgility, .focusExplosive),
                (.statEndurance, .focusEndurance),
                (.statVitality, .focusMobility)
            ]
            for (attribute, focus) in approximatePairs {
                let attributeData = try #require(attribute.uiImage(pointSize: pointSize).pngData())
                let focusData = try #require(focus.uiImage(pointSize: pointSize).pngData())
                #expect(attributeData != focusData,
                        "\(attribute.rawValue) still duplicates \(focus.rawValue) at \(pointSize) points")
            }

            let nonTierRanks: [RPGSymbol] = [.rank, .lootCrown]
            for rank in ranks {
                let rankData = try #require(rank.uiImage(pointSize: pointSize).pngData())
                for other in nonTierRanks {
                    let otherData = try #require(other.uiImage(pointSize: pointSize).pngData())
                    #expect(rankData != otherData,
                            "\(rank.rawValue) duplicates \(other.rawValue) at \(pointSize) points")
                }
            }
        }
    }
}
