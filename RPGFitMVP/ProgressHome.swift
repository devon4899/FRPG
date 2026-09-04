import SwiftUI

// MARK: - Progress
//
// What has the training actually built? The week in numbers, the big lifts
// leveled against real standards, the balance of the last seven days, and
// the log itself — every entry one tap from its chart.

private enum HistoryFormatters {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    static let week: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct WorkoutHistoryGroup: Identifiable {
    let id: String
    let title: String
    let workouts: [WorkoutEntry]
    let sortDate: Date
}

struct ProgressHomeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showEditSheet = false
    @State private var editingWorkout: WorkoutEntry?
    @State private var workoutToDelete: WorkoutEntry?
    @State private var showDeleteConfirmation = false
    @State private var groupingMode: WorkoutGrouping = .day
    @State private var historySearchText = ""
    @State private var selectedRange: HistoryRangeFilter = .all
    @State private var selectedFocus: FocusGroup? = nil
    @State private var showPRsOnly = false
    @State private var progressTarget: ProgressTarget? = nil
    @State private var showEmptyStateQuickLog = false
    @AppStorage("hasUsedWorkoutContextMenu") private var hasUsedWorkoutContextMenu = false

    // MARK: Filtering

    private var filteredHistory: [WorkoutEntry] {
        let now = Date()
        let normalizedSearch = historySearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return state.getSortedHistory().filter { entry in
            let matchesSearch =
                normalizedSearch.isEmpty ||
                entry.name.localizedCaseInsensitiveContains(normalizedSearch) ||
                entry.category.displayName.localizedCaseInsensitiveContains(normalizedSearch)
            let matchesRange = selectedRange.includes(entry.date, now: now)
            let matchesFocus = selectedFocus == nil || entry.category.focus == selectedFocus
            let matchesPR = !showPRsOnly || isPersonalRecord(entry)
            return matchesSearch && matchesRange && matchesFocus && matchesPR
        }
    }

    private var hasActiveFilters: Bool {
        selectedRange != .all || selectedFocus != nil || showPRsOnly
    }

    private var groupedWorkouts: [WorkoutHistoryGroup] {
        let calendar = Calendar.current
        let sortedHistory = filteredHistory

        switch groupingMode {
        case .all:
            return [
                WorkoutHistoryGroup(
                    id: "all-workouts",
                    title: "All Workouts",
                    workouts: sortedHistory,
                    sortDate: sortedHistory.first?.date ?? .distantPast
                )
            ]

        case .day:
            let grouped = Dictionary(grouping: sortedHistory) { workout in
                calendar.startOfDay(for: workout.date)
            }
            return grouped.map { (date, workouts) in
                WorkoutHistoryGroup(
                    id: "day-\(Int(date.timeIntervalSince1970))",
                    title: dayTitle(for: date, calendar: calendar),
                    workouts: workouts,
                    sortDate: date
                )
            }.sorted { $0.sortDate > $1.sortDate }

        case .week:
            let grouped = Dictionary(grouping: sortedHistory) { workout in
                calendar.dateInterval(of: .weekOfYear, for: workout.date)?.start ?? workout.date
            }
            return grouped.map { (weekStart, workouts) in
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
                let weekLabel = "\(HistoryFormatters.week.string(from: weekStart)) – \(HistoryFormatters.week.string(from: weekEnd))"
                return WorkoutHistoryGroup(
                    id: "week-\(Int(weekStart.timeIntervalSince1970))",
                    title: weekLabel,
                    workouts: workouts,
                    sortDate: weekStart
                )
            }.sorted { $0.sortDate > $1.sortDate }
        }
    }

    private func dayTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return HistoryFormatters.day.string(from: date)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if state.history.isEmpty {
                    EmptyStateView(
                        title: "Nothing Written Yet",
                        message: "Your training log, records, and lift levels appear here after the first session.",
                        actionTitle: "Log a Workout",
                        action: { showEmptyStateQuickLog = true },
                        symbol: .progress
                    )
                    .screenColumn()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            weekSummaryPanel

                            AdaptiveColumns {
                                SignatureLiftsCard(onSelect: { category in
                                    progressTarget = ProgressTarget(category: category)
                                })
                                .environmentObject(state)

                                WeeklyBalanceCard()
                                    .environmentObject(state)
                            }

                            historySection
                        }
                        .screenColumn(maxWidth: sizeClass == .regular ? AppLayout.wideMaxWidth : AppLayout.contentMaxWidth)
                        .padding(.vertical, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $progressTarget) { target in
                ExerciseDetailView(target: target)
                    .environmentObject(state)
            }
            .searchable(text: $historySearchText,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "Search workouts or exercises")
            .sheet(isPresented: $showEmptyStateQuickLog) {
                LogWorkoutView()
                    .environmentObject(state)
            }
            .sheet(isPresented: $showEditSheet) {
                if let workout = editingWorkout {
                    EditWorkoutView(workout: workout, onSave: { updatedWorkout in
                        state.updateWorkout(updatedWorkout)
                        showEditSheet = false
                    }, onCancel: {
                        showEditSheet = false
                    })
                    .environmentObject(state)
                }
            }
            .confirmationDialog("Delete Workout", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let workout = workoutToDelete,
                       let index = state.history.firstIndex(where: { $0.id == workout.id }) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            state.deleteWorkout(at: IndexSet(integer: index))
                        }
                        workoutToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    workoutToDelete = nil
                }
            } message: {
                if let workout = workoutToDelete {
                    Text("Delete this \(workout.category.displayName) workout? This cannot be undone.")
                }
            }
        }
    }

    // MARK: Week summary

    private struct WeekSummary {
        var sessions = 0
        var sets = 0
        var xp = 0.0
        var allTime = 0
        var bestXP = 0.0
    }

    private func weekSummary() -> WeekSummary {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var summary = WeekSummary(allTime: state.history.count)
        var sessionIDs = Set<UUID>()
        for entry in state.history {
            summary.bestXP = max(summary.bestXP, entry.expGained)
            guard entry.date >= weekAgo else { continue }
            summary.sets += max(1, entry.sets ?? 1)
            summary.xp += entry.expGained
            if let id = entry.sessionID {
                if sessionIDs.insert(id).inserted { summary.sessions += 1 }
            } else {
                summary.sessions += 1
            }
        }
        return summary
    }

    private var weekSummaryPanel: some View {
        let summary = weekSummary()
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel("This Week")

            let tiles = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))
            tiles {
                summaryTile(value: "\(summary.sessions)", label: summary.sessions == 1 ? "session" : "sessions", tint: RPGTheme.accent)
                summaryTile(value: "\(summary.sets)", label: "sets", tint: RPGTheme.accent)
                summaryTile(value: "+\(Int(summary.xp.rounded()))", label: "XP", tint: RPGTheme.xp)
            }

            HStack(spacing: 6) {
                Text("\(summary.allTime) workout\(summary.allTime == 1 ? "" : "s") all time")
                Text("·")
                Text("best \(Int(summary.bestXP.rounded())) XP")
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundColor(.secondary)
        }
        .rpgCard(padding: 16)
        .accessibilityElement(children: .combine)
    }

    private func summaryTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(RPGTheme.display(22, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .rpgInset(padding: 0)
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Recent Workouts") {
                filterMenu
            }

            if hasActiveFilters {
                HStack(spacing: 8) {
                    Text("Showing \(filteredHistory.count) of \(state.history.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear") {
                        withAnimation {
                            selectedRange = .all
                            selectedFocus = nil
                            showPRsOnly = false
                        }
                    }
                    .buttonStyle(RPGQuietButtonStyle())
                    .accessibilityLabel("Clear filters")
                }
            } else if !hasUsedWorkoutContextMenu {
                Text("Tap a workout for its chart. Long-press to edit or delete.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let groups = groupedWorkouts
            if groups.isEmpty {
                EmptyStateView(
                    title: "No Matching Workouts",
                    message: "Try clearing the search or widening the date range.",
                    actionTitle: "Clear Filters",
                    action: {
                        historySearchText = ""
                        selectedRange = .all
                        selectedFocus = nil
                        showPRsOnly = false
                    },
                    symbol: .chronicle
                )
            } else {
                ForEach(Array(groups.enumerated()), id: \.element.id) { groupIndex, group in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(group.title)
                                .font(RPGTheme.heading(.subheadline, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Text("\(group.workouts.count) workout\(group.workouts.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, groupIndex == 0 ? 0 : 8)
                        .accessibilityAddTraits(.isHeader)

                        ForEach(displayUnits(for: group.workouts)) { unit in
                            switch unit {
                            case .single(let entry):
                                ModernHistoryCard(entry: entry, units: state.user.units, onEdit: {
                                    editingWorkout = entry
                                    showEditSheet = true
                                })
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    progressTarget = ProgressTarget(entry: entry)
                                }
                                .accessibilityAction(named: "View Progress") {
                                    progressTarget = ProgressTarget(entry: entry)
                                }
                                .contextMenu { entryMenu(entry) }
                                // The same actions, visible: long-press is a
                                // shortcut, never the only door.
                                .overlay(alignment: .bottomTrailing) {
                                    Menu {
                                        entryMenu(entry)
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.body)
                                            .foregroundColor(RPGTheme.accent)
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .accessibilityLabel("Workout options")
                                    .padding(4)
                                }
                                .accessibilityHint("Opens this exercise's progress chart. Long press to edit or delete.")
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            case .session(_, let entries):
                                SessionHistoryCard(
                                    entries: entries,
                                    units: state.user.units,
                                    onEdit: { entry in
                                        hasUsedWorkoutContextMenu = true
                                        editingWorkout = entry
                                        showEditSheet = true
                                    },
                                    onDelete: { entry in
                                        hasUsedWorkoutContextMenu = true
                                        workoutToDelete = entry
                                        showDeleteConfirmation = true
                                    },
                                    onProgress: { entry in
                                        hasUsedWorkoutContextMenu = true
                                        progressTarget = ProgressTarget(entry: entry)
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func entryMenu(_ entry: WorkoutEntry) -> some View {
        Button {
            hasUsedWorkoutContextMenu = true
            progressTarget = ProgressTarget(entry: entry)
        } label: {
            RPGSymbolLabel("View Progress", symbol: .progress)
        }
        Button {
            hasUsedWorkoutContextMenu = true
            editingWorkout = entry
            showEditSheet = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button(role: .destructive) {
            hasUsedWorkoutContextMenu = true
            workoutToDelete = entry
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Range", selection: $selectedRange) {
                ForEach(HistoryRangeFilter.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            Picker("Type", selection: $selectedFocus) {
                Text("All Types").tag(FocusGroup?.none)
                ForEach(FocusGroup.allCases) { focus in
                    Text(focus.shortDisplayName).tag(FocusGroup?.some(focus))
                }
            }
            Toggle(isOn: $showPRsOnly) {
                HStack(spacing: 6) {
                    RPGSymbolIcon(
                        symbol: .personalRecord,
                        size: 15,
                        presentation: .compact,
                        palette: .monochrome(RPGTheme.gold)
                    )
                    Text("Personal Records Only")
                }
            }
            Picker("Group by", selection: $groupingMode) {
                ForEach(WorkoutGrouping.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                Text(hasActiveFilters ? "Filtered" : "Filter")
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(RPGTheme.accent)
            .frame(minWidth: 44, minHeight: 44)
            .fixedSize()
        }
        .accessibilityLabel(hasActiveFilters ? "Filters, active" : "Filters")
    }

    private func isPersonalRecord(_ entry: WorkoutEntry) -> Bool {
        guard let est1RM = entry.est1RM else { return false }
        return est1RM > (entry.prevBest1RM ?? 0)
    }

    /// One display unit per card: solo entries stand alone; entries sharing
    /// a sessionID fold into a session card, positioned by newest entry.
    enum HistoryDisplayUnit: Identifiable {
        case single(WorkoutEntry)
        case session(UUID, [WorkoutEntry])

        var id: String {
            switch self {
            case .single(let entry): return entry.id.uuidString
            case .session(let id, _): return "session-\(id.uuidString)"
            }
        }

        var latestDate: Date {
            switch self {
            case .single(let entry): return entry.date
            case .session(_, let entries): return entries.map(\.date).max() ?? .distantPast
            }
        }
    }

    private func displayUnits(for workouts: [WorkoutEntry]) -> [HistoryDisplayUnit] {
        var sessions: [UUID: [WorkoutEntry]] = [:]
        var units: [HistoryDisplayUnit] = []
        for entry in workouts {
            if let sessionID = entry.sessionID {
                sessions[sessionID, default: []].append(entry)
            } else {
                units.append(.single(entry))
            }
        }
        for (sessionID, entries) in sessions {
            if entries.count == 1 {
                units.append(.single(entries[0]))
            } else {
                units.append(.session(sessionID, entries.sorted { $0.date < $1.date }))
            }
        }
        return units.sorted { $0.latestDate > $1.latestDate }
    }
}
