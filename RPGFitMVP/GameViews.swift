import SwiftUI
import Foundation
import UIKit

// MARK: - Class selection

struct ClassSelectionView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedClass: RPGClass?
    @State private var showChangeClassAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Choose Your Class")
                        .font(RPGTheme.heading(.largeTitle, weight: .bold))
                        .padding(.top)
                        .frame(maxWidth: .infinity)

                    Text("Your class determines the types of quests you'll receive")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    ForEach(RPGClass.allCases, id: \.self) { rpgClass in
                        ClassSelectionCard(
                            rpgClass: rpgClass,
                            isSelected: selectedClass == rpgClass,
                            onTap: {
                                selectedClass = rpgClass
                            }
                        )
                    }
                }
                .frame(maxWidth: AppLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(AppBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        if let selectedClass = selectedClass {
                            // Check if user already has a class (changing classes)
                            if state.user.rpgClass != nil {
                                showChangeClassAlert = true
                            } else {
                                // First time selecting class
                                state.setRPGClass(selectedClass)
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedClass == nil)
                    .font(.headline)
                }
            }
            .alert("Change Class?", isPresented: $showChangeClassAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Change Class", role: .destructive) {
                    if let selectedClass = selectedClass {
                        state.changeRPGClassWithQuestReset(selectedClass)
                        dismiss()
                    }
                }
            } message: {
                Text("Changing your class will reset your current quest progress but keep the quest timers. Are you sure you want to continue?")
            }
        }
    }
}

struct ClassSelectionCard: View {
    let rpgClass: RPGClass
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ClassEmblem(rpgClass: rpgClass, size: 46)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rpgClass.displayName)
                            .font(RPGTheme.heading(.headline, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(rpgClass.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(RPGTheme.gold)
                    }
                }

                // The class's trained attribute pair + its affinity bonus
                HStack(spacing: 8) {
                    ForEach(rpgClass.trainedStats, id: \.self) { stat in
                        HStack(spacing: 4) {
                            RPGSymbolIcon(
                                symbol: stat.rpgSymbol,
                                size: 11,
                                presentation: .compact,
                                palette: .monochrome(stat.color)
                            )
                            Text(stat.name)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundColor(stat.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(RPGTheme.surfaceInner)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
                        )
                    }

                    Spacer(minLength: 0)

                    Text("+10% Might")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(RPGTheme.xp)
                        .fixedSize()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                    .fill(isSelected ? rpgClass.color.opacity(0.12) : RPGTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? RPGTheme.gold.opacity(0.70) : RPGTheme.frame.opacity(RPGTheme.hairline),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Satchel
//
// Everything the character carries: loot to equip, and chests to open. One
// screen, two shelves. Reached from Character (Loadout → Satchel, or the
// "chests are waiting" row), never a tab of its own.

struct SatchelView: View {
    enum Section: Hashable {
        case items, chests
    }

    let initialSection: Section

    @EnvironmentObject var state: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var section: Section
    @State private var selectedChest: TreasureChest?
    @State private var showChestRewards = false
    @State private var chestOpeningStep = 0 // 0 = closed, 1 = reveal, 2 = rewards
    @State private var chestPop = false
    @State private var pendingDeleteItemIDs: [UUID] = []
    @State private var inspectedItem: InventoryItem? = nil

    init(initialSection: Section = .items) {
        self.initialSection = initialSection
        _section = State(initialValue: initialSection)
    }

    private var isScreenshotCapture: Bool {
        ProcessInfo.processInfo.arguments.contains("-rpgfit-screenshot-capture")
    }

    private var unopenedCount: Int {
        state.user.treasureChests.filter { !$0.isOpened }.count
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                SatchelSwitcher(section: $section, chestCount: unopenedCount)
                    .padding(.horizontal, AppLayout.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .frame(maxWidth: AppLayout.contentMaxWidth)

                if section == .chests {
                    TreasureVaultView(selectedChest: $selectedChest,
                                      showChestRewards: $showChestRewards,
                                      chestOpeningStep: $chestOpeningStep)
                        .environmentObject(state)
                } else {
                    itemsShelf
                }
            }
        }
        .navigationTitle(section == .chests ? "Chests" : "Satchel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            #if DEBUG
            if !isScreenshotCapture {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Debug") { generateTestChests() }
                        .font(.caption)
                        .foregroundColor(RPGTheme.warningText)
                }
            }
            #endif
        }
        .sheet(item: $inspectedItem) { item in
            ItemDetailSheet(item: item, onDelete: {
                pendingDeleteItemIDs = [item.id]
            })
            .environmentObject(state)
        }
        .confirmationDialog(
            "Delete \(pendingDeleteItemIDs.count == 1 ? "this item" : "\(pendingDeleteItemIDs.count) items")?",
            isPresented: Binding(
                get: { !pendingDeleteItemIDs.isEmpty },
                set: { if !$0 { pendingDeleteItemIDs = [] } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    state.user.inventory.removeAll { pendingDeleteItemIDs.contains($0.id) }
                }
                pendingDeleteItemIDs = []
                state.pruneEquippedItems()
                state.save()
            }
            Button("Cancel", role: .cancel) { pendingDeleteItemIDs = [] }
        } message: {
            Text("This cannot be undone.")
        }
        .overlay(
            // Two-step chest opening ritual
            showChestRewards && selectedChest != nil ? ZStack {
                // Opaque backdrop — the whole overlay is tappable to dismiss
                RPGTheme.canvas.opacity(1.0)
                    .ignoresSafeArea()

                if chestOpeningStep == 1, let chest = selectedChest {
                    VStack(spacing: 28) {
                        TreasureChestCardDisplay(chest: chest, scale: 2.2)
                            .scaleEffect(chestPop ? 1.12 : 1.0)
                            .rotationEffect(.degrees(chestPop ? 2 : 0))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Double tap to open the chest")
                            .onTapGesture {
                                guard !chestPop else { return }
                                Haptics.tap()
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                                    chestPop = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    // Stale-write guard: dismissing and opening
                                    // another chest within 0.25s must not skip
                                    // the new chest's reveal step.
                                    guard showChestRewards, selectedChest?.id == chest.id else { return }
                                    chestOpeningStep = 2
                                    chestPop = false
                                }
                            }

                        Text("Tap the chest to open it")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .scaleEffect(chestOpeningStep == 1 ? 1.0 : 0.8)
                    .opacity(chestOpeningStep == 1 ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: chestOpeningStep)
                } else if chestOpeningStep == 2, let chest = selectedChest {
                    TreasureChestRewardsView(chest: chest) {
                        openChest(chest)
                    }
                    .scaleEffect(chestOpeningStep == 2 ? 1.0 : 0.8)
                    .opacity(chestOpeningStep == 2 ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: chestOpeningStep)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissChestOverlay() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Double tap to continue")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { dismissChestOverlay() }
            // Keep VoiceOver inside the overlay, and let the escape gesture out
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) { dismissChestOverlay() }
            : nil
        )
    }

    // MARK: Items shelf

    private var itemsShelf: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if state.user.inventory.isEmpty {
                    EmptyStateView(
                        title: "An Empty Satchel",
                        message: "Chests and fallen Trials leave loot here. Equip it to sharpen your strikes.",
                        tint: RPGTheme.gold,
                        symbol: .satchel
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Items") {
                            Text("\(state.user.inventory.count)")
                                .font(RPGTheme.label(11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        Text("Tap an item to equip it. Long-press to discard.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72, maximum: 110), spacing: 12)], spacing: 12) {
                            ForEach(state.user.inventory) { item in
                                InventoryItemCard(item: item) {
                                    pendingDeleteItemIDs = [item.id]
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if state.isEquipped(item) {
                                        ZStack {
                                            RPGSymbolIcon(
                                                symbol: .equipped,
                                                size: 16,
                                                presentation: .compact,
                                                palette: .monochrome(RPGTheme.gold)
                                            )
                                        }
                                        .padding(4)
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel("Equipped")
                                    }
                                }
                                .onTapGesture {
                                    inspectedItem = item
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint("Opens item details")
                            }
                        }
                    }
                    .rpgCard(padding: 14)
                }
            }
            .screenColumn()
            .padding(.vertical, 12)
            .padding(.bottom, 24)
        }
    }

    // Debug function to generate test chests of each rarity
    private func generateTestChests() {
        let rarities: [TreasureChestType] = [.common, .uncommon, .rare, .epic, .mythic]
        for rarity in rarities {
            let testChest = StatEngine.generateTreasureChest(forLevel: state.user.level, forcedType: rarity)
            state.user.treasureChests.append(testChest)
        }
        state.save()
    }

    /// Closes the chest-opening overlay and resets its step state.
    private func dismissChestOverlay() {
        showChestRewards = false
        selectedChest = nil
        chestOpeningStep = 0
        chestPop = false
    }

    private func openChest(_ chest: TreasureChest) {
        if let index = state.user.treasureChests.firstIndex(where: { $0.id == chest.id }),
           !state.user.treasureChests[index].isOpened {
            state.user.treasureChests[index].isOpened = true
            applyRewards(chest.rewards)
            state.save()
        }
    }

    private func applyRewards(_ rewards: [TreasureReward]) {
        state.applyTreasureRewards(rewards)
    }
}

/// Two shelves, one control.
struct SatchelSwitcher: View {
    @Binding var section: SatchelView.Section
    let chestCount: Int

    var body: some View {
        HStack(spacing: 0) {
            segment(title: "Items", symbol: .satchel, isActive: section == .items) { section = .items }
            segment(title: chestCount > 0 ? "Chests · \(chestCount)" : "Chests", symbol: .chest, isActive: section == .chests) { section = .chests }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                .fill(RPGTheme.surfaceInner)
        )
    }

    private func segment(title: String, symbol: RPGSymbol, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { action() }
            Haptics.tick()
        } label: {
            HStack(spacing: 6) {
                RPGSymbolIcon(
                    symbol: symbol,
                    size: 14,
                    presentation: .compact,
                    palette: isActive ? .onPlate : .adaptive
                )
                Text(title)
                    .font(RPGTheme.label(14, weight: .semibold))
            }
            .foregroundColor(isActive ? RPGTheme.onPlate : .primary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: RPGTheme.innerRadius - 2, style: .continuous)
                    .fill(isActive ? RPGTheme.accentFill : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

struct TreasureVaultView: View {
    @EnvironmentObject var state: AppState
    @Binding var selectedChest: TreasureChest?
    @Binding var showChestRewards: Bool
    @Binding var chestOpeningStep: Int
    @State private var showTitle = false
    @Environment(\.colorScheme) var colorScheme

    // Simple deck browsing
    @State private var topCardIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var cardSwitchAnimation: Bool = false
    @State private var swipeDirection: CGFloat = 0 // Positive for right swipe, negative for left swipe

    // Sorting state
    @State private var sortByRarity = false
    @State private var rarestFirst = true // true = rarest first, false = most common first

    // Cached so browsing gestures don't re-filter and re-sort the whole
    // collection on every frame; refreshed only when the inputs change.
    @State private var unopenedChests: [TreasureChest] = []

    /// Deterministic ordering: newest first by date, and within a rarity tier
    /// (when sorting by rarity) still newest first — Swift's sort isn't
    /// stable, so the date tiebreaker keeps the pile from shuffling.
    private func refreshChests() {
        let unopened = state.user.treasureChests.filter { !$0.isOpened }
        if sortByRarity {
            unopenedChests = unopened.sorted { a, b in
                if a.type.sortRank != b.type.sortRank {
                    return rarestFirst
                        ? a.type.sortRank > b.type.sortRank
                        : a.type.sortRank < b.type.sortRank
                }
                return a.dateEarned > b.dateEarned
            }
        } else {
            unopenedChests = unopened.sorted { $0.dateEarned > $1.dateEarned }
        }
        topCardIndex = min(topCardIndex, max(0, unopenedChests.count - 1))
    }

    var body: some View {
        ZStack {

            VStack(spacing: 20) {
                    // Epic title with animation

                    if unopenedChests.isEmpty {
                        EmptyTreasureStateAnimated(isVisible: showTitle)
                    } else {
                        VStack(spacing: 0) {
                            // Fixed position card deck container
                            ZStack {
                                // Only render up to 20 cards (no fade, all fully visible)
                                ForEach(0..<min(unopenedChests.count, 5), id: \.self) { index in
                                    let chestIndex = (topCardIndex + index) % unopenedChests.count

                                    DeckCard(
                                        chest: unopenedChests[chestIndex],
                                        index: index,
                                        dragOffset: index == 0 ? dragOffset : 0,
                                        isVisible: true,
                                        cardSwitchAnimation: cardSwitchAnimation,
                                        totalCards: unopenedChests.count,
                                        swipeDirection: swipeDirection,
                                        paused: showChestRewards
                                    ) {
                                        selectedChest = unopenedChests[chestIndex]
                                        showChestRewards = true
                                        chestOpeningStep = 1
                                    }
                                }
                            }
                            .id("\(sortByRarity)-\(rarestFirst)") // Force re-render when sort changes
                            .frame(maxWidth: .infinity, minHeight: 370) // Fixed height for consistent positioning
                            .padding(.top, 8)
                            .contentShape(Rectangle())
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Chest pile, \(unopenedChests.isEmpty ? 0 : topCardIndex + 1) of \(unopenedChests.count)")
                            .accessibilityAdjustableAction { direction in
                                guard unopenedChests.count > 1 else { return }
                                switch direction {
                                case .increment:
                                    topCardIndex = (topCardIndex + 1) % unopenedChests.count
                                case .decrement:
                                    topCardIndex = (topCardIndex - 1 + unopenedChests.count) % unopenedChests.count
                                @unknown default:
                                    break
                                }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if unopenedChests.count > 1 {
                                            dragOffset = value.translation.width
                                        }
                                    }
                                    .onEnded { value in
                                        guard unopenedChests.count > 1 else { return }
                                        let swipeThreshold: CGFloat = 60
                                        let velocity = abs(value.velocity.width)
                                        let dragDistance = abs(value.translation.width)

                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            if dragDistance > swipeThreshold || velocity > 300 {
                                                // This is a swipe gesture - trigger back card animation
                                                cardSwitchAnimation = true
                                                swipeDirection = value.translation.width > 0 ? 1 : -1 // Track swipe direction
                                                if value.translation.width > 0 {
                                                    // Swipe right - show previous card (loop to end if at beginning)
                                                    topCardIndex = (topCardIndex - 1 + unopenedChests.count) % unopenedChests.count
                                                } else if value.translation.width < 0 {
                                                    // Swipe left - show next card (loop to beginning if at end)
                                                    topCardIndex = (topCardIndex + 1) % unopenedChests.count
                                                }
                                                // Reset animation flag after a short delay
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                    cardSwitchAnimation = false
                                                }
                                            }
                                            dragOffset = 0
                                        }
                                    }
                            )

                            // Controls container below the card deck
                            VStack(spacing: 12) {
                                // Sort controls - now below the cards
                                HStack(spacing: 8) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            sortByRarity.toggle()
                                            topCardIndex = 0 // Reset to first card when sorting changes
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: sortByRarity ? "line.3.horizontal.decrease" : "calendar")
                                            Text(sortByRarity ? "By Rarity" : "By Date")
                                        }
                                        .font(RPGTheme.label(12, weight: .semibold))
                                        .foregroundColor(sortByRarity ? .white : .primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .frame(minHeight: 44)
                                        .contentShape(Capsule())
                                        .background(
                                            Capsule()
                                                .fill(sortByRarity ? RPGTheme.accentFill : RPGTheme.surface)
                                                .overlay(
                                                    Capsule()
                                                        .strokeBorder(RPGTheme.frame.opacity(sortByRarity ? 0 : RPGTheme.hairline), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .disabled(unopenedChests.count <= 1)
                                    .opacity(unopenedChests.count > 1 ? 1.0 : 0.0)

                                    if sortByRarity && unopenedChests.count > 1 {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                rarestFirst.toggle()
                                                topCardIndex = 0 // Reset to first card when sort order changes
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: rarestFirst ? "arrow.up" : "arrow.down")
                                                Text(rarestFirst ? "Rare→Common" : "Common→Rare")
                                            }
                                            .font(RPGTheme.label(12, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .frame(minHeight: 44)
                                            .contentShape(Capsule())
                                            .background(
                                                Capsule()
                                                    .fill(RPGTheme.surface)
                                                    .overlay(
                                                        Capsule()
                                                            .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
                                                    )
                                            )
                                        }
                                    }
                                }
                                .frame(height: unopenedChests.count > 1 ? nil : 0) // Collapse when only 1 card

                                // Swipe instruction - show when 2-20 cards, hide when slider appears
                                if unopenedChests.count > 1 && unopenedChests.count <= 20 {
                                    Text("← Swipe to browse chests →")
                                        .font(RPGTheme.label(11, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(RPGTheme.surface)
                                                .overlay(Capsule().strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1))
                                        )
                                }

                                // Slider for quick navigation through cards - only show when cards exceed visible limit
                                if unopenedChests.count > 20 {
                                    HStack(spacing: 12) {
                                        // Slider value is inverted (right = top of pile),
                                        // so the endpoint labels are too.
                                        Text("\(unopenedChests.count)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)

                                        Circle()
                                            .fill(Color.secondary.opacity(0.4))
                                            .frame(width: 4, height: 4)

                                        Slider(
                                            value: Binding(
                                                get: {
                                                    // Invert the slider position
                                                    Double(unopenedChests.count - 1 - topCardIndex)
                                                },
                                                set: { newValue in
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                        // Invert back when setting
                                                        topCardIndex = unopenedChests.count - 1 - Int(newValue)
                                                    }
                                                }
                                            ),
                                            in: 0...Double(unopenedChests.count - 1),
                                            step: 1
                                        )
                                        .tint(RPGTheme.accent)

                                        // End dot with number
                                        Circle()
                                            .fill(Color.secondary.opacity(0.4))
                                            .frame(width: 4, height: 4)

                                        Text("1")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 40)
                                }
                            }
                            .padding(.top, -40) // Bring controls closer to cards
                        }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onChangeCompat(of: sortByRarity) { _, _ in
            topCardIndex = 0
            refreshChests()
        }
        .onChangeCompat(of: rarestFirst) { _, _ in
            topCardIndex = 0
            refreshChests()
        }
        .onChangeCompat(of: state.user.treasureChests) { _, _ in
            // A chest was opened or earned
            refreshChests()
        }
        .onAppear {
            startEntranceAnimation()
            refreshChests()
        }
    }

    private func startEntranceAnimation() {
        // Reset animation states
        showTitle = false
        topCardIndex = 0

        // Animate title
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            showTitle = true
        }
    }


}

struct DeckCard: View {
    let chest: TreasureChest
    let index: Int
    let dragOffset: CGFloat
    let isVisible: Bool
    let cardSwitchAnimation: Bool
    let totalCards: Int
    let swipeDirection: CGFloat
    var paused: Bool = false
    let onTap: () -> Void

    private var opacity: Double {
        guard isVisible else { return 0 }
        // A small pile: the top chest plus a few fading behind it
        return index < 5 ? max(0, 1.0 - Double(index) * 0.18) : 0
    }

    var body: some View {
        // Don't render anything if completely invisible
        if opacity <= 0 {
            EmptyView()
        } else {
            TreasureChestCard(chest: chest, onTap: onTap, index: index, paused: paused)
                .scaleEffect(1.4) // Scale up the entire card and all its contents
                .opacity(opacity)
                .scaleEffect(1.0 - CGFloat(index) * 0.02) // Additional scale for depth
                .rotation3DEffect(.degrees(Double(index) * 3), axis: (x: 0, y: 0, z: 1))
                .offset(
                    x: dragOffset * 0.3, // Keep centered on vertical axis - no horizontal offset for spiral
                    y: CGFloat(index) * -14
                )
                // Add movement only to the last visible card in the deck - opposite to swipe direction
                .offset(x: cardSwitchAnimation && index == min(19, totalCards - 1) && index > 0 ? -swipeDirection * 4.0 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: cardSwitchAnimation)
                .zIndex(Double(10 - index))
                // Pile depth: a whisper of shadow between stacked chests is
                // illustration, not panel chrome — kept faint.
                .shadow(
                    color: .black.opacity(0.10),
                    radius: 3 + CGFloat(index),
                    x: 1 + CGFloat(index) * 0.5,
                    y: 2 + CGFloat(index)
                )
        }
    }

}

// MARK: - Treasure card design
// One shared card face: rarity-colored panel, cream inlay frame, corner
// brackets, and a diamond seal around the suit — the same ornament language
// as the rest of the app.

struct ChestCardFace: View {
    let chest: TreasureChest
    var scale: CGFloat = 1.0
    var animated: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color { chest.type.rarityColor }
    private var hasSparkles: Bool { chest.type == .epic || chest.type == .mythic }

    var body: some View {
        Group {
            if animated && hasSparkles && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    face(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                face(time: 0)
            }
        }
        .frame(width: ChestCardDesign.chestWidth * scale, height: ChestCardDesign.chestHeight * scale)
        .accessibilityHidden(true)
    }

    private func face(time t: Double) -> some View {
        Canvas { context, size in
            // Design grid: 100 wide, chest drawn between y 16–88, centered
            // vertically in the taller frame.
            let s = size.width / 100
            let yPad = (size.height - size.width) / 2
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s + yPad) }
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
                CGRect(x: x * s, y: y * s + yPad, width: w * s, height: h * s)
            }
            let cream = RPGTheme.cream
            let gold = RPGTheme.artGold
            let outline = 4.0 * s

            // Lid
            var lid = Path()
            lid.move(to: pt(14, 50))
            lid.addCurve(to: pt(50, 16), control1: pt(14, 27), control2: pt(30, 16))
            lid.addCurve(to: pt(86, 50), control1: pt(70, 16), control2: pt(86, 27))
            lid.closeSubpath()
            context.fill(lid, with: .color(color))
            context.stroke(lid, with: .color(cream), lineWidth: outline)

            // Body (slightly darker than the lid)
            let body = Path(roundedRect: rect(14, 50, 72, 36), cornerRadius: 7 * s)
            context.fill(body, with: .color(color))
            context.fill(body, with: .color(.black.opacity(0.14)))
            context.stroke(body, with: .color(cream), lineWidth: outline)

            // Gold straps
            for x in [31.0, 69.0] {
                var strap = Path()
                strap.move(to: pt(CGFloat(x), 19))
                strap.addLine(to: pt(CGFloat(x), 84))
                context.stroke(strap, with: .color(gold), lineWidth: 4.5 * s)
            }

            // Seam
            var seam = Path()
            seam.move(to: pt(14, 50))
            seam.addLine(to: pt(86, 50))
            context.stroke(seam, with: .color(gold), lineWidth: 3.5 * s)

            // Clasp + keyhole
            let clasp = Path(roundedRect: rect(42, 43, 16, 18), cornerRadius: 4 * s)
            context.fill(clasp, with: .color(gold))
            context.stroke(clasp, with: .color(cream), lineWidth: 2.5 * s)
            context.fill(
                Path(ellipseIn: rect(47, 47, 6, 6)),
                with: .color(RPGTheme.ink)
            )
            var keySlot = Path()
            keySlot.move(to: pt(50, 53))
            keySlot.addLine(to: pt(50, 57))
            context.stroke(keySlot, with: .color(RPGTheme.ink), lineWidth: 2.5 * s)

            // Twinkling sparkles for the top tiers
            if hasSparkles {
                let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, phase: Double)] =
                    chest.type == .mythic
                        ? [(77, 20, 15, 0.0), (23, 27, 10, 1.9), (81, 60, 9, 3.6)]
                        : [(77, 21, 13, 0.4), (24, 30, 9, 2.3)]

                for sparkle in sparkles {
                    // Twinkle: each spark breathes on its own phase and
                    // slowly rotates; at t == 0 (static) they still render.
                    let tw = 0.5 + 0.5 * sin(t * 2.2 + sparkle.phase)
                    let sparkScale = CGFloat(0.55 + 0.45 * tw)
                    let opacity = 0.30 + 0.65 * tw
                    let rotation = t * 0.7 + sparkle.phase

                    var sctx = context
                    sctx.translateBy(x: sparkle.x * s, y: sparkle.y * s + yPad)
                    sctx.rotate(by: .radians(rotation))
                    let half = sparkle.size * s * sparkScale / 2
                    let path = GlyphShape(glyph: .spark).path(
                        in: CGRect(x: -half, y: -half, width: half * 2, height: half * 2)
                    )
                    sctx.stroke(path, with: .color(cream.opacity(opacity)), lineWidth: 1.6 * s)
                }
            }
        }
    }
}
struct TreasureChestCard: View {
    let chest: TreasureChest
    let onTap: () -> Void
    let index: Int
    var paused: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowPulse = false
    @State private var bounceAnimation = false

    private var isTop: Bool { index == 0 }
    private var shouldGlow: Bool { isTop && !paused && (chest.type == .epic || chest.type == .mythic) }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if shouldGlow {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(chest.type.rarityColor.opacity(glowPulse ? 0.45 : 0.15))
                        .frame(width: ChestCardDesign.chestWidth, height: ChestCardDesign.chestHeight)
                        .blur(radius: 14)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: glowPulse)
                }

                ChestCardFace(chest: chest, animated: isTop && !paused)
                    .scaleEffect(bounceAnimation ? ChestCardDesign.bounceScale : 1.0)
                    .rotation3DEffect(.degrees(bounceAnimation ? -5 : 0), axis: (x: 1, y: 0, z: 0))
            }
            .onTapGesture {
                guard isTop else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    bounceAnimation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onTap()
                    bounceAnimation = false
                }
            }

            // Card name (visible for top card, invisible for others to keep spacing)
            Text(isTop ? chest.type.displayName : " ")
                .font(RPGTheme.heading(.headline, weight: .semibold))
                .foregroundColor(isTop ? .primary : .clear)
                .scaleEffect(isTop ? 0.71 : 1.0)
                .lineLimit(1)
        }
        .frame(width: ChestCardDesign.cardWidth, height: ChestCardDesign.cardHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(chest.type.displayName) treasure chest")
        .accessibilityHint(isTop ? "Double tap to open" : "")
        .accessibilityAddTraits(isTop ? .isButton : [])
        .onAppear {
            guard shouldGlow, !reduceMotion else { return }
            glowPulse = true
        }
        .onChangeCompat(of: index) { _, _ in
            glowPulse = shouldGlow && !reduceMotion
        }
    }
}
// MARK: - Display-only Chest Card (Non-interactive)
struct TreasureChestCardDisplay: View {
    let chest: TreasureChest
    let scale: CGFloat
    var hideGlow: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowPulse = false

    private var shouldGlow: Bool { !hideGlow && (chest.type == .epic || chest.type == .mythic) }

    var body: some View {
        ZStack {
            if shouldGlow {
                RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                    .fill(chest.type.rarityColor.opacity(glowPulse ? 0.35 : 0.10))
                    .frame(width: ChestCardDesign.chestWidth * scale, height: ChestCardDesign.chestHeight * scale)
                    .blur(radius: 12 * scale)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)
            }

            ChestCardFace(chest: chest, scale: scale)
        }
        .frame(width: ChestCardDesign.cardWidth * scale, height: ChestCardDesign.cardHeight * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(chest.type.displayName) treasure chest")
        .onAppear {
            guard shouldGlow, !reduceMotion else { return }
            glowPulse = true
        }
    }
}
struct EmptyTreasureStateAnimated: View {
    let isVisible: Bool
    @State private var floating = false

    var body: some View {
        VStack(spacing: 16) {
            // Empty vault illustration: a waiting chest outline
            ZStack {
                RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius, style: .continuous)
                    .strokeBorder(RPGTheme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                    .frame(width: ChestCardDesign.chestWidth * 0.85,
                           height: ChestCardDesign.chestHeight * 0.7)

                RPGSymbolIcon(
                    symbol: .chest,
                    size: 46,
                    presentation: .hero,
                    palette: .adaptive
                )
            }
            .scaleEffect(isVisible ? 1.0 : 0.5)
            .opacity(isVisible ? 1.0 : 0.0)

            Text("Empty Vault")
                .font(RPGTheme.heading(.title2, weight: .semibold))
                .foregroundColor(.primary)
                .scaleEffect(isVisible ? 1.0 : 0.8)
                .opacity(isVisible ? 1.0 : 0.0)

            Text("Level up to earn treasure chests — some hold companion eggs.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .opacity(isVisible ? 1.0 : 0.0)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
    }
}

// MARK: - Confetti Particle System
struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGSize
    var position: CGPoint
    var velocity: CGVector
    var rotation: Double
    var rotationSpeed: Double
    var opacity: Double

    static func random(centerX: CGFloat, centerY: CGFloat) -> ConfettiParticle {
        let colors: [Color] = [RPGTheme.gold, RPGTheme.cream, RPGTheme.xp, RPGTheme.accent]
        return ConfettiParticle(
            color: colors.randomElement() ?? RPGTheme.gold,
            size: CGSize(width: CGFloat.random(in: 8...12), height: CGFloat.random(in: 4...6)),
            position: CGPoint(
                x: centerX + CGFloat.random(in: -20...20), // Tight spawn area around center
                y: centerY
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -200...200), // Wider spread
                dy: CGFloat.random(in: -350...(-150)) // More upward initial velocity
            ),
            rotation: Double.random(in: 0...360),
            rotationSpeed: Double.random(in: -15...15),
            opacity: 1.0
        )
    }
}

struct ConfettiView: View {
    let particle: ConfettiParticle

    var body: some View {
        Rectangle()
            .fill(particle.color)
            .frame(width: particle.size.width, height: particle.size.height)
            .rotationEffect(.degrees(particle.rotation))
            .position(particle.position)
            .opacity(particle.opacity)
    }
}

struct TreasureChestRewardsView: View {
    let chest: TreasureChest
    let onClaim: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rewardAnimationStates: [Bool] = []
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var confettiTimer: Timer?

    var body: some View {
        ZStack {
            // Confetti particles (full screen coverage)
            ForEach(confettiParticles) { particle in
                ConfettiView(particle: particle)
            }

            VStack(spacing: 14) {
                // Diamond seal with the card's suit
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(chest.type.rarityColor.opacity(0.7), lineWidth: 1.6)
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(45))

                    RPGSymbolIcon(
                        symbol: .chest,
                        size: 24,
                        presentation: .standard,
                        palette: .monochrome(chest.type.rarityColor)
                    )
                }
                .padding(.top, 8)
                .accessibilityHidden(true)

                VStack(spacing: 2) {
                    Text("\(chest.type.displayName) Chest")
                        .font(RPGTheme.heading(.title3, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Earned at Level \(chest.earnedAtLevel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                OrnateDivider(tint: chest.type.rarityColor)
                    .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    ForEach(Array(chest.rewards.enumerated()), id: \.element.id) { index, reward in
                        CompactRewardRow(
                            reward: reward,
                            chestType: chest.type,
                            isVisible: index < rewardAnimationStates.count ? rewardAnimationStates[index] : false
                        )
                    }
                }

                Text("Tap anywhere to continue")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.top, 2)
            }
            .padding(22)
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                    .fill(RPGTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                            .strokeBorder(chest.type.rarityColor.opacity(0.5), lineWidth: 1.5)
                    )
                    .overlay(
                        CornerBrackets(inset: 9, length: 12)
                            .stroke(chest.type.rarityColor.opacity(0.45), lineWidth: 1)
                    )
            )
        }
        .onAppear {
            startOpeningSequence()
        }
        .onDisappear {
            confettiTimer?.invalidate()
            confettiTimer = nil
            confettiParticles.removeAll()
        }
    }

    private func startOpeningSequence() {
        rewardAnimationStates = Array(repeating: false, count: chest.rewards.count)

        if !reduceMotion {
            launchConfetti()
        }

        // Stagger the reward rows in
        for (index, _) in chest.rewards.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    if index < rewardAnimationStates.count {
                        rewardAnimationStates[index] = true
                    }
                }
            }
        }

        // Rewards are claimed the moment the card is opened
        onClaim()
    }

    private func launchConfetti() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let centerX = screenWidth / 2
        let centerY = (screenHeight / 2.5) - 120

        let particleCount = chest.type == .mythic ? 50 : chest.type == .epic ? 40 : 28
        for _ in 0..<particleCount {
            confettiParticles.append(ConfettiParticle.random(centerX: centerX, centerY: centerY))
        }

        animateConfetti()
    }

    private func animateConfetti() {
        confettiTimer?.invalidate()
        confettiTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            for i in confettiParticles.indices.reversed() {
                confettiParticles[i].velocity.dy += 12.0
                confettiParticles[i].velocity.dx *= 0.999
                confettiParticles[i].position.x += confettiParticles[i].velocity.dx * 0.016
                confettiParticles[i].position.y += confettiParticles[i].velocity.dy * 0.016
                confettiParticles[i].rotation += confettiParticles[i].rotationSpeed

                if confettiParticles[i].position.y > 400 {
                    confettiParticles[i].opacity *= 0.99
                }

                if confettiParticles[i].position.y > UIScreen.main.bounds.height + 200 ||
                   confettiParticles[i].opacity < 0.01 {
                    confettiParticles.remove(at: i)
                }
            }

            if confettiParticles.isEmpty {
                timer.invalidate()
            }
        }
    }
}
// Compact version for the card-sized view
// One reward line inside an opened card — quiet inset row, no shimmer.
struct CompactRewardRow: View {
    let reward: TreasureReward
    let chestType: TreasureChestType
    let isVisible: Bool

    /// Only the chest tier's top coin roll counts as a jackpot.
    private var isJackpot: Bool {
        reward.type == .coins && reward.amount == chestType.jackpotCoinAmount
    }

    private var tint: Color {
        switch reward.type {
        case .bonus_xp: return RPGTheme.xp
        case .coins: return RPGTheme.gold
        case .item: return reward.itemInfo?.rarityColor ?? .gray
        case .egg: return RPGTheme.gold
        }
    }

    @ViewBuilder
    private var rewardIcon: some View {
        switch reward.type {
        case .bonus_xp:
            RPGSymbolIcon(
                symbol: .xp,
                size: 16,
                presentation: .compact,
                palette: .monochrome(tint)
            )
        case .coins:
            RPGSymbolIcon(
                symbol: .coin,
                size: 16,
                presentation: .compact,
                palette: .monochrome(tint)
            )
        case .item:
            if let itemInfo = reward.itemInfo {
                RPGSymbolIcon(
                    symbol: itemInfo.rpgSymbol,
                    size: 16,
                    presentation: .compact,
                    palette: .themed(tint)
                )
            } else {
                RPGSymbolIcon(
                    symbol: .lootEquipment,
                    size: 16,
                    presentation: .compact,
                    palette: .themed(tint)
                )
            }
        case .egg:
            RPGSymbolIcon(
                symbol: .companionEgg,
                size: 16,
                presentation: .compact,
                palette: .monochrome(tint)
            )
        }
    }

    private var typeLabel: String {
        if isJackpot { return "Jackpot!" }
        switch reward.type {
        case .item: return reward.itemInfo?.rarity ?? "Item"
        case .egg: return "Hatchable"
        default: return reward.type.displayName
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .strokeBorder(tint.opacity(0.45), lineWidth: 1)
                    .frame(width: 30, height: 30)
                rewardIcon
            }
            .accessibilityHidden(true)

            // Items resolve their name live so re-themed loot names apply to
            // chests generated before the change.
            Text(reward.itemInfo?.displayName ?? reward.description)
                .font(RPGTheme.label(13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Text(typeLabel)
                .font(RPGTheme.label(10, weight: isJackpot ? .bold : .semibold))
                .tracking(0.4)
                .foregroundColor(isJackpot ? RPGTheme.gold : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(RPGTheme.surfaceInner)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(tint.opacity(0.25), lineWidth: 1)
                )
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isVisible)
    }
}
// MARK: - Inventory UI Helper Components

struct InventoryItemCard: View {
    let item: InventoryItem
    var onDelete: (() -> Void)? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
            .fill(RPGTheme.surface)
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                    .strokeBorder(rarityColor.opacity(0.35), lineWidth: 1)
            )
            .overlay(
                ItemIcon(item: item, size: 36, tint: itemColor)
            )
            .overlay(
                // Rarity indicator in top-right corner
                Group {
                    if item.rarity == .mythic {
                        GlyphIcon(glyph: .crown, size: 13, tint: TreasureChestType.mythic.rarityColor, weight: 0.14)
                    } else if item.rarity == .legendary {
                        GlyphIcon(glyph: .spark, size: 13, tint: RPGTheme.gold, weight: 0.14)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 4)
                .padding(.trailing, 4)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.name), \(item.rarity.rawValue)")
            .contextMenu {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    private var itemColor: Color {
        // InventoryItem only stores the icon name, so resolve the color by
        // looking the icon up in the tier enums — the single source of truth.
        if let t = UncommonTierItem.allCases.first(where: { $0.iconName == item.iconName }) { return t.iconColor }
        if let t = RareTierItem.allCases.first(where: { $0.iconName == item.iconName }) { return t.iconColor }
        if let t = EpicTierItem.allCases.first(where: { $0.iconName == item.iconName }) { return t.iconColor }
        if let t = LegendaryTierItem.allCases.first(where: { $0.iconName == item.iconName }) { return t.iconColor }
        if let t = MythicTierItem.allCases.first(where: { $0.iconName == item.iconName }) { return t.iconColor }
        return .primary
    }

    private var rarityColor: Color {
        switch item.rarity {
        case .common: return RPGTheme.frame
        case .uncommon: return TreasureChestType.uncommon.rarityColor
        case .rare: return TreasureChestType.rare.rarityColor
        case .epic: return TreasureChestType.epic.rarityColor
        case .legendary: return RPGTheme.gold
        case .mythic: return TreasureChestType.mythic.rarityColor
        }
    }
}


// MARK: - Goal Selection Components

struct GoalSelectionCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            VStack(spacing: 8) {
                RPGSymbolIcon(
                    symbol: goal.stat.rpgSymbol,
                    size: 24,
                    presentation: .standard,
                    palette: isSelected ? .onPlate : .monochrome(goal.color)
                )

                Text(goal.displayName)
                    .font(RPGTheme.heading(.subheadline, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(usesAccessibilityLayout ? nil : 1)
                    .minimumScaleFactor(0.8)

                Text(goal.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(usesAccessibilityLayout ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(
                RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                    .fill(isSelected ? goal.stat.fill : RPGTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? RPGTheme.gold.opacity(0.55) : RPGTheme.frame.opacity(RPGTheme.hairline),
                        lineWidth: 1
                    )
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.displayName). \(goal.description)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ClassPreviewCard: View {
    let rpgClass: RPGClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(spacing: 16) {
            // Class Emblem and Name
            VStack(spacing: 8) {
                ClassEmblem(rpgClass: rpgClass, size: usesAccessibilityLayout ? 64 : 88)

                Text(rpgClass.displayName)
                    .font(RPGTheme.heading(.title2, weight: .bold))
                    .foregroundColor(.primary)
            }

            // Class Description
            Text(rpgClass.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(usesAccessibilityLayout ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)

            // Skill Focus
            VStack(spacing: 10) {
                SectionLabel("Skill Focus")

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: usesAccessibilityLayout ? 180 : 120))],
                    spacing: 12
                ) {
                    ForEach(rpgClass.trainedStats, id: \.self) { stat in
                        HStack(spacing: 6) {
                            RPGSymbolIcon(
                                symbol: stat.rpgSymbol,
                                size: 14,
                                presentation: .compact,
                                palette: .monochrome(stat.color)
                            )
                            Text(stat.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(RPGTheme.surfaceInner))
                        .overlay(
                            Capsule().strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
                        )
                    }
                }

                HStack(spacing: 4) {
                    RPGSymbolIcon(
                        symbol: .might,
                        size: 10,
                        presentation: .compact,
                        palette: .monochrome(RPGTheme.xp)
                    )
                    Text("+10% Trial Might when training these")
                        .font(.caption.weight(.medium))
                        .foregroundColor(RPGTheme.xp)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .rpgCard(padding: 24, ornate: true)
    }
}





























// MARK: - Challenge Settings View
struct ChallengeSettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var stagedPreferences: [FocusGroup: ChallengePreference] = [:]

    var body: some View {
        NavigationStack {
            List {
                if let rpgClass = state.user.rpgClass {
                    ForEach(rpgClass.focusCategories, id: \.self) { category in
                        ChallengePreferenceRow(
                            category: category,
                            preference: Binding(
                                get: { stagedPreferences[category] ?? state.getPreference(for: category) },
                                set: { stagedPreferences[category] = $0 }
                            )
                        )
                            .environmentObject(state)
                            .listRowBackground(RPGTheme.surface)
                            .listRowSeparatorTint(RPGTheme.frame.opacity(RPGTheme.hairline))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .tint(RPGTheme.accent)
            .navigationTitle("Challenge Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if let rpgClass = state.user.rpgClass {
                            for category in rpgClass.focusCategories {
                                guard let preference = stagedPreferences[category],
                                      preference != state.getPreference(for: category) else { continue }
                                state.setPreference(preference, for: category)
                            }
                        }
                        // Swap active quests to the new units in place —
                        // the daily/weekly generators no-op mid-period.
                        state.applyPreferenceChangesToActiveQuests()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .onAppear {
            guard let rpgClass = state.user.rpgClass else { return }
            stagedPreferences = Dictionary(uniqueKeysWithValues: rpgClass.focusCategories.map {
                ($0, state.getPreference(for: $0))
            })
        }
    }
}

struct ChallengePreferenceRow: View {
    @EnvironmentObject var state: AppState
    let category: FocusGroup
    @Binding var preference: ChallengePreference

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(state.getStatName(for: category))
                    .font(RPGTheme.heading(.headline, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            let availablePreferences = state.getAvailablePreferences(for: category)
            let currentPreference = preference

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availablePreferences, id: \.self) { preference in
                        let isSelected = currentPreference == preference
                        Button(action: {
                            self.preference = preference
                        }) {
                            Text(preference.displayName)
                                .font(RPGTheme.label(13, weight: .semibold))
                                .foregroundColor(isSelected ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .frame(minHeight: 44)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? RPGTheme.accentFill : RPGTheme.surfaceInner)
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(RPGTheme.frame.opacity(isSelected ? 0 : RPGTheme.hairline), lineWidth: 1)
                                )
                                .contentShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 1)
            }

            Text(getPreferenceDescription(for: category, preference: currentPreference))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }

    private func getPreferenceDescription(for category: FocusGroup, preference: ChallengePreference) -> String {
        let statName = state.getStatName(for: category).lowercased()

        switch preference {
        case .time:
            return "Track \(statName) challenges by time spent"
        case .distance:
            return "Track \(statName) challenges by distance covered"
        case .frequency:
            return "Track \(statName) challenges by number of sessions"
        case .sets:
            return "Track \(statName) challenges by sets completed"
        case .reps:
            return "Track \(statName) challenges by repetitions completed"
        case .times:
            return "Track \(statName) challenges by rounds completed"
        }
    }
}
