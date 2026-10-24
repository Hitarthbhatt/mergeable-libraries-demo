import Foundation

public protocol AnalyticsTracking {
    func track(_ event: String, properties: [String: String])
}

public final class ConsoleAnalytics: AnalyticsTracking {
    public static let shared = ConsoleAnalytics()

    private init() {}

    public func track(_ event: String, properties: [String: String] = [:]) {
        print("[analytics] \(event) \(properties)")
    }
}
