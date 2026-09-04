import SwiftUI
import Foundation
import UIKit

// MARK: - App shell
//
// Four destinations, each answering one question:
//   Character — who am I, what do I own, what grew?
//   Train     — what do I do right now?
//   Journey   — where am I in the world, what is asked of me today?
//   Progress  — what has the training actually built?

enum AppTab: Hashable {
    case character, train, journey, progress
}

/// Lets any screen send the user to another destination ("Begin your first
/// session" on Character lands on Train) without threading bindings.
final class TabRouter: ObservableObject {
    @Published var selected: AppTab = .character
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @StateObject private var router = TabRouter()
    @State private var showOnboarding = false
    @State private var onboardingSession = UUID()
    #if DEBUG
    @State private var appliedScreenshotSeed = false
    #endif
    @Environment(\.scenePhase) private var scenePhase

    private var needsOnboarding: Bool {
        !hasSeenOnboarding || (state.user.bodyweightKg ?? 0) <= 0
    }

    private var questsRemaining: Int {
        state.user.dailyChallenges.filter { $0.isActive && !$0.isCompleted }.count
            + state.user.weeklyChallenges.filter { $0.isActive && !$0.isCompleted }.count
    }

    var body: some View {
        ZStack {
            TabView(selection: $router.selected) {
                CharacterView()
                    .tabItem { Label { Text("Character") } icon: { Image(uiImage: RPGSymbol.character.uiImage(pointSize: 26)) } }
                    .tag(AppTab.character)
                    .environmentObject(state)

                TrainHomeView()
                    .tabItem { Label { Text("Train") } icon: { Image(uiImage: RPGSymbol.training.uiImage(pointSize: 26)) } }
                    .tag(AppTab.train)
                    .environmentObject(state)

                JourneyView()
                    .tabItem { Label { Text("Journey") } icon: { Image(uiImage: RPGSymbol.journey.uiImage(pointSize: 26)) } }
                    .tag(AppTab.journey)
                    .badge(questsRemaining)
                    .environmentObject(state)

                ProgressHomeView()
                    .tabItem { Label { Text("Progress") } icon: { Image(uiImage: RPGSymbol.progress.uiImage(pointSize: 26)) } }
                    .tag(AppTab.progress)
                    .environmentObject(state)
            }
            .tint(RPGTheme.accent)
            .environmentObject(router)

            if let error = state.persistenceError {
                PersistenceBanner(message: error)
                    .environmentObject(state)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: state.persistenceError)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                .environmentObject(state)
                // Fresh identity per presentation — a re-shown cover must
                // never resume mid-flow with a previous run's page/answers.
                .id(onboardingSession)
        }
        .onChangeCompat(of: hasSeenOnboarding) { _, _ in
            syncOnboardingPresentation()
            seedScreenshotDataIfRequested()
        }
        .overlay(alignment: .top) {
            RewardToastStack(toasts: state.toasts)
        }
        .alert("Check your input", isPresented: Binding(
            get: { state.inputWarning != nil },
            set: { if !$0 { state.inputWarning = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.inputWarning ?? "")
        }
        .onChangeCompat(of: scenePhase) { _, phase in
            // Flush pending writes the moment we leave the foreground — a
            // force-quit right after an action must never lose that action.
            if phase == .background || phase == .inactive {
                state.save(immediately: true)
            }
            if phase == .active {
                state.maintainStreak()
                state.checkComebackQuest()
            }
        }
        .onAppear {
            syncOnboardingPresentation()
            seedScreenshotDataIfRequested()
            state.maintainStreak()
            state.checkComebackQuest()
        }
    }

    private func syncOnboardingPresentation() {
        let needed = needsOnboarding
        if needed && !showOnboarding {
            onboardingSession = UUID()
        }
        if showOnboarding != needed {
            showOnboarding = needed
        }
    }

    /// UI-test-only entry point for deterministic App Store captures. Keeping
    /// this behind DEBUG avoids a fragile Settings-popover scroll on iPad;
    /// the harness still backgrounds, terminates, and relaunches without the
    /// flag to prove the ordinary save path retained the seed.
    private func seedScreenshotDataIfRequested() {
        #if DEBUG
        guard !appliedScreenshotSeed,
              hasSeenOnboarding,
              ProcessInfo.processInfo.arguments.contains("-rpgfit-seed-screenshot-data")
        else { return }
        appliedScreenshotSeed = true
        state.seedScreenshotData()
        #endif
    }
}

/// Persistence problems are the one thing that may interrupt any screen:
/// a save that cannot land is a save the player must know about.
struct PersistenceBanner: View {
    let message: String
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(RPGTheme.warningText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(.caption)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 16) {
                        if state.canRestoreBackup {
                            Button("Restore Backup") { state.restoreFromBackup() }
                                .buttonStyle(RPGQuietButtonStyle())
                        }
                        Button("Retry Save") { state.retrySave() }
                            .buttonStyle(RPGQuietButtonStyle())
                    }
                }
                Spacer()
                Button("Dismiss") { state.persistenceError = nil }
                    .buttonStyle(RPGQuietButtonStyle(tint: .secondary))
            }
            .rpgCard(padding: 14, accent: RPGTheme.warningText)
            .padding(.horizontal)

            Spacer()
        }
    }
}

/// Stacked celebration banners (quest completions, bonus-XP level ups,
/// streak events). Purely informational — auto-dismissing, never modal.
struct RewardToastStack: View {
    let toasts: [AppState.RewardToast]

    private func tint(for kind: AppState.RewardToast.Kind) -> Color {
        switch kind {
        case .xp: return RPGTheme.xp
        case .gold: return RPGTheme.gold
        case .accent: return RPGTheme.accent
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(toasts) { toast in
                HStack(spacing: 10) {
                    if let symbol = toast.symbol {
                        RPGSymbolIcon(
                            symbol: symbol,
                            size: 22,
                            presentation: .compact,
                            palette: .monochrome(tint(for: toast.kind))
                        )
                    } else if let icon = toast.icon {
                        Image(systemName: icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(tint(for: toast.kind))
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(toast.title)
                            .font(RPGTheme.heading(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        if let subtitle = toast.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                        .fill(RPGTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                                .strokeBorder(tint(for: toast.kind).opacity(0.5), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .frame(maxWidth: 420)
        .allowsHitTesting(false)
    }
}

// MARK: - Character

/// The character sheet. One marquee element (the identity plate), then the
/// things a character has: today's state, attributes, a companion, a
/// loadout. Every panel's secondary action sits beside what it affects.
struct CharacterView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var router: TabRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("lastViewedLevel") private var lastViewedLevel: Int = 1

    @State private var showSettings = false
    @State private var showClassSelection = false
    @State private var showStreak = false
    @State private var showShop = false
    @State private var showRanks = false
    @State private var satchelDestination: SatchelView.Section? = nil

    // Level display — animated separately from the model so a level-up can
    // be replayed as a ceremony instead of a jump cut.
    @State private var displayLevel: Int = 1
    @State private var displayPrestige: Int = 0
    @State private var displayXP: Double = 0
    @State private var displayNext: Double = 100
    @State private var displayProgress: Double = 0
    @State private var celebrating = false
    @State private var levelUpTask: Task<Void, Never>? = nil

    private var usesAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    identityPlate

                    AdaptiveColumns {
                        todayPanel
                        attributesPanel
                        companionSection
                        loadoutSection
                    }
                }
                .screenColumn(maxWidth: sizeClass == .regular ? AppLayout.wideMaxWidth : AppLayout.contentMaxWidth)
                .padding(.vertical, 16)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("Character")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.medium))
                            .foregroundColor(RPGTheme.accent)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(isPresented: $showRanks) {
                RanksExplanationView()
            }
            .navigationDestination(item: $satchelDestination) { section in
                SatchelView(initialSection: section)
                    .environmentObject(state)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(state)
            }
            .sheet(isPresented: $showClassSelection) {
                ClassSelectionView()
                    .environmentObject(state)
            }
            .sheet(isPresented: $showStreak) {
                StreakSheet()
                    .environmentObject(state)
            }
            .sheet(isPresented: $showShop) {
                PetShopView()
                    .environmentObject(state)
            }
            .onAppear {
                celebrateIfNeeded()
            }
            .onDisappear {
                levelUpTask?.cancel()
                levelUpTask = nil
                if celebrating {
                    celebrating = false
                    lastViewedLevel = state.user.level
                }
                syncDisplay(animated: false)
            }
            .onChangeCompat(of: state.user.xp) { _, _ in
                guard !celebrating else { return }
                syncDisplay(animated: true)
            }
        }
    }

    // MARK: Identity plate

    private var identityLine: String {
        guard let rpgClass = state.user.rpgClass else { return "Choose your class" }
        if let epithet = state.user.placement?.epithet, !epithet.isEmpty {
            return "\(rpgClass.displayName), \(epithet)"
        }
        return rpgClass.displayName
    }

    private var nextLevelCaption: String {
        if celebrating { return "Level up!" }
        if state.user.level >= 100 { return "Max level · XP becomes coins" }
        let pct = displayNext > 0 ? Int((displayXP / displayNext) * 100) : 0
        return "\(pct)% to Level \(state.user.level + 1)"
    }

    private var identityPlate: some View {
        VStack(spacing: 14) {
            if usesAccessibilityLayout {
                // Accessibility sizes: everything stacks; nothing truncates.
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        LevelSeal(level: displayLevel, prestige: displayPrestige, size: 44)
                        Spacer(minLength: 0)
                        CoinBadge(amount: state.user.coins, size: 14)
                    }
                    identityText
                }
            } else {
            HStack(alignment: .center, spacing: 14) {
                LevelSeal(level: displayLevel, prestige: displayPrestige, size: 54)
                    .scaleEffect(celebrating && !reduceMotion ? 1.06 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: celebrating)

                identityText
                    .layoutPriority(1)

                Spacer(minLength: 6)

                CoinBadge(amount: state.user.coins, size: 14)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().strokeBorder(RPGTheme.gold.opacity(0.45), lineWidth: 1)
                    )
                    .fixedSize()
            }
            }

            xpReadout
        }
        .rpgCard(padding: 18, ornate: true)
    }

    private var identityText: some View {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Level \(displayLevel)")
                            .font(RPGTheme.heading(usesAccessibilityLayout ? 24 : 30))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(reduceMotion ? .identity : .numericText())
                        if displayPrestige > 0 {
                            HStack(spacing: 2) {
                                ForEach(0..<min(displayPrestige, 5), id: \.self) { _ in
                                    RPGSymbolIcon(
                                        symbol: .rank,
                                        size: 12,
                                        presentation: .compact,
                                        palette: .monochrome(RPGTheme.gold)
                                    )
                                }
                                if displayPrestige > 5 {
                                    Text("×\(displayPrestige)")
                                        .font(RPGTheme.label(10, weight: .bold))
                                        .foregroundColor(RPGTheme.gold)
                                }
                            }
                            .accessibilityLabel("Prestige \(displayPrestige)")
                        }
                    }

                    Button {
                        showClassSelection = true
                    } label: {
                        HStack(spacing: 4) {
                            if let rpgClass = state.user.rpgClass {
                                ClassEmblem(rpgClass: rpgClass, size: 20)
                            }
                            Text(identityLine)
                                .font(RPGTheme.heading(.subheadline, weight: .semibold))
                                .foregroundColor(.secondary)
                                .lineLimit(usesAccessibilityLayout ? nil : 2)
                                .minimumScaleFactor(usesAccessibilityLayout ? 1 : 0.85)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(RPGTheme.frame)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(state.user.rpgClass == nil ? "Choose your class" : "Class: \(identityLine)")
                    .accessibilityHint(state.user.rpgClass == nil ? "Opens class selection" : "Changes your class")
                }
    }

    @ViewBuilder
    private var xpReadout: some View {
            VStack(spacing: 7) {
                OrnateProgressBar(progress: displayProgress, tint: RPGTheme.xp, height: 10, label: "Experience toward next level")
                let counter = Text("\(Int(displayXP)) / \(Int(displayNext)) XP")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                let caption = Text(nextLevelCaption)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(celebrating ? RPGTheme.gold : RPGTheme.xp)
                if usesAccessibilityLayout {
                    VStack(alignment: .leading, spacing: 2) {
                        counter.contentTransition(reduceMotion ? .identity : .numericText())
                        caption
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack {
                        counter.contentTransition(reduceMotion ? .identity : .numericText())
                        Spacer()
                        caption
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Int(displayXP)) of \(Int(displayNext)) experience points. \(nextLevelCaption)")
    }

    // MARK: Level display / celebration

    private func syncDisplay(animated: Bool) {
        displayLevel = state.user.displayLevel
        displayPrestige = state.user.prestigeLevel
        displayNext = state.user.nextLevelXP
        let fraction = displayNext > 0 ? min(1, state.user.xp / displayNext) : 0
        if animated && !reduceMotion {
            withAnimation(.easeOut(duration: 0.9)) {
                displayXP = state.user.xp
                displayProgress = fraction
            }
        } else {
            displayXP = state.user.xp
            displayProgress = fraction
        }
    }

    /// Replays every level gained since the sheet was last read — a short
    /// ceremony per level, then the true bar. Reduce Motion skips straight
    /// to the truth.
    private func celebrateIfNeeded() {
        let current = state.user.level
        let start = lastViewedLevel
        lastViewedLevel = current

        guard current > start, start > 0, !reduceMotion else {
            displayProgress = 0
            displayXP = 0
            syncDisplay(animated: true)
            return
        }

        levelUpTask?.cancel()
        celebrating = true
        levelUpTask = Task { @MainActor in
            for level in start..<current {
                if Task.isCancelled { return }
                displayLevel = level <= 10 ? level : ((level - 1) % 10) + 1
                displayPrestige = level > 10 ? min((level - 1) / 10, StatEngine.maxPrestige) : 0
                displayNext = StatEngine.xpNeeded(forNextLevel: level)
                displayXP = 0
                displayProgress = 0
                try? await Task.sleep(nanoseconds: 120_000_000)
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.8)) {
                    displayProgress = 1
                    displayXP = displayNext
                }
                try? await Task.sleep(nanoseconds: 950_000_000)
                if Task.isCancelled { return }
                Haptics.success()
            }
            displayProgress = 0
            displayXP = 0
            celebrating = false
            syncDisplay(animated: true)
        }
    }

    // MARK: Today

    private var unopenedChests: Int {
        state.user.treasureChests.filter { !$0.isOpened }.count
    }

    @ViewBuilder
    private var todayPanel: some View {
        let streak = state.currentStreak()
        let chronicle = state.yesterdayChronicle
        let showNudge = state.history.isEmpty
        if streak >= 1 || chronicle != nil || unopenedChests > 0 || showNudge {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("Today")
                    .padding(.bottom, 6)

                if showNudge {
                    Button {
                        router.selected = .train
                    } label: {
                        RPGRow(title: "Begin your first session",
                               subtitle: "One logged set and this sheet starts to fill.") {
                            RPGSymbolIcon(
                                symbol: .training,
                                size: 20,
                                presentation: .compact,
                                palette: .monochrome(RPGTheme.plate)
                            )
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                }

                if streak >= 1 {
                    if showNudge { HairlineRule() }
                    Button {
                        showStreak = true
                    } label: {
                        RPGRow(title: "\(streak)-day streak",
                               subtitle: streakSubtitle(streak)) {
                            RPGSymbolIcon(
                                symbol: .streak,
                                size: 20,
                                presentation: .compact,
                                palette: .monochrome(RPGTheme.gold)
                            )
                        } trailing: {
                            HStack(spacing: 3) {
                                RPGSymbolIcon(
                                    symbol: .streakFreeze,
                                    size: 13,
                                    presentation: .compact,
                                    palette: .monochrome(RPGTheme.accent)
                                )
                                Text("\(state.user.streakFreezes)")
                                    .font(RPGTheme.label(12, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .foregroundColor(RPGTheme.accent)
                            .accessibilityLabel("\(state.user.streakFreezes) streak freezes")
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                }

                if let chronicle {
                    if streak >= 1 || showNudge { HairlineRule() }
                    RPGRow(title: "Yesterday's Chronicle",
                           subtitle: chronicle.summaryLine,
                           chevron: false) {
                        RPGSymbolIcon(
                            symbol: .chronicle,
                            size: 20,
                            presentation: .compact,
                            palette: .monochrome(RPGTheme.accent)
                        )
                    }
                    .accessibilityElement(children: .combine)
                }

                if unopenedChests > 0 {
                    if streak >= 1 || chronicle != nil || showNudge { HairlineRule() }
                    Button {
                        satchelDestination = .chests
                    } label: {
                        RPGRow(title: unopenedChests == 1 ? "A chest is waiting" : "\(unopenedChests) chests are waiting",
                               subtitle: "Open them in your Satchel.") {
                            RPGSymbolIcon(
                                symbol: .chest,
                                size: 20,
                                presentation: .compact,
                                palette: .monochrome(RPGTheme.gold)
                            )
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .rpgCard(padding: 14)
        }
    }

    private func streakSubtitle(_ streak: Int) -> String {
        if streak >= 7 { return "A true adventurer's rhythm." }
        return "One session a day keeps the fire lit."
    }

    // MARK: Attributes

    private var attributesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Attributes") {
                Button("Ranks") { showRanks = true }
                    .buttonStyle(RPGQuietButtonStyle())
                    .accessibilityHint("Explains attribute rank tiers")
            }

            let pairs = state.user.stats.statPairs
            let maxValue = max(0.0001, pairs.map(\.value).max() ?? 0)

            if usesAccessibilityLayout {
                VStack(spacing: 14) {
                    RadarChartView(stats: state.user.stats)
                        .frame(width: 140, height: 132)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(radarAccessibilitySummary)
                    attributeRows(pairs: pairs, maxValue: maxValue)
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    RadarChartView(stats: state.user.stats)
                        .frame(width: 124, height: 118)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(radarAccessibilitySummary)
                    attributeRows(pairs: pairs, maxValue: maxValue)
                }
            }
        }
        .rpgCard()
    }

    private func attributeRows(pairs: [(stat: Stat, value: Double)], maxValue: Double) -> some View {
        VStack(spacing: 8) {
            ForEach(pairs, id: \.stat) { pair in
                AttributeRow(stat: pair.stat,
                             value: pair.value,
                             fraction: pair.value / maxValue,
                             tier: state.user.attributeRank(for: pair.value))
            }
        }
    }

    /// Spoken summary of the radar chart for VoiceOver users.
    private var radarAccessibilitySummary: String {
        let parts = state.user.stats.statPairs.map {
            "\($0.stat.name) \(String(format: "%.1f", $0.value))"
        }
        return "Attribute chart. " + parts.joined(separator: ", ")
    }

    // MARK: Companion & loadout

    private var companionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Companion") {
                Button("Shop") { showShop = true }
                    .buttonStyle(RPGQuietButtonStyle())
                    .accessibilityLabel("Companion Shop")
            }
            CompanionCard()
                .environmentObject(state)
        }
    }

    private var loadoutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Loadout") {
                Button {
                    satchelDestination = .items
                } label: {
                    HStack(spacing: 4) {
                        Text("Satchel")
                        if unopenedChests > 0 {
                            Text("\(unopenedChests)")
                                .font(RPGTheme.label(10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(RPGTheme.goldFill))
                        }
                    }
                }
                .buttonStyle(RPGQuietButtonStyle())
                .accessibilityLabel(unopenedChests > 0 ? "Satchel, \(unopenedChests) unopened chests" : "Satchel")
            }
            LoadoutCard(onEmptySlotTap: { satchelDestination = .items })
                .environmentObject(state)
        }
    }
}

/// One attribute: glyph, abbreviation, value, a thin relative bar, rank.
struct AttributeRow: View {
    let stat: Stat
    let value: Double
    let fraction: Double
    let tier: RankTier

    var body: some View {
        HStack(spacing: 8) {
            StatIcon(stat: stat, size: 13)
                .frame(width: 16)
            Text(stat.abbreviation)
                .font(RPGTheme.label(11, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .leading)
            Text(String(format: "%.1f", value))
                .font(RPGTheme.display(15, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(stat.color)
                .frame(minWidth: 42, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(RPGTheme.surfaceInner)
                    Capsule()
                        .fill(stat.color.opacity(0.85))
                        .frame(width: max(value > 0 ? 4 : 0, min(geo.size.width, CGFloat(fraction) * geo.size.width)))
                }
            }
            .frame(height: 4)

            AttributeRankBadge(tier: tier)
                .scaleEffect(0.85)
        }
        .frame(minHeight: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.name) \(String(format: "%.1f", value)), \(tier.rawValue) rank")
    }
}

// MARK: - Streak

/// The streak explained, with the one thing you can do about it: keep a
/// freeze in reserve. Nothing here punishes — a missed day is covered, and
/// an uncovered one simply starts a new chain.
struct StreakSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    private var canBuy: Bool {
        state.user.streakFreezes < 3 && state.user.coins >= 250
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    let streak = state.currentStreak()
                    VStack(spacing: 8) {
                        RPGSymbolIcon(symbol: .streak, size: 52, presentation: .hero)
                        Text(streak == 1 ? "1-day streak" : "\(streak)-day streak")
                            .font(RPGTheme.heading(28))
                        Text("One session a day keeps the fire lit. Miss a day and a freeze covers it; nothing is ever taken from you.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Freezes")
                        RPGRow(title: "\(state.user.streakFreezes) of 3 in reserve",
                               subtitle: "Spent automatically on a missed day. One is earned for every seven-day streak.",
                               chevron: false) {
                            RPGSymbolIcon(
                                symbol: .streakFreeze,
                                size: 22,
                                presentation: .compact,
                                palette: .monochrome(RPGTheme.accent)
                            )
                        }
                        .accessibilityElement(children: .combine)

                        Button {
                            if state.buyStreakFreeze() { Haptics.success() }
                        } label: {
                            HStack(spacing: 8) {
                                Text(state.user.streakFreezes >= 3 ? "Reserve full" : "Buy a Freeze")
                                if state.user.streakFreezes < 3 {
                                    CoinBadge(amount: 250, size: 13)
                                }
                            }
                        }
                        .buttonStyle(RPGSecondaryButtonStyle())
                        .disabled(!canBuy)
                        .accessibilityHint(canBuy ? "Costs 250 coins" : (state.user.streakFreezes >= 3 ? "You already hold three freezes" : "Not enough coins"))

                        HStack(spacing: 4) {
                            Text("You have")
                            CoinBadge(amount: state.user.coins, size: 12)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .rpgCard()
                }
                .screenColumn()
                .padding(.vertical, 16)
            }
            .background(AppBackground())
            .navigationTitle("Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Ranks

struct RanksExplanationView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .strokeBorder(RPGTheme.gold.opacity(0.5), lineWidth: 1)
                            .frame(width: 76, height: 76)
                        RPGSymbolIcon(symbol: .rank, size: 48, presentation: .hero)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Attribute Ranks")
                            .font(RPGTheme.heading(24))
                            .foregroundColor(.primary)

                        Text("Each attribute is ranked on its own, against standards for a trained body. Every rank is reachable through consistent work.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                }
                .rpgCard(padding: 24, ornate: true)

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel("Rank Tiers")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                              spacing: 12) {
                        ForEach(RankTier.allCases, id: \.self) { rank in
                            RankExplanationCard(rank: rank)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel("How Rankings Work")

                    VStack(alignment: .leading, spacing: 12) {
                        RankFeatureRow(
                            symbol: .progress,
                            title: "Built from your log",
                            description: "Each attribute grows from the training that feeds it."
                        )
                        RankFeatureRow(
                            symbol: .rankIndependent,
                            title: "Independent",
                            description: "Strength can be Gold while Endurance is still Bronze."
                        )
                        RankFeatureRow(
                            symbol: .rank,
                            title: "Reachable",
                            description: "The anchors are real-world standards, not a leaderboard."
                        )
                        RankFeatureRow(
                            symbol: .rankCurrent,
                            title: "Always current",
                            description: "Ranks update every time a session is logged."
                        )
                    }
                }
                .rpgCard()
            }
            .screenColumn()
            .padding(.vertical, 16)
        }
        .background(AppBackground())
        .navigationTitle("Ranks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RankExplanationCard: View {
    let rank: RankTier

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .strokeBorder(rank.color.opacity(0.45), lineWidth: 1)
                    .frame(width: 40, height: 40)
                RankIcon(tier: rank, size: 24)
            }
            .accessibilityHidden(true)

            Text(rank.rawValue)
                .font(RPGTheme.heading(.headline, weight: .semibold))
                .foregroundColor(.primary)

            Text(rank.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                .fill(RPGTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                        .strokeBorder(rank.color.opacity(0.35), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

struct RankFeatureRow: View {
    let symbol: RPGSymbol
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            RPGSymbolIcon(
                symbol: symbol,
                size: 22,
                presentation: .compact,
                palette: .monochrome(RPGTheme.accent)
            )
            .frame(width: 28)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Radar

/// The shape of the character: a six-axis hexagon normalized to the
/// strongest attribute, drawn in brass rings.
struct RadarChartView: View {
    let stats: StatBlock
    @Environment(\.colorScheme) var colorScheme
    private let axes = Stat.allCases

    private var dominantColor: Color {
        let top = stats.statPairs.max { a, b in a.value < b.value }?.stat ?? .vitality
        return top.color
    }

    private var values: [Double] {
        stats.statPairs.map(\.value)
    }

    var body: some View {
        GeometryReader { geo in
            let n = axes.count
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size * 0.40
            let maxVal = max(values.max() ?? 1, 0.0001)
            let normalized = values.map { $0 / maxVal }
            let ringCount = 3
            let ringOpacity: Double = colorScheme == .dark ? 0.40 : 0.32

            ZStack {
                ForEach(1...ringCount, id: \.self) { i in
                    let frac = CGFloat(i) / CGFloat(ringCount)
                    Polygon(sides: n)
                        .stroke(RPGTheme.frame.opacity(i == ringCount ? ringOpacity + 0.2 : ringOpacity), lineWidth: i == ringCount ? 1.2 : 0.8)
                        .frame(width: radius * 2 * frac, height: radius * 2 * frac)
                        .position(center)
                }

                ForEach(0..<n, id: \.self) { i in
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: point(for: Double(i), total: n, center: center, radius: radius))
                    }
                    .stroke(RPGTheme.frame.opacity(ringOpacity * 0.7), lineWidth: 0.8)
                }

                if values.contains(where: { $0 > 0 }) {
                    Path { p in
                        for i in 0..<n {
                            let r = radius * normalized[i]
                            let pt = point(for: Double(i), total: n, center: center, radius: r)
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                        p.closeSubpath()
                    }
                    .fill(dominantColor.opacity(0.16))
                    .overlay(
                        Path { p in
                            for i in 0..<n {
                                let r = radius * normalized[i]
                                let pt = point(for: Double(i), total: n, center: center, radius: r)
                                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                            }
                            p.closeSubpath()
                        }
                        .stroke(dominantColor.opacity(0.85), lineWidth: 1.6)
                    )
                }

                ForEach(0..<n, id: \.self) { i in
                    let labelPt = point(for: Double(i), total: n, center: center, radius: radius + 13)
                    StatIcon(stat: axes[i], size: 12)
                        .position(labelPt)
                }
            }
        }
    }

    private func point(for index: Double, total: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = (-Double.pi / 2) + (2 * Double.pi) * (index / Double(total))
        return CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                       y: center.y + CGFloat(sin(angle)) * radius)
    }
}

struct Polygon: Shape {
    var sides: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        guard sides > 2 else { return p }
        for i in 0..<sides {
            let angle = (-Double.pi / 2) + 2 * Double.pi * Double(i) / Double(sides)
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r, y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
