import SwiftUI

@main
struct JetWIFIApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onAppear { state.bootstrap() }
        }
    }
}
