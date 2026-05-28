//
//  AnalysisResultAvailabilityTests.swift
//  OnVoiceTests
//
//  AnalysisResult 의 기능 단위 가용성 플래그(isTranscriptionAvailable /
//  isComparisonAvailable) 가 transcriptionFailure / limitation / scriptAnalysis
//  세 입력으로부터 정확히 derive 되는지 검증한다.
//

import XCTest
@testable import OnVoice

final class AnalysisResultAvailabilityTests: XCTestCase {

    private func makeResult(
        transcriptionFailure: TranscriptionFailure? = nil,
        limitation: AnalysisLimitation? = nil,
        scriptAnalysis: PronunciationErrorScript = .empty,
        isPronunciationEvaluationAvailable: Bool = false
    ) -> AnalysisResult {
        AnalysisResult(
            transcript: "",
            standardText: "",
            standardPronunciation: "",
            sentences: [],
            overallAccuracy: 0,
            isPronunciationEvaluationAvailable: isPronunciationEvaluationAvailable,
            scriptAnalysis: scriptAnalysis,
            transcriptionFailure: transcriptionFailure,
            limitation: limitation
        )
    }

    private func makeNonEmptyScript() -> PronunciationErrorScript {
        PronunciationErrorScript.makePlainScript(from: ["가나다"])
    }

    // MARK: - isTranscriptionAvailable

    func testTranscriptionAvailableWhenNoFailure() {
        let result = makeResult()
        XCTAssertTrue(result.isTranscriptionAvailable)
    }

    func testTranscriptionUnavailableWhenFailure() {
        let result = makeResult(transcriptionFailure: .modelMissing)
        XCTAssertFalse(result.isTranscriptionAvailable)
    }

    // MARK: - isComparisonAvailable

    func testComparisonAvailableWhenAllConditionsMet() {
        let result = makeResult(scriptAnalysis: makeNonEmptyScript())
        XCTAssertTrue(result.isComparisonAvailable,
            "transcriptionFailure / limitation / scriptAnalysis 모두 정상일 때 활성")
    }

    func testComparisonUnavailableWhenTranscriptionFailed() {
        let result = makeResult(
            transcriptionFailure: .pipelineLoadFailed,
            scriptAnalysis: makeNonEmptyScript()
        )
        XCTAssertFalse(result.isComparisonAvailable,
            "전사가 실패하면 비교도 활성화될 수 없음")
    }

    func testComparisonUnavailableWhenLimitationPresent() {
        let result = makeResult(
            limitation: .intentTextEmpty,
            scriptAnalysis: makeNonEmptyScript()
        )
        XCTAssertFalse(result.isComparisonAvailable,
            "intentText 가 비면 G2P 비교가 비활성")
    }

    func testComparisonUnavailableWhenScriptAnalysisEmpty() {
        let result = makeResult(scriptAnalysis: .empty)
        XCTAssertFalse(result.isComparisonAvailable,
            "scriptAnalysis 가 비면 표시할 내용이 없어 비교 비활성")
    }

    func testComparisonUnavailableWhenAuthorizationDenied() {
        let result = makeResult(
            limitation: .speechAuthorizationDenied,
            scriptAnalysis: makeNonEmptyScript()
        )
        XCTAssertFalse(result.isComparisonAvailable)
    }

    // MARK: - evaluationState (불가 사유 구분)

    func testEvaluationStateAvailable() {
        let result = makeResult(
            scriptAnalysis: makeNonEmptyScript(),
            isPronunciationEvaluationAvailable: true
        )
        XCTAssertEqual(result.evaluationState, .available)
    }

    func testEvaluationStateTranscriptionFailedTakesPriority() {
        // 전사 실패는 limitation/평가 가능 여부보다 우선한다.
        let result = makeResult(
            transcriptionFailure: .modelMissing,
            limitation: .intentTextEmpty,
            isPronunciationEvaluationAvailable: true
        )
        XCTAssertEqual(result.evaluationState, .transcriptionFailed(.modelMissing))
    }

    func testEvaluationStateComparisonUnavailableForLimitation() {
        let result = makeResult(limitation: .speechAuthorizationDenied)
        XCTAssertEqual(
            result.evaluationState,
            .comparisonUnavailable(.speechAuthorizationDenied)
        )
    }

    func testEvaluationStateNoEvaluableContent() {
        // 전사 성공·limitation 없음인데 평가 불가(한글 입력 없음/정렬 결과 없음).
        let result = makeResult(isPronunciationEvaluationAvailable: false)
        XCTAssertEqual(result.evaluationState, .noEvaluableContent)
    }

    func testEvaluationStateDistinguishesAllUnavailableReasons() {
        // score=0 fallback 으로 뭉개지던 세 불가 사유가 서로 다른 상태로 구분되는지.
        let failed = makeResult(transcriptionFailure: .transcribeFailed).evaluationState
        let denied = makeResult(limitation: .speechAuthorizationDenied).evaluationState
        let noContent = makeResult(isPronunciationEvaluationAvailable: false).evaluationState
        XCTAssertNotEqual(failed, denied)
        XCTAssertNotEqual(denied, noContent)
        XCTAssertNotEqual(failed, noContent)
    }
}
