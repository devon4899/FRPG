import WidgetKit
import SwiftUI
import ActivityKit

@main
struct RPGFitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AdventureWidget()
        RestActivityWidget()
    }
}

// MARK: - Rest timer Live Activity
//
// The countdown that survives leaving the app: lock screen banner and
// Dynamic Island, driven entirely by the session's rest state.

/// The widget target cannot import Theme.swift, so the dark keep's tokens
/// are mirrored here: charcoal canvas, brass gold, XP green, parchment cream.
enum WidgetPalette {
    static let canvas = Color(red: 0.078, green: 0.080, blue: 0.105)
    static let gold = Color(red: 0.92, green: 0.76, blue: 0.40)
    static let xp = Color(red: 0.44, green: 0.80, blue: 0.56)
    static let cream = Color(red: 0.97, green: 0.94, blue: 0.87)
    static let creamMuted = cream.opacity(0.72)
}

struct RestActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            HStack(spacing: 12) {
                WidgetRestMark(size: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(context.isStale ? "Rest complete" : "Resting")
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.creamMuted)
                    Text(context.state.exerciseName)
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(WidgetPalette.cream)
                        .lineLimit(1)
                }
                Spacer()
                if context.isStale {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(WidgetPalette.xp)
                        .frame(maxWidth: 90, alignment: .trailing)
                        .accessibilityLabel("Rest complete")
                } else {
                    Text(timerInterval: timerRange(for: context.state), countsDown: true)
                        .font(.system(size: 30, weight: .semibold, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(WidgetPalette.cream)
                        .frame(maxWidth: 90, alignment: .trailing)
                }
            }
            .padding()
            .activityBackgroundTint(WidgetPalette.canvas)
            .activitySystemActionForegroundColor(WidgetPalette.gold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        WidgetRestMark(size: 16)
                            .accessibilityHidden(true)
                        Text("Rest")
                            .foregroundStyle(WidgetPalette.gold)
                    }
                    .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.isStale {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .accessibilityHidden(true)
                            Text("Done")
                        }
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(WidgetPalette.xp)
                        .accessibilityLabel("Rest complete")
                    } else {
                        Text(timerInterval: timerRange(for: context.state), countsDown: true)
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(WidgetPalette.cream)
                            .frame(maxWidth: 72, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Next: \(context.state.exerciseName)")
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.creamMuted)
                }
            } compactLeading: {
                WidgetRestMark(size: 17)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Rest timer")
            } compactTrailing: {
                if context.isStale {
                    Image(systemName: "checkmark")
                        .foregroundStyle(WidgetPalette.xp)
                        .accessibilityLabel("Rest complete")
                } else {
                    Text(timerInterval: timerRange(for: context.state), countsDown: true)
                        .monospacedDigit()
                        .foregroundStyle(WidgetPalette.cream)
                        .frame(maxWidth: 44)
                }
            } minimal: {
                if context.isStale {
                    Image(systemName: "checkmark")
                        .foregroundStyle(WidgetPalette.xp)
                        .accessibilityLabel("Rest complete")
                } else {
                    WidgetRestMark(size: 18)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Rest timer")
                }
            }
            .keylineTint(WidgetPalette.gold)
        }
    }

    private func timerRange(for state: RestActivityAttributes.ContentState) -> ClosedRange<Date> {
        let now = Date()
        return now...max(now.addingTimeInterval(1), state.endDate)
    }
}

// MARK: - Home screen summary widget

enum SharedStore {
    static let appGroup = "group.com.devoncheng.RPGFitMVP"

    static func load() -> WidgetSummary? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-summary.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSummary.self, from: data)
    }
}

struct AdventureEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary?
}

struct AdventureProvider: TimelineProvider {
    func placeholder(in context: Context) -> AdventureEntry {
        AdventureEntry(date: Date(),
                       summary: WidgetSummary(level: 12, xpProgress: 0.6,
                                              questsRemaining: 2, updatedAt: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (AdventureEntry) -> Void) {
        // Demo data belongs to the widget gallery only; elsewhere a missing
        // summary is a real empty state and must render as one.
        let fallback = context.isPreview ? placeholder(in: context).summary : nil
        completion(AdventureEntry(date: Date(), summary: SharedStore.load() ?? fallback))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AdventureEntry>) -> Void) {
        let now = Date()
        let summary = SharedStore.load()
        let calendar = Calendar.current
        let nextMidnight = calendar.date(byAdding: .day, value: 1,
                                         to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(24 * 60 * 60)
        let entries = [
            AdventureEntry(date: now, summary: summary),
            // An explicit midnight entry invalidates yesterday's quest count
            // even if the app is not opened and no reload request arrives.
            AdventureEntry(date: nextMidnight, summary: summary),
        ]
        completion(Timeline(entries: entries,
                            policy: .after(nextMidnight.addingTimeInterval(60))))
    }
}

struct AdventureWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AdventureEntry

    private let gold = WidgetPalette.gold
    private let xpGreen = WidgetPalette.xp

    var body: some View {
        content
            .containerBackground(for: .widget) {
                WidgetPalette.canvas
            }
            .foregroundStyle(WidgetPalette.cream)
    }

    @ViewBuilder
    private var content: some View {
        if let summary = entry.summary {
            if family == .systemMedium {
                medium(summary)
            } else {
                small(summary)
            }
        } else {
            empty
        }
    }

    private func small(_ summary: WidgetSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Lv \(summary.level)")
                    .font(.system(.title2, design: .serif, weight: .bold))
                Spacer()
                WidgetBrandMark(size: 22)
            }
            ProgressView(value: summary.xpProgress)
                .tint(xpGreen)
            Text(questStatus(for: summary))
                .font(.caption2)
                .foregroundStyle(WidgetPalette.creamMuted)
        }
    }

    // The extra width earns its keep with the crest as an anchor and an exact
    // XP figure, rather than stretching the small layout across the card.
    private func medium(_ summary: WidgetSummary) -> some View {
        HStack(spacing: 18) {
            WidgetBrandMark(size: 48)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Lv \(summary.level)")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                    Spacer()
                    Text("\(Int((summary.xpProgress * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(xpGreen)
                }
                ProgressView(value: summary.xpProgress)
                    .tint(xpGreen)
                Text(questStatus(for: summary))
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.creamMuted)
                    .lineLimit(1)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetBrandMark(size: 22)
            Text("Open RPGFit to begin your adventure")
                .font(.caption)
                .foregroundStyle(WidgetPalette.creamMuted)
        }
    }

    private func questStatus(for summary: WidgetSummary) -> String {
        guard summary.hasCurrentQuestCount(asOf: entry.date), summary.hasQuests else {
            return "Open RPGFit for today's quests"
        }
        return summary.questsRemaining == 0
            ? "All quests done"
            : "\(summary.questsRemaining) quest\(summary.questsRemaining == 1 ? "" : "s") remaining"
    }
}

struct AdventureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RPGFitAdventure", provider: AdventureProvider()) { entry in
            AdventureWidgetView(entry: entry)
        }
        .configurationDisplayName("Adventure")
        .description("Your level, XP, and today's remaining quests.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
