import SwiftUI

@main
struct FRPGMVPApp: App {
    // One AppState for the app lifetime, owned here. Multiple scenes remain
    // disabled until active-session drafts and timers are scene-scoped; all
    // persistence still serializes through AppState's save queue.
    @StateObject private var state = AppState.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Serif navigation titles — part of the app's fantasy identity.
        RPGTheme.configureChrome()
        // Reclaim or retire Live Activities that survived process termination,
        // and seed the widget for existing users before their next mutation.
        RestLiveActivity.reconcile()
        WidgetBridge.publish(user: AppState.shared.user)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            RestLiveActivity.reconcile()
            WidgetBridge.publish(user: state.user)
        }
    }
}
