//
//  RecordingAnalysisViewModel.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Combine
import Foundation

@MainActor
final class RecordingAnalysisViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var analysis: SpeechAnalysisResult?

    let recording: Recording

    private let analysisService: SpeechAnalysisService

    init(
        recording: Recording,
        analysisService: SpeechAnalysisService = SpeechAnalysisService()
    ) {
        self.recording = recording
        self.analysisService = analysisService
    }

    var overallAccuracy: Double {
        analysis?.overallAccuracy ?? 0
    }

    var errorSentences: [SentenceComparison] {
        analysis?.errorSentences ?? []
    }

    var sentences: [SentenceComparison] {
        analysis?.sentences ?? []
    }

    func loadIfNeeded() async {
        guard analysis == nil, !isLoading else { return }

        isLoading = true
        analysis = await analysisService.analyze(url: recording.fileURL, referenceText: nil)
        isLoading = false
    }
}
