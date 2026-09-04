import SwiftUI

// MARK: - Journey
//
// Where am I in the world, and what is asked of me today? The region names
// the place, the Trial is the thing that stands in the road, and the quests
// are today's work. Class identity lives on Character; this screen is about
// the road ahead.

struct JourneyView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showClassSelection = false
    @State private var showChallengeSettings = false
    @State private var showCampaign = false
    @State private var showCompleted = false

    private var currentRegion: CampaignRegion {
        let rung = state.user.trialRung
        return CampaignRegion.all.first { $0.rungs.contains(rung) }
            ?? CampaignRegion(name: "The Elder Wilds",
                              flavor: "Beyond the last map. The Elders wait in cycles.",
                              rungs: 12...Int.max)
    }

    private var activeDaily: [Challenge] { state.user.dailyChallenges.filter { $0.isActive } }
    private var activeWeekly: [Challenge] { state.user.weeklyChallenges.filter { $0.isActive } }
    private var completed: [Challenge] {
        (state.user.dailyChallenges + state.user.weeklyChallenges)
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if state.user.rpgClass == nil {
                    noClass
                } else {
                    content
                }
            }
            .background(AppBackground())
            .navigationTitle("Journey")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if state.user.rpgClass != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showChallengeSettings = true
                            } label: {
                                RPGSymbolLabel("Quest Preferences", symbol: .quest)
                            }
                            Button {
                                showClassSelection = true
                            } label: {
                                RPGSymbolLabel(
                                    "Change Class",
                                    symbol: state.user.rpgClass?.rpgSymbol ?? .character
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body.weight(.medium))
                                .foregroundColor(RPGTheme.accent)
                        }
                        .accessibilityLabel("Journey options")
                    }
                }
            }
            .sheet(isPresented: $showClassSelection) {
                ClassSelectionView()
                    .environmentObject(state)
            }
            .sheet(isPresented: $showChallengeSettings) {
                ChallengeSettingsView()
                    .environmentObject(state)
            }
            .sheet(isPresented: $showCampaign) {
                CampaignMapView()
                    .environmentObject(state)
            }
            .onAppear {
                // Generate quests if needed (no-ops once per period)
                if state.user.rpgClass != nil {
                    state.generateDailyChallenges()
                    state.generateWeeklyChallenges()
                }
            }
        }
    }

    private var noClass: some View {
        VStack(spacing: 8) {
            Spacer()
            EmptyStateView(
                title: "Choose Your Class",
                message: "A class shapes the daily and weekly quests the road asks of you.",
                actionTitle: "Select Class",
                action: { showClassSelection = true },
                symbol: .quest
            )
            Spacer()
        }
        .screenColumn()
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                regionBanner

                AdaptiveColumns {
                    TrialCard()
                        .environmentObject(state)

                    VStack(spacing: 16) {
                        questPanel(title: "Today", challenges: activeDaily,
                                   empty: "No daily quests remain. The road rests until tomorrow.")
                        questPanel(title: "This Week", challenges: activeWeekly,
                                   empty: "The week's quests are done.")
                        completedPanel
                    }
                }
            }
            .screenColumn(maxWidth: sizeClass == .regular ? AppLayout.wideMaxWidth : AppLayout.contentMaxWidth)
            .padding(.vertical, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: Region

    private var regionBanner: some View {
        Button {
            showCampaign = true
        } label: {
            HStack(spacing: 14) {
                RPGSymbolIcon(
                    symbol: currentRegion.rpgSymbol,
                    size: 26,
                    presentation: .standard,
                    palette: .adaptive
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentRegion.name)
                        .font(RPGTheme.heading(.title3, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(currentRegion.flavor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text("Campaign Map")
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .foregroundColor(RPGTheme.accent)
                .fixedSize()
            }
            .rpgCard(padding: 14)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("\(currentRegion.name). Campaign Map")
        .accessibilityHint("Opens the campaign map")
    }

    // MARK: Quests

    @ViewBuilder
    private func questPanel(title: String, challenges: [Challenge], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(title) {
                if !challenges.isEmpty {
                    Text("\(challenges.count) open")
                        .font(RPGTheme.label(11, weight: .medium))
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
            }
            .padding(.bottom, 6)

            if challenges.isEmpty {
                Text(empty)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(challenges.enumerated()), id: \.element.id) { index, challenge in
                    if index > 0 { HairlineRule() }
                    QuestRow(challenge: challenge)
                }
            }
        }
        .rpgCard(padding: 14)
    }

    @ViewBuilder
    private var completedPanel: some View {
        let done = completed
        if !done.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                        showCompleted.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("COMPLETED")
                            .font(RPGTheme.label(11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundColor(RPGTheme.xp)
                            .accessibilityLabel("Completed")
                        HairlineRule(tint: RPGTheme.xp)
                        Text("\(done.count)")
                            .font(RPGTheme.label(11, weight: .semibold))
                            .foregroundColor(RPGTheme.xp)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(RPGTheme.xp)
                            .rotationEffect(.degrees(showCompleted ? 180 : 0))
                            .animation(reduceMotion ? nil : .default, value: showCompleted)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue(showCompleted ? "Expanded" : "Collapsed")

                if showCompleted {
                    ForEach(Array(done.enumerated()), id: \.element.id) { index, challenge in
                        if index > 0 { HairlineRule() }
                        HStack(spacing: 10) {
                            RPGSymbolIcon(
                                symbol: .completionSeal,
                                size: 18,
                                presentation: .compact,
                                palette: .monochrome(RPGTheme.xp)
                            )
                                .frame(width: 30)
                                .accessibilityHidden(true)
                            Text(challenge.title)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .strikethrough()
                                .lineLimit(1)
                            Spacer()
                            Text("+\(challenge.expReward) XP")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundColor(RPGTheme.xp)
                        }
                        .frame(minHeight: 36)
                        .accessibilityElement(children: .combine)
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
            .rpgCard(padding: 14)
        }
    }
}

/// One quest as a row: a progress ring around the attribute glyph, the
/// title, a counted line, and the reward. The authored flavor line stays —
/// it is the quest's voice, and one sentence is not clutter.
struct QuestRow: View {
    let challenge: Challenge
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var stat: Stat { challenge.targetCategory.primaryStat }

    private var progressText: String {
        if challenge.unit == .exercises {
            return "\(challenge.uniqueExercises.count)/\(challenge.targetAmount) \(challenge.unit.displayName)"
        }
        return "\(challenge.progress)/\(challenge.targetAmount) \(challenge.unit.displayName)"
    }

    private var timeRemaining: String {
        let interval = challenge.expiresAt.timeIntervalSince(Date())
        if interval <= 0 { return "Expired" }
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        let days = hours / 24
        if days > 0 { return "\(days)d left" }
        if hours > 0 { return "\(hours)h left" }
        return "\(max(1, minutes))m left"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(RPGTheme.surfaceInner, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(challenge.progressPercentage))
                    .stroke(challenge.isCompleted ? RPGTheme.xp : stat.color,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8),
                               value: challenge.progressPercentage)
                StatIcon(stat: stat, size: 13)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(challenge.title)
                        .font(RPGTheme.heading(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    if challenge.isComeback ?? false {
                        PillTag(text: "Comeback", tint: RPGTheme.gold)
                    } else if challenge.type == .weekly {
                        PillTag(text: "Weekly", tint: RPGTheme.goldDeep)
                    }
                }
                Text("\(progressText) · \(timeRemaining)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                Text(QuestVoice.flavor(for: challenge))
                    .font(.caption2.italic())
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if challenge.isCompleted {
                RPGSymbolIcon(
                    symbol: .completionSeal,
                    size: 20,
                    presentation: .compact,
                    palette: .monochrome(RPGTheme.xp)
                )
                    .accessibilityHidden(true)
            } else {
                Text("+\(challenge.expReward) XP")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundColor(RPGTheme.xp)
                    .fixedSize()
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(challenge.title). \(progressText), \(timeRemaining). \(challenge.isCompleted ? "Completed." : "Rewards \(challenge.expReward) experience points.")")
    }
}
