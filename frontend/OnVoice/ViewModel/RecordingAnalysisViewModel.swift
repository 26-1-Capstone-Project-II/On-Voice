//
//  RecordingAnalysisViewModel.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//
//  분석 작업은 detached Task 로 띄워 view lifecycle 의 .task cancel 영향에서
//  벗어나게 한다. AnalysisSummaryView 가 push/pop 으로 잠시 사라지더라도 Whisper
//  추론은 끊김 없이 끝까지 진행되고, 화면이 돌아오면 같은 Task 의 결과를
//  await 해 즉시 사용한다.
//

import Combine
import Foundation

@MainActor
final class RecordingAnalysisViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var analysis: AnalysisResult?

    let recording: Recording

    private let analysisService: SpeechAnalysisService
    private var analysisTask: Task<AnalysisResult, Never>?

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

    var isPronunciationEvaluationAvailable: Bool {
        analysis?.isPronunciationEvaluationAvailable ?? false
    }

    var errorSentences: [AnalysisSentence] {
        analysis?.errorSentences ?? []
    }

    var sentences: [AnalysisSentence] {
        analysis?.sentences ?? []
    }

    func loadIfNeeded() async {
        if analysis != nil { return }

        let task = startAnalysisIfNeeded()

        // Task<_, Never>.value 는 non-throwing 이라 view 의 .task cancel 이 와도
        // 분석을 중단하지 않고 그대로 끝까지 기다린다. detached 라 cancel 전파도 없음.
        let result = await task.value

        if analysis == nil {
            analysis = result
        }
        isLoading = false
    }

    private func startAnalysisIfNeeded() -> Task<AnalysisResult, Never> {
        if let analysisTask { return analysisTask }

        isLoading = true
        let url = recording.fileURL
        let service = analysisService
        let task = Task.detached(priority: .userInitiated) {
            await service.analyze(url: url, referenceText: nil)
        }
        analysisTask = task
        return task
    }
}
