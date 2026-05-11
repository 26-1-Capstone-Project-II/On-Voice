import Foundation

enum OnVoiceLiveActivityState {
    struct Thresholds: Equatable {
        let low: Int
        let high: Int

        var isValid: Bool {
            low >= 0 && high > low
        }

        var voiceVolumeThresholds: VoiceVolumeThresholds {
            VoiceVolumeThresholds(low: low, high: high)
        }
    }

    static func makeContentState(
        decibels: Float,
        isMeasuring: Bool,
        title: String?,
        thresholds: Thresholds?
    ) -> OnVoiceLiveActivityAttributes.ContentState {
        let sanitizedThresholds = sanitized(thresholds)

        return OnVoiceLiveActivityAttributes.ContentState(
            decibels: VoiceVolumeStateCalculator.clampedDecibels(decibels),
            level: level(
                for: decibels,
                isMeasuring: isMeasuring,
                thresholds: sanitizedThresholds
            ),
            progress: VoiceVolumeStateCalculator.progress(for: decibels),
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            lowThreshold: sanitizedThresholds?.low ?? 0,
            highThreshold: sanitizedThresholds?.high ?? 0
        )
    }

    static func level(
        for decibels: Float,
        isMeasuring: Bool,
        thresholds: Thresholds?
    ) -> OnVoiceLiveActivityAttributes.Level {
        let volumeLevel = VoiceVolumeStateCalculator.level(
            for: decibels,
            isMeasuring: isMeasuring,
            thresholds: sanitized(thresholds)?.voiceVolumeThresholds
        )
        return OnVoiceLiveActivityAttributes.Level(volumeLevel)
    }

    static func interpolationPhase(
        for state: OnVoiceLiveActivityAttributes.ContentState
    ) -> Double {
        guard state.level != .idle else { return 0 }

        guard let thresholds = sanitized(
            Thresholds(low: state.lowThreshold, high: state.highThreshold)
        ) else {
            return fallbackPhase(for: state.level)
        }

        let decibels = Double(state.decibels)
        let low = Double(thresholds.low)
        let high = Double(thresholds.high)
        let transitionWidth = 8.0
        let halfTransition = transitionWidth / 2

        let lowTransitionStart = low - halfTransition
        let lowTransitionEnd = low + halfTransition
        let highTransitionStart = high - halfTransition
        let highTransitionEnd = high + halfTransition

        if decibels <= lowTransitionStart {
            return 0
        }

        if decibels < lowTransitionEnd {
            let fraction = (decibels - lowTransitionStart) / transitionWidth
            return smoothStep(fraction) * 0.5
        }

        if decibels <= highTransitionStart {
            return 0.5
        }

        if decibels < highTransitionEnd {
            let fraction = (decibels - highTransitionStart) / transitionWidth
            return 0.5 + smoothStep(fraction) * 0.5
        }

        return 1.0
    }

    static func fallbackPhase(
        for level: OnVoiceLiveActivityAttributes.Level
    ) -> Double {
        switch level {
        case .low:
            return 0
        case .medium:
            return 0.5
        case .high:
            return 1
        case .idle:
            return 0
        }
    }

    static func progress(for decibels: Float) -> Int {
        VoiceVolumeStateCalculator.progress(for: decibels)
    }

    private static func sanitized(_ thresholds: Thresholds?) -> Thresholds? {
        guard let thresholds, thresholds.isValid else {
            return nil
        }

        return thresholds
    }

    private static func smoothStep(_ value: Double) -> Double {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue * clampedValue * (3 - 2 * clampedValue)
    }
}

private extension OnVoiceLiveActivityAttributes.Level {
    init(_ volumeLevel: VoiceVolumeLevel) {
        switch volumeLevel {
        case .low:
            self = .low
        case .medium:
            self = .medium
        case .high:
            self = .high
        case .idle:
            self = .idle
        }
    }
}
