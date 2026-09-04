import Foundation
import Testing
@testable import RPGFitMVP

@Suite("Loot symbol identity regressions")
struct LootSymbolIdentityRegressionTests {
    private struct LootPair {
        let name: String
        let iconName: String
        let symbol: RPGSymbol
    }

    private var currentPairs: [LootPair] {
        [
            LootPair(name: "Bronze Buckler", iconName: "glyph:shield", symbol: .lootBuckler),
            LootPair(name: "Strength Tonic", iconName: "glyph:potion", symbol: .lootTonic),
            LootPair(name: "Traveler's Map", iconName: "glyph:scroll", symbol: .lootMap),
            LootPair(name: "Enchanted Dice", iconName: "dice.fill", symbol: .lootDice),
            LootPair(name: "Rune Fragment", iconName: "glyph:rune", symbol: .lootRuneFragment),
            LootPair(name: "Phoenix Feather", iconName: "glyph:wing", symbol: .lootPhoenixFeather),
            LootPair(name: "Gilded Chalice", iconName: "glyph:chalice", symbol: .lootChalice),
            LootPair(name: "Arcane Tome", iconName: "glyph:book", symbol: .lootTome),
            LootPair(name: "Champion's Trophy", iconName: "trophy.fill", symbol: .lootTrophy),
            LootPair(name: "Wand of Stars", iconName: "wand.and.stars", symbol: .lootWand),
            LootPair(name: "Ancient Crown", iconName: "glyph:crown", symbol: .lootCrown)
        ]
    }

    private var legacyPairs: [LootPair] {
        [
            LootPair(name: "Soccer Ball", iconName: "soccerball", symbol: .lootBuckler),
            LootPair(name: "Basketball", iconName: "basketball.fill", symbol: .lootTonic),
            LootPair(name: "Volleyball", iconName: "volleyball.fill", symbol: .lootMap),
            LootPair(name: "Dice", iconName: "dice.fill", symbol: .lootDice),
            LootPair(name: "Puzzle Piece", iconName: "puzzlepiece.fill", symbol: .lootRuneFragment),
            LootPair(name: "Balloon", iconName: "balloon.fill", symbol: .lootPhoenixFeather),
            LootPair(name: "Birthday Cake", iconName: "birthday.cake.fill", symbol: .lootChalice),
            LootPair(name: "Game Controller", iconName: "gamecontroller.fill", symbol: .lootTome),
            LootPair(name: "Trophy", iconName: "trophy.fill", symbol: .lootTrophy),
            LootPair(name: "Magic Wand", iconName: "wand.and.stars", symbol: .lootWand),
            LootPair(name: "Teddy Bear", iconName: "teddybear.fill", symbol: .lootCrown)
        ]
    }

    private func inventoryItem(
        for pair: LootPair,
        type: InventoryItemType = .collectible
    ) -> InventoryItem {
        InventoryItem(
            name: pair.name,
            description: "Persisted loot",
            type: type,
            rarity: .rare,
            iconName: pair.iconName,
            quantity: 1,
            dateObtained: Date(timeIntervalSinceReferenceDate: 1_234),
            value: 10
        )
    }

    @Test func allCurrentCatalogPairsResolveToTheirExactArtwork() {
        #expect(currentPairs.count == 11)

        for pair in currentPairs {
            #expect(RPGSymbol.lootSymbol(
                forItemNamed: pair.name,
                persistedIconName: pair.iconName
            ) == pair.symbol)

            let item = inventoryItem(for: pair)
            #expect(item.rpgSymbol == pair.symbol)
            #expect(item.type == .equipment)
            #expect(item.iconName == pair.iconName)
        }
    }

    @Test func legacyCatalogPairsResolveWithoutRewritingPersistedIdentifiers() {
        let currentIdentifiers = Set(currentPairs.map(\.iconName))
        let legacyOnlyIdentifiers = Set(legacyPairs.map(\.iconName)).subtracting(currentIdentifiers)
        #expect(legacyOnlyIdentifiers == [
            "soccerball", "basketball.fill", "volleyball.fill", "puzzlepiece.fill",
            "balloon.fill", "birthday.cake.fill", "gamecontroller.fill", "teddybear.fill"
        ])

        for pair in legacyPairs {
            #expect(RPGSymbol.lootSymbol(
                forItemNamed: pair.name,
                persistedIconName: pair.iconName
            ) == pair.symbol)

            let item = inventoryItem(for: pair)
            #expect(item.rpgSymbol == pair.symbol)
            #expect(item.type == .equipment)
            #expect(item.name == pair.name)
            #expect(item.iconName == pair.iconName)
        }
    }

    @Test func unrelatedItemReusingRuneIdentifierDoesNotBecomeRuneFragment() {
        let debugRelic = InventoryItem(
            name: "Starforged Relic",
            description: "A rune that sharpens every Trial strike.",
            type: .equipment,
            rarity: .legendary,
            iconName: "glyph:rune",
            quantity: 1,
            dateObtained: Date(timeIntervalSinceReferenceDate: 1_234),
            value: 500
        )

        #expect(RPGSymbol.lootSymbol(
            forItemNamed: debugRelic.name,
            persistedIconName: debugRelic.iconName
        ) == nil)
        #expect(debugRelic.rpgSymbol == .lootEquipment)
        #expect(debugRelic.rpgSymbol != .lootRuneFragment)
        #expect(debugRelic.iconName == "glyph:rune")
    }
}
