import ActivityKit
import Foundation

struct OnVoiceLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let decibels: Int
        let level: Level
        let progress: Int
        let title: String
        let lowThreshold: Int
        let highThreshold: Int
    }

    enum Level: String, Codable, Hashable {
        case low
        case medium
        case high
        case idle
    }

    let name: String
}
