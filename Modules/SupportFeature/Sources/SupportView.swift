import CoreKit
import SwiftUI

public struct SupportView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: Theme.spacing) {
            Text("Need help?").font(.title2.bold())
            Button("Contact support") {
                ConsoleAnalytics.shared.track(AnalyticsEvent.Support.event00)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding()
    }
}
