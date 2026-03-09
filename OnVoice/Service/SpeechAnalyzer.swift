//
//  SpeechAnalyzer.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/25/25.
//

import Foundation
import Speech
import AVFoundation

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
    private var standardText: String = ""

    override init() {
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
        
        standardText = standardPronunciation
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
        let url = recorder?.url ?? recordingURL() // fallback
        let hyp = (try? await transcribe(url: url)) ?? ""
        recognizedText = hyp
        currentAccuracy = Self.accuracyPercent(standard: standardText, hypothesis: hyp)
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

    // MARK: - Apple STT
    private func transcribe(url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
            guard let recognizer, recognizer.isAvailable else {
                cont.resume(throwing: NSError(domain: "STT", code: -1))
                return
            }
            let req = SFSpeechURLRecognitionRequest(url: url)
            req.requiresOnDeviceRecognition = false
            recognizer.recognitionTask(with: req) { result, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let result, result.isFinal else { return }
                cont.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }

    // MARK: - Accuracy Calculation
    private static func accuracyPercent(standard: String, hypothesis: String) -> Double {
        let ref = tokenize(standard)
        let hyp = tokenize(hypothesis)
        let matched = lcs(a: ref, b: hyp)
        let denom = max(ref.count, hyp.count, 1)
        return (Double(matched) / Double(denom)) * 100.0
    }

    private static func tokenize(_ s: String) -> [String] {
        s.lowercased()
            .replacingOccurrences(of: "[^ㄱ-ㅎ가-힣0-9a-z\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
    }

    private static func lcs(a: [String], b: [String]) -> Int {
        let n = a.count, m = b.count
        var dp = Array(repeating: Array(repeating: 0, count: m+1), count: n+1)
        for i in 1...n {
            for j in 1...m {
                dp[i][j] = (a[i-1] == b[j-1]) ? dp[i-1][j-1] + 1 : max(dp[i-1][j], dp[i][j-1])
            }
        }
        return dp[n][m]
    }

    private func recordingURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("practice-\(UUID().uuidString).m4a")
    }
}
