import CoreKit
import SwiftUI

public struct ProfileView: View {
    private let user = Model00(id: "1", title: "Jane", subtitle: "Appleseed", imageURL: "",
                               price: 0, quantity: 0, isActive: true, createdAt: 0)

    public init() {}

    public var body: some View {
        VStack(spacing: Theme.spacing) {
            Text(user.displayTitle).font(.title2.bold())
            Text("\(CoreKitCatalog.touchEverything()) shared things in CoreKit")
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear { ConsoleAnalytics.shared.track(AnalyticsEvent.Profile.event00) }
    }
}
