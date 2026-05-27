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
        scriptAnalysis: PronunciationErrorScript = .empty
    ) -> AnalysisResult {
        AnalysisResult(
            transcript: "",
            standardText: "",
            standardPronunciation: "",
            sentences: [],
            overallAccuracy: 0,
            isPronunciationEvaluationAvailable: false,
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
}
