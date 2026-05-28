//
//  PronunciationScoreCalculatorTests.swift
//  OnVoiceTests
//
//  자모 정렬 cell 시퀀스로부터 점수가 한글 expected 음절 분모 기준으로
//  올바르게 산출되는지 검증한다.
//

import XCTest
@testable import OnVoice

final class PronunciationScoreCalculatorTests: XCTestCase {

    // MARK: - Helpers

    private func syl(_ ch: Character) -> HangulJamo.Syllable {
        HangulJamo.decompose(ch)
    }

    /// 두 한글이 동일한 정확 매치 cell.
    private func correctCell(_ ch: Character, expectedIndex: Int = 0, actualIndex: Int = 0) -> AlignmentCell {
        AlignmentCell(
            expected: syl(ch),
            actual: syl(ch),
            expectedIndex: expectedIndex,
            actualIndex: actualIndex,
            differences: []
        )
    }

    /// 자모 차이가 있는 substitution cell.
    private func substitutionCell(
        expected: Character,
        actual: Character,
        expectedIndex: Int = 0,
        actualIndex: Int = 0
    ) -> AlignmentCell {
        let e = syl(expected)
        let a = syl(actual)
        var diffs: [JamoDifference] = []
        if e.initialIndex != a.initialIndex {
            diffs.append(.init(slot: .initial, expected: e.initial, actual: a.initial))
        }
        if e.medialIndex != a.medialIndex {
            diffs.append(.init(slot: .medial, expected: e.medial, actual: a.medial))
        }
        if e.finalIndex != a.finalIndex {
            diffs.append(.init(slot: .final, expected: e.final, actual: a.final))
        }
        return AlignmentCell(
            expected: e,
            actual: a,
            expectedIndex: expectedIndex,
            actualIndex: actualIndex,
            differences: diffs
        )
    }

    /// expected-only gap cell (사용자가 음절을 누락한 케이스).
    private func droppedCell(_ ch: Character, expectedIndex: Int = 0) -> AlignmentCell {
        AlignmentCell(
            expected: syl(ch),
            actual: nil,
            expectedIndex: expectedIndex,
            actualIndex: nil,
            differences: []
        )
    }

    /// actual-only gap cell (사용자가 추가 음절을 끼워넣은 케이스).
    private func insertedCell(_ ch: Character, actualIndex: Int = 0) -> AlignmentCell {
        AlignmentCell(
            expected: nil,
            actual: syl(ch),
            expectedIndex: nil,
            actualIndex: actualIndex,
            differences: []
        )
    }

    /// 비-한글 expected cell (공백/구두점). 분모에서 제외되어야 한다.
    private func nonHangulCell(_ ch: Character, expectedIndex: Int, actualIndex: Int) -> AlignmentCell {
        AlignmentCell(
            expected: HangulJamo.Syllable.nonHangul(ch),
            actual: HangulJamo.Syllable.nonHangul(ch),
            expectedIndex: expectedIndex,
            actualIndex: actualIndex,
            differences: []
        )
    }

    // MARK: - Edge cases

    func testEmptyCellsReturnsUnavailable() {
        let summary = PronunciationScoreCalculator.compute(cells: [])
        XCTAssertEqual(summary.score, 0)
        XCTAssertEqual(summary.accuracy, 0)
        XCTAssertEqual(summary.level, .low)
    }

    func testOnlyActualOnlyGapsReturnsUnavailable() {
        // expected 가 하나도 없으면 분모가 0 → unavailable.
        let cells = [
            insertedCell("아", actualIndex: 0),
            insertedCell("이", actualIndex: 1)
        ]
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.score, 0)
        XCTAssertEqual(summary.level, .low)
    }

    // MARK: - 정확도 산출

    func testAllCorrectGivesFullScore() {
        let cells = [
            correctCell("학", expectedIndex: 0, actualIndex: 0),
            correctCell("교", expectedIndex: 1, actualIndex: 1)
        ]
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.accuracy, 1.0)
        XCTAssertEqual(summary.score, 100)
        XCTAssertEqual(summary.level, .high)
    }

    func testHalfCorrectGivesFiftyAndMiddleLevel() {
        let cells = [
            correctCell("학", expectedIndex: 0, actualIndex: 0),
            substitutionCell(expected: "꾜", actual: "교", expectedIndex: 1, actualIndex: 1)
        ]
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.accuracy, 0.5, accuracy: 0.0001)
        XCTAssertEqual(summary.score, 50)
        XCTAssertEqual(summary.level, .middle)
    }

    func testAllErrorsGivesZeroAndLowLevel() {
        let cells = [
            substitutionCell(expected: "가", actual: "거", expectedIndex: 0, actualIndex: 0),
            substitutionCell(expected: "나", actual: "너", expectedIndex: 1, actualIndex: 1)
        ]
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.score, 0)
        XCTAssertEqual(summary.level, .low)
    }

    func testDropoutsCountAsErrors() {
        // 4 음절 중 2 음절은 정확, 2 음절은 누락 → 50점.
        let cells = [
            correctCell("나", expectedIndex: 0, actualIndex: 0),
            droppedCell("는", expectedIndex: 1),
            correctCell("학", expectedIndex: 2, actualIndex: 1),
            droppedCell("생", expectedIndex: 3)
        ]
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.accuracy, 0.5, accuracy: 0.0001)
        XCTAssertEqual(summary.score, 50)
    }

    func testActualOnlyInsertionsDoNotInflateScore() {
        // expected 2 음절 모두 정확, actual 쪽에 끼워넣어진 음절(분모 외)이 1개 있다.
        // 정확도는 expected 기준이므로 100% 유지.
        let cells = [
            correctCell("학", expectedIndex: 0, actualIndex: 0),
            insertedCell("어", actualIndex: 1),
            correctCell("교", expectedIndex: 1, actualIndex: 2)
        ]
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.accuracy, 1.0)
        XCTAssertEqual(summary.score, 100)
    }

    // MARK: - Level boundary

    func testBoundaryAt35IsLow() {
        // 7/20 = 0.35 → 정확히 35 점 → low.
        let correctCount = 7
        let totalCount = 20
        var cells: [AlignmentCell] = []
        for i in 0..<correctCount {
            cells.append(correctCell("가", expectedIndex: i, actualIndex: i))
        }
        for i in correctCount..<totalCount {
            cells.append(substitutionCell(
                expected: "가", actual: "거",
                expectedIndex: i, actualIndex: i
            ))
        }
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.score, 35)
        XCTAssertEqual(summary.level, .low)
    }

    func testBoundaryAt71IsHigh() {
        // 71/100 = 0.71 → 71 점 → high.
        var cells: [AlignmentCell] = []
        for i in 0..<71 {
            cells.append(correctCell("가", expectedIndex: i, actualIndex: i))
        }
        for i in 71..<100 {
            cells.append(substitutionCell(
                expected: "가", actual: "거",
                expectedIndex: i, actualIndex: i
            ))
        }
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.score, 71)
        XCTAssertEqual(summary.level, .high)
    }

    func testBoundaryAt36IsMiddle() {
        // 36/100 = 36 점 → low(<=35) 가 아닌 middle 첫 값.
        let summary = PronunciationScoreCalculator.compute(cells: makeCells(correct: 36, total: 100))
        XCTAssertEqual(summary.score, 36)
        XCTAssertEqual(summary.level, .middle)
    }

    func testBoundaryAt70IsMiddle() {
        // 70/100 = 70 점 → middle 마지막 값(71 부터 high).
        let summary = PronunciationScoreCalculator.compute(cells: makeCells(correct: 70, total: 100))
        XCTAssertEqual(summary.score, 70)
        XCTAssertEqual(summary.level, .middle)
    }

    // MARK: - 분모 정책 (개선 3)

    func testGapCellsCountInDenominatorAsErrors() {
        // expected != nil, actual == nil 인 gap cell 은 hasError 정의상 오류로
        // 분자에서 빠지지만 분모에는 포함된다. 2 정확 + 2 누락 → 50점.
        let cells = [
            correctCell("학", expectedIndex: 0, actualIndex: 0),
            droppedCell("교", expectedIndex: 1),
            correctCell("생", expectedIndex: 2, actualIndex: 1),
            droppedCell("활", expectedIndex: 3)
        ]
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.accuracy, 0.5, accuracy: 0.0001)
        XCTAssertEqual(summary.score, 50)
    }

    func testNonHangulCellsExcludedFromDenominator() {
        // 공백/구두점 cell 이 섞여도 분모는 한글 음절만. 한글 2개 모두 정확 → 100점.
        let cells = [
            correctCell("학", expectedIndex: 0, actualIndex: 0),
            nonHangulCell(" ", expectedIndex: 1, actualIndex: 1),
            correctCell("교", expectedIndex: 2, actualIndex: 2),
            nonHangulCell(".", expectedIndex: 3, actualIndex: 3)
        ]
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.accuracy, 1.0,
            "비-한글 cell 이 분모/분자에 들어가 정확도를 왜곡함")
        XCTAssertEqual(summary.score, 100)
    }

    func testOnlyNonHangulCellsReturnsUnavailable() {
        // 한글이 하나도 없으면(숫자/구두점만) 분모 0 → unavailable.
        let cells = [
            nonHangulCell("1", expectedIndex: 0, actualIndex: 0),
            nonHangulCell("2", expectedIndex: 1, actualIndex: 1)
        ]
        let summary = PronunciationScoreCalculator.compute(cells: cells)
        XCTAssertEqual(summary.score, 0)
        XCTAssertEqual(summary.level, .low)
    }

    // MARK: - Helper

    /// correct 개의 정확 cell + (total-correct) 개의 substitution cell.
    private func makeCells(correct: Int, total: Int) -> [AlignmentCell] {
        var cells: [AlignmentCell] = []
        for i in 0..<correct {
            cells.append(correctCell("가", expectedIndex: i, actualIndex: i))
        }
        for i in correct..<total {
            cells.append(substitutionCell(
                expected: "가", actual: "거",
                expectedIndex: i, actualIndex: i
            ))
        }
        return cells
    }
}
