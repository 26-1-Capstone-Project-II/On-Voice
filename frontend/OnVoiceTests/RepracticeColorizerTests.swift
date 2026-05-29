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

    // MARK: - colorize (평가 대상은 remaining 만)

    func testColorize_remainingStillWrong_isRed_andNotSuccess() {
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                substitution(expected: "다", actual: "가", expectedIndex: 0, actualIndex: 0),
                substitution(expected: "바", actual: "나", expectedIndex: 1, actualIndex: 1)
            ],
            newHypText: "가나",
            originalErrorExpectedIndices: [0, 1],
            remainingExpectedIndices: [0, 1]
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가나"])
        XCTAssertEqual(outcome.segments.map(\.status), [.error])
        XCTAssertEqual(outcome.correctedExpectedIndices, [])
        XCTAssertFalse(outcome.isFullSuccess)
    }

    func testColorize_remainingCorrected_isBlue_andSuccess() {
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                correct("가", expectedIndex: 0, actualIndex: 0),
                correct("나", expectedIndex: 1, actualIndex: 1)
            ],
            newHypText: "가나",
            originalErrorExpectedIndices: [0, 1],
            remainingExpectedIndices: [0, 1]
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가나"])
        XCTAssertEqual(outcome.segments.map(\.status), [.success])
        XCTAssertEqual(outcome.correctedExpectedIndices, [0, 1])
        XCTAssertTrue(outcome.isFullSuccess)
    }

    func testColorize_mixedRedAndBlue_isNotSuccess() {
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                correct("가", expectedIndex: 0, actualIndex: 0),
                substitution(expected: "바", actual: "나", expectedIndex: 1, actualIndex: 1)
            ],
            newHypText: "가나",
            originalErrorExpectedIndices: [0, 1],
            remainingExpectedIndices: [0, 1]
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가", "나"])
        XCTAssertEqual(outcome.segments.map(\.status), [.success, .error])
        XCTAssertEqual(outcome.correctedExpectedIndices, [0])
        XCTAssertFalse(outcome.isFullSuccess)
    }

    func testColorize_originallyCorrectSyllableExcluded_evenIfNowWrong() {
        // 핵심: 원래 맞았던 음절(평가 대상 아님)이 이번에 오인식돼도 빨강이 아니고 성공을 막지 않는다.
        // remaining = {0} 만 평가. index 1 은 원래 정답이라 틀려도 일반색.
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                correct("가", expectedIndex: 0, actualIndex: 0),
                substitution(expected: "나", actual: "다", expectedIndex: 1, actualIndex: 1)
            ],
            newHypText: "가다",
            originalErrorExpectedIndices: [0],
            remainingExpectedIndices: [0]
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가", "다"])
        XCTAssertEqual(outcome.segments.map(\.status), [.success, .normal])
        XCTAssertEqual(outcome.correctedExpectedIndices, [0])
        XCTAssertTrue(outcome.isFullSuccess)
    }

    func testColorize_lockedCorrectedSyllableStaysBlue_andNotReEvaluated() {
        // 이전 시도에서 이미 교정한 음절(index 0): remaining 에서 빠져 있다.
        // 다시 맞으면 파랑 유지, 틀려도(아래 테스트) 빨강 아님.
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                correct("가", expectedIndex: 0, actualIndex: 0),
                correct("나", expectedIndex: 1, actualIndex: 1)
            ],
            newHypText: "가나",
            originalErrorExpectedIndices: [0, 1],
            remainingExpectedIndices: [1]
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가나"])
        XCTAssertEqual(outcome.segments.map(\.status), [.success])
        XCTAssertEqual(outcome.correctedExpectedIndices, [1])
        XCTAssertTrue(outcome.isFullSuccess)
    }

    func testColorize_lockedSyllableWrongAgain_notRed_stillSuccess() {
        // 이미 교정한 음절(0)이 이번엔 오인식돼도 평가 제외 → 일반색, 성공 유지.
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                substitution(expected: "가", actual: "다", expectedIndex: 0, actualIndex: 0),
                correct("나", expectedIndex: 1, actualIndex: 1)
            ],
            newHypText: "다나",
            originalErrorExpectedIndices: [0, 1],
            remainingExpectedIndices: [1]
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["다", "나"])
        XCTAssertEqual(outcome.segments.map(\.status), [.normal, .success])
        XCTAssertEqual(outcome.correctedExpectedIndices, [1])
        XCTAssertTrue(outcome.isFullSuccess)
    }

    func testColorize_droppedRemainingTarget_blocksSuccess() {
        // 평가 대상(remaining=1)이 이번 시도에서 누락되면 색칠 자리는 없어도 성공을 막는다.
        let outcome = RepracticeColorizer.colorize(
            newCells: [
                correct("가", expectedIndex: 0, actualIndex: 0),
                deletion("나", expectedIndex: 1)
            ],
            newHypText: "가",
            originalErrorExpectedIndices: [0, 1],
            remainingExpectedIndices: [1]
        )
        XCTAssertEqual(outcome.segments.map(\.text), ["가"])
        // index 0 은 이미 교정돼(remaining 에 없음) 파랑 유지.
        XCTAssertEqual(outcome.segments.map(\.status), [.success])
        XCTAssertEqual(outcome.correctedExpectedIndices, [])
        XCTAssertFalse(outcome.isFullSuccess)
    }
}
