import Foundation

enum VoiceVolumeLevel: String, Codable, Hashable {
    case low
    case medium
    case high
    case idle
}

struct VoiceVolumeThresholds: Equatable {
    let low: Int
    let high: Int

    static let loudTalking = VoiceVolumeThresholds(low: 58, high: 80)

    var isValid: Bool {
        low >= 0 && high > low
    }
}

enum VoiceVolumeStateCalculator {
    static func level(
        for decibels: Float,
        isMeasuring: Bool,
        thresholds: VoiceVolumeThresholds?
    ) -> VoiceVolumeLevel {
        guard isMeasuring, let thresholds = sanitized(thresholds) else {
            return .idle
        }

        let decibelValue = Double(clampedDecibels(decibels))

        if decibelValue > Double(thresholds.high) {
            return .high
        }

        if decibelValue > Double(thresholds.low) {
            return .medium
        }

        return .low
    }

    static func progress(for decibels: Float) -> Int {
        let normalizedDecibels = min(max(decibels / 120.0, 0.0), 1.0)
        return Int(normalizedDecibels * 100)
    }

    static func clampedDecibels(_ decibels: Float) -> Int {
        Int(min(max(decibels, 0), 120))
    }

    static func calibratedDecibels(from dbFS: Float) -> Float {
        let referenceLevel: Float = 94.0
        let dbSPL = dbFS + referenceLevel
        return max(min(max(dbSPL, 0.0), 120.0) - 10, 0)
    }

    static func sanitized(_ thresholds: VoiceVolumeThresholds?) -> VoiceVolumeThresholds? {
        guard let thresholds, thresholds.isValid else {
            return nil
        }

        return thresholds
    }
}
