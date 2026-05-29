//
//  ErrorSentencePracticeViewModel.swift
//  OnVoice
//
//  오류 문장 재연습(이슈 #117) 화면의 녹음·재분석·난이도 피드백 상태를 관리한다.
//
//  흐름: 마이크 탭으로 녹음 시작 → 다시 탭하면 종료 후 자동 재분석.
//  재분석은 Apple ASR 을 다시 돌리지 않고, 원본 문장의 표기 텍스트(referenceText)를
//  intent 로 재사용해 Whisper phonetic 결과와 자모 정렬한다. 원본 attempt 와 새 attempt 를
//  같은 referenceText 좌표계로 정렬하면 expected 음절 인덱스가 일치하므로,
//  RepracticeColorizer 가 빨강(여전히 틀림)/파랑(교정됨)을 안전하게 구분한다.
//
//  녹음 파일은 temporaryDirectory 에 쓰고 분석 직후 삭제한다. AudioRecorder.shared 가
//  스캔하는 Documents 폴더를 쓰지 않아 연습 녹음이 라이브러리에 노출되지 않는다.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class ErrorSentencePracticeViewModel: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isAnalyzing = false
    /// 재연습 시도들. 가장 최근 시도가 마지막 원소. 문장을 바꾸면 reset() 으로 비운다.
    @Published private(set) var attempts: [PronunciationPracticeAttempt] = []
    /// 마지막 시도에서 빨강·누락 음절이 하나도 없어 문장 전체를 성공한 상태.
    @Published private(set) var isFullSuccess = false
    /// 직전 재분석이 전사 실패(무음/모델 누락 등)로 끝났는지. attempt 는 추가되지 않는다.
    @Published private(set) var analysisFailed = false
    /// 문장별 난이도 피드백(메모리 only). 문장 전환에도 유지돼 다시 돌아오면 잠금이 보인다.
    @Published private(set) var difficultyBySentence: [UUID: PracticeDifficulty] = [:]

    private let analyzer: PronunciationScriptAnalyzing
    private var recorder: AVAudioRecorder?
    /// SpeechAnalyzer 와 동일: 워밍업 슬립 도중 stop/새 start/reset 이 끼면 record() 무효화.
    private var pendingStartToken: UUID?
    /// 아직 교정하지 못한 평가 대상(원래 오류 음절의 expected 인덱스). 시도를 거치며 줄어든다.
    ///
    /// 생명주기: 선택된 한 문장의 재연습 세션 동안에만 의미를 가진다. nil = 아직 첫 재분석 전
    /// (다음 재분석에서 원래 오류 집합으로 초기화). 시도마다 교정분(correctedExpectedIndices)을
    /// 빼서 줄이고, 비면 isFullSuccess=true 가 되어 난이도 버튼으로 전환된다. 문장 전환/해제 시
    /// reset() 에서 nil 로 되돌린다 — 다른 문장/세션으로 이어지지 않는다.
    private var remainingTargets: Set<Int>?
    /// 재분석 무효화 토큰. reset()(문장 전환/해제) 마다 증가시켜, 진행 중이던 옛 재분석 Task 가
    /// 늦게 끝나도 결과를 다른 문장 상태에 잘못 적용하지 않게 한다(RecordingAnalysisViewModel 패턴).
    private var analysisGeneration = 0

    private static let warmupDelay: TimeInterval = 0.15

    init(analyzer: PronunciationScriptAnalyzing = PronunciationScriptAnalysisService()) {
        self.analyzer = analyzer
    }

    func selectedDifficulty(for sentenceID: UUID) -> PracticeDifficulty? {
        difficultyBySentence[sentenceID]
    }

    /// 난이도 버튼은 한 번 고르면 잠긴다(재선택 불가). 이미 고른 문장은 무시한다.
    func selectDifficulty(_ difficulty: PracticeDifficulty, for sentenceID: UUID) {
        guard difficultyBySentence[sentenceID] == nil else { return }
        difficultyBySentence[sentenceID] = difficulty
    }

    // MARK: - Recording

    func start() async {
        guard !isRecording, !isAnalyzing else { return }
        analysisFailed = false

        let session = AVAudioSession.sharedInstance()
        do {
            // Whisper(파인튜닝) 입력 가정에 맞춰 시스템 신호처리를 끄는 .measurement 모드.
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setPreferredSampleRate(16000)
            try session.setActive(true)

            let url = makeRecordingURL()
            // Whisper 발음 모델과 동일한 16 kHz mono 16-bit PCM.
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

            let token = UUID()
            pendingStartToken = token

            try? await Task.sleep(nanoseconds: UInt64(Self.warmupDelay * 1_000_000_000))

            guard pendingStartToken == token else { return }
            guard let recorder, recorder === newRecorder else { return }
            recorder.record()
            isRecording = true
            pendingStartToken = nil
        } catch {
            print("재연습 녹음 시작 실패: \(error)")
        }
    }

    /// 녹음을 멈추고 새 발화를 재분석해 색칠된 attempt 를 추가한다.
    /// - referenceText: 원본 문장의 표기 텍스트(intent).
    /// - originalAttemptText: 원본 attempt 의 phonetic 전사.
    /// - sentenceID: 성공 시 난이도 잠금을 그 문장에 묶기 위한 식별자(현재는 attempt 만 사용).
    func stopAndAnalyze(referenceText: String, originalAttemptText: String) async {
        pendingStartToken = nil
        guard isRecording, let recorder else { return }

        recorder.stop()
        isRecording = false
        let url = recorder.url
        self.recorder = nil

        guard !referenceText.trimmingCharacters(in: .whitespaces).isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }

        isAnalyzing = true
        analysisFailed = false
        // 이 재분석 cycle 의 세대. reset() 이 끼어들어 세대가 바뀌면 결과를 적용하지 않는다.
        let generation = analysisGeneration
        defer { if generation == analysisGeneration { isAnalyzing = false } }

        let result = await WhisperPhoneticTranscriptionService.shared.transcribe(url: url)
        try? FileManager.default.removeItem(at: url)

        // 전사를 기다리는 동안 문장 전환/해제(reset)가 일어났으면 stale 이므로 중단.
        guard generation == analysisGeneration else { return }

        switch result {
        case let .success(transcription):
            let newHypText = transcription.fullText

            // 두 정렬 모두 같은 referenceText 좌표계 → expected 인덱스가 일치한다.
            // 단일 문장(짧은 음절열) 정렬이라 순차 await 비용은 무시할 수준이다.
            let newArtifacts = await analyzer.analyzeArtifacts(
                phoneticScript: Self.singleSegmentScript(newHypText),
                intentText: referenceText
            )
            let originalArtifacts = await analyzer.analyzeArtifacts(
                phoneticScript: Self.singleSegmentScript(originalAttemptText),
                intentText: referenceText
            )

            // analyzeArtifacts await 동안에도 reset 이 끼어들 수 있어, 상태 적용 직전 한 번 더 확인.
            guard generation == analysisGeneration else { return }

            let originalErrors = RepracticeColorizer.errorExpectedIndices(
                cells: originalArtifacts.cells
            )
            // 첫 재분석이면 원래 오류 전체가 평가 대상. 이후 시도는 누적 교정분만큼 줄어든 집합을 쓴다.
            let remaining = remainingTargets ?? originalErrors
            let outcome = RepracticeColorizer.colorize(
                newCells: newArtifacts.cells,
                newHypText: newHypText,
                originalErrorExpectedIndices: originalErrors,
                remainingExpectedIndices: remaining
            )
            remainingTargets = remaining.subtracting(outcome.correctedExpectedIndices)

            attempts.append(PronunciationPracticeAttempt(segments: outcome.segments))
            isFullSuccess = outcome.isFullSuccess

        case .failure:
            analysisFailed = true
        }
    }

    /// 문장 전환/해제 시 호출. 진행 중 녹음을 정리하고 시도/성공 상태를 비운다.
    /// 난이도 피드백(difficultyBySentence)은 문장에 묶여 있어 비우지 않는다.
    func reset() {
        pendingStartToken = nil
        // 진행 중이던 재분석 Task 의 결과가 새 문장 상태에 적용되지 않도록 세대를 올린다.
        analysisGeneration &+= 1
        if recorder?.isRecording == true { recorder?.stop() }
        recorder = nil
        isRecording = false
        isAnalyzing = false
        analysisFailed = false
        attempts = []
        isFullSuccess = false
        remainingTargets = nil
    }

    // MARK: - Helpers

    /// makePlainScript 의 종결어미 문장분할/공백삽입을 우회해 한 문장을 한 세그먼트로 둔다.
    private static func singleSegmentScript(_ text: String) -> PronunciationErrorScript {
        PronunciationErrorScript(
            sentences: [PronunciationTranscriptSentence(segments: [.normal(text)])]
        )
    }

    private func makeRecordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("repractice-\(UUID().uuidString).wav")
    }
}
