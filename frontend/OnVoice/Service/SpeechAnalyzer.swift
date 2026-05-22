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
    @Published var isEvaluationAvailable: Bool = false

    // 목표 달성 여부 (80% 이상)
    var hasReachedTarget: Bool { isEvaluationAvailable && currentAccuracy >= 80.0 }

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
        isEvaluationAvailable = false
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

    // 마이크 입력 파이프라인이 안정화되기 전 구간이 모델에 들어가지 않도록 두는 슬립.
    private static let warmupDelay: TimeInterval = 0.15

    private func startRecording() async {
        guard !isRecording && canPractice else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            // 발음 평가 입력에는 시스템 신호처리(AGC/AEC/NS)를 끄는 .measurement 모드를 사용한다.
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setPreferredSampleRate(16000)
            try session.setActive(true)
            let url = recordingURL()
            // Whisper 발음 평가 모델과 동일한 16 kHz mono 16-bit PCM로 녹음한다.
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.prepareToRecord()
            recorder = newRecorder

            try? await Task.sleep(nanoseconds: UInt64(Self.warmupDelay * 1_000_000_000))

            // 워밍업 슬립 동안 stop이 호출돼 recorder가 정리됐다면 record()를 호출하지 않는다.
            guard let recorder = self.recorder, recorder === newRecorder else { return }
            recorder.record()
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
        isEvaluationAvailable = assessment.isEvaluationAvailable
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
        return dir.appendingPathComponent("practice-\(UUID().uuidString).wav")
    }
}
