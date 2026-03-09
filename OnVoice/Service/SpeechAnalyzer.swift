//
//  SpeechAnalyzer.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/25/25.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class SpeechAnalyzer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    // Practice state
    @Published var isRecording: Bool = false
    @Published var practiceCount: Int = 0
    @Published var recognizedText: String = ""
    @Published var currentAccuracy: Double = 0.0  // 0~100

    // 목표 달성 여부 (80% 이상)
    var hasReachedTarget: Bool { currentAccuracy >= 80.0 }

    // 4회 연습 완료 여부
    var hasCompletedFourAttempts: Bool { practiceCount >= 4 }

    // 연습 가능 여부 (목표 달성하지 않았으면 계속 연습 가능)
    var canPractice: Bool { !hasReachedTarget }

    // Audio/TTS
    private var recorder: AVAudioRecorder?
    private let synthesizer = AVSpeechSynthesizer()
    private let assessmentService: PronunciationAssessmentService
    private var practiceTargetText: String = ""

    init(assessmentService: PronunciationAssessmentService = PronunciationAssessmentService()) {
        self.assessmentService = assessmentService
        super.init()
        synthesizer.delegate = self
    }

    func resetPractice() {
        isRecording = false
        practiceCount = 0
        recognizedText = ""
        currentAccuracy = 0.0
        stopTTSIfNeeded()
        stopRecorderIfNeeded()
    }

    // MARK: - Flow: TTS → 3초 → 녹음
    func startPronunciationPractice(standardPronunciation: String) async {
        // 연습 가능한 상태인지 확인
        guard canPractice else { return }

        practiceTargetText = standardPronunciation
        speakStandard(standardPronunciation)
        // TTS 시작 후 3초 대기 → 녹음 시작
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await startRecording()
    }

    // MARK: - Recording
    private func startRecording() async {
        guard !isRecording && canPractice else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            let url = recordingURL()
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            isRecording = true
        } catch {
            print("Record start error:", error)
        }
    }

    func stopRecording() async {
        guard isRecording else { return }
        recorder?.stop()
        isRecording = false
        practiceCount += 1

        // STT → 정확도 계산
        let url = recorder?.url ?? recordingURL()
        let assessment = await assessmentService.evaluatePractice(
            recordingURL: url,
            standardText: practiceTargetText
        )
        recognizedText = assessment.recognizedText
        currentAccuracy = assessment.accuracy
    }

    private func stopRecorderIfNeeded() {
        if recorder?.isRecording == true { recorder?.stop() }
        recorder = nil
    }

    // MARK: - TTS (개인 음성 우선)
    private func speakStandard(_ text: String) {
        stopTTSIfNeeded()
        let utter = AVSpeechUtterance(string: text)
        // 개인 음성이 세팅되어 있다면 사용(식별자 저장 방식 예시)
        if let id = UserDefaults.standard.string(forKey: "personal_voice_id"),
           let pv = AVSpeechSynthesisVoice(identifier: id) {
            utter.voice = pv
        } else {
            utter.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        }
        utter.rate = 0.48
        synthesizer.speak(utter)
    }

    private func stopTTSIfNeeded() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    private func recordingURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("practice-\(UUID().uuidString).m4a")
    }
}
