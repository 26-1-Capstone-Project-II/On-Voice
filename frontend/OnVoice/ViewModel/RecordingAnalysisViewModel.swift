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
//  `Task.detached` 로 시작점도 MainActor 가 아닌 global executor 에 둔다.
//  분석 서비스(SpeechAnalysisService)가 actor 가 아닌 final class 이므로
//  상속할 actor isolation 이 처음부터 없고, MainActor 점유로 인한 UI 스레드 부담을
//  완전히 제거한다. 내부에서 호출하는 WhisperKit 등은 자체적으로 actor isolation
//  을 가지고 있어 hop 으로 처리된다. cancel 전파도 끊겨 view .task 영향 받지 않음.
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

    private let analysisService: SpeechAnalyzing
    private var analysisTask: Task<AnalysisResult, Never>?
    /// invalidate() 호출마다 증가하는 세대 토큰. 옛 task 가 늦게 끝나
    /// 결과를 들고 와도 세대가 바뀌었다면 무시한다.
    private var loadGeneration: UInt64 = 0

    init(
        recording: Recording,
        analysisService: SpeechAnalyzing = SpeechAnalysisService()
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

    /// 재분석을 원할 때 호출한다. 진행 중 task 가 있으면 cancel 신호를 보내고
    /// 결과는 loadGeneration 토큰으로 stale 처리되어 새 상태를 덮어쓰지 않는다.
    /// 다음 `loadIfNeeded()` 호출에서 새 task 가 생성된다.
    ///
    /// Note: detached task 의 cancel 은 WhisperKit/SFSpeechRecognizer 가 협력해야
    /// 실제 중단된다. 협력하지 않으면 task 는 background 에서 끝까지 도지만,
    /// loadGeneration 가드로 결과 적용은 차단된다 — 부작용은 CPU/배터리 소량 낭비.
    func invalidate() {
        loadGeneration &+= 1
        analysisTask?.cancel()
        analysis = nil
        analysisTask = nil
    }

    private func ensureAnalysisTask() -> Task<AnalysisResult, Never> {
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
