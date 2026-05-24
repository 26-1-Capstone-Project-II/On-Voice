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
//  Task lifecycle 정책:
//   - analysis(=결과) 와 analysisTask(=진행 중 작업) 는 분리된 상태로 관리한다.
//   - task 완료 후 analysisTask 는 반드시 nil 로 정리한다(여러 호출자가 같은
//     task 를 await 할 수 있으므로 `=== task` 동일성 비교 후 한 번만 정리).
//   - 동일 ViewModel 인스턴스에서 재분석을 허용하려면 analysis 만 nil 로
//     되돌리고 다시 loadIfNeeded() 를 호출하면 새 task 가 생성된다.
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

        // Task<_, Never>.value 는 non-throwing 이라 view 의 .task cancel 이 와도
        // 분석을 중단하지 않고 그대로 끝까지 기다린다. detached 라 cancel 전파도 없음.
        let result = await task.value

        // task 가 끝났으니 정리한다. 다만 invalidate() 후 누군가 새 task 를
        // 시작했을 가능성이 있으므로 동일성 검사로 자기가 실행한 task 만 nil 처리.
        // Task<_, Never> 는 Equatable 이라 옵셔널 == 비교가 안전하다.
        if analysisTask == task {
            analysisTask = nil
        }

        if analysis == nil {
            analysis = result
        }
        isLoading = false
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
        let task = Task.detached(priority: .userInitiated) {
            await service.analyze(url: url, referenceText: nil)
        }
        analysisTask = task
        return task
    }
}
