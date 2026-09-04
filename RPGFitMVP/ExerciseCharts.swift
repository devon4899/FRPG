import SwiftUI
import Charts

// MARK: - Per-exercise progress
//
// The honest-data payoff: every chart reads resolvedSets, so real per-set
// records (v4+) and expanded legacy summaries both plot — and PR detection
// stays anchored to the engine's stored est1RM/prevBest1RM, never a
// re-derivation that could disagree with what the user was told at log time.

/// What the progress screen charts: one exercise IDENTITY — a built-in
/// category, or a single custom exercise (never merged into its base).
struct ProgressTarget: Identifiable, Hashable {
    let category: ExerciseCategory
    let customExerciseID: UUID?
    let title: String

    var id: String { customExerciseID?.uuidString ?? category.rawValue }

    init(entry: WorkoutEntry) {
        self.category = entry.category
        self.customExerciseID = entry.customExerciseID
        self.title = entry.customExerciseID != nil ? entry.name : entry.category.displayName
    }

    /// A built-in exercise by category — Signature Lifts open their charts
    /// without needing a specific history entry.
    init(category: ExerciseCategory) {
        self.category = category
        self.customExerciseID = nil
        self.title = category.displayName
    }
}

struct ExerciseDetailView: View {
    let target: ProgressTarget
    @EnvironmentObject var state: AppState

    private var category: ExerciseCategory { target.category }

    private struct DatedValue: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    /// Oldest first, so lines read left to right.
    private var entries: [WorkoutEntry] {
        state.history
            .filter { $0.category == category && $0.customExerciseID == target.customExerciseID }
            .sorted { $0.date < $1.date }
    }

    private var units: Units { state.user.units }

    // MARK: series

    private var e1RMSeries: [DatedValue] {
        entries.compactMap { entry in
            entry.est1RM.map { DatedValue(date: entry.date, value: units.fromKg($0)) }
        }
    }

    private var topSetSeries: [DatedValue] {
        entries.compactMap { entry in
            let top = entry.resolvedSets.compactMap(\.weightKg).max() ?? 0
            return top > 0 ? DatedValue(date: entry.date, value: units.fromKg(top)) : nil
        }
    }

    private var usesWeight: Bool { !topSetSeries.isEmpty }

    /// Per training day: Σ reps × weight for loaded work, Σ reps otherwise.
    private var volumeSeries: [DatedValue] {
        let calendar = Calendar.current
        var byDay: [Date: Double] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            for set in entry.resolvedSets {
                let reps = Double(set.reps ?? 0)
                let amount = usesWeight ? reps * units.fromKg(set.weightKg ?? 0) : reps
                byDay[day, default: 0] += amount
            }
        }
        return byDay.keys.sorted().map { DatedValue(date: $0, value: byDay[$0] ?? 0) }
    }

    private var minutesSeries: [DatedValue] {
        let calendar = Calendar.current
        var byDay: [Date: Double] = [:]
        for entry in entries {
            guard let minutes = entry.durationMinutes, minutes > 0 else { continue }
            byDay[calendar.startOfDay(for: entry.date), default: 0] += minutes
        }
        return byDay.keys.sorted().map { DatedValue(date: $0, value: byDay[$0] ?? 0) }
    }

    private var distanceSeries: [DatedValue] {
        let calendar = Calendar.current
        var byDay: [Date: Double] = [:]
        for entry in entries {
            guard let km = entry.distanceKm, km > 0 else { continue }
            byDay[calendar.startOfDay(for: entry.date), default: 0] += units.fromKm(km)
        }
        return byDay.keys.sorted().map { DatedValue(date: $0, value: byDay[$0] ?? 0) }
    }

    /// Sessions that set a new estimated-1RM record, newest first.
    private var prEntries: [WorkoutEntry] {
        entries
            .filter { entry in
                guard let est = entry.est1RM else { return false }
                return est > (entry.prevBest1RM ?? 0)
            }
            .reversed()
    }

    // MARK: body

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    statsHeader

                    if category.prefersDuration {
                        chartCard(title: "Minutes per Day", series: minutesSeries,
                                  color: RPGTheme.accent, asBars: true)
                        chartCard(title: "Distance per Day (\(units.distanceDisplayName))",
                                  series: distanceSeries, color: RPGTheme.xp, asBars: true)
                    } else {
                        chartCard(title: "Estimated 1RM (\(units.displayName))",
                                  series: e1RMSeries, color: RPGTheme.accent, asBars: false)
                        chartCard(title: "Top Set (\(units.displayName))",
                                  series: topSetSeries, color: RPGTheme.gold, asBars: false)
                        chartCard(title: usesWeight ? "Volume per Day (\(units.displayName))" : "Reps per Day",
                                  series: volumeSeries, color: RPGTheme.xp, asBars: true)
                    }

                    if !prEntries.isEmpty {
                        prTimeline
                    }

                    if entries.count < 2 {
                        Text("Log \(target.title) again and the trend lines start drawing themselves.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .rpgCard(padding: 14)
                    }
                }
                .frame(maxWidth: AppLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(target.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: pieces

    private var statsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Summary")
            HStack(spacing: 10) {
                statTile(value: "\(entries.count)", label: entries.count == 1 ? "session" : "sessions")
                // Customs never enter the shared record pool, so the tile only
                // makes sense for built-ins.
                if target.customExerciseID == nil,
                   let best = state.user.best1RM[category], best > 0 {
                    statTile(value: AppState.fieldNumber(units.fromKg(best)),
                             label: "best est. 1RM")
                }
                if let last = entries.last {
                    statTile(value: last.date.formatted(.dateTime.month(.abbreviated).day()),
                             label: "last trained")
                }
            }
        }
        .rpgCard(padding: 14)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(RPGTheme.display(22))
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(RPGTheme.label(10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .rpgInset(padding: 10)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func chartCard(title: String, series: [DatedValue], color: Color, asBars: Bool) -> some View {
        if series.count >= 2 {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title)
                Chart(series) { point in
                    if asBars {
                        BarMark(x: .value("Date", point.date, unit: .day),
                                y: .value(title, point.value))
                            .foregroundStyle(color.opacity(0.7))
                            .cornerRadius(3)
                    } else {
                        LineMark(x: .value("Date", point.date),
                                 y: .value(title, point.value))
                            .foregroundStyle(color)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", point.date),
                                  y: .value(title, point.value))
                            .foregroundStyle(color)
                            .symbolSize(30)
                    }
                }
                .chartYScale(domain: asBars ? 0...max(1, (series.map(\.value).max() ?? 1) * 1.15)
                                            : lineDomain(for: series))
                // Keep edge labels inside the card. Without plot padding,
                // Charts centers the final date on the trailing boundary and
                // abbreviates a perfectly ordinary value such as “Aug 31”.
                .chartXScale(range: .plotDimension(startPadding: 28, endPadding: 28))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 170)
            }
            .rpgCard(padding: 14)
        }
    }

    /// Explicit padded domain — .automatic collapses when every value is
    /// equal (the flat-progress case) and renders a degenerate axis.
    private func lineDomain(for series: [DatedValue]) -> ClosedRange<Double> {
        let values = series.map(\.value)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        if low == high {
            let pad = max(1, low * 0.05)
            return (low - pad)...(high + pad)
        }
        let pad = (high - low) * 0.2
        return (low - pad)...(high + pad)
    }

    private var prTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Record History")
                .padding(.bottom, 6)
            ForEach(Array(prEntries.prefix(6).enumerated()), id: \.element.id) { index, entry in
                if index > 0 { HairlineRule() }
                HStack(spacing: 10) {
                    RPGSymbolIcon(
                        symbol: .personalRecord,
                        size: 15,
                        presentation: .compact,
                        palette: .monochrome(RPGTheme.gold)
                    )
                    Text(entry.date.formatted(.dateTime.year().month(.abbreviated).day()))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    if let est = entry.est1RM {
                        Text("\(AppState.fieldNumber(units.fromKg(est))) \(units.displayName)")
                            .font(RPGTheme.display(15))
                            .monospacedDigit()
                            .foregroundColor(RPGTheme.gold)
                    }
                }
                .frame(minHeight: 40)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rpgCard(padding: 14)
    }
}
