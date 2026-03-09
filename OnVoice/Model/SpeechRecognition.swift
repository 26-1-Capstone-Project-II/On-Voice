//
//  SpeechRecognition.swift
//  OnVoice
//
//  Created by Lee YunJi on 8/11/25.
//

import Combine
import Foundation

@MainActor
final class SpeechRecognition: ObservableObject {
    @Published var appleTranscript: String = ""
    @Published var standardText: String = ""
    @Published var sentences: [SentenceComparison] = []
    @Published var overallAccuracy: Double = 0.0
    @Published var errorSentences: [SentenceComparison] = []

    private let analysisService: SpeechAnalysisService

    init(analysisService: SpeechAnalysisService = SpeechAnalysisService()) {
        self.analysisService = analysisService
    }

    func analyze(url: URL, referenceText: String? = nil) async {
        let result = await analysisService.analyze(url: url, referenceText: referenceText)
        appleTranscript = result.appleTranscript
        standardText = result.standardText
        sentences = result.sentences
        overallAccuracy = result.overallAccuracy
        errorSentences = result.errorSentences
    }
}

struct WordPiece: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isError: Bool
}

struct SentenceComparison: Identifiable {
    let id = UUID()
    let index: Int
    let reference: String
    let standardPronunciation: String
    let hypothesis: String
    let referencePieces: [WordPiece]
    let hypothesisPieces: [WordPiece]
    let accuracy: Double
    let isCorrect: Bool
}
