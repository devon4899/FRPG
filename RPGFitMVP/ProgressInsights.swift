import SwiftUI

// MARK: - Progress Insights
//
// Three quiet analytics surfaces that only ever speak from real training
// data: per-lift levels with just-in-time milestone targets (the thing only
// a standards-anchored engine can say honestly), a weekly training-balance
// readout, and a gentle look back at yesterday. All computed offline from
// existing logs; nothing here is gated, prescribed, or punished.

// MARK: Signature Lifts

struct SignatureLiftStatus: Identifiable {
    let category: ExerciseCategory
    let oneRM: Double
    let level: Int
    let nextTarget: (level: Int, oneRM: Double)?

    var id: String { category.rawValue }

    /// 0…1 toward the next 10-level milestone band.
    var milestoneProgress: Double {
        guard let next = nextTarget, next.oneRM > 0 else { return 1 }
        let bandStart = next.oneRM * 0.75 // show meaningful motion in the last stretch
        guard oneRM > bandStart else { return 0.05 }
        return min(1, (oneRM - bandStart) / (next.oneRM - bandStart))
    }

    var isCloseToMilestone: Bool {
        guard let next = nextTarget else { return false }
        return oneRM >= next.oneRM * 0.90
    }
}

extension AppState {
    /// The big four, leveled from best est-1RM against the same anchors that
    /// drive attribute placement. Only lifts with a logged best appear.
    var signatureLiftStatuses: [SignatureLiftStatus] {
        guard let bodyweight = user.bodyweightKg, bodyweight > 0 else { return [] }
        return StatEngine.signatureLifts.compactMap { category in
            guard let best = user.best1RM[category], best > 0 else { return nil }
            let level = StatEngine.liftLevel(category: category, oneRM: best, bodyweightKg: bodyweight)
            // Next milestone: the next multiple of 10 the anchors can price.
            let nextLevel = min(100, ((level / 10) + 1) * 10)
            let target = StatEngine.requiredOneRM(category: category, level: nextLevel, bodyweightKg: bodyweight)
                .map { (nextLevel, $0) }
            return SignatureLiftStatus(category: category, oneRM: best, level: level, nextTarget: target)
        }
    }
}

/// Per-lift leveling for the big compounds — Skillbook's "hall of records"
/// seed. When a milestone is within reach, the row becomes a challenge.
struct SignatureLiftsCard: View {
    @EnvironmentObject var state: AppState
    /// Tapping a lift opens its chart.
    var onSelect: ((ExerciseCategory) -> Void)? = nil

    var body: some View {
        let lifts = state.signatureLiftStatuses
        if !lifts.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Signature Lifts")

                ForEach(lifts) { lift in
                    Button {
                        onSelect?(lift.category)
                    } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(lift.category.displayName)
                                .font(RPGTheme.heading(.subheadline, weight: .semibold))
                            Spacer()
                            Text("Lv \(lift.level)")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Stat.strength.color.opacity(0.85)))
                        }

                        OrnateProgressBar(progress: lift.milestoneProgress,
                                          tint: lift.isCloseToMilestone ? RPGTheme.gold : Stat.strength.color)
                            .frame(height: 8)

                        HStack {
                            Text("Best est. 1RM \(weightText(lift.oneRM))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let next = lift.nextTarget {
                                if lift.isCloseToMilestone {
                                    // The rank-up challenge: a target only the
                                    // standards anchor can name honestly.
                                    HStack(spacing: 4) {
                                        RPGSymbolIcon(
                                            symbol: .rank,
                                            size: 14,
                                            presentation: .compact,
                                            palette: .monochrome(RPGTheme.gold)
                                        )
                                        Text("Lv \(next.level) at \(weightText(next.oneRM))")
                                    }
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(RPGTheme.gold)
                                } else {
                                    Text("Lv \(next.level) at \(weightText(next.oneRM))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableCardStyle())
                    .disabled(onSelect == nil)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(onSelect == nil ? "" : "Opens the \(lift.category.displayName) chart")
                }
            }
            .rpgCard()
        }
    }

    private func weightText(_ kg: Double) -> String {
        let value = state.user.units.fromKg(kg)
        return "\(String(format: value < 100 ? "%.1f" : "%.0f", value)) \(state.user.units.displayName)"
    }
}

// MARK: - Weekly balance

/// Sets per focus group across the last 7 days — six small bars and one
/// honest sentence. Free where competitors paywall their "muscle matrix."
struct WeeklyBalanceCard: View {
    @EnvironmentObject var state: AppState

    private struct FocusLoad: Identifiable {
        let focus: FocusGroup
        let sets: Int
        var id: String { focus.rawValue }
    }

    private var loads: [FocusLoad] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = state.history.filter { $0.date >= cutoff }
        return FocusGroup.allCases.map { focus in
            let sets = recent.filter { $0.category.focus == focus }
                .reduce(0) { $0 + max(1, $1.sets ?? 1) }
            return FocusLoad(focus: focus, sets: sets)
        }
    }

    private func insight(for loads: [FocusLoad]) -> String {
        let active = loads.filter { $0.sets > 0 }
        if active.isEmpty { return "A quiet week so far — the first set changes that." }
        if active.count == loads.count { return "All six disciplines touched this week. True hybrid work." }
        let missing = loads.filter { $0.sets == 0 }.map { $0.focus.primaryStat.name }
        if missing.count <= 2 {
            return "\(missing.joined(separator: " and ")) could use some love this week."
        }
        let top = loads.max { $0.sets < $1.sets }!
        return "A \(top.focus.primaryStat.name)-heavy week — variety feeds the other attributes."
    }

    var body: some View {
        let loads = self.loads
        let maxSets = max(1, loads.map(\.sets).max() ?? 1)
        if loads.contains(where: { $0.sets > 0 }) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Weekly Balance")

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(loads) { load in
                        VStack(spacing: 4) {
                            Text("\(load.sets)")
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .foregroundColor(load.sets > 0 ? load.focus.primaryStat.color : .secondary.opacity(0.5))
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(load.sets > 0 ? load.focus.primaryStat.color.opacity(0.8) : RPGTheme.surfaceInner)
                                .frame(height: max(4, 44 * CGFloat(load.sets) / CGFloat(maxSets)))
                            StatIcon(stat: load.focus.primaryStat, size: 11)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(load.focus.primaryStat.name): \(load.sets) sets this week")
                    }
                }
                .frame(height: 76)

                Text(insight(for: loads))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .rpgCard()
        }
    }
}

// MARK: - Yesterday's chronicle

/// Yesterday's training, summarized for a gentle look back. Shown only until
/// today's first session — celebration of what happened, never a nag.
struct DayChronicle {
    let sessions: Int
    let sets: Int
    let xp: Double
    let highlight: String?

    var summaryLine: String {
        var parts = ["\(sets) set\(sets == 1 ? "" : "s")", "+\(Int(xp.rounded())) XP"]
        if let highlight { parts.append(highlight) }
        return parts.joined(separator: " · ") + ". A fine day's work."
    }
}

extension AppState {
    /// Yesterday's chronicle, or nil once today has its own first entry (or
    /// when yesterday was quiet).
    var yesterdayChronicle: DayChronicle? {
        let cal = Calendar.current
        let trainedToday = history.contains { cal.isDateInToday($0.date) }
        guard !trainedToday else { return nil }
        let yesterdayEntries = history.filter { cal.isDateInYesterday($0.date) }
        guard !yesterdayEntries.isEmpty else { return nil }

        let sessionCount = Set(yesterdayEntries.compactMap(\.sessionID)).count
            + yesterdayEntries.filter { $0.sessionID == nil }.count
        let sets = yesterdayEntries.reduce(0) { $0 + max(1, $1.sets ?? 1) }
        let xp = yesterdayEntries.reduce(0.0) { $0 + $1.expGained }

        let best = yesterdayEntries.max { ($0.est1RM ?? 0) < ($1.est1RM ?? 0) }
        var highlight: String? = nil
        if let best, let est = best.est1RM, est > 0 {
            let value = user.units.fromKg(est)
            highlight = "\(best.category.displayName) est. 1RM \(String(format: "%.0f", value)) \(user.units.displayName)"
        }
        return DayChronicle(sessions: sessionCount, sets: sets, xp: xp, highlight: highlight)
    }
}

/// A gentle look back at yesterday, as a panel row.
struct ChronicleCard: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if let chronicle = state.yesterdayChronicle {
            HStack(spacing: 12) {
                RPGSymbolIcon(
                    symbol: .chronicle,
                    size: 20,
                    presentation: .compact,
                    palette: .monochrome(RPGTheme.accent)
                )
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Yesterday's Chronicle")
                        .font(RPGTheme.heading(.subheadline, weight: .semibold))
                    Text(chronicle.summaryLine)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .rpgCard(padding: 14)
            .accessibilityElement(children: .combine)
        }
    }
}
