import AVFoundation
import SwiftUI

@Observable
final class WatchNoiseMeter {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    var decibels: Float = 0
    var errorMessage: String?

    var isMeasuring: Bool {
        timer != nil
    }

    @MainActor
    func toggleMetering() async {
        if isMeasuring {
            stopMetering()
        } else {
            await startMetering()
        }
    }

    @MainActor
    func startMetering() async {
        errorMessage = nil

        do {
            try configureAudioSession()
            let recorder = try makeRecorder()
            recorder.isMeteringEnabled = true
            recorder.record()
            audioRecorder = recorder

            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, let audioRecorder = self.audioRecorder else { return }
                audioRecorder.updateMeters()
                decibels = VoiceVolumeStateCalculator.calibratedDecibels(
                    from: audioRecorder.averagePower(forChannel: 0)
                )
            }
        } catch {
            errorMessage = "마이크를 사용할 수 없어요."
            stopMetering()
        }
    }

    @MainActor
    func stopMetering() {
        audioRecorder?.stop()
        audioRecorder = nil
        timer?.invalidate()
        timer = nil

        withAnimation(.easeOut(duration: 0.35)) {
            decibels = 0
        }

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
    }

    private func makeRecorder() throws -> AVAudioRecorder {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch_voice_meter.m4a")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        return try AVAudioRecorder(url: url, settings: settings)
    }
}
