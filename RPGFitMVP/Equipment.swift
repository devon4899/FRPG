import SwiftUI

// MARK: - Equipment
//
// Loot becomes gear. The evidence across the genre is unambiguous: equippable
// items are praised even when their stats are trivial — gear is visible proof
// of training. So the numbers stay deliberately shallow: each equipped piece
// adds Might, which sharpens Trial damage. Nothing here gates training,
// nothing is purchasable — every piece is earned from chests and Trials.

/// The three loadout slots. Derived from what an item *is*, so the existing
/// catalog maps without any schema change.
enum EquipSlot: String, CaseIterable, Identifiable {
    case arms      // what you wield
    case guardSlot // what shields you
    case relic     // what empowers you

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arms: return "Arms"
        case .guardSlot: return "Guard"
        case .relic: return "Relic"
        }
    }

    var emptyHint: String {
        switch self {
        case .arms: return "Nothing wielded"
        case .guardSlot: return "Unshielded"
        case .relic: return "No relic"
        }
    }

    var rpgSymbol: RPGSymbol {
        switch self {
        case .arms: return .equipmentArms
        case .guardSlot: return .equipmentGuard
        case .relic: return .equipmentRelic
        }
    }
}

extension InventoryItem {
    /// Slot by identity; the catalog is authored, so a name table is the
    /// honest mapping. Unknown (future) items default to Relic.
    var equipSlot: EquipSlot {
        switch name {
        case "Enchanted Dice", "Arcane Tome", "Wand of Stars":
            return .arms
        case "Bronze Buckler", "Champion's Trophy":
            return .guardSlot
        default:
            return .relic
        }
    }

    /// Might is rarity-keyed and small on purpose: gear is a trophy that
    /// helps, never a stat sim to optimize.
    var might: Int {
        switch rarity {
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 4
        case .epic: return 7
        case .legendary: return 11
        case .mythic: return 16
        }
    }

    var rarityColor: Color {
        switch rarity {
        case .common: return TreasureChestType.common.rarityColor
        case .uncommon: return TreasureChestType.uncommon.rarityColor
        case .rare: return TreasureChestType.rare.rarityColor
        case .epic: return TreasureChestType.epic.rarityColor
        case .legendary: return RPGTheme.gold
        case .mythic: return TreasureChestType.mythic.rarityColor
        }
    }
}

extension AppState {
    /// Applies a chest's payload in the model layer so chest and Trial item
    /// grants share the same catalog/category rules. Chest-specific stacking,
    /// descriptions, and values stay unchanged.
    func applyTreasureRewards(_ rewards: [TreasureReward]) {
        for reward in rewards {
            switch reward.type {
            case .bonus_xp:
                grantBonusXP(reward.amount)
            case .coins:
                user.coins += Int(reward.amount)
            case .item:
                if let itemInfo = reward.itemInfo {
                    let rarity = InventoryItemRarity(rawValue: itemInfo.rarity.lowercased()) ?? .common
                    let name = itemInfo.displayName
                    user.inventory.append(InventoryItem(
                        name: name,
                        description: "A \(rarity.rawValue) \(name.lowercased())",
                        type: itemInfo.inventoryType,
                        rarity: rarity,
                        iconName: itemInfo.iconName,
                        quantity: 1,
                        dateObtained: Date(),
                        value: treasureItemValue(for: rarity)
                    ))
                }
            case .egg:
                user.companionEggs += Int(reward.amount)
            }
        }
    }

    private func treasureItemValue(for rarity: InventoryItemRarity) -> Int {
        switch rarity {
        case .common: return 10
        case .uncommon: return 25
        case .rare: return 50
        case .epic: return 100
        case .legendary: return 200
        case .mythic: return 250
        }
    }

    func equippedItem(in slot: EquipSlot) -> InventoryItem? {
        guard let idString = user.equippedItems[slot.rawValue],
              let id = UUID(uuidString: idString) else { return nil }
        return user.inventory.first { $0.id == id }
    }

    func isEquipped(_ item: InventoryItem) -> Bool {
        user.equippedItems[item.equipSlot.rawValue] == item.id.uuidString
    }

    /// Total Might across the loadout → +Might% Trial damage. Full loadouts
    /// earn set bonuses: a complete kit +2, and matching rarity across all
    /// three slots +3 more. Game layer only, like all gear.
    var equipmentMight: Int {
        let equipped = EquipSlot.allCases.compactMap { equippedItem(in: $0) }
        var might = equipped.reduce(0) { $0 + $1.might }
        if equipped.count == EquipSlot.allCases.count {
            might += 2
            if Set(equipped.map(\.rarity)).count == 1 {
                might += 3
            }
        }
        return might
    }

    /// The active set bonus line for the loadout UI, nil when no bonus.
    var equipmentSetBonusLabel: String? {
        let equipped = EquipSlot.allCases.compactMap { equippedItem(in: $0) }
        guard equipped.count == EquipSlot.allCases.count else { return nil }
        return Set(equipped.map(\.rarity)).count == 1
            ? "Matched set · +5 Might"
            : "Full kit · +2 Might"
    }

    func equip(_ item: InventoryItem) {
        user.equippedItems[item.equipSlot.rawValue] = item.id.uuidString
        Haptics.tap()
        save()
    }

    func unequip(slot: EquipSlot) {
        user.equippedItems[slot.rawValue] = nil
        Haptics.tap()
        save()
    }

    /// One-time v4 migration. Pre-v4 saves minted fresh inventory ids on
    /// every decode, so any equipped-gear reference is dangling by the time
    /// this runs — and the dead UUID carries no recoverable identity.
    /// Re-link only where the choice is unambiguous (exactly one owned item
    /// fits the slot); otherwise clear the slot and say so, once.
    func relinkEquippedItemsAfterIDMigration() {
        var clearedAnything = false
        for slot in EquipSlot.allCases {
            guard let idString = user.equippedItems[slot.rawValue],
                  !user.inventory.contains(where: { $0.id.uuidString == idString }) else { continue }
            let candidates = user.inventory.filter { $0.equipSlot == slot }
            if candidates.count == 1, let only = candidates.first {
                user.equippedItems[slot.rawValue] = only.id.uuidString
            } else {
                user.equippedItems[slot.rawValue] = nil
                clearedAnything = true
            }
        }
        if clearedAnything {
            pushToast(title: "Loadout Needs You",
                      subtitle: "Some gear returned to your Satchel — re-equip it from your Character sheet",
                      kind: .accent,
                      symbol: .satchel)
        }
    }

    /// Drops equipment references whose item no longer exists (deleted loot).
    func pruneEquippedItems() {
        for slot in EquipSlot.allCases {
            if let idString = user.equippedItems[slot.rawValue],
               !user.inventory.contains(where: { $0.id.uuidString == idString }) {
                user.equippedItems[slot.rawValue] = nil
            }
        }
    }

    /// Adds a reward item to the inventory (stacking duplicates), shared by
    /// chests and Trials.
    func grantItem(from itemInfo: ItemInfo) {
        let name = itemInfo.displayName
        if let index = user.inventory.firstIndex(where: { $0.name == name }) {
            user.inventory[index].quantity += 1
            return
        }
        let rarity = InventoryItemRarity(rawValue: itemInfo.rarity.lowercased()) ?? .uncommon
        user.inventory.append(InventoryItem(
            name: name,
            description: "Won in battle — proof of training done.",
            type: itemInfo.inventoryType,
            rarity: rarity,
            iconName: itemInfo.iconName,
            quantity: 1,
            dateObtained: Date(),
            value: 10
        ))
    }
}

// MARK: - Loadout UI

/// The three-slot loadout strip at the top of the Inventory. Tap a filled
/// slot to unequip; items equip from their detail sheet in the grid.
struct LoadoutCard: View {
    @EnvironmentObject var state: AppState
    /// Where an empty slot sends the player — the Satchel, to pick loot.
    var onEmptySlotTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gear sharpens your Trial strikes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if state.equipmentMight > 0 {
                    HStack(spacing: 4) {
                        RPGSymbolIcon(
                            symbol: .might,
                            size: 12,
                            presentation: .compact,
                            palette: .monochrome(RPGTheme.gold)
                        )
                        Text("Might +\(state.equipmentMight)%")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundColor(RPGTheme.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(RPGTheme.gold.opacity(0.12)))
                    .accessibilityLabel("Equipment might bonus: plus \(state.equipmentMight) percent trial damage")
                }
            }

            HStack(spacing: 12) {
                ForEach(EquipSlot.allCases) { slot in
                    LoadoutSlotView(slot: slot, item: state.equippedItem(in: slot)) {
                        if state.equippedItem(in: slot) != nil {
                            state.unequip(slot: slot)
                            Haptics.tap()
                        } else {
                            onEmptySlotTap?()
                        }
                    }
                }
            }

            if let bonus = state.equipmentSetBonusLabel {
                HStack(spacing: 4) {
                    RPGSymbolIcon(
                        symbol: .equipped,
                        size: 12,
                        presentation: .compact,
                        palette: .monochrome(RPGTheme.accent)
                    )
                    Text(bonus)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundColor(RPGTheme.accent)
            }

        }
        .rpgCard(padding: 14)
    }
}

struct LoadoutSlotView: View {
    let slot: EquipSlot
    let item: InventoryItem?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                        .fill(RPGTheme.surfaceInner)
                        .overlay(
                            RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                                .strokeBorder(
                                    item.map { $0.rarityColor.opacity(0.55) } ?? RPGTheme.frame.opacity(RPGTheme.hairline),
                                    style: item == nil ? StrokeStyle(lineWidth: 1, dash: [4, 3]) : StrokeStyle(lineWidth: 1.4)
                                )
                        )
                        .frame(height: 58)

                    if let item {
                        ItemIcon(item: item, size: 24, tint: item.rarityColor)
                    } else {
                        RPGSymbolIcon(
                            symbol: slot.rpgSymbol,
                            size: 20,
                            presentation: .compact,
                            palette: .themed(RPGTheme.frame.opacity(0.65))
                        )
                    }
                }

                Text(item?.name ?? slot.displayName)
                    .font(RPGTheme.label(10, weight: item == nil ? .medium : .semibold))
                    .foregroundColor(item == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(item.map { "\(slot.displayName): \($0.name) equipped, might \($0.might). Double tap to unequip." }
                            ?? "\(slot.displayName) slot, empty: \(slot.emptyHint). Double tap to open the Satchel.")
    }
}

/// Item detail sheet — equip/unequip lives here so the grid tap has a
/// purpose beyond deletion.
struct ItemDetailSheet: View {
    let item: InventoryItem
    /// Discarding an item is confirmed by the presenter, never here.
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(RPGTheme.frame.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            ItemIcon(item: item, size: 52, tint: item.rarityColor)
                .frame(width: 96, height: 96)
                .background(
                    Circle()
                        .fill(RPGTheme.surfaceInner)
                        .overlay(Circle().strokeBorder(item.rarityColor.opacity(0.5), lineWidth: 1.5))
                )

            VStack(spacing: 6) {
                Text(item.name)
                    .font(RPGTheme.heading(.title2, weight: .bold))
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        RPGSymbolIcon(
                            symbol: item.type.rpgSymbol,
                            size: 11,
                            presentation: .compact,
                            palette: .themed(item.rarityColor)
                        )
                        Text("\(item.rarity.rawValue.capitalized) \(item.type.displayName)")
                            .font(RPGTheme.label(11, weight: .semibold))
                            .foregroundColor(item.rarityColor)
                    }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(item.rarityColor.opacity(0.12)))
                    HStack(spacing: 4) {
                        RPGSymbolIcon(
                            symbol: item.equipSlot.rpgSymbol,
                            size: 11,
                            presentation: .compact,
                            palette: .themed(RPGTheme.frame)
                        )
                        Text(item.equipSlot.displayName)
                            .font(RPGTheme.label(11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().strokeBorder(RPGTheme.frame.opacity(0.4), lineWidth: 1))
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 4) {
                RPGSymbolIcon(
                    symbol: .might,
                    size: 14,
                    presentation: .compact,
                    palette: .monochrome(RPGTheme.gold)
                )
                Text("Might +\(item.might)%")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundColor(RPGTheme.gold)

            Button {
                if state.isEquipped(item) {
                    state.unequip(slot: item.equipSlot)
                } else {
                    state.equip(item)
                }
                dismiss()
            } label: {
                Text(state.isEquipped(item) ? "Unequip" : "Equip to \(item.equipSlot.displayName)")
            }
            .buttonStyle(RPGPrimaryButtonStyle())
            .frame(maxWidth: 280)

            if let onDelete {
                Button(role: .destructive) {
                    dismiss()
                    onDelete()
                } label: {
                    Text("Discard")
                }
                .buttonStyle(RPGQuietButtonStyle(tint: RPGTheme.errorText))
                .accessibilityHint("Removes this item from your satchel after confirmation")
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.hidden)
        .background(AppBackground())
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .accessibilityLabel("Close item details")
            .padding(.top, 6)
            .padding(.trailing, 12)
        }
    }
}
