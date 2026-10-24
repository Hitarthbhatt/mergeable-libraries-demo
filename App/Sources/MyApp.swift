import CoreKit
import ProfileFeature
import SupportFeature
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ProfileView().tabItem { Label("Profile", systemImage: "person") }
                SupportView().tabItem { Label("Support", systemImage: "questionmark.circle") }
            }
            .tint(Theme.accent)
            .onAppear { ConsoleAnalytics.shared.track(AnalyticsEvent.Home.event00) }
        }
    }
}
