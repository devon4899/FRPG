import Foundation
import ActivityKit

/// The app side of the rest-timer Live Activity: one activity at a time,
/// started/updated/ended alongside the in-session rest banner. Everything
/// is guarded, so devices with Live Activities disabled just fall back to
/// the existing notification.
@MainActor
enum RestLiveActivity {
    private static let fallbackExerciseName = "your next set"
    private static var pendingOperation: Task<Void, Never>?
    private static var expirationTask: Task<Void, Never>?

    /// Recovers the most relevant surviving activity after an app relaunch.
    /// Exposed so callers extending a timer can retain its authored label.
    static var currentExerciseName: String? {
        canonicalActivity(in: Activity<RestActivityAttributes>.activities)
            .map { normalizedExerciseName($0.content.state.exerciseName) }
    }

    static func start(endDate: Date, totalSeconds: Int, exerciseName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        expirationTask?.cancel()
        let state = RestActivityAttributes.ContentState(endDate: endDate,
                                                        totalSeconds: totalSeconds,
                                                        exerciseName: normalizedExerciseName(exerciseName))
        enqueue {
            await endAllActivities()
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            if (try? Activity.request(attributes: RestActivityAttributes(),
                                      content: .init(state: state, staleDate: endDate))) != nil {
                scheduleExpiration(at: endDate)
            }
        }
    }

    /// Updates the surviving activity even when this process did not create it.
    /// The activity's existing exercise label wins; `exerciseName` is only a
    /// fallback for a legacy/invalid empty label.
    static func update(endDate: Date, totalSeconds: Int, exerciseName: String? = nil) {
        enqueue {
            let activities = Activity<RestActivityAttributes>.activities
            guard let activity = canonicalActivity(in: activities) else { return }
            let retainedName = meaningfulExerciseName(activity.content.state.exerciseName)
            let fallbackName = normalizedExerciseName(exerciseName)
            let state = RestActivityAttributes.ContentState(endDate: endDate,
                                                            totalSeconds: totalSeconds,
                                                            exerciseName: retainedName ?? fallbackName)
            await activity.update(.init(state: state, staleDate: endDate))
            await endDuplicates(in: activities, keeping: activity.id)
            scheduleExpiration(at: endDate)
        }
    }

    static func end() {
        expirationTask?.cancel()
        expirationTask = nil
        enqueue {
            // A previously queued update may have installed another expiry task
            // after the eager cancellation above.
            expirationTask?.cancel()
            expirationTask = nil
            await endAllActivities()
        }
    }

    /// Cleans up expired and duplicate activities on launch/foreground while
    /// preserving the newest still-running timer for subsequent update/end.
    static func reconcile(at date: Date = Date()) {
        expirationTask?.cancel()
        expirationTask = nil
        enqueue {
            expirationTask?.cancel()
            expirationTask = nil
            let activities = Activity<RestActivityAttributes>.activities
            let running = activities.filter { $0.content.state.endDate > date }
            let keeper = canonicalActivity(in: running)
            for activity in activities where activity.id != keeper?.id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            if let keeper {
                scheduleExpiration(at: keeper.content.state.endDate)
            }
        }
    }

    /// Ends the activity on time while the process is runnable. If iOS has
    /// suspended or terminated the app, `staleDate` still flips the widget to
    /// its truthful completed presentation and foreground reconciliation
    /// removes it at the next opportunity.
    private static func scheduleExpiration(at endDate: Date) {
        expirationTask?.cancel()
        expirationTask = Task { @MainActor in
            let delay = max(0, endDate.timeIntervalSinceNow)
            if delay > 0 {
                let nanoseconds = delay * 1_000_000_000
                // A restored/corrupt draft can contain an implausibly distant
                // date. Converting an out-of-range Double to UInt64 traps, so
                // leave foreground reconciliation to clean that case up.
                guard nanoseconds.isFinite,
                      nanoseconds < Double(UInt64.max) else { return }
                do {
                    try await Task.sleep(nanoseconds: UInt64(nanoseconds))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            for activity in Activity<RestActivityAttributes>.activities
            where activity.content.state.endDate <= Date() {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            expirationTask = nil
        }
    }

    private static func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = pendingOperation
        pendingOperation = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }

    private static func canonicalActivity(
        in activities: [Activity<RestActivityAttributes>]
    ) -> Activity<RestActivityAttributes>? {
        activities.max { lhs, rhs in
            lhs.content.state.endDate < rhs.content.state.endDate
        }
    }

    private static func normalizedExerciseName(_ name: String?) -> String {
        meaningfulExerciseName(name) ?? fallbackExerciseName
    }

    private static func meaningfulExerciseName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func endDuplicates(
        in activities: [Activity<RestActivityAttributes>],
        keeping activityID: String
    ) async {
        for activity in activities where activity.id != activityID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func endAllActivities() async {
        for activity in Activity<RestActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
