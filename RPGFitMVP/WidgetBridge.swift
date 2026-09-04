import Foundation
import WidgetKit

/// Publishes a tiny summary into the app group after every save so the
/// home-screen widget stays honest without ever reading the real save file.
enum WidgetBridge {
    static let appGroup = "group.com.devoncheng.RPGFitMVP"

    static func publish(user: UserProfile) {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-summary.json") else { return }
        let active = user.dailyChallenges.filter { $0.isActive }
        let summary = WidgetSummary(
            level: user.level,
            xpProgress: user.nextLevelXP > 0 ? min(1, user.xp / user.nextLevelXP) : 0,
            questsRemaining: active.filter { !$0.isCompleted }.count,
            updatedAt: Date(),
            questsTotal: active.count
        )
        guard let data = try? JSONEncoder().encode(summary) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadTimelines(ofKind: "RPGFitAdventure")
    }
}
