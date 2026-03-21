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
    @Published var sentences: [AnalysisSentence] = []
    @Published var overallAccuracy: Double = 0.0
    @Published var errorSentences: [AnalysisSentence] = []

    private let analysisService: SpeechAnalysisService

    init(analysisService: SpeechAnalysisService = SpeechAnalysisService()) {
        self.analysisService = analysisService
    }

    func analyze(url: URL, referenceText: String? = nil) async {
        let result = await analysisService.analyze(url: url, referenceText: referenceText)
        appleTranscript = result.transcript
        standardText = result.standardText
        sentences = result.sentences
        overallAccuracy = result.overallAccuracy
        errorSentences = result.errorSentences
    }
}
