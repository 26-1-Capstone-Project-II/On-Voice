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
        let transcription = await transcriptionService.transcribe(url: url)

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
            scriptAnalysis: analyzedScript
        )
    }
}
