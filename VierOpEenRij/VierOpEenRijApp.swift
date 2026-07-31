import SwiftUI

@main
struct VierOpEenRijApp: App {
    @State private var profileStore = ProfileStore()
    @State private var gameStore = GameStore()
    @State private var entitlements = EntitlementStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(profileStore)
                .environment(gameStore)
                .environment(entitlements)
                .appMetrics()
        }
    }
}
