import Foundation
import HealthKit

// MARK: - Apple Health writing
//
// Write-only and off by default — the no-account promise extends to "no
// surprise data flows". When enabled, each finished training session is
// saved as one strength-training workout covering the session window.
// RPGFit requests no read access at all.

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    static let enabledKey = "healthKitWorkoutsEnabled"

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Prompts for share-only workout permission. Returns false when Health
    /// is unavailable or the prompt itself fails — the user's actual
    /// grant/deny choice is enforced by HealthKit at save time.
    func requestAuthorization() async -> Bool {
        guard Self.isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
            return true
        } catch {
            return false
        }
    }

    func saveSession(start: Date, end: Date) async {
        guard Self.isAvailable, Self.isEnabled, end > start else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store,
                                       configuration: configuration,
                                       device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            try await builder.finishWorkout()
        } catch {
            // Denied permission or a Health store hiccup — the in-app log is
            // the source of truth either way, so fail quietly.
            #if DEBUG
            print("HealthKit save failed: \(error)")
            #endif
        }
    }
}
