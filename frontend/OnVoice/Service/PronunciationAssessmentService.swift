//
//  PronunciationAssessmentService.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Foundation

final class PronunciationAssessmentService {
    func evaluatePractice(recordingURL: URL, standardText: String) async -> PracticeEvaluationResult {
        PracticeEvaluationResult(
            recognizedText: "",
            accuracy: 0,
            isEvaluationAvailable: false
        )
    }
}
