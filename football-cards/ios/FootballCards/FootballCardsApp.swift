import SwiftUI

@main
struct FootballCardsApp: App {
    @StateObject private var session = FootballSessionViewModel()

    var body: some Scene {
        WindowGroup {
            FootballRootView()
                .environmentObject(session)
        }
    }
}