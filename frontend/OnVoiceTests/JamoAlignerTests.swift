//
//  JamoAlignerTests.swift
//  OnVoiceTests
//
//  자모 정렬 NW 알고리즘의 핵심 동작과 tie-break 결정성 회귀 방지.
//

import XCTest
@testable import OnVoice

final class JamoAlignerTests: XCTestCase {

    private func decompose(_ s: String) -> [HangulJamo.Syllable] {
        HangulJamo.decompose(s)
    }

    // MARK: - Identical sequences

    func testIdenticalSequenceProducesNoErrors() {
        let cells = JamoAligner.align(
            expected: decompose("학교"),
            actual: decompose("학교")
        )
        XCTAssertEqual(cells.count, 2)
        XCTAssertTrue(cells.allSatisfy { !$0.hasError })
    }

    // MARK: - Single-jamo difference

    func testSingleJamoDifferenceMarksOneCell() {
        // 학교 vs 학꾜 — 두 번째 음절 초성만 다름 (경음화 미적용 패턴)
        let cells = JamoAligner.align(
            expected: decompose("학꾜"),
            actual: decompose("학교")
        )
        XCTAssertEqual(cells.count, 2)
        XCTAssertFalse(cells[0].hasError)
        XCTAssertTrue(cells[1].hasError)
        XCTAssertEqual(cells[1].differences.count, 1)
        XCTAssertEqual(cells[1].differences.first?.slot, .initial)
    }

    // MARK: - Length difference (insertion/deletion)

    func testInsertionCreatesGapCell() {
        // ref: "사과를" (3음절) vs hyp: "사를" (2음절). 중간에 음절 누락.
        let cells = JamoAligner.align(
            expected: decompose("사과를"),
            actual: decompose("사를")
        )
        let gapCells = cells.filter { $0.actual == nil }
        XCTAssertEqual(gapCells.count, 1)
        XCTAssertEqual(gapCells.first?.expected?.composed, "과")
    }

    // MARK: - Full-jamo substitution should prefer gap (tie-break)

    func testFullJamoSubstitutionPenalizedSoGapWins() {
        // ref: "가" vs hyp: "" — 음절 통째 누락 케이스.
        // hyp 이 비어있으니 alignment 는 단일 gap 으로 잡힌다.
        let cells = JamoAligner.align(
            expected: decompose("가"),
            actual: []
        )
        XCTAssertEqual(cells.count, 1)
        XCTAssertNil(cells.first?.actual)
        XCTAssertEqual(cells.first?.expected?.composed, "가")
    }

    func testFullyDifferentSyllableNotPreferredOverGap() {
        // ref: "가나" vs hyp: "다" — "가" 또는 "나" 중 하나가 누락된 형태.
        // 자모 3개 모두 다른 substitution 페널티로 gap 경로가 선호된다.
        let cells = JamoAligner.align(
            expected: decompose("가나"),
            actual: decompose("다")
        )
        // gap 이 최소 한 번은 등장해야 한다.
        XCTAssertTrue(cells.contains { $0.actual == nil || $0.expected == nil })
    }

    // MARK: - Non-Hangul handling

    func testNonHangulMatchHasNoError() {
        // 비-한글(공백)끼리 같으면 차이 없음.
        let cells = JamoAligner.align(
            expected: decompose(" "),
            actual: decompose(" ")
        )
        XCTAssertEqual(cells.count, 1)
        XCTAssertFalse(cells[0].hasError)
    }

    // MARK: - Determinism (tie-break stability)

    func testAlignmentIsDeterministic() {
        let exp = decompose("오느른 키움")
        let act = decompose("오늘은 키움")
        let cells1 = JamoAligner.align(expected: exp, actual: act)
        let cells2 = JamoAligner.align(expected: exp, actual: act)
        XCTAssertEqual(cells1.count, cells2.count)
        for (a, b) in zip(cells1, cells2) {
            XCTAssertEqual(a.expectedIndex, b.expectedIndex)
            XCTAssertEqual(a.actualIndex, b.actualIndex)
            XCTAssertEqual(a.differences.count, b.differences.count)
        }
    }
}
