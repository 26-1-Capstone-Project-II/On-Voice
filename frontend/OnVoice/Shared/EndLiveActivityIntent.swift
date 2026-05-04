import AppIntents

struct EndLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Live Activity"

    func perform() async throws -> some IntentResult {
        await RecordingSessionController.shared.terminateActiveSession()
        return .result()
    }
}

@available(*, deprecated)
extension EndLiveActivityIntent {
    static var openAppWhenRun: Bool { false }
}
