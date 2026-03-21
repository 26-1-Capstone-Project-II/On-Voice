//
//  PronunciationPracticeViewModel.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Combine
import Foundation

@MainActor
final class PronunciationPracticeViewModel: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var practiceCount = 0
    @Published private(set) var recognizedText = ""
    @Published private(set) var currentAccuracy = 0.0

    private let analyzer: SpeechAnalyzer

    init(analyzer: SpeechAnalyzer) {
        self.analyzer = analyzer

        analyzer.$isRecording
            .receive(on: RunLoop.main)
            .assign(to: &$isRecording)
        analyzer.$practiceCount
            .receive(on: RunLoop.main)
            .assign(to: &$practiceCount)
        analyzer.$recognizedText
            .receive(on: RunLoop.main)
            .assign(to: &$recognizedText)
        analyzer.$currentAccuracy
            .receive(on: RunLoop.main)
            .assign(to: &$currentAccuracy)
    }

    var hasReachedTarget: Bool {
        analyzer.hasReachedTarget
    }

    var hasCompletedFourAttempts: Bool {
        analyzer.hasCompletedFourAttempts
    }

    func startPractice(standardPronunciation: String) async {
        await analyzer.startPronunciationPractice(standardPronunciation: standardPronunciation)
    }

    func stopRecording() async {
        await analyzer.stopRecording()
    }

    func resetPractice() {
        analyzer.resetPractice()
    }
}

extension PronunciationPracticeViewModel {
    convenience init() {
        self.init(analyzer: SpeechAnalyzer())
    }
}
