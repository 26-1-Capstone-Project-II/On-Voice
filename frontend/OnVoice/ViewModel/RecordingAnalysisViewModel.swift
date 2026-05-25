//
//  RecordingAnalysisViewModel.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//
//  분석 작업은 unstructured Task 로 띄워 view lifecycle 의 .task cancel 영향에서
//  벗어나게 한다. AnalysisSummaryView 가 push/pop 으로 잠시 사라지더라도 Whisper
//  추론은 끊김 없이 끝까지 진행되고, 화면이 돌아오면 같은 Task 의 결과를
//  await 해 즉시 사용한다.
//
//  Unstructured `Task { ... }` 는 SwiftUI .task 와 부모-자식 관계가 아니므로
//  cancel 이 전파되지 않는다. MainActor context 는 그대로 상속하지만 analyze()
//  내부가 nonisolated async / actor 호출 위주라 main thread 를 길게 점유하지
//  않는다. detached 와 달리 actor isolation 이 보존되어 디버깅이 단순하다.
//
//  Task lifecycle 정책:
//   - analysis(결과) / analysisTask(진행 중 작업) / loadGeneration(invalidate 토큰)
//     셋을 분리해 관리한다.
//   - invalidate() 시 loadGeneration 을 증가시키고 analysis/analysisTask 를 비운다.
//   - 진행 중이던 옛 task 가 끝나서 결과가 도착해도, 토큰이 바뀐 뒤라면 무시한다.
//     이로 인해 stale 결과가 새 상태를 덮어쓰는 race 가 차단된다.
//   - isLoading 은 defer 로 모든 경로에서 회수되도록 보장.
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
    /// invalidate() 호출마다 증가하는 세대 토큰. 옛 task 가 늦게 끝나
    /// 결과를 들고 와도 세대가 바뀌었다면 무시한다.
    private var loadGeneration: UInt64 = 0

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

        let generation = loadGeneration
        let task = ensureAnalysisTask()

        // 모든 경로에서 isLoading 이 false 로 회수되도록 defer.
        // 단, 세대가 바뀐 경우에는 새 호출이 새 상태를 관리하므로 건드리지 않는다.
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        let result = await task.value

        // invalidate() 이후 결과가 도착하면 stale 이므로 적용하지 않는다.
        guard generation == loadGeneration else { return }

        if analysisTask == task { analysisTask = nil }
        if analysis == nil { analysis = result }
    }

    /// 재분석을 원할 때 호출한다. 진행 중 task 의 결과는 stale 로 처리되며
    /// 다음 `loadIfNeeded()` 호출에서 새 task 가 생성된다.
    func invalidate() {
        loadGeneration &+= 1
        analysis = nil
        analysisTask = nil
    }

    private func ensureAnalysisTask() -> Task<AnalysisResult, Never> {
        if let analysisTask { return analysisTask }

        isLoading = true
        let url = recording.fileURL
        let service = analysisService
        let task = Task { @MainActor in
            await service.analyze(url: url, referenceText: nil)
        }
        analysisTask = task
        return task
    }
}
