import SwiftUI
import Foundation
import UIKit

// MARK: - Onboarding
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var page = 0
    @State private var isMovingForward = true
    @State private var bodyweightValue: Double = 150.0
    @State private var selectedGoals: [FitnessGoal] = []
    @State private var showWelcomeAnimation = false
    @State private var showFeatures = false
    // Staged until the final CTA fires — the rite writes nothing on its own.
    @State private var weighing = WeighingAnswers()
    @State private var ceremonyDone = false

    private var usesAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    private var pageAnnouncement: String {
        switch page {
        case 0: return "Welcome to RPGFit"
        case 1: return "Three Roads"
        case 2: return "Class Placement"
        case 3: return "Your Class"
        case 4: return "Almost There"
        case 5: return "The Weighing at the Ledgerstone"
        default: return "Your name is written"
        }
    }

    private func announcePageChange() {
        let announcement = pageAnnouncement
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .screenChanged, argument: announcement)
        }
    }

    private func advance() {
        if page < totalPages - 1 {
            if page == 5 {
                // An unread stone is a first-class outcome — record it as one
                // instead of an empty rite.
                weighing.skipped = !weighingMeasured
            }
            isMovingForward = true
            page += 1
            announcePageChange()
        } else if bodyweightValid {
            let kg = state.user.units.toKg(bodyweightValue)
            state.user.bodyweightKg = kg

            // The rite commits here, after the bodyweight it was weighed
            // against and before the class that names it.
            state.applyPlacement(record: stagedVerdict.makeRecord(carryingOver: state.user.placement))

            if let assignedClass = RPGClass.classPlacement(from: Set(selectedGoals)) {
                // Also generates the first day's quests, so the Quests tab is
                // alive from minute one.
                state.setRPGClass(assignedClass)
            }

            // Persist immediately — nothing else saves this profile until the
            // first workout is logged.
            state.save(immediately: true)
            hasSeenOnboarding = true
        }
    }

    private func goBack() {
        // Leaving the Naming re-arms its gate: returning replays the whole
        // ceremony from the top.
        if page == 6 { ceremonyDone = false }
        isMovingForward = false
        page -= 1
        announcePageChange()
    }

    // Helper function for goal selection
    private func toggleGoalSelection(_ goal: FitnessGoal) {
        if selectedGoals.contains(goal) {
            selectedGoals.removeAll { $0 == goal }
        } else if selectedGoals.count < 2 {
            selectedGoals.append(goal)
        }
    }

    // Bodyweight validator: must be in 25–350 kg
    private var bodyweightValid: Bool {
        let kg = state.user.units.toKg(bodyweightValue)
        return kg >= 25 && kg <= 350
    }

    // Get appropriate range for the slider based on units. The lower bound
    // must satisfy the 25 kg validator — 55 lb is 24.95 kg, which used to
    // leave the slider's own minimum an invalid, silently-stuck value.
    private var weightRange: ClosedRange<Double> {
        switch state.user.units {
        case .kg:
            return 25...200 // kg
        case .lb:
            return 56...440 // lbs
        }
    }

    private let totalPages = 7 // Welcome, Features, Class Placement, Class Reveal, Setup, Weighing, Naming

    /// True once a ladder or a drawer entry gives the stone something to read.
    /// Asked of the verdict, not of the staged fields: the Fire alone is not a
    /// measurement, and a drawer value typed before the fire was moved back down
    /// is one the rite will never read.
    private var weighingMeasured: Bool { stagedVerdict.hasReading }

    private var canProceed: Bool {
        switch page {
        case 0, 1: return true // Welcome and Features pages
        case 2: return selectedGoals.count == 2 // Goal selection (need exactly 2)
        case 3: return true // Class reveal page
        case 4: return bodyweightValid // Setup page
        case 5: return true // Everything on the Weighing is optional
        case 6: return ceremonyDone // Never complete mid-theater
        default: return false
        }
    }

    private var buttonTitle: String {
        switch page {
        case 0: return "Get Started"
        case 1: return "Continue"
        case 2:
            if selectedGoals.count == 0 {
                return "Select Your Goals"
            } else if selectedGoals.count == 1 {
                return "Select One More"
            } else if selectedGoals.count == 2 {
                return "Reveal My Class"
            } else {
                return "Select Only 2 Goals"
            }
        case 3: return "Continue"
        case 4: return PlacementCopy.approachCTA
        // Skipping is the default state of the primary button, never a buried
        // link — passing the stone unread must cost nothing.
        case 5: return weighingMeasured ? PlacementCopy.commitCTA : PlacementCopy.skipCTA
        case 6: return "Start Your Journey"
        default: return "Continue"
        }
    }

    private var buttonIcon: String {
        switch page {
        case 0, 1, 2, 3, 4, 5: return "arrow.right"
        case 6: return "checkmark"
        default: return "arrow.right"
        }
    }

    // The three roads through the app — one line each, no marketing wall.
    private let features: [(symbol: RPGSymbol, title: String, description: String)] = [
        (.training, "Train", "Log sets. Every one counts."),
        (.progress, "Progress", "Lifts leveled against real standards."),
        (.journey, "Journey", "Quests, Trials, and a map to cross.")
    ]

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? RPGTheme.accent : RPGTheme.frame.opacity(RPGTheme.hairline))
                    .frame(height: 4)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8),
                               value: page)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
        // Breathing room the scrolling pages need: content passing the top of
        // the viewport must not graze the dots.
        .padding(.bottom, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(page + 1) of \(totalPages)")
    }

    private var welcomeHeroIcon: some View {
        let diameter: CGFloat = usesAccessibilityLayout ? 88 : 120
        let rippleStep: CGFloat = usesAccessibilityLayout ? 20 : 30

        return ZStack {
            // Brass ripples (skipped under Reduce Motion) — hairlines that
            // spread and fade, never a glow.
            if !reduceMotion {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(RPGTheme.frame.opacity(0.35), lineWidth: 1)
                        .frame(width: diameter + CGFloat(index) * rippleStep,
                               height: diameter + CGFloat(index) * rippleStep)
                        .scaleEffect(showWelcomeAnimation ? 1.0 : 0.5)
                        .opacity(showWelcomeAnimation ? 0.0 : 1.0)
                        .animation(
                            Animation.easeOut(duration: 2.0)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                            value: showWelcomeAnimation
                        )
                }
            }

            // A brass ring on the panel surface, with a second hairline set
            // inside it — an engraved seal, not a badge.
            Circle()
                .fill(RPGTheme.surface)
                .overlay(Circle().strokeBorder(RPGTheme.frame.opacity(0.7), lineWidth: 1.5))
                .overlay(
                    Circle()
                        .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
                        .padding(7)
                )
                .frame(width: diameter, height: diameter)
                .scaleEffect(showWelcomeAnimation || reduceMotion ? 1.0 : 0.8)
                .animation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.6),
                           value: showWelcomeAnimation)

            RPGSymbolIcon(
                symbol: .character,
                size: usesAccessibilityLayout ? 52 : 68,
                presentation: .hero,
                palette: .adaptive
            )
                .scaleEffect(showWelcomeAnimation || reduceMotion ? 1.0 : 0.5)
                .animation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.6).delay(0.2),
                           value: showWelcomeAnimation)
        }
        .accessibilityHidden(true)
    }

    private var welcomeTitleSection: some View {
        VStack(spacing: usesAccessibilityLayout ? 8 : 16) {
            Text("Welcome to")
                .font(usesAccessibilityLayout ? .headline : .title2)
                .foregroundColor(.secondary)
                .opacity(showWelcomeAnimation || reduceMotion ? 1.0 : 0.0)
                .animation(reduceMotion ? nil : .easeIn(duration: 0.5), value: showWelcomeAnimation)
                .accessibilityAddTraits(.isHeader)

            Text("RPGFit")
                .font(usesAccessibilityLayout
                      ? RPGTheme.heading(.largeTitle, weight: .bold)
                      : RPGTheme.heading(48))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .opacity(showWelcomeAnimation || reduceMotion ? 1.0 : 0.0)
                .animation(reduceMotion ? nil : .easeIn(duration: 0.5).delay(0.2),
                           value: showWelcomeAnimation)

            Text("Your Fitness Adventure Begins")
                .font(usesAccessibilityLayout ? .headline : .title3)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showWelcomeAnimation || reduceMotion ? 1.0 : 0.0)
                .animation(reduceMotion ? nil : .easeIn(duration: 0.5).delay(0.4),
                           value: showWelcomeAnimation)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }

    private var welcomePage: some View {
        VStack(spacing: usesAccessibilityLayout ? 16 : 40) {
            if !usesAccessibilityLayout { Spacer() }

            VStack(spacing: 24) {
                welcomeHeroIcon
                welcomeTitleSection
            }

            if !usesAccessibilityLayout { Spacer() }
        }
        .padding(.vertical, usesAccessibilityLayout ? 16 : 0)
        .tag(0)
        .onAppear {
            if reduceMotion {
                showWelcomeAnimation = true
            } else {
                withAnimation { showWelcomeAnimation = true }
            }
        }
    }

    private var backgroundView: some View {
        // Same parchment/midnight world as the rest of the app — the front
        // door and the interior must share one identity.
        AppBackground()
    }

    private var featuresPage: some View {
        VStack(spacing: usesAccessibilityLayout ? 16 : 30) {
            if !usesAccessibilityLayout { Spacer() }

            VStack(spacing: 12) {
                Text("Three Roads")
                    .font(RPGTheme.heading(.largeTitle, weight: .bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Everything in RPGFit lives on one of them.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)
            .opacity(showFeatures || reduceMotion ? 1.0 : 0.0)
            .offset(y: showFeatures || reduceMotion ? 0 : 20)
            .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8),
                       value: showFeatures)

            // Three hairline rows on one quiet panel — the screen's single
            // flourish is the bracketed frame around them.
            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    if index > 0 { HairlineRule() }
                    OnboardingFeature(
                        symbol: feature.symbol,
                        title: feature.title,
                        subtitle: feature.description,
                        color: RPGTheme.accent
                    )
                    .opacity(showFeatures || reduceMotion ? 1.0 : 0.0)
                    .offset(x: showFeatures || reduceMotion ? 0 : -30)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                        value: showFeatures
                    )
                }
            }
            .rpgCard(padding: 14, ornate: true)
            .padding(.horizontal, 20)

            if !usesAccessibilityLayout { Spacer() }
        }
        .padding(.vertical, usesAccessibilityLayout ? 12 : 0)
        .tag(1)
        .onAppear {
            if reduceMotion {
                showFeatures = true
            } else {
                withAnimation { showFeatures = true }
            }
        }
    }

    private var classPlacementPage: some View {
        VStack(spacing: usesAccessibilityLayout ? 18 : 30) {
            if !usesAccessibilityLayout { Spacer() }

            VStack(spacing: 20) {
                Text("Class Placement")
                    .font(RPGTheme.heading(.largeTitle, weight: .bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Choose 2 fitness goals to find your perfect class")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)

            // Accessibility categories use one flexible column so labels can
            // grow without being squeezed into half the phone width.
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 16),
                    count: usesAccessibilityLayout ? 1 : 2
                ),
                spacing: 16
            ) {
                ForEach(FitnessGoal.allCases) { goal in
                    GoalSelectionCard(
                        goal: goal,
                        isSelected: selectedGoals.contains(goal)
                    ) {
                        toggleGoalSelection(goal)
                    }
                }
            }
            .padding(.horizontal, 20)

            if !usesAccessibilityLayout { Spacer() }
        }
        .padding(.vertical, usesAccessibilityLayout ? 12 : 0)
        .tag(2)
    }

    private var classRevealPage: some View {
        VStack(spacing: usesAccessibilityLayout ? 18 : 40) {
            if !usesAccessibilityLayout { Spacer() }

            VStack(spacing: 20) {
                Text("Your Class")
                    .font(RPGTheme.heading(.largeTitle, weight: .bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Based on your goals, you are a...")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)

            // Class reveal without animations
            if let assignedClass = RPGClass.classPlacement(from: Set(selectedGoals)) {
                ClassPreviewCard(rpgClass: assignedClass)
                    .padding(.horizontal, 20)
            }

            if !usesAccessibilityLayout { Spacer() }
        }
        .padding(.vertical, usesAccessibilityLayout ? 12 : 0)
        .tag(3)
    }

    private var setupPage: some View {
        VStack(spacing: usesAccessibilityLayout ? 18 : 30) {
            if !usesAccessibilityLayout { Spacer() }

            VStack(spacing: 20) {
                Text("Almost There!")
                    .font(RPGTheme.heading(.largeTitle, weight: .bold))
                    .accessibilityAddTraits(.isHeader)

                Text("Tell us your bodyweight to get started")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 24) {
                // Units picker
                Picker("Units", selection: $state.user.units) {
                    ForEach(Units.allCases, id: \.self) { u in
                        Text(u.displayName).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .frame(minHeight: 44)

                // Weight display
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("\(Int(bodyweightValue))")
                            .font(usesAccessibilityLayout
                                  ? .system(.largeTitle, design: .default, weight: .semibold)
                                  : RPGTheme.display(48))
                            .monospacedDigit()
                            .foregroundColor(RPGTheme.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(state.user.units.displayName.lowercased())
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }

                    // Slider
                    Slider(value: $bodyweightValue, in: weightRange, step: 1)
                        .tint(RPGTheme.accent)
                        .frame(maxWidth: 300)
                        .accessibilityLabel("Bodyweight")
                        .accessibilityValue("\(Int(bodyweightValue)) \(state.user.units.displayName)")

                    // Range labels
                    HStack {
                        Text("\(Int(weightRange.lowerBound))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(weightRange.upperBound))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: 300)

                    // The button below never no-ops silently: if the value
                    // can't be accepted, say so right here.
                    if !bodyweightValid {
                        Text("Enter a bodyweight between \(Int(weightRange.lowerBound)) and \(Int(weightRange.upperBound)) \(state.user.units.displayName).")
                            .font(.caption)
                            .foregroundColor(RPGTheme.errorText)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 40)

            if !usesAccessibilityLayout { Spacer() }
        }
        .padding(.vertical, usesAccessibilityLayout ? 12 : 0)
        .tag(4)
    }

    /// The staged bodyweight, not the committed one — the verdict must track
    /// the slider the player can still go back and move.
    private var stagedBodyweightKg: Double {
        state.user.units.toKg(bodyweightValue)
    }

    private var stagedVerdict: PlacementVerdict {
        PlacementVerdict.make(answers: weighing,
                              bodyweightKg: stagedBodyweightKg,
                              rpgClass: RPGClass.classPlacement(from: Set(selectedGoals)),
                              units: state.user.units)
    }

    private var weighingPage: some View {
        WeighingFormView(answers: $weighing,
                         units: state.user.units,
                         bodyweightKg: stagedBodyweightKg)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .tag(5)
    }

    private var namingPage: some View {
        // Recomputed on every entry, so backing up to change bodyweight or
        // goals can never leave the naming stale.
        NamingCeremonyView(verdict: stagedVerdict) { ceremonyDone = true }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .tag(6)
    }

    private var currentPageTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        let insertion: Edge = isMovingForward ? .trailing : .leading
        let removal: Edge = isMovingForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertion).combined(with: .opacity),
            removal: .move(edge: removal).combined(with: .opacity)
        )
    }

    @ViewBuilder
    private var currentPageView: some View {
        switch page {
        case 0:
            welcomePage
        case 1:
            featuresPage
        case 2:
            classPlacementPage
        case 3:
            classRevealPage
        case 4:
            setupPage
        case 5:
            weighingPage
        default:
            namingPage
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            progressIndicator

            // Scroll instead of clip: compact phones truncated the copy and
            // larger Dynamic Type sizes never fit at all. minHeight keeps the
            // pages' Spacer-centering on screens tall enough to not scroll.
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    ZStack {
                        currentPageView
                            .id(page)
                            .transition(currentPageTransition)
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
                // Recreate the scroll container for each page. VoiceOver (and
                // accessibility actions in UI tests) can scroll a selected
                // goal into view; carrying that offset into the next page
                // otherwise opens the class reveal halfway down its content.
                .id(page)
            }
            .clipped()
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82),
                       value: page)

            // Action Button
            VStack(spacing: 16) {
                Button(action: {
                    if reduceMotion {
                        advance()
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { advance() }
                    }
                }) {
                    HStack {
                        Text(buttonTitle)

                        Image(systemName: buttonIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(RPGPrimaryButtonStyle())
                .frame(maxWidth: 320)
                .padding(.horizontal, 40)
                .disabled(!canProceed)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                           value: canProceed)

                if page > 0 {
                    Button("Back") {
                        if reduceMotion {
                            goBack()
                        } else {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { goBack() }
                        }
                    }
                    .buttonStyle(RPGQuietButtonStyle(tint: .secondary))
                    .frame(minWidth: 44)
                }
            }
            .padding(.bottom, 30)
        }
    }

    var body: some View {
        // The readable-width column keeps iPad from stretching a phone
        // composition across the whole canvas.
        backgroundView.overlay(
            mainContent
                .frame(maxWidth: AppLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
        )
            .onAppear {
                // Prefill from stored value (if any) or set default based on units
                if let bw = state.user.bodyweightKg {
                    bodyweightValue = state.user.units.fromKg(bw)
                } else {
                    // Set a reasonable default
                    bodyweightValue = state.user.units == .kg ? 70 : 150
                }
            }
            .onChangeCompat(of: state.user.units) { oldU, newU in
                // Convert the slider value to the newly selected units. The
                // Weighing's drawer needs nothing here: its staged values are
                // canonical kg/km, and the form redraws its own fields off the
                // same units change.
                let kg = oldU.toKg(bodyweightValue)
                bodyweightValue = newU.fromKg(kg)
            }
    }
}

struct OnboardingFeature: View {
    let symbol: RPGSymbol
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        // A bare row: glyph tint, serif title, one line of copy. No fill,
        // no tile — the hairline between rows is the only structure.
        HStack(spacing: 14) {
            RPGSymbolIcon(
                symbol: symbol,
                size: 24,
                presentation: .compact,
                palette: .monochrome(color)
            )
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(RPGTheme.heading(.headline, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showConfirmReset = false
    @State private var showFinalConfirmReset = false
    @State private var healthKitEnabled = HealthKitManager.isEnabled
    @State private var showPrivacyPolicy = false
    @State private var cloudBusy = false
    @State private var cloudStatus: String? = nil
    @State private var showRestoreConfirm = false
    @State private var showDeleteCloudConfirm = false
    @State private var bodyweightInput: String = ""
    @State private var showWeightError = false
    @State private var isEditingWeight = false
    @State private var isInitializing = false
    @State private var exportURL: URL?
    @State private var showLedgerstone = false

    // Weight validation (same as onboarding)
    private var bodyweightValid: Bool {
        if let v = flexibleDouble(bodyweightInput) {
            let kg = state.user.units.toKg(v)
            return kg >= 25 && kg <= 350
        }
        return false
    }

    private var bodyweightAccessibilityValue: String {
        guard !bodyweightInput.isEmpty else { return "Not set" }
        return "\(bodyweightInput) \(state.user.units.displayName)"
    }

    private var usesAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    private var profileIdentityBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if let rpgClass = state.user.rpgClass {
                    ClassEmblem(rpgClass: rpgClass, size: usesAccessibilityLayout ? 48 : 62)
                } else {
                    // No class yet: a brass ring waiting for its emblem.
                    ZStack {
                        Circle()
                            .fill(RPGTheme.surfaceInner)
                            .overlay(Circle().strokeBorder(RPGTheme.frame.opacity(0.6), lineWidth: 1))
                            .frame(width: usesAccessibilityLayout ? 48 : 60,
                                   height: usesAccessibilityLayout ? 48 : 60)
                        RPGSymbolIcon(
                            symbol: .character,
                            size: usesAccessibilityLayout ? 24 : 28,
                            presentation: .compact,
                            palette: .monochrome(RPGTheme.accent)
                        )
                    }
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                let level = state.user.displayLevel
                let title = levelTitle(for: state.user.level)
                Text("Level \(level) \(title)")
                    .font(RPGTheme.heading(.title3, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                let prestige = state.user.prestigeLevel
                if prestige > 0 {
                    Text("Prestige: \(prestige)")
                        .font(.subheadline)
                        .foregroundColor(RPGTheme.gold)
                } else {
                    Text(state.user.rpgClass?.displayName ?? "Ready for adventure")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var profileMetrics: some View {
        if usesAccessibilityLayout {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                profileXP
                profileWorkoutCount
            }
        } else {
            VStack(alignment: .trailing, spacing: 4) {
                profileXP
                profileWorkoutCount
            }
        }
    }

    private var profileXP: some View {
        Text("\(Int(state.user.xp)) XP")
            .font(.headline.weight(.semibold))
            .monospacedDigit()
            .foregroundColor(RPGTheme.xp)
    }

    private var profileWorkoutCount: some View {
        Text("\(state.history.count) workouts")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var profileSummaryHeader: some View {
        if usesAccessibilityLayout {
            VStack(alignment: .leading, spacing: 12) {
                profileIdentityBlock
                profileMetrics
            }
        } else {
            HStack {
                profileIdentityBlock
                Spacer()
                profileMetrics
            }
        }
    }

    private func levelTitle(for level: Int) -> String {
        switch level {
        case 1...10: return "Novice"
        case 11...20: return "Apprentice"
        case 21...30: return "Challenger"
        case 31...40: return "Warrior"
        case 41...50: return "Hero"
        case 51...60: return "Champion"
        default: return "Legend"
        }
    }

    // MARK: Panels

    /// Identity, the stone, units, bodyweight — everything that says who the
    /// character is. The one bracketed panel on this screen.
    private var profilePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Profile")

            profileSummaryHeader

            HairlineRule()

            Button {
                showLedgerstone = true
            } label: {
                RPGRow(title: PlacementCopy.settingsRow,
                       subtitle: state.user.placement?.epithet ?? "The stone has not read your hand.") {
                    RPGSymbolIcon(
                        symbol: .ledgerstone,
                        size: 22,
                        presentation: .compact,
                        palette: .adaptive
                    )
                }
            }
            .buttonStyle(PressableCardStyle())

            HairlineRule()

            // Units
            VStack(alignment: .leading, spacing: 8) {
                Text("Units")
                    .font(RPGTheme.label(12, weight: .semibold))
                    .foregroundColor(.secondary)

                Picker("Units", selection: $state.user.units) {
                    ForEach(Units.allCases) { u in
                        Text(u.displayName).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
            }

            // Bodyweight
            VStack(alignment: .leading, spacing: 8) {
                Text("Bodyweight")
                    .font(RPGTheme.label(12, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    TextField(
                        state.user.units == .kg ? "e.g. 70" : "e.g. 155",
                        text: $bodyweightInput
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(ModernTextFieldStyle())
                    .accessibilityLabel("Bodyweight")
                    .accessibilityValue(bodyweightAccessibilityValue)
                    .onTapGesture {
                        isEditingWeight = true
                    }
                    .onSubmit {
                        isEditingWeight = false
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                            .strokeBorder(
                                isEditingWeight ? (bodyweightValid && !bodyweightInput.isEmpty ? RPGTheme.xp : (!bodyweightInput.isEmpty ? RPGTheme.errorText : Color.clear)) : Color.clear,
                                lineWidth: isEditingWeight && !bodyweightInput.isEmpty ? 1.5 : 0
                            )
                    )
                    .onChangeCompat(of: bodyweightInput) { _, _ in
                        // Set editing state when user types (but not during initialization)
                        if !isEditingWeight && !isInitializing {
                            isEditingWeight = true
                        }

                        // Never write back while initializing — the display
                        // string is rounded, and writing it on open silently
                        // replaced the stored value with the rounded one.
                        guard !isInitializing else { return }

                        if bodyweightValid, let v = flexibleDouble(bodyweightInput) {
                            let kg = state.user.units.toKg(v)
                            state.user.bodyweightKg = kg
                            showWeightError = false
                            state.save()
                        } else if !bodyweightInput.isEmpty {
                            showWeightError = true
                        }
                    }

                    Text(state.user.units.displayName)
                        .font(RPGTheme.label(13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 28, alignment: .leading)
                        .accessibilityHidden(true)
                }

                // Error message
                if showWeightError && !bodyweightInput.isEmpty && !bodyweightValid {
                    let rangeText = (state.user.units == .kg) ? "25–350 kg" : "56–770 lb"
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(RPGTheme.errorText)
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text("Weight must be between \(rangeText)")
                            .font(.caption.weight(.medium))
                            .foregroundColor(RPGTheme.errorText)
                    }
                }
            }
        }
        .rpgCard(padding: 14, ornate: true)
    }

    /// Gear and Health — the things that shape how sessions are logged.
    private var trainingPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Training")

            // Equipment — the picker adapts to real gear
            EquipmentSettingsCard()
                .environmentObject(state)

            // Apple Health — write-only, off by default
            if HealthKitManager.isAvailable {
                Toggle(isOn: $healthKitEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Save Workouts to Health")
                            .font(RPGTheme.heading(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Each finished session is saved as a strength workout. RPGFit never reads your health data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(RPGTheme.xp)
                .frame(minHeight: 44)
                .onChangeCompat(of: healthKitEnabled) { _, enabled in
                    HealthKitManager.isEnabled = enabled
                    if enabled {
                        Task { _ = await HealthKitManager.shared.requestAuthorization() }
                    }
                }
                .rpgCard(padding: 14)
            }
        }
    }

    /// Your log is yours: take it with you, keep a copy, or wipe it.
    private var dataPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Data")
                .padding(.bottom, 6)

            if let exportURL {
                ShareLink(item: exportURL) {
                    RPGRow(title: "Export Workouts (CSV)",
                           subtitle: "\(state.history.count) workouts, openable anywhere",
                           chevron: false) {
                        RPGSymbolIcon(
                            symbol: .chronicle,
                            size: 22,
                            presentation: .compact,
                            palette: .monochrome(RPGTheme.accent)
                        )
                    } trailing: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(RPGTheme.frame)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(PressableCardStyle())

                HairlineRule()
            }

            // iCloud backup — manual, private, no RPGFit account
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "icloud")
                        .font(.body.weight(.medium))
                        .foregroundColor(RPGTheme.accent)
                        .frame(width: 30, height: 30)
                        .accessibilityHidden(true)
                    Text("iCloud Backup (Beta)")
                        .font(RPGTheme.heading(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 6)

                Text("Back up your character to your private iCloud using CloudKit encrypted storage. Nothing syncs automatically — iCloud is contacted only when you choose a backup action.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !CloudBackupManager.entitlementPresent {
                    // Personal-team device builds are signed
                    // without iCloud; a live button would crash
                    // CKContainer at first touch.
                    Text("Not available in this development build — iCloud backup requires paid Apple Developer signing. It works in the simulator and in App Store builds.")
                        .font(.caption)
                        .foregroundColor(RPGTheme.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let last = CloudBackupManager.lastBackupDate {
                    Text("Last backup: \(last.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                if CloudBackupManager.entitlementPresent {
                    cloudActionButtons

                    Button(role: .destructive) {
                        showDeleteCloudConfirm = true
                    } label: {
                        Label("Delete iCloud Backup", systemImage: "icloud.slash")
                    }
                    .buttonStyle(RPGSecondaryButtonStyle(tint: RPGTheme.errorText))
                    .disabled(cloudBusy)
                }

                if let cloudStatus {
                    Text(cloudStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 10)

            HairlineRule()

            // Destructive, but quiet — a row, not a red plate.
            Button(role: .destructive) {
                showConfirmReset = true
            } label: {
                RPGRow(title: "Reset All Data",
                       subtitle: "Deletes this device; iCloud backup remains",
                       chevron: false) {
                    Image(systemName: "trash")
                        .font(.body.weight(.medium))
                        .foregroundColor(RPGTheme.errorText)
                }
            }
            .buttonStyle(PressableCardStyle())
        }
        .rpgCard(padding: 14)
    }

    /// Back up / Restore side by side, stacked at accessibility sizes so
    /// neither label is squeezed.
    @ViewBuilder
    private var cloudActionButtons: some View {
        let backUp = Button {
            runCloudTask {
                let data = try state.encodedSaveData()
                try await CloudBackupManager.shared.backUp(data)
                return "Backed up to iCloud"
            }
        } label: {
            Text("Back Up Now")
        }
        .buttonStyle(RPGSecondaryButtonStyle())

        let restore = Button {
            showRestoreConfirm = true
        } label: {
            Text("Restore…")
        }
        .buttonStyle(RPGSecondaryButtonStyle(tint: RPGTheme.goldDeep))

        Group {
            if usesAccessibilityLayout {
                VStack(spacing: 10) {
                    backUp
                    restore
                }
            } else {
                HStack(spacing: 10) {
                    backUp
                    restore
                }
            }
        }
        .disabled(cloudBusy)
    }

    /// Policy, support, and the pledge.
    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("About")
                .padding(.bottom, 6)

            Button {
                showPrivacyPolicy = true
            } label: {
                RPGRow(title: "Privacy Policy") {
                    Image(systemName: "hand.raised")
                        .font(.body.weight(.medium))
                        .foregroundColor(RPGTheme.accent)
                }
            }
            .buttonStyle(PressableCardStyle())

            HairlineRule()

            Link(destination: URL(string: "mailto:devoncheng8@gmail.com?subject=RPGFit%20Support")!) {
                RPGRow(title: "Contact Support", chevron: false) {
                    Image(systemName: "envelope")
                        .font(.body.weight(.medium))
                        .foregroundColor(RPGTheme.accent)
                } trailing: {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(RPGTheme.frame)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(PressableCardStyle())

            // App Info
            VStack(spacing: 8) {
                OrnateDivider()
                    .frame(maxWidth: 200)
                    .padding(.bottom, 6)

                Text("RPGFit")
                    .font(RPGTheme.heading(18))
                    .foregroundColor(RPGTheme.gold)

                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                Text("Transform your fitness into an epic adventure")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                // The pledge — the one monetization stance nobody
                // in the genre's reviews ever complains about.
                Text("Progress is earned, never bought.\nNo ads. No RPGFit account. Your log stays on this device unless you choose iCloud backup or export it.")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 6)
        }
        .rpgCard(padding: 14)
    }

    #if DEBUG
    /// Developer Tools (debug builds only)
    private var developerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Developer Tools")
                .padding(.bottom, 6)

            Button {
                // Ledgered like all non-workout XP — bare addXP would vanish
                // on recalculation and poison the chest high-water mark.
                state.grantBonusXP(50)
            } label: {
                RPGRow(title: "Add 50 XP", subtitle: "Quick experience boost", chevron: false) {
                    RPGSymbolIcon(
                        symbol: .xp,
                        size: 22,
                        presentation: .compact,
                        palette: .monochrome(RPGTheme.accent)
                    )
                }
            }
            .buttonStyle(PressableCardStyle())

            HairlineRule()

            Button {
                state.seedScreenshotData()
            } label: {
                RPGRow(title: "Seed Screenshot Data", subtitle: "A lived-in month of training", chevron: false) {
                    Image(systemName: "camera")
                        .font(.body.weight(.medium))
                        .foregroundColor(RPGTheme.gold)
                }
            }
            .buttonStyle(PressableCardStyle())

            HairlineRule()

            Button {
                state.user.stats.size += 10
                state.user.stats.strength += 10
                state.user.stats.dexterity += 10
                state.user.stats.agility += 10
                state.user.stats.endurance += 10
                state.user.stats.vitality += 10
                state.save()
            } label: {
                RPGRow(title: "Boost All Stats", subtitle: "+10 to all attributes", chevron: false) {
                    RPGSymbolIcon(
                        symbol: .character,
                        size: 22,
                        presentation: .compact,
                        palette: .monochrome(RPGTheme.xp)
                    )
                }
            }
            .buttonStyle(PressableCardStyle())
        }
        .rpgCard(padding: 14)
    }
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        profilePanel
                        trainingPanel
                        dataPanel
                        aboutPanel
                        #if DEBUG
                        developerPanel
                        #endif
                    }
                    .screenColumn()
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .dismissKeyboardOnTap()
            .dismissKeyboardOnSwipe()
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        isEditingWeight = false
                    }
            )
            .onAppear {
                // Set initialization flag to prevent editing state during setup
                isInitializing = true
                isEditingWeight = false

                exportURL = state.history.isEmpty ? nil : state.exportHistoryCSV()

                // Initialize bodyweight input from stored value
                if let bw = state.user.bodyweightKg {
                    bodyweightInput = String(format: "%.0f", state.user.units.fromKg(bw))
                }

                // Clear initialization flag after a brief delay to ensure all setup is done
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInitializing = false
                }
            }
            .onChangeCompat(of: state.user.units) { oldU, newU in
                // Persist the units choice even when no bodyweight is entered
                state.save()
                // Convert input when units change (also during initialization)
                if !bodyweightInput.isEmpty, let currentValue = flexibleDouble(bodyweightInput) {
                    isInitializing = true // Prevent editing state during units conversion
                    let kgValue = oldU.toKg(currentValue)
                    bodyweightInput = String(format: "%.0f", newU.fromKg(kgValue))

                    // Clear initialization flag after conversion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInitializing = false
                    }
                }
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showLedgerstone) {
                ReturnToTheStoneView(initialRecord: state.user.placement)
                    .environmentObject(state)
            }
            .alert("Restore from iCloud?", isPresented: $showRestoreConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Restore", role: .destructive) {
                    runCloudTask {
                        let data = try await CloudBackupManager.shared.restore()
                        try state.applyRestoredSave(data)
                        return "Restored from iCloud"
                    }
                }
            } message: {
                Text("This replaces everything on this device with your last iCloud backup.")
            }
            .alert("Delete iCloud backup?", isPresented: $showDeleteCloudConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete iCloud Backup", role: .destructive) {
                    runCloudTask {
                        try await CloudBackupManager.shared.deleteBackup()
                        return "iCloud backup deleted"
                    }
                }
            } message: {
                Text("This permanently deletes the RPGFit backup in your private iCloud. Data on this device is not changed.")
            }
            .alert("Reset all data?", isPresented: $showConfirmReset) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) { showFinalConfirmReset = true }
            } message: {
                Text("This permanently deletes workouts, progress, and settings from this device. Any iCloud backup remains until you delete it separately.")
            }
            .alert("Delete local data?", isPresented: $showFinalConfirmReset) {
                Button("Keep My Data", role: .cancel) {}
                Button("Delete From This Device", role: .destructive) { state.resetAll() }
            } message: {
                Text("Your training history and character will be erased from this device. Your optional iCloud backup is not deleted.")
            }
        }
    }

    /// Runs one backup/restore/delete call, surfacing the outcome (or the error's
    /// own words) under the buttons instead of failing silently.
    private func runCloudTask(_ work: @escaping () async throws -> String) {
        cloudBusy = true
        cloudStatus = nil
        Task { @MainActor in
            do {
                cloudStatus = try await work()
            } catch {
                cloudStatus = error.localizedDescription
            }
            cloudBusy = false
        }
    }
}
