import ActivityKit
import Foundation

// This file is compiled into both the app and widget-extension targets. Keep
// shared ActivityKit and widget-storage payloads here so both processes always
// encode and decode the exact same schema.
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var totalSeconds: Int
        var exerciseName: String
    }
}

struct WidgetSummary: Codable {
    var level: Int
    var xpProgress: Double
    var questsRemaining: Int
    var updatedAt: Date
    /// Optional so summaries written before this field existed still decode.
    var questsTotal: Int?

    /// Quest counts are day-scoped. A summary from yesterday can still show
    /// durable level/XP, but must not claim that yesterday's quests are today's.
    func hasCurrentQuestCount(asOf date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(updatedAt, inSameDayAs: date)
    }

    /// Zero remaining means "all done" only when quests actually exist; before a
    /// class is chosen there are none, and claiming victory over an empty list
    /// is a lie. A summary with no total predates the field, so the remaining
    /// count is all there is to go on.
    var hasQuests: Bool {
        guard let questsTotal else { return questsRemaining > 0 }
        return questsTotal > 0
    }
}
