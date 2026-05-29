//
//  RepracticeColorizerTests.swift
//  OnVoiceTests
//
//  오류 문장 재연습(이슈 #117)의 빨강/파랑 diff 로직 단위 테스트.
//  정렬 결과(AlignmentCell)를 직접 구성해 색칠/성공 판정이 회귀하지 않는지 검증한다.
//

import XCTest
@testable import OnVoice

final class RepracticeColorizerTests: XCTestCase {

    // MARK: - Cell builders

    private func substitution(
        expected: Character,
        actual: Character,
        expectedIndex: Int,
        actualIndex: Int
    ) -> AlignmentCell {
        AlignmentCell(
            expected: HangulJamo.decompose(expected),
            actual: HangulJamo.decompose(actual),
            expectedIndex: expectedIndex,
            actualIndex: actualIndex,
            differences: [JamoDifference(slot: .initial, expected: expected, actual: actual)]
        )
    }

    private func correct(_ ch: Character, expectedIndex: Int, actualIndex: Int) -> AlignmentCell {
        AlignmentCell(
            expected: HangulJamo.decompose(ch),
            actual: HangulJamo.decompose(ch),
            expectedIndex: expectedIndex,
            actualIndex: actualIndex,
            differences: []
        )
    }

    private func deletion(_ expected: Character, expectedIndex: Int) -> AlignmentCell {
        AlignmentCell(
            expected: HangulJamo.decompose(expected),
            actual: nil,
            expectedIndex: expectedIndex,
            actualIndex: nil,
            differences: []
        )
    }

    // MARK: - errorExpectedIndices

    func testErrorExpectedIndices_collectsSubstitutionsAndDeletions() {
        let cells = [
            substitution(expected: "다", actual: "가", expectedIndex: 0, actualIndex: 0),
            correct("나", expectedIndex: 1, actualIndex: 1),
            deletion("라", expectedIndex: 2)
        ]
        // 틀린 expected 음절(치환 0, 누락 2)만 잡히고 정답(1)은 제외돼야 한다.
        XCTAssertEqual(RepracticeColorizer.errorExpectedIndices(cells: cells), [0, 2])
    }

    // MARK: - colorize

    func testColorize_allStillWrong_isRed_andNotSuccess() {
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                substitution(expected: "다", actual: "가", expectedIndex: 0, actualIndex: 0),
                substitution(expected: "바", actual: "나", expectedIndex: 1, actualIndex: 1)
            ],
            newHypText: "가나",
            originalErrorExpectedIndices: [0, 1]
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가나"])
        XCTAssertEqual(outcome.segments.map(\.status), [.error])
        XCTAssertFalse(outcome.isFullSuccess)
    }

    func testColorize_allCorrected_isBlue_andSuccess() {
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                correct("가", expectedIndex: 0, actualIndex: 0),
                correct("나", expectedIndex: 1, actualIndex: 1)
            ],
            newHypText: "가나",
            originalErrorExpectedIndices: [0, 1]
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가나"])
        XCTAssertEqual(outcome.segments.map(\.status), [.success])
        XCTAssertTrue(outcome.isFullSuccess)
    }

    func testColorize_mixedRedAndBlue_isNotSuccess() {
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                correct("가", expectedIndex: 0, actualIndex: 0),
                substitution(expected: "바", actual: "나", expectedIndex: 1, actualIndex: 1)
            ],
            newHypText: "가나",
            originalErrorExpectedIndices: [0, 1]
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가", "나"])
        XCTAssertEqual(outcome.segments.map(\.status), [.success, .error])
        XCTAssertFalse(outcome.isFullSuccess)
    }

    func testColorize_correctButNotOriginallyWrong_staysNormal_andSuccess() {
        // 원래도 맞았고 이번에도 맞은 음절은 파랑이 아니라 일반색이어야 한다.
        let outcome = RepracticeColorizer.colorize(
            newCells: [correct("가", expectedIndex: 0, actualIndex: 0)],
            newHypText: "가",
            originalErrorExpectedIndices: []
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가"])
        XCTAssertEqual(outcome.segments.map(\.status), [.normal])
        XCTAssertTrue(outcome.isFullSuccess)
    }

    func testColorize_droppedExpected_blocksSuccess() {
        // 누락된 expected 한글은 색칠 자리가 없지만 성공 판정은 막아야 한다.
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                correct("가", expectedIndex: 0, actualIndex: 0),
                deletion("나", expectedIndex: 1)
            ],
            newHypText: "가",
            originalErrorExpectedIndices: []
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가"])
        XCTAssertEqual(outcome.segments.map(\.status), [.normal])
        XCTAssertFalse(outcome.isFullSuccess)
    }
}
