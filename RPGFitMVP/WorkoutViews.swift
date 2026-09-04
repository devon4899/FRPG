import SwiftUI
import Foundation
import UIKit
import UserNotifications

struct LogWorkoutView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var name: String = ""
    @State private var focus: FocusGroup = .strength
    @State private var category: ExerciseCategory = .squat
    @State private var sets: String = ""
    @State private var reps: String = ""
    @State private var weight: String = ""
    @State private var duration: String = ""
    @State private var distance: String = ""
    @State private var showPopup: Bool = false
    @State private var popupEntry: WorkoutEntry? = nil
    @State private var popupDismissWork: DispatchWorkItem? = nil
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var searchText: String = ""

    private var filteredExercises: [ExerciseCategory] {
        let base = searchText.isEmpty
            ? ExerciseCategory.allCases.filter { $0.focus == focus }
            : ExerciseCategory.allCases
        return base.filter {
            state.isAvailable($0) &&
            (searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText))
        }
    }

    private func bestMatch(for query: String) -> ExerciseCategory? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return nil }
        // Score each exercise name: prefix gets highest weight, word-prefix next, substring last.
        let scored: [(cat: ExerciseCategory, score: Int)] = ExerciseCategory.allCases
            .filter { state.isAvailable($0) }
            .map { cat in
            let name = cat.displayName.lowercased()
            var s = 0
            if name.hasPrefix(q) { s += 3 }
            if name.split(separator: " ").contains(where: { $0.hasPrefix(Substring(q)) }) { s += 2 }
            if name.contains(q) { s += 1 }
            return (cat, s)
        }.filter { $0.score > 0 }
        return scored.sorted { a, b in
            if a.score == b.score { return a.cat.displayName < b.cat.displayName }
            return a.score > b.score
        }.first?.cat
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        // Bodyweight reminder — scaling needs a bodyweight.
                        if state.user.bodyweightKg == nil {
                            setupBanner
                        }

                        focusPanel

                        exercisePanel

                        // Last-time ghost card: what you did the previous
                        // session of this exercise, one tap to prefill.
                        if let last = lastEntry(for: category) {
                            LastSessionCard(entry: last, units: state.user.units) {
                                prefill(from: last)
                            }
                        }

                        numbersPanel

                        // Rest timer — keeps counting when the phone locks
                        // (the alarm is a scheduled local notification).
                        RestTimerCard()

                        // Helper Text
                        Text("Record your training session. For strength: sets × reps × weight. For endurance: duration and/or distance. Weight uses \(state.user.units.displayName).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .screenColumn()
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .dismissKeyboardOnTap()
                .dismissKeyboardOnSwipe()
                .safeAreaInset(edge: .bottom) {
                    // The one action on this screen lives in the dock so it
                    // is always in thumb reach, whatever is scrolled above.
                    DockBar {
                        Button(action: save) {
                            HStack(spacing: 8) {
                                RPGSymbolIcon(
                                    symbol: .training,
                                    size: 22,
                                    presentation: .compact,
                                    palette: .onPlate
                                )
                                Text("Complete Training")
                            }
                        }
                        .buttonStyle(RPGPrimaryButtonStyle())
                        .disabled(state.user.bodyweightKg == nil || !hasAtLeastOneInput)
                        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                                   value: hasAtLeastOneInput)
                    }
                }

                // Popup overlay
                if showPopup, let entry = popupEntry {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(1)
                        .accessibilityHidden(true)
                        .onTapGesture {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9)) {
                                showPopup = false
                            }
                        }

                    GainPopupView(entry: entry, onDismiss: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9)) {
                            showPopup = false
                        }
                    })
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search exercises")
            .navigationTitle("Complete Training")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Check your input", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
        .onChangeCompat(of: focus) { _, newFocus in
            let list = ExerciseCategory.allCases.filter { $0.focus == newFocus && state.isAvailable($0) }
            if !list.contains(category), let first = list.first {
                category = first
            }
        }
        .onChangeCompat(of: searchText) { _, newText in
            if let best = bestMatch(for: newText) {
                if focus != best.focus { focus = best.focus }
                category = best
            }
            if !filteredExercises.contains(category), let first = filteredExercises.first {
                category = first
            }
        }
        .onAppear {
            if !state.isAvailable(category),
               let replacement = ExerciseCategory.allCases.first(where: {
                   $0.focus == focus && state.isAvailable($0)
               }) ?? ExerciseCategory.allCases.first(where: { state.isAvailable($0) }) {
                focus = replacement.focus
                category = replacement
            }
        }
    }

    // MARK: Panels

    private var setupBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(RPGTheme.warningText)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Setup Required")
                    .font(RPGTheme.heading(.headline, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Set your bodyweight in Settings to get accurate scaling.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .rpgCard(padding: 14, accent: RPGTheme.warningText)
        .accessibilityElement(children: .combine)
    }

    private var focusPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Focus")

            // Chips bleed to the panel edge so the row can scroll under it.
            ModernFocusChips(selection: $focus)
                .padding(.horizontal, -16)
        }
        .rpgCard(padding: 16)
    }

    private var fieldSurface: some View {
        RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
            .fill(RPGTheme.surfaceInner)
            .overlay(
                RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                    .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
            )
    }

    private func fieldLabel(_ title: String, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title.uppercased())
                .font(RPGTheme.label(11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.secondary)
                .accessibilityLabel(title)
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
    }

    private var exercisePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Exercise")

            // Exercise Category Picker
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Movement")

                Menu {
                    ForEach(filteredExercises) { cat in
                        Button(cat.displayName) {
                            category = cat
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        StatIcon(stat: category.focus.primaryStat, size: 15)
                            .frame(width: 20)
                        Text(category.displayName)
                            .font(RPGTheme.heading(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(RPGTheme.accent)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(fieldSurface)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Exercise, \(category.displayName)")
                .accessibilityHint("Choose a movement")
            }

            // Exercise Name Field
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Name", note: "optional")

                TextField("Optional custom name", text: $name)
                    .textFieldStyle(ModernTextFieldStyle())
                    .accessibilityLabel("Workout name")
            }
        }
        .rpgCard(padding: 16)
    }

    private var numbersPanel: some View {
        let pair = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))

        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Numbers") {
                Text(state.user.units.displayName)
                    .font(RPGTheme.label(11, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize()
            }

            pair {
                ModernInputRow(
                    title: "Sets",
                    placeholder: "e.g. 3",
                    text: $sets,
                    keyboardType: .numberPad
                )

                ModernInputRow(
                    title: "Reps",
                    subtitle: "per set",
                    placeholder: "e.g. 8",
                    text: $reps,
                    keyboardType: .numberPad
                )
            }

            ModernInputRow(
                title: "Weight",
                subtitle: state.user.units.displayName,
                placeholder: "e.g. 60",
                text: $weight,
                keyboardType: .decimalPad
            )

            pair {
                ModernInputRow(
                    title: "Duration",
                    subtitle: "minutes",
                    placeholder: "e.g. 20",
                    text: $duration,
                    keyboardType: .decimalPad
                )

                ModernInputRow(
                    title: "Distance",
                    subtitle: state.user.units.distanceDisplayName,
                    placeholder: "e.g. 3.2",
                    text: $distance,
                    keyboardType: .decimalPad
                )
            }
        }
        .rpgCard(padding: 16)
    }

    private func celebrate() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    private var hasAtLeastOneInput: Bool {
        !(reps.isEmpty && weight.isEmpty && duration.isEmpty && distance.isEmpty)
    }

    /// The most recent logged session of this exercise, for ghosting.
    private func lastEntry(for category: ExerciseCategory) -> WorkoutEntry? {
        state.history.first { $0.category == category }
    }

    private func prefill(from entry: WorkoutEntry) {
        Haptics.tap()
        sets = entry.sets.map(String.init) ?? ""
        reps = entry.reps.map(String.init) ?? ""
        weight = entry.weight.map { String(format: "%.1f", state.user.units.fromKg($0)) } ?? ""
        duration = entry.durationMinutes.map { String(format: "%.0f", $0) } ?? ""
        distance = entry.distanceKm.map { String(format: "%.2f", state.user.units.fromKm($0)) } ?? ""
    }

    private func save() {
        // Validation
        let setsVal = Int(sets)
        let repsVal = Int(reps)
        let weightRaw = flexibleDouble(weight)
        let durVal = flexibleDouble(duration)
        let distRaw = flexibleDouble(distance)
        let distKm: Double? = {
            guard let d = distRaw else { return nil }
            return state.user.units.toKm(d) // mi → km when units == .lb
        }()

        // Convert weight to kg based on settings
        let weightValKg: Double? = {
            guard let w = weightRaw else { return nil }
            return state.user.units.toKg(w)
        }()

        func invalid(_ msg: String) {
            validationMessage = msg
            showValidationAlert = true
        }

        if let s = setsVal, s < 1 || s > 50 { invalid("Sets must be between 1 and 50."); return }
        if let r = repsVal, r < 1 || r > 1000 { invalid("Reps must be between 1 and 1000."); return }
        if let w = weightValKg, !w.isFinite || w < 0 || w > 700 { invalid("Weight seems unrealistic. Please check units."); return }
        if let d = durVal, !d.isFinite || d < 0 || d > 600 { invalid("Duration must be between 0 and 600 minutes."); return }
        if let entered = distRaw {
            let km = state.user.units.toKm(entered)
            let maxKm = 200.0
            if !km.isFinite || km < 0 || km > maxKm {
                let maxDisplay = state.user.units == .kg ? maxKm : maxKm / 1.6
                invalid(String(format: "Distance must be between 0 and %.0f %@", maxDisplay, state.user.units.distanceDisplayName))
                return
            }
        }

        let entry = state.logWorkout(name: name, category: category, sets: setsVal, reps: repsVal, weight: weightValKg, durationMinutes: durVal, distanceKm: distKm)
        popupEntry = entry

        // Dismiss keyboard before showing popup
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) {
            showPopup = true
        }
        celebrate()

        // Auto-dismiss popup — cancellable so a stale timer from a previous
        // log can't close a newer popup early, and skipped for VoiceOver
        // users, who dismiss by tapping when they're done.
        popupDismissWork?.cancel()
        if !UIAccessibility.isVoiceOverRunning {
            let work = DispatchWorkItem {
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9)) {
                    showPopup = false
                }
            }
            popupDismissWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: work)
        }

        // Reset inputs (keep category for convenience)
        name = ""
        sets = ""
        reps = ""
        weight = ""
        duration = ""
        distance = ""
    }
}

/// Rest timer between sets. The countdown is date math (not a running
/// Timer), so locking the phone or switching apps never resets it, and a
/// local notification rings when rest is up even with the screen off.
struct RestTimerCard: View {
    @State private var endDate: Date? = nil
    @State private var selectedSeconds: Int = 90
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let notificationID = "rpgfit.restTimer"
    private let presets = [60, 90, 120, 180]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Rest Timer") {
                HStack(spacing: 6) {
                    RPGSymbolIcon(
                        symbol: .rest,
                        size: 16,
                        presentation: .compact,
                        palette: .monochrome(endDate == nil ? .secondary : RPGTheme.accent)
                    )

                    if endDate != nil {
                        Text("Resting")
                            .font(RPGTheme.label(11, weight: .medium))
                            .foregroundColor(RPGTheme.accent)
                            .fixedSize()
                    }
                }
            }

            if let endDate {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let remaining = max(0, endDate.timeIntervalSince(context.date))
                    let fraction = selectedSeconds > 0
                        ? min(1, max(0, remaining / Double(selectedSeconds)))
                        : 0
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 12))
                        : AnyLayout(HStackLayout(spacing: 16))
                    layout {
                        // Brass ring drains as the rest runs down.
                        ZStack {
                            Circle()
                                .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: CGFloat(fraction))
                                .stroke(remaining <= 5 ? RPGTheme.xp : RPGTheme.accent,
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .padding(1.5)
                                .animation(reduceMotion ? nil : .linear(duration: 0.5), value: fraction)
                            Text(timeString(remaining))
                                .font(RPGTheme.display(32))
                                .monospacedDigit()
                                .foregroundColor(remaining <= 5 ? RPGTheme.xp : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 14)
                        }
                        .frame(width: 124, height: 124)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Rest: \(Int(remaining)) seconds remaining")

                        HStack(spacing: 8) {
                            Button("+30s") { extend(by: 30) }
                                .buttonStyle(RPGQuietButtonStyle())
                                .frame(minWidth: 64)

                            Button("Stop") { stop() }
                                .buttonStyle(RPGQuietButtonStyle(tint: .secondary))
                                .frame(minWidth: 64)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .onChangeCompat(of: remaining <= 0) { _, done in
                        if done { finished() }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { seconds in
                        Button {
                            start(seconds: seconds)
                        } label: {
                            Text(seconds % 60 == 0 ? "\(seconds / 60)m" : "\(seconds)s")
                                .font(RPGTheme.display(15))
                                .monospacedDigit()
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background(
                                    Capsule()
                                        .fill(RPGTheme.surfaceInner)
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
                                        )
                                )
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start \(seconds)-second rest timer")
                    }
                }
            }
        }
        .rpgCard(padding: 16)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func start(seconds: Int) {
        Haptics.tap()
        selectedSeconds = seconds
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        scheduleNotification(after: TimeInterval(seconds))
    }

    private func extend(by seconds: Int) {
        guard let current = endDate else { return }
        Haptics.tap()
        let newEnd = max(current, Date()).addingTimeInterval(TimeInterval(seconds))
        endDate = newEnd
        // Grow the ring's span so the added time reads as added, not reset.
        selectedSeconds += seconds
        scheduleNotification(after: newEnd.timeIntervalSinceNow)
    }

    private func stop() {
        endDate = nil
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func finished() {
        endDate = nil
        Haptics.success()
    }

    private func scheduleNotification(after interval: TimeInterval) {
        guard interval > 1 else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Rest complete"
            content.body = "Back to it — your next set awaits."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
            center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
        }
    }
}

/// "Last time" ghost card: the fastest path from opening the app to a
/// logged session is repeating what you did before.
struct LastSessionCard: View {
    let entry: WorkoutEntry
    let units: Units
    let onUse: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var summary: String {
        var parts: [String] = []
        if let r = entry.reps {
            let setCount = max(1, entry.sets ?? 1)
            if let w = entry.weight, w > 0 {
                parts.append("\(setCount)×\(r) @ \(String(format: "%.1f", units.fromKg(w))) \(units.displayName)")
            } else {
                parts.append("\(setCount)×\(r)")
            }
        }
        if let d = entry.durationMinutes, d > 0 { parts.append(String(format: "%.0f min", d)) }
        if let km = entry.distanceKm, km > 0 {
            parts.append(String(format: "%.2f %@", units.fromKm(km), units.distanceDisplayName))
        }
        return parts.isEmpty ? "logged" : parts.joined(separator: " · ")
    }

    private var exerciseName: String {
        entry.customExerciseID != nil && !entry.name.isEmpty ? entry.name : entry.category.displayName
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))

        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Last Time") {
                Text(entry.date, style: .date)
                    .font(RPGTheme.label(11, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }

            layout {
                HStack(spacing: 12) {
                    RPGSymbolIcon(symbol: .chronicle, size: 20,
                                  presentation: .compact,
                                  palette: .monochrome(RPGTheme.accent))
                        .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exerciseName)
                            .font(RPGTheme.heading(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(summary)
                            .font(RPGTheme.display(15, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)
                }

                Button("Use", action: onUse)
                    .buttonStyle(RPGSecondaryButtonStyle())
                    .fixedSize()
                    .accessibilityLabel("Use last session's numbers")
            }
            .frame(minHeight: 44)
        }
        .rpgCard(padding: 16)
        .accessibilityElement(children: .contain)
    }
}

struct GainPopupView: View {
    let entry: WorkoutEntry
    let onDismiss: () -> Void
    @State private var showInfo: Bool = false
    @State private var animateIn: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var state: AppState
    @AccessibilityFocusState private var popupFocused: Bool

    private func formatXP(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = true
        nf.maximumFractionDigits = value < 1000 ? 1 : 0
        return nf.string(from: NSNumber(value: value)) ?? String(format: value < 1000 ? "%.1f" : "%.0f", value)
    }

    private var gainRows: [(stat: Stat, value: Double)] {
        entry.statGains.statPairs
            .filter { $0.value > 0.005 } // Only show gains of 0.01 or higher
            .sorted { $0.value > $1.value }
    }

    private var isLevelUp: Bool {
        if let from = entry.prevLevel, let to = entry.newLevel, to > from {
            return true
        }
        return false
    }

    /// Lifts whose estimated 1RM is worth announcing.
    private static let oneRMLifts: Set<ExerciseCategory> = [
        .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .powerClean,
        .andersonSquat, .boardPress, .closeGripBenchPress, .declineBenchPress,
        .deficitDeadlift, .inclineBenchPress, .logPress, .pauseSquat,
        .rackPull, .safetyBarSquat, .seatedBarbellPress, .sumoDeadlift,
        .trapBarDeadlift, .cleanAndJerk, .hangClean, .hangSnatch,
        .powerSnatch, .pushJerk, .snatch, .splitJerk,
        .squatClean, .floorPress, .overheadSquat, .pushPress,
        .snatchGripDeadlift
    ]

    var body: some View {
        // Hug short summaries; scroll only when the content outgrows the plate.
        ViewThatFits(in: .vertical) {
            summary
            ScrollView(showsIndicators: false) { summary }
        }
        .rpgCard(padding: 22, ornate: true)
        .frame(maxWidth: 360, maxHeight: 680)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityFocused($popupFocused)
        .accessibilityAction(.escape, onDismiss)
        .onAppear {
            if reduceMotion {
                animateIn = true
            } else {
                withAnimation { animateIn = true }
            }
            popupFocused = true
        }
        .alert("About XP", isPresented: $showInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("XP scales with how hard the session was for you (reps × weight, pace, time). Beat your baseline and you'll see bigger gains; easy or off days still give a little progress.")
        }
    }

    private var summary: some View {
        VStack(spacing: 18) {
            // Ceremony header
            VStack(spacing: 10) {
                if isLevelUp, let species = state.activeCompanionSpecies {
                    CompanionSpriteView(species: species, size: 72, accessory: state.accessory(for: species))
                        .scaleEffect(animateIn || reduceMotion ? 1.0 : 0.6)
                        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6),
                                   value: animateIn)
                }

                HStack(spacing: 8) {
                    Group {
                        if isLevelUp {
                            RPGSymbolIcon(
                                symbol: .rank,
                                size: 22,
                                presentation: .compact,
                                palette: .monochrome(RPGTheme.gold)
                            )
                        } else {
                            RPGSymbolIcon(symbol: .completionSeal, size: 22,
                                          presentation: .compact,
                                          palette: .monochrome(RPGTheme.xp))
                        }
                    }
                    .scaleEffect(animateIn || reduceMotion ? 1.0 : 0.5)
                    .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.6).delay(0.1),
                               value: animateIn)
                    .accessibilityHidden(true)

                    Text(isLevelUp ? "Level Up!" : "Challenge Completed!")
                        .font(RPGTheme.heading(.title2, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                // The XP numeral is the marquee figure of the plate.
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("+\(formatXP(entry.totalProgressXP ?? entry.expGained))")
                            .font(RPGTheme.display(40, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(RPGTheme.xp)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .scaleEffect(animateIn || reduceMotion ? 1.0 : 0.8)
                            .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(0.2),
                                       value: animateIn)

                        Text("XP")
                            .font(RPGTheme.label(14, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(RPGTheme.xp)
                    }

                    Text("Experience Gained")
                        .font(RPGTheme.label(11, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 2)

            OrnateDivider()
                .padding(.horizontal, 8)

            // Level up information
            if let from = entry.prevLevel, let to = entry.newLevel, to > from {
                HStack(spacing: 10) {
                    RPGSymbolIcon(symbol: .rank, size: 18,
                                  presentation: .compact,
                                  palette: .monochrome(RPGTheme.gold))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level \(from) → \(to)")
                            .font(RPGTheme.display(15))
                            .monospacedDigit()
                            .foregroundColor(.primary)
                        if entry.catchUpLevel != nil {
                            Text("Catch-up bonus applied")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(RPGTheme.accent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("About XP")
                }
                .padding(.vertical, -6)
                .rpgInset(padding: 12)
            }

            // Treasure chest notification — only when this level-up
            // actually minted one (the high-water gate can suppress it,
            // and pointing at .last showed old, already-opened chests).
            if isLevelUp,
               let from = entry.prevLevel, let to = entry.newLevel,
               let latestChest = state.user.treasureChests.last(where: {
                   !$0.isOpened && $0.earnedAtLevel > from && $0.earnedAtLevel <= to
               }) {
                HStack(spacing: 10) {
                    RPGSymbolIcon(
                        symbol: .chest,
                        size: 18,
                        presentation: .compact,
                        palette: .monochrome(latestChest.type.rarityColor)
                    )
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(latestChest.type.displayName) Chest Earned!")
                            .font(RPGTheme.heading(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("A chest waits in your Satchel")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                    PillTag(text: latestChest.type.displayName, tint: latestChest.type.rarityColor)
                }
                .rpgInset(padding: 12)
            }

            // 1RM information (only for relevant compound lifts)
            if let est = entry.est1RM, let prev = entry.prevBest1RM, est > 0, est > prev,
               Self.oneRMLifts.contains(entry.category) {
                HStack(spacing: 10) {
                    RPGSymbolIcon(
                        symbol: .personalRecord,
                        size: 18,
                        presentation: .compact,
                        palette: .monochrome(RPGTheme.gold)
                    )
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New 1RM Personal Best!")
                            .font(RPGTheme.heading(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        // Convert from kg to user's preferred units for display
                        let units = state.user.units
                        let displayEst = units.fromKg(est)
                        let displayPrev = units.fromKg(prev)
                        Text(String(format: "Est. 1RM: %.0f %@ (prev %.0f %@)", displayEst, units.displayName, displayPrev, units.displayName))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                    PillTag(text: "PR", tint: RPGTheme.gold, filled: true)
                }
                .rpgInset(padding: 12)
            }

            // Attribute gains
            if !gainRows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Attribute Gains")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(Array(gainRows.enumerated()), id: \.element.stat) { index, row in
                            HStack(spacing: 8) {
                                StatIcon(stat: row.stat, size: 14)
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.stat.name)
                                        .font(RPGTheme.label(10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(String(format: "+%.2f", row.value))
                                        .font(RPGTheme.display(14))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                }

                                Spacer(minLength: 0)
                            }
                            .rpgInset(padding: 10)
                            .scaleEffect(animateIn || reduceMotion ? 1.0 : 0.9)
                            .opacity(animateIn || reduceMotion ? 1.0 : 0.0)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(Double(index) * 0.1),
                                       value: animateIn)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }

            Button("Continue", action: onDismiss)
                .buttonStyle(RPGPrimaryButtonStyle())
                .accessibilityHint("Dismisses this training summary")
        }
    }
}

struct WorkoutEditFields: Equatable {
    var sets = ""
    var reps = ""
    var weight = ""
    var duration = ""
    var distance = ""

    init(
        sets: String = "",
        reps: String = "",
        weight: String = "",
        duration: String = "",
        distance: String = ""
    ) {
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.distance = distance
    }

    init(workout: WorkoutEntry, units: Units) {
        if let value = workout.sets, value > 1 {
            sets = "\(value)"
        }
        if let value = workout.reps {
            reps = "\(value)"
        }
        if let value = workout.weight {
            weight = String(format: "%.1f", units.fromKg(value))
        }
        if let value = workout.durationMinutes {
            duration = String(format: "%.0f", value)
        }
        if let value = workout.distanceKm {
            distance = String(format: "%.2f", units.fromKm(value))
        }
    }
}

struct WorkoutEditResolution {
    let workout: WorkoutEntry?
    let validationMessage: String?
}

struct EditWorkoutView: View {
    @State var workout: WorkoutEntry
    var onSave: (WorkoutEntry) -> Void
    var onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var state: AppState

    @State private var name: String = ""
    @State private var sets: String = ""
    @State private var reps: String = ""
    @State private var weight: String = ""
    @State private var duration: String = ""
    @State private var distance: String = ""
    @State private var validationMessage: String? = nil
    // Field contents as first shown — performance is "changed" only when the
    // user actually alters a field, never from lossy display formatting.
    @State private var initialFields = WorkoutEditFields()

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Custom Name", text: $name)
                    Text("Category: \(workout.category.displayName)")
                        .foregroundColor(.secondary)
                }
                .listRowBackground(RPGTheme.surface)

                Section("Performance") {
                    numberRow("Sets", placeholder: "1", text: $sets, keyboard: .numberPad)
                    numberRow("Reps (per set)", placeholder: "0", text: $reps, keyboard: .numberPad)
                    numberRow("Weight (\(state.user.units.displayName))", placeholder: "0", text: $weight, keyboard: .decimalPad)
                    numberRow("Duration (minutes)", placeholder: "0", text: $duration, keyboard: .numberPad)
                    numberRow("Distance (\(state.user.units.distanceDisplayName))", placeholder: "0", text: $distance, keyboard: .decimalPad)
                }
                .listRowBackground(RPGTheme.surface)
            }
            .listRowSeparatorTint(RPGTheme.frame.opacity(RPGTheme.hairline))
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .tint(RPGTheme.accent)
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Workout")
                        .font(RPGTheme.heading(.headline, weight: .bold))
                        .foregroundColor(.primary)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            name = workout.name
            let fields = WorkoutEditFields(workout: workout, units: state.user.units)
            sets = fields.sets
            reps = fields.reps
            weight = fields.weight
            duration = fields.duration
            distance = fields.distance
            initialFields = fields
        }
        .alert("Check your input", isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage ?? "")
        }
    }

    /// One labeled numeric field: plain label, tabular value in brass.
    private func numberRow(_ title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(RPGTheme.display(17, weight: .medium))
                .monospacedDigit()
                .foregroundColor(RPGTheme.accent)
                .accessibilityLabel(title)
        }
    }

    private func saveWorkout() {
        let fields = WorkoutEditFields(
            sets: sets,
            reps: reps,
            weight: weight,
            duration: duration,
            distance: distance
        )
        let resolution = Self.resolveWorkoutEdit(
            workout,
            name: name,
            fields: fields,
            initialFields: initialFields,
            state: state
        )
        if let message = resolution.validationMessage {
            validationMessage = message
            return
        }
        if let updatedWorkout = resolution.workout {
            onSave(updatedWorkout)
        }
    }

    static func resolveWorkoutEdit(
        _ workout: WorkoutEntry,
        name: String,
        fields: WorkoutEditFields,
        initialFields: WorkoutEditFields,
        state: AppState
    ) -> WorkoutEditResolution {
        var updatedWorkout = workout
        updatedWorkout.name = name

        let setsChanged = fields.sets != initialFields.sets
        let repsChanged = fields.reps != initialFields.reps
        let weightChanged = fields.weight != initialFields.weight
        let durationChanged = fields.duration != initialFields.duration
        let distanceChanged = fields.distance != initialFields.distance
        let performanceChanged = setsChanged || repsChanged || weightChanged || durationChanged || distanceChanged

        let setsText = fields.sets.trimmingCharacters(in: .whitespacesAndNewlines)
        let repsText = fields.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightText = fields.weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationText = fields.duration.trimmingCharacters(in: .whitespacesAndNewlines)
        let distanceText = fields.distance.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedSets = Int(setsText)
        let parsedReps = Int(repsText)
        let parsedWeight = flexibleDouble(weightText).map { state.user.units.toKg($0) }
        let parsedDuration = flexibleDouble(durationText)
        let parsedDistance = flexibleDouble(distanceText).map { state.user.units.toKm($0) }

        var parsingErrors: [String] = []
        if setsChanged, !setsText.isEmpty, parsedSets == nil {
            parsingErrors.append("Sets must be a whole number")
        }
        if repsChanged, !repsText.isEmpty, parsedReps == nil {
            parsingErrors.append("Reps must be a whole number")
        }
        if weightChanged, !weightText.isEmpty, parsedWeight == nil {
            parsingErrors.append("Weight must be a number")
        }
        if durationChanged, !durationText.isEmpty, parsedDuration == nil {
            parsingErrors.append("Duration must be a number")
        }
        if distanceChanged, !distanceText.isEmpty, parsedDistance == nil {
            parsingErrors.append("Distance must be a number")
        }
        if !parsingErrors.isEmpty {
            return WorkoutEditResolution(
                workout: nil,
                validationMessage: parsingErrors.joined(separator: "; ")
            )
        }

        // Same validation gate as logging — the edit door must not accept
        // values the log door rejects. Unchanged values deliberately stay out
        // of this round-trip because their display strings can be lossy.
        let validation = state.validateWorkoutInputs(
            sets: setsChanged ? parsedSets : nil,
            reps: repsChanged ? parsedReps : nil,
            weight: weightChanged ? parsedWeight : nil,
            durationMinutes: durationChanged ? parsedDuration : nil,
            distanceKm: distanceChanged ? parsedDistance : nil
        )
        if !validation.isValid, let error = validation.error {
            return WorkoutEditResolution(workout: nil, validationMessage: error)
        }

        if setsChanged { updatedWorkout.sets = validation.sets }
        if repsChanged { updatedWorkout.reps = validation.reps }
        if weightChanged { updatedWorkout.weight = validation.weight }
        if durationChanged { updatedWorkout.durationMinutes = validation.duration }
        if distanceChanged { updatedWorkout.distanceKm = validation.distance }

        if performanceChanged {
            // Per-set rows describe the old summary. Keeping them after a
            // summary edit makes charts, exports, and future routines disagree
            // with what the user just saved.
            updatedWorkout.performedSets = nil
        }

        // Also clean legacy custom entries that already carried pooled PR
        // metadata, even when this edit only changed their display name.
        if updatedWorkout.customExerciseID != nil {
            updatedWorkout.est1RM = nil
            updatedWorkout.prevBest1RM = nil
        }

        return WorkoutEditResolution(workout: updatedWorkout, validationMessage: nil)
    }
}

enum WorkoutGrouping: String, CaseIterable {
    case all = "All"
    case day = "Day"
    case week = "Week"
}

enum HistoryRangeFilter: String, CaseIterable, Identifiable {
    case all = "All Time"
    case week = "7 Days"
    case month = "30 Days"
    case quarter = "90 Days"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .all: return "All"
        case .week: return "7D"
        case .month: return "30D"
        case .quarter: return "90D"
        }
    }

    func includes(_ date: Date, now: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .week:
            return date >= (calendar.date(byAdding: .day, value: -7, to: now) ?? now)
        case .month:
            return date >= (calendar.date(byAdding: .day, value: -30, to: now) ?? now)
        case .quarter:
            return date >= (calendar.date(byAdding: .day, value: -90, to: now) ?? now)
        }
    }
}

/// A training session in the Progress log: one card, the session's totals on
/// top, each exercise as a compact row (long-press a row to edit/delete).
struct SessionHistoryCard: View {
    let entries: [WorkoutEntry]
    let units: Units
    let onEdit: (WorkoutEntry) -> Void
    let onDelete: (WorkoutEntry) -> Void
    var onProgress: ((WorkoutEntry) -> Void)? = nil

    private var totalXP: Double { entries.reduce(0) { $0 + $1.expGained } }
    private var totalSets: Int { entries.reduce(0) { $0 + max(1, $1.sets ?? 1) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RPGSymbolIcon(
                    symbol: .training,
                    size: 18,
                    presentation: .compact,
                    palette: .monochrome(RPGTheme.accent)
                )
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Training Session")
                        .font(RPGTheme.heading(.headline, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("\(entries.count) exercises · \(totalSets) sets")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    if let first = entries.first {
                        Text(first.date, style: .time)
                            .font(.footnote.weight(.medium))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    ModernXPChip(value: totalXP)
                }
            }

            HairlineRule()

            VStack(spacing: 6) {
                ForEach(entries) { entry in
                    HStack(spacing: 10) {
                        StatIcon(stat: entry.category.focus.primaryStat, size: 12)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        Text(entry.customExerciseID != nil ? entry.name : entry.category.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(performanceLine(entry))
                            .font(RPGTheme.display(13, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    .rpgInset(padding: 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onProgress?(entry)
                    }
                    .contextMenu {
                        if let onProgress {
                            Button { onProgress(entry) } label: {
                                RPGSymbolLabel("View Progress", symbol: .progress)
                            }
                        }
                        Button { onEdit(entry) } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { onDelete(entry) } label: { Label("Delete", systemImage: "trash") }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAction(named: "View Progress") {
                        onProgress?(entry)
                    }
                    .accessibilityHint("Opens this exercise's progress chart. Long press to edit or delete.")
                }
            }
        }
        .rpgCard(padding: 16)
    }

    private func performanceLine(_ entry: WorkoutEntry) -> String {
        var parts: [String] = []
        if let reps = entry.reps {
            let sets = max(1, entry.sets ?? 1)
            if let weight = entry.weight, weight > 0 {
                parts.append("\(sets)×\(reps) @ \(String(format: "%.1f", units.fromKg(weight)))")
            } else {
                parts.append("\(sets)×\(reps)")
            }
        }
        if let duration = entry.durationMinutes, duration > 0 { parts.append(String(format: "%.0fm", duration)) }
        if let distance = entry.distanceKm, distance > 0 { parts.append(String(format: "%.1f %@", units.fromKm(distance), units.distanceDisplayName)) }
        return parts.joined(separator: " · ")
    }
}


/// Experience earned, as a quiet XP-green capsule — no fill, one hairline.
struct ModernXPChip: View {
    let value: Double
    var body: some View {
        HStack(spacing: 5) {
            RPGSymbolIcon(
                symbol: .xp,
                size: 11,
                presentation: .compact,
                palette: .monochrome(RPGTheme.xp)
            )

            Text(String(format: "+%.0f XP", value))
                .font(RPGTheme.label(12, weight: .bold))
                .monospacedDigit()
                .foregroundColor(RPGTheme.xp)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .overlay(
            Capsule()
                .strokeBorder(RPGTheme.xp.opacity(0.4), lineWidth: 1)
        )
        .fixedSize()
    }
}

/// A single figure with its label. The stat's color survives only as a thin
/// underline — never as a tinted tile.
struct ModernStatChip: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(RPGTheme.display(22))
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Capsule()
                .fill(color)
                .frame(width: 28, height: 2)
                .accessibilityHidden(true)

            Text(title.uppercased())
                .font(RPGTheme.label(10, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .rpgInset(padding: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

struct ModernHistoryCard: View {
    let entry: WorkoutEntry
    let units: Units
    var onEdit: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let metrics = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        return VStack(alignment: .leading, spacing: 14) {
            // Header with exercise name and date
            HStack(alignment: .top, spacing: 12) {
                let focusStat = entry.category.focus.primaryStat
                StatIcon(stat: focusStat, size: 18)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    let title = entry.name.isEmpty ? entry.category.displayName : entry.name
                    Text(title)
                        .font(RPGTheme.heading(.headline, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    // Skip the category subtitle when it would repeat the title
                    if title != entry.category.displayName {
                        Text(entry.category.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(entry.category.focus.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.date, style: .date)
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundColor(.secondary)

                    Text(entry.date, style: .time)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary.opacity(0.8))

                    ModernXPChip(value: entry.expGained)
                }
            }

            // Performance metrics
            if hasPerformanceData {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Performance")

                    metrics {
                        if let r = entry.reps {
                            let setCount = max(1, entry.sets ?? 1)
                            ModernMetricBadge(symbol: .metricRepetitions, title: setCount > 1 ? "Sets × Reps" : "Reps", value: setCount > 1 ? "\(setCount)×\(r)" : "\(r)")
                        }
                        if let wKg = entry.weight, wKg > 0 {
                            let wDisp = units.fromKg(wKg)
                            ModernMetricBadge(symbol: .metricLoad, title: "Weight", value: "\(String(format: "%.1f", wDisp)) \(units.displayName)")
                        }
                        if let d = entry.durationMinutes, d > 0 {
                            ModernMetricBadge(symbol: .metricDuration, title: "Duration", value: String(format: "%.0f min", d))
                        }
                        if let km = entry.distanceKm, km > 0 {
                            let d = units.fromKm(km)
                            ModernMetricBadge(symbol: .metricDistance, title: "Distance", value: String(format: "%.2f %@", d, units.distanceDisplayName))
                        }
                    }
                }
            }

            // Attribute gains
            if !gainChips.isEmpty {
                HStack(spacing: 8) {
                    ForEach(gainChips, id: \.stat) { chip in
                        ModernAttributeChip(stat: chip.stat, value: chip.value)
                    }
                    Spacer()
                }
            }
        }
        .rpgCard(padding: 16)
    }

    private var hasPerformanceData: Bool {
        entry.reps != nil || (entry.weight ?? 0) > 0 || (entry.durationMinutes ?? 0) > 0 || (entry.distanceKm ?? 0) > 0
    }

    /// The exercise's primary attributes (per its emphasis weights), with the
    /// values actually gained this session.
    private var gainChips: [(stat: Stat, value: Double)] {
        let g = entry.statGains
        let w = StatEngine.statWeights(for: entry.category)
        var tuples = Stat.allCases.map { (stat: $0, weight: w.value(for: $0), value: g.value(for: $0)) }
        tuples.sort { $0.weight > $1.weight }
        let count = StatEngine.primaryDisplayCount(for: entry.category)
        return tuples.prefix(count)
            .filter { $0.value > 0.0001 }
            .sorted { $0.value > $1.value }
            .map { (stat: $0.stat, value: $0.value) }
    }
}

/// A labeled figure on an inset surface: small-caps title, tabular value.
struct ModernMetricBadge: View {
    let symbol: RPGSymbol
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            RPGSymbolIcon(
                symbol: symbol,
                size: 16,
                presentation: .compact,
                palette: .monochrome(RPGTheme.accent)
            )
            .frame(width: 16, height: 16)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(RPGTheme.label(9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(value)
                    .font(RPGTheme.display(14))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .rpgInset(padding: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// An attribute gain as a hairline capsule: the stat's glyph carries its
/// color, the number stays ink.
struct ModernAttributeChip: View {
    let stat: Stat
    let value: Double

    var body: some View {
        HStack(spacing: 5) {
            StatIcon(stat: stat, size: 11)

            Text(String(format: "+%@ %.2f", stat.abbreviation, value))
                .font(RPGTheme.label(12, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .overlay(
            Capsule()
                .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline + 0.1), lineWidth: 1)
        )
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.name) plus \(String(format: "%.2f", value))")
    }
}
