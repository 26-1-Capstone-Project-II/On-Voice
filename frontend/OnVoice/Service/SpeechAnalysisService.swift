//
//  SpeechAnalysisService.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//
//  발음 오류 검출 파이프라인의 오케스트레이터.
//   ┌─────────────────────────────────────────┐
//   │ 1) 동일 오디오를 두 모델에 동시 입력           │
//   │    ├─ Apple ASR(SFSpeechRecognizer)       │  → "의도된 표기"
//   │    └─ Whisper(파인튜닝 CoreML)              │  → "소리 그대로 실제 발음"
//   │ 2) Apple 결과 → G2P → 기대 발음              │
//   │ 3) 기대 발음 vs Whisper 발음 자모 정렬        │
//   │ 4) 오류 어절/오류 유형을 scriptAnalysis 에 채움 │
//   └─────────────────────────────────────────┘
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.onvoice", category: "speech-analysis")

final class SpeechAnalysisService {
    private let phoneticService: WhisperPhoneticTranscriptionService
    private let intentService: AppleSpeechTranscriptionService
    private let scriptAnalyzer: PronunciationScriptAnalyzing

    init(
        phoneticService: WhisperPhoneticTranscriptionService = .shared,
        intentService: AppleSpeechTranscriptionService = AppleSpeechTranscriptionService(),
        scriptAnalyzer: PronunciationScriptAnalyzing = PronunciationScriptAnalysisService()
    ) {
        self.phoneticService = phoneticService
        self.intentService = intentService
        self.scriptAnalyzer = scriptAnalyzer
    }

    func analyze(url: URL, referenceText: String? = nil) async -> AnalysisResult {
        // Apple ASR 권한 요청. 거부 상태면 transcribe 가 빈 결과를 돌려주고
        // intentText 가 nil 로 처리되어 G2P 비교만 비활성화된다(전사는 그대로 표시).
        await intentService.requestAuthorizationIfNeeded()

        // 두 모델을 동시에 돌린다. Apple 은 자동 교정된 "의도 텍스트", Whisper 는
        // 발음 그대로의 phonetic 전사 — 두 결과를 자모 정렬해 오류를 찾는다.
        async let phoneticTask = phoneticService.transcribe(url: url)
        async let appleTask = intentService.transcribe(url: url)

        let phoneticResult = await phoneticTask
        let (appleText, _) = await appleTask

        switch phoneticResult {
        case let .success(transcription):
            let rawScript = PronunciationErrorScript.makePlainScript(from: transcription.segments)

            // referenceText 가 명시되면(미래의 스크립트 모드) 그것을 우선, 아니면
            // Apple ASR 결과를 의도 텍스트로 사용한다.
            let resolvedIntent: String? = {
                if let referenceText, !referenceText.isEmpty { return referenceText }
                return appleText.isEmpty ? nil : appleText
            }()

            let limitation = resolveLimitation(intentText: resolvedIntent)
            logLimitation(limitation)

            let analyzedScript = await scriptAnalyzer.analyze(
                phoneticScript: rawScript,
                intentText: resolvedIntent
            )

            return AnalysisResult(
                transcript: transcription.fullText,
                standardText: resolvedIntent ?? "",
                standardPronunciation: "",
                sentences: [],
                overallAccuracy: 0,
                isPronunciationEvaluationAvailable: false,
                scriptAnalysis: analyzedScript,
                transcriptionFailure: nil,
                limitation: limitation
            )

        case let .failure(failure):
            return AnalysisResult(
                transcript: "",
                standardText: referenceText ?? "",
                standardPronunciation: "",
                sentences: [],
                overallAccuracy: 0,
                isPronunciationEvaluationAvailable: false,
                scriptAnalysis: .empty,
                transcriptionFailure: failure,
                limitation: nil
            )
        }
    }

    // MARK: - Limitation helpers

    /// 권한 거부 / 빈 결과 / 정상의 세 갈래를 분리해 사유를 명확히 한다.
    /// UI 는 두 limitation 케이스를 동일한 배너로 안내하지만, 로그/지원은 분기를 보존.
    private func resolveLimitation(intentText: String?) -> AnalysisLimitation? {
        guard intentText == nil else { return nil }
        if intentService.authorizationStatus != .authorized {
            return .speechAuthorizationDenied
        }
        return .intentTextEmpty
    }

    private func logLimitation(_ limitation: AnalysisLimitation?) {
        switch limitation {
        case .speechAuthorizationDenied:
            logger.error("Speech recognition not authorized — pronunciation comparison disabled")
        case .intentTextEmpty:
            logger.info("Apple ASR returned empty intent text — pronunciation comparison disabled")
        case .none:
            break
        }
    }
}
