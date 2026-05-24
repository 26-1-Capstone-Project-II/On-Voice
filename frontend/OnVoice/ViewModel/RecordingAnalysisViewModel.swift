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
//   - analysis(=결과) 와 analysisTask(=진행 중 작업) 는 분리된 상태로 관리한다.
//   - task 완료 후 analysisTask 는 동일성 검사(==) 후 nil 처리한다.
//   - isLoading 은 모든 경로에서 false 로 회수되도록 defer 로 보장한다.
//   - 동일 ViewModel 에서 재분석을 허용하려면 invalidate() 로 analysis 만
//     nil 로 되돌리고 다시 loadIfNeeded() 를 호출하면 새 task 가 생성된다.
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

        let task = ensureAnalysisTask()

        // 모든 경로(정상/early-exit/예외)에서 isLoading 이 false 로 회수되도록 defer.
        // Task<_, Never>.value 는 non-throwing 이지만 향후 변경에도 안전하게 가드.
        defer { isLoading = false }

        let result = await task.value

        // task 가 끝났으니 정리한다. 다만 invalidate() 후 누군가 새 task 를
        // 시작했을 가능성이 있으므로 동일성 검사로 자기가 실행한 task 만 nil 처리.
        if analysisTask == task {
            analysisTask = nil
        }

        if analysis == nil {
            analysis = result
        }
    }

    /// 재분석을 원할 때 호출한다. 진행 중 task 는 손대지 않고 결과만 비워두면
    /// 다음 `loadIfNeeded()` 호출이 새 task 를 시작한다.
    func invalidate() {
        analysis = nil
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
