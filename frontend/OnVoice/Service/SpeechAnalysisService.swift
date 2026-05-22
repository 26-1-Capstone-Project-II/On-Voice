//
//  SpeechAnalysisService.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Foundation

final class SpeechAnalysisService {
    private let transcriptionService: WhisperPhoneticTranscriptionService

    init(transcriptionService: WhisperPhoneticTranscriptionService = .shared) {
        self.transcriptionService = transcriptionService
    }

    func analyze(url: URL, referenceText: String? = nil) async -> AnalysisResult {
        let transcript = await transcriptionService.transcribe(url: url)
        let script = PronunciationErrorScript.makePlainScript(from: transcript)

        return AnalysisResult(
            transcript: transcript,
            standardText: referenceText ?? "",
            standardPronunciation: "",
            sentences: [],
            overallAccuracy: 0,
            isPronunciationEvaluationAvailable: false,
            scriptAnalysis: script
        )
    }
}
