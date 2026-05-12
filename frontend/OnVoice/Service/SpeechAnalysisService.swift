//
//  SpeechAnalysisService.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Foundation

final class SpeechAnalysisService {
    func analyze(url: URL, referenceText: String? = nil) async -> AnalysisResult {
        AnalysisResult(
            transcript: "",
            standardText: referenceText ?? "",
            standardPronunciation: "",
            sentences: [],
            overallAccuracy: 0,
            isPronunciationEvaluationAvailable: false
        )
    }
}
