//
//  AnalysisModels.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Foundation

struct AnalysisWordPiece: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isError: Bool
}

struct AnalysisSentence: Identifiable {
    let id = UUID()
    let index: Int
    let referenceText: String
    let standardPronunciation: String
    let spokenText: String
    let referencePieces: [AnalysisWordPiece]
    let spokenPieces: [AnalysisWordPiece]
    let accuracy: Double
    let isCorrect: Bool
}

struct AnalysisResult {
    let transcript: String
    let standardText: String
    let standardPronunciation: String
    let sentences: [AnalysisSentence]
    let overallAccuracy: Double
    let isPronunciationEvaluationAvailable: Bool
    let scriptAnalysis: PronunciationErrorScript

    init(
        transcript: String,
        standardText: String,
        standardPronunciation: String,
        sentences: [AnalysisSentence],
        overallAccuracy: Double,
        isPronunciationEvaluationAvailable: Bool,
        scriptAnalysis: PronunciationErrorScript = .empty
    ) {
        self.transcript = transcript
        self.standardText = standardText
        self.standardPronunciation = standardPronunciation
        self.sentences = sentences
        self.overallAccuracy = overallAccuracy
        self.isPronunciationEvaluationAvailable = isPronunciationEvaluationAvailable
        self.scriptAnalysis = scriptAnalysis
    }

    var errorSentences: [AnalysisSentence] {
        guard isPronunciationEvaluationAvailable else { return [] }
        return sentences.filter { $0.accuracy < 0.8 }
    }
}

struct PracticeEvaluationResult {
    let recognizedText: String
    let accuracy: Double
    let isEvaluationAvailable: Bool
}
