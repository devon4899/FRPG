import Foundation
import Testing
@testable import RPGFitMVP

@Suite("Inventory item model regressions")
struct InventoryItemModelRegressionTests {
    private struct CatalogCase {
        let info: ItemInfo
        let legacyName: String
        let legacyIconName: String
    }

    private struct PersistedItemPayload: Encodable {
        let id: UUID
        let name: String
        let description: String
        let type: InventoryItemType
        let rarity: InventoryItemRarity
        let iconName: String
        let quantity: Int
        let dateObtained: Date
        let value: Int
    }

    private var catalog: [CatalogCase] {
        [
            CatalogCase(info: .uncommon(.soccerball), legacyName: "Soccer Ball", legacyIconName: "soccerball"),
            CatalogCase(info: .uncommon(.basketball), legacyName: "Basketball", legacyIconName: "basketball.fill"),
            CatalogCase(info: .uncommon(.volleyball), legacyName: "Volleyball", legacyIconName: "volleyball.fill"),
            CatalogCase(info: .rare(.dice), legacyName: "Dice", legacyIconName: "dice.fill"),
            CatalogCase(info: .rare(.puzzlepiece), legacyName: "Puzzle Piece", legacyIconName: "puzzlepiece.fill"),
            CatalogCase(info: .rare(.balloon), legacyName: "Balloon", legacyIconName: "balloon.fill"),
            CatalogCase(info: .epic(.birthdaycake), legacyName: "Birthday Cake", legacyIconName: "birthday.cake.fill"),
            CatalogCase(info: .epic(.gamecontroller), legacyName: "Game Controller", legacyIconName: "gamecontroller.fill"),
            CatalogCase(info: .legendary(.trophy), legacyName: "Trophy", legacyIconName: "trophy.fill"),
            CatalogCase(info: .legendary(.wand), legacyName: "Magic Wand", legacyIconName: "wand.and.stars"),
            CatalogCase(info: .mythic(.teddybear), legacyName: "Teddy Bear", legacyIconName: "teddybear.fill")
        ]
    }

    private func decodePayload(
        name: String,
        iconName: String,
        type: InventoryItemType
    ) throws -> (InventoryItem, PersistedItemPayload) {
        let payload = PersistedItemPayload(
            id: UUID(),
            name: name,
            description: "Persisted description",
            type: type,
            rarity: .rare,
            iconName: iconName,
            quantity: 3,
            dateObtained: Date(timeIntervalSinceReferenceDate: 12_345),
            value: 77
        )
        let data = try JSONEncoder().encode(payload)
        return (try JSONDecoder().decode(InventoryItem.self, from: data), payload)
    }

    @Test func everyShippedItemHasCanonicalEquipmentCategory() {
        #expect(InventoryItemType.allCases.map(\.rawValue) == [
            "consumable", "equipment", "material", "collectible"
        ])

        for entry in catalog {
            #expect(entry.info.inventoryType == .equipment)
            #expect(InventoryItemType.canonical(
                forItemNamed: entry.info.displayName,
                persistedIconName: entry.info.iconName
            ) == .equipment)
            #expect(InventoryItemType.canonical(
                forItemNamed: entry.legacyName,
                persistedIconName: entry.legacyIconName
            ) == .equipment)
        }
    }

    @Test func constructionNormalizesEveryCurrentCatalogItemWithoutRewritingItsIcon() {
        for entry in catalog {
            let item = InventoryItem(
                name: entry.info.displayName,
                description: "test",
                type: .collectible,
                rarity: .uncommon,
                iconName: entry.info.iconName,
                quantity: 1,
                dateObtained: .now,
                value: 10
            )

            #expect(item.type == .equipment)
            #expect(item.iconName == entry.info.iconName)
        }
    }

    @Test func currentAndLegacySavesNormalizeWithoutLosingPersistedFields() throws {
        for entry in catalog {
            for (name, iconName) in [
                (entry.info.displayName, entry.info.iconName),
                (entry.legacyName, entry.legacyIconName)
            ] {
                let (item, payload) = try decodePayload(
                    name: name,
                    iconName: iconName,
                    type: .collectible
                )

                #expect(item.type == .equipment)
                #expect(item.id == payload.id)
                #expect(item.name == payload.name)
                #expect(item.description == payload.description)
                #expect(item.rarity == payload.rarity)
                #expect(item.iconName == payload.iconName)
                #expect(item.quantity == payload.quantity)
                #expect(item.dateObtained == payload.dateObtained)
                #expect(item.value == payload.value)
            }
        }
    }

    @Test func unknownOrMismatchedItemsKeepTheirStoredCategory() throws {
        // The debug relic deliberately reuses the rune icon; its name prevents
        // it from being mistaken for the shipped Rune Fragment.
        let (debugRelic, _) = try decodePayload(
            name: "Starforged Relic",
            iconName: "glyph:rune",
            type: .material
        )
        #expect(debugRelic.type == .material)

        let (mismatched, _) = try decodePayload(
            name: "Bronze Buckler",
            iconName: "glyph:rune",
            type: .collectible
        )
        #expect(mismatched.type == .collectible)
    }

    @Test func chestAndTrialGrantPathsConvergeAndStack() throws {
        let state = AppState(persistenceEnabled: false)
        state.user = UserProfile()
        state.history = []
        let info = ItemInfo.epic(.gamecontroller)
        let chestReward = TreasureReward(
            type: .item,
            amount: 1,
            description: info.displayName,
            itemInfo: info
        )

        state.applyTreasureRewards([chestReward])

        let chestItem = try #require(state.user.inventory.first)
        #expect(chestItem.type == .equipment)
        #expect(chestItem.description == "A epic arcane tome")
        #expect(chestItem.value == 100)

        state.grantItem(from: info)

        #expect(state.user.inventory.count == 1)
        let item = try #require(state.user.inventory.first)
        #expect(item.type == .equipment)
        #expect(item.iconName == info.iconName)
        #expect(item.quantity == 2)
    }
}
