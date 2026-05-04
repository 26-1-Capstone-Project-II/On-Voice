import Foundation

@MainActor
final class RecordingSessionController: ObservableObject {
    static let shared = RecordingSessionController()

    @Published private(set) var terminationCount = 0

    private init() {}

    func terminateActiveSession() async {
        AudioRecorder.shared.stop()
        await NoiseMeter.shared.endLiveActivity()
        terminationCount += 1
    }
}
