//
//  SegmentGroupingTests.swift
//  OnVoiceTests
//
//  PronunciationScriptAnalysisService.groupCellsBySegment 의 ref-distance 기반
//  분배 정책을 직접 단위 테스트한다. snapshot 테스트는 결과의 hasErrorDetail/카테고리만
//  보지만 여기서는 각 cell 이 정확히 어느 segment 로 가는지 검증한다.
//

import XCTest
@testable import OnVoice

final class SegmentGroupingTests: XCTestCase {

    private let service = PronunciationScriptAnalysisService()

    // MARK: - Helpers

    /// 한글 음절 한 글자로 syllable 생성.
    private func syl(_ ch: Character) -> HangulJamo.Syllable {
        HangulJamo.decompose(ch)
    }

    /// 테스트용 cell 생성 헬퍼. expected/actual 는 한 글자 String 또는 nil.
    private func cell(
        expected: Character?,
        actual: Character?,
        expectedIndex: Int?,
        actualIndex: Int?
    ) -> AlignmentCell {
        AlignmentCell(
            expected: expected.map { syl($0) },
            actual: actual.map { syl($0) },
            expectedIndex: expectedIndex,
            actualIndex: actualIndex,
            differences: []
        )
    }

    // MARK: - 단일 actual cell 부착

    func testActualCellGoesToOwnSegment() {
        // actual cell 두 개, 각각 다른 segment.
        let cells = [
            cell(expected: "가", actual: "가", expectedIndex: 0, actualIndex: 0),
            cell(expected: "나", actual: "나", expectedIndex: 1, actualIndex: 1)
        ]
        let syllableToSegment = [0, 1]
        let groups = service.groupCellsBySegment(cells: cells, syllableToSegment: syllableToSegment)
        XCTAssertEqual(groups[0]?.count, 1)
        XCTAssertEqual(groups[1]?.count, 1)
        XCTAssertEqual(groups[0]?.first?.actualIndex, 0)
        XCTAssertEqual(groups[1]?.first?.actualIndex, 1)
    }

    // MARK: - ref-distance 분배 (핵심 케이스)

    func testGapDistributedByRefDistance() {
        // ref: [0]가 [1]나 [2]다 [3]라 [4]마 [5]바 [6]사
        // hyp: [0]가 [1]나               [2]바 [3]사   (segment 0: 가나, segment 1: 바사)
        // cells: 가-가, 나-나, 다(gap), 라(gap), 마(gap), 바-바, 사-사
        // 다(exp=2): prev=1, next=5 → dist 1, 3 → segment 0
        // 라(exp=3): prev=1, next=5 → dist 2, 2 → 동률 → segment 0 (prev 선호)
        // 마(exp=4): prev=1, next=5 → dist 3, 1 → segment 1
        let cells = [
            cell(expected: "가", actual: "가", expectedIndex: 0, actualIndex: 0),
            cell(expected: "나", actual: "나", expectedIndex: 1, actualIndex: 1),
            cell(expected: "다", actual: nil,  expectedIndex: 2, actualIndex: nil),
            cell(expected: "라", actual: nil,  expectedIndex: 3, actualIndex: nil),
            cell(expected: "마", actual: nil,  expectedIndex: 4, actualIndex: nil),
            cell(expected: "바", actual: "바", expectedIndex: 5, actualIndex: 2),
            cell(expected: "사", actual: "사", expectedIndex: 6, actualIndex: 3)
        ]
        let syllableToSegment = [0, 0, 1, 1]
        let groups = service.groupCellsBySegment(cells: cells, syllableToSegment: syllableToSegment)

        // segment 0 에는 가, 나, 다, 라 (4개)
        XCTAssertEqual(groups[0]?.count, 4)
        XCTAssertEqual(
            groups[0]?.compactMap { $0.expected?.composed },
            ["가", "나", "다", "라"]
        )
        // segment 1 에는 마, 바, 사 (3개)
        XCTAssertEqual(groups[1]?.count, 3)
        XCTAssertEqual(
            groups[1]?.compactMap { $0.expected?.composed },
            ["마", "바", "사"]
        )
    }

    // MARK: - 연속 gap 3개 이상

    func testFiveConsecutiveGapsDistributedCorrectly() {
        // ref: [0]가 [1]나 [2]다 [3]라 [4]마 [5]바 [6]사 [7]아 [8]자
        // hyp: [0]가 [1]나                                [2]자  (segment 0: 가나, segment 1: 자)
        // cells: 가-가, 나-나, 다(gap), 라(gap), 마(gap), 바(gap), 사(gap), 아(gap), 자-자
        // gap 6개의 prev exp=1, next exp=8. 거리 비교:
        //   다(exp=2): dist 1·6 → segment 0
        //   라(exp=3): dist 2·5 → segment 0
        //   마(exp=4): dist 3·4 → segment 0
        //   바(exp=5): dist 4·3 → segment 1
        //   사(exp=6): dist 5·2 → segment 1
        //   아(exp=7): dist 6·1 → segment 1
        let cells = [
            cell(expected: "가", actual: "가", expectedIndex: 0, actualIndex: 0),
            cell(expected: "나", actual: "나", expectedIndex: 1, actualIndex: 1),
            cell(expected: "다", actual: nil,  expectedIndex: 2, actualIndex: nil),
            cell(expected: "라", actual: nil,  expectedIndex: 3, actualIndex: nil),
            cell(expected: "마", actual: nil,  expectedIndex: 4, actualIndex: nil),
            cell(expected: "바", actual: nil,  expectedIndex: 5, actualIndex: nil),
            cell(expected: "사", actual: nil,  expectedIndex: 6, actualIndex: nil),
            cell(expected: "아", actual: nil,  expectedIndex: 7, actualIndex: nil),
            cell(expected: "자", actual: "자", expectedIndex: 8, actualIndex: 2)
        ]
        let syllableToSegment = [0, 0, 1]
        let groups = service.groupCellsBySegment(cells: cells, syllableToSegment: syllableToSegment)

        XCTAssertEqual(
            groups[0]?.compactMap { $0.expected?.composed },
            ["가", "나", "다", "라", "마"]
        )
        XCTAssertEqual(
            groups[1]?.compactMap { $0.expected?.composed },
            ["바", "사", "아", "자"]
        )
    }

    // MARK: - actual 이 한쪽 끝에만 존재

    func testActualOnlyAtStartAttachesAllGapsToFirstSegment() {
        // actual 이 시퀀스 시작에만 있고 뒤는 모두 gap.
        let cells = [
            cell(expected: "가", actual: "가", expectedIndex: 0, actualIndex: 0),
            cell(expected: "나", actual: nil,  expectedIndex: 1, actualIndex: nil),
            cell(expected: "다", actual: nil,  expectedIndex: 2, actualIndex: nil)
        ]
        let groups = service.groupCellsBySegment(cells: cells, syllableToSegment: [0])

        XCTAssertEqual(groups[0]?.count, 3,
            "actual 이 한쪽 끝에만 있을 때 모든 gap 이 그쪽 segment 에 부착되어야 함")
    }

    func testActualOnlyAtEndAttachesAllGapsToLastSegment() {
        let cells = [
            cell(expected: "가", actual: nil,  expectedIndex: 0, actualIndex: nil),
            cell(expected: "나", actual: nil,  expectedIndex: 1, actualIndex: nil),
            cell(expected: "다", actual: "다", expectedIndex: 2, actualIndex: 0)
        ]
        let groups = service.groupCellsBySegment(cells: cells, syllableToSegment: [0])
        XCTAssertEqual(groups[0]?.count, 3)
    }

    // MARK: - actual 이 한 번도 없음 → 무시

    func testNoActualCellsProducesEmptyGroups() {
        let cells = [
            cell(expected: "가", actual: nil, expectedIndex: 0, actualIndex: nil),
            cell(expected: "나", actual: nil, expectedIndex: 1, actualIndex: nil)
        ]
        let groups = service.groupCellsBySegment(cells: cells, syllableToSegment: [])
        XCTAssertTrue(groups.isEmpty,
            "hyp 가 비어 있으면 모든 gap 이 무시되어 첫 segment 오탐을 만들지 않아야 함")
    }

    // MARK: - actual-only gap (expectedIndex == nil 인 actual cell) 처리

    func testActualOnlyGapAttachesToOwnSegmentWithoutBreakingNeighborLookup() {
        // ref: [0]가 [1]나        [2]다
        // hyp: [0]가 [1]나 [2]?  [3]다  ← hyp 측에 ref 에 없는 음절 ?
        // cells: 가-가, 나-나, gap-?(actual-only), 다-다
        // actual-only gap (?) 는 syllableToSegment 로 본인 segment 결정.
        // 그 사이에 expected-only gap 이 끼어도 prev/next lookup 이 actual-only 를
        // 건너뛰고 정상 actual cell 을 찾아야 한다.
        let cells = [
            cell(expected: "가", actual: "가", expectedIndex: 0, actualIndex: 0),
            cell(expected: "나", actual: "나", expectedIndex: 1, actualIndex: 1),
            cell(expected: nil,  actual: "?", expectedIndex: nil, actualIndex: 2),
            cell(expected: "다", actual: "다", expectedIndex: 2, actualIndex: 3)
        ]
        // segment 0: 가나, segment 1: ?다
        let syllableToSegment = [0, 0, 1, 1]
        let groups = service.groupCellsBySegment(cells: cells, syllableToSegment: syllableToSegment)

        XCTAssertEqual(groups[0]?.count, 2)
        XCTAssertEqual(groups[1]?.count, 2)
        // segment 1 에는 actual-only gap (?) 과 다-다 cell 이 포함.
        XCTAssertEqual(
            groups[1]?.compactMap { $0.actual?.composed },
            ["?", "다"]
        )
    }
}
