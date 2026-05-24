//
//  SpeechAnalysisService.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Foundation

final class SpeechAnalysisService {
    private let transcriptionService: WhisperPhoneticTranscriptionService
    private let scriptAnalyzer: PronunciationScriptAnalyzing

    init(
        transcriptionService: WhisperPhoneticTranscriptionService = .shared,
        scriptAnalyzer: PronunciationScriptAnalyzing = PronunciationScriptAnalysisService()
    ) {
        self.transcriptionService = transcriptionService
        self.scriptAnalyzer = scriptAnalyzer
    }

    func analyze(url: URL, referenceText: String? = nil) async -> AnalysisResult {
        // 1) 소리나는 대로 전사 (segment 단위로 받아 원본 UI의 다문단 구조 유지)
        //    실패 케이스는 .failure(TranscriptionFailure)로 명시 전달되어 UI가
        //    빈 결과와 실패 상태를 구분해 표시할 수 있도록 한다.
        let transcriptionResult = await transcriptionService.transcribe(url: url)

        switch transcriptionResult {
        case let .success(transcription):
            // 2) Whisper segment를 그대로 문단으로 옮긴 raw 스크립트
            let rawScript = PronunciationErrorScript.makePlainScript(from: transcription.segments)

            // 3) 분석 단계: 현재는 stub(no-op)이며 2단계 구현 후 errorDetail이 채워진다.
            let analyzedScript = await scriptAnalyzer.analyze(
                script: rawScript,
                referenceText: referenceText
            )

            return AnalysisResult(
                transcript: transcription.fullText,
                standardText: referenceText ?? "",
                standardPronunciation: "",
                sentences: [],
                overallAccuracy: 0,
                isPronunciationEvaluationAvailable: false,
                scriptAnalysis: analyzedScript,
                transcriptionFailure: nil
            )

        case let .failure(failure):
            // 전사 파이프라인 자체가 실패한 경우. 스크립트는 비워두고 실패 사유만
            // 상위로 전달한다. UI는 transcriptionFailure를 보고 빈 결과 vs 실패를 구분한다.
            return AnalysisResult(
                transcript: "",
                standardText: referenceText ?? "",
                standardPronunciation: "",
                sentences: [],
                overallAccuracy: 0,
                isPronunciationEvaluationAvailable: false,
                scriptAnalysis: .empty,
                transcriptionFailure: failure
            )
        }
    }
}
