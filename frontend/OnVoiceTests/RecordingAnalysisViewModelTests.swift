//
//  RecordingAnalysisViewModelTests.swift
//  OnVoiceTests
//
//  RecordingAnalysisViewModel 의 lifecycle 정책을 mock SpeechAnalyzing 으로 검증한다.
//  검증 대상:
//   - loadIfNeeded() 가 한 번만 task 를 시작하는가
//   - 같은 task 의 결과가 두 호출자에게 공유되는가
//   - invalidate() 가 옛 task 에 cancel 신호를 보내고 stale 결과를 차단하는가
//   - invalidate() 후 다음 loadIfNeeded() 가 새 task 를 시작하는가
//

import XCTest
@testable import OnVoice

@MainActor
final class RecordingAnalysisViewModelTests: XCTestCase {

    // MARK: - Mock service

    /// 분석 호출 횟수를 카운트하고 결과를 지연·취소 가능하게 만든다.
    private final class MockAnalyzer: SpeechAnalyzing, @unchecked Sendable {
        var callCount = 0
        var cancelledCount = 0
        /// true 면 analyze 가 외부 resume 까지 멈춰있는다.
        var shouldHang = false
        /// 멈춤 모드에서 등록되는 continuation. 테스트에서 명시적으로 resume.
        private var pendingContinuation: CheckedContinuation<Void, Never>?
        /// 반환할 결과.
        var stubResult: AnalysisResult = AnalysisResult(
            transcript: "",
            standardText: "",
            standardPronunciation: "",
            sentences: [],
            overallAccuracy: 0,
            isPronunciationEvaluationAvailable: false
        )

        func analyze(url: URL, referenceText: String?) async -> AnalysisResult {
            callCount += 1
            if shouldHang {
                await withTaskCancellationHandler {
                    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                        pendingContinuation = cont
                    }
                } onCancel: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.cancelledCount += 1
                        self?.pendingContinuation?.resume()
                        self?.pendingContinuation = nil
                    }
                }
            }
            return stubResult
        }

        /// 멈춰있던 analyze 를 풀어준다.
        func finishPending() {
            pendingContinuation?.resume()
            pendingContinuation = nil
        }
    }

    private func makeRecording() -> Recording {
        Recording(
            fileURL: URL(fileURLWithPath: "/tmp/test.wav"),
            createdAt: Date(),
            duration: 1.0
        )
    }

    // MARK: - Tests

    func testLoadIfNeededStartsSingleTask() async {
        let mock = MockAnalyzer()
        let vm = RecordingAnalysisViewModel(
            recording: makeRecording(),
            analysisService: mock
        )

        await vm.loadIfNeeded()
        XCTAssertEqual(mock.callCount, 1)
        XCTAssertNotNil(vm.analysis)

        // 두 번째 호출은 analysis 가 이미 있으므로 skip.
        await vm.loadIfNeeded()
        XCTAssertEqual(mock.callCount, 1,
            "이미 결과가 있는데 analyze 가 다시 호출됨 — guard 회귀")
    }

    func testConcurrentLoadIfNeededShareSameTask() async {
        let mock = MockAnalyzer()
        let vm = RecordingAnalysisViewModel(
            recording: makeRecording(),
            analysisService: mock
        )

        // analyze 가 즉시 끝나는 mode 로 두 동시 호출이 모두 같은 task 를 공유하는지 검증.
        async let first: Void = vm.loadIfNeeded()
        async let second: Void = vm.loadIfNeeded()
        _ = await (first, second)

        XCTAssertEqual(mock.callCount, 1,
            "동시 두 호출이 분석을 두 번 시작함 — task 공유 회귀")
        XCTAssertNotNil(vm.analysis)
    }

    func testInvalidateBumpsGenerationAndAllowsReanalysis() async {
        let mock = MockAnalyzer()
        let vm = RecordingAnalysisViewModel(
            recording: makeRecording(),
            analysisService: mock
        )

        await vm.loadIfNeeded()
        XCTAssertEqual(mock.callCount, 1)
        XCTAssertNotNil(vm.analysis)

        vm.invalidate()
        XCTAssertNil(vm.analysis, "invalidate 후 analysis 가 비워져야 함")

        // 새 분석 시작 가능해야 함.
        await vm.loadIfNeeded()
        XCTAssertEqual(mock.callCount, 2,
            "invalidate 후 새 loadIfNeeded 가 새 task 를 시작하지 않음")
        XCTAssertNotNil(vm.analysis)
    }

    func testInvalidateCancelsOngoingTask() async {
        let mock = MockAnalyzer()
        let vm = RecordingAnalysisViewModel(
            recording: makeRecording(),
            analysisService: mock
        )

        // analyze 가 시작되어 멈출 수 있도록 미리 sentinel 등록.
        // analyze 안에서 await withCheckedContinuation 이 pendingContinuation 을 세팅한다.
        // 따라서 우선 mock 을 "다음 호출은 멈춤" 모드로 만들기 위해 마커를 둔다.
        // 단순화: pendingContinuation 을 nil 이 아닌 dummy 로 두는 트릭은 어려우니
        // mock 의 analyze 가 잘 멈추도록 직접 task 를 시작하고 yield 만 한다.

        // analyze 가 await 에서 멈추도록 mode 활성화.
        mock.shouldHang = true

        let loadTask = Task { @MainActor in
            await vm.loadIfNeeded()
        }

        // mock 이 멈출 시간 확보 (continuation 등록까지)
        await Task.yield()
        await Task.yield()

        vm.invalidate()

        // cancel 이 mock 에 전파되어 cancelledCount 증가까지 대기.
        // mock 의 onCancel 이 main actor 에 task 를 띄우므로 yield 여러 번.
        for _ in 0..<5 { await Task.yield() }

        // cleanup: continuation 이 아직 살아있을 수 있으니 resume.
        mock.finishPending()
        await loadTask.value

        XCTAssertEqual(mock.callCount, 1, "task 가 한 번은 시작되었어야 함")
        XCTAssertGreaterThanOrEqual(mock.cancelledCount, 1,
            "invalidate 가 ongoing task 에 cancel 신호를 보내지 않음")
    }
}
