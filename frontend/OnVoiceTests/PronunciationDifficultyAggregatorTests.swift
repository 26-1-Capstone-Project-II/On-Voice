//
//  PronunciationDifficultyAggregatorTests.swift
//  OnVoiceTests
//
//  10종 카테고리 빈도 집계 → 상위 3개 difficultyItem 산출 동작 검증.
//  카테고리 매핑 자체는 `PronunciationErrorClassifier` 책임이라 여기서는
//  랭킹/동률 정책/표시 데이터 fallback 만 본다.
//

import XCTest
import SwiftUI
@testable import OnVoice

final class PronunciationDifficultyAggregatorTests: XCTestCase {

    // MARK: - Helpers

    private func syl(_ ch: Character) -> HangulJamo.Syllable {
        HangulJamo.decompose(ch)
    }

    /// substitution(자모 차이) cell. 단순 단일 cell 호출용.
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

    private func droppedCell(_ ch: Character, expectedIndex: Int = 0) -> AlignmentCell {
        AlignmentCell(
            expected: syl(ch),
            actual: nil,
            expectedIndex: expectedIndex,
            actualIndex: nil,
            differences: []
        )
    }

    // MARK: - 빈 입력

    func testEmptyCellsReturnsEmptyItems() {
        let items = PronunciationDifficultyAggregator.aggregate(cells: [], expectedAll: [])
        XCTAssertTrue(items.isEmpty)
    }

    func testNoErrorCellsReturnsEmptyItems() {
        // 모두 정확한 cell 이면 difficultyItems 도 비어있어야 한다.
        let cells = [
            AlignmentCell(
                expected: syl("학"), actual: syl("학"),
                expectedIndex: 0, actualIndex: 0,
                differences: []
            ),
            AlignmentCell(
                expected: syl("교"), actual: syl("교"),
                expectedIndex: 1, actualIndex: 1,
                differences: []
            )
        ]
        let items = PronunciationDifficultyAggregator.aggregate(
            cells: cells,
            expectedAll: [syl("학"), syl("교")]
        )
        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - 랭킹

    func testSingleCategoryProducesSingleRankOne() {
        // 학 vs 거(초성+중성 차이): 모음 오류 분류만 발생.
        // 한 cell 의 결과를 그대로 노출.
        let cells = [substitutionCell(expected: "가", actual: "거")]
        let items = PronunciationDifficultyAggregator.aggregate(
            cells: cells,
            expectedAll: [syl("가")]
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].rank, 1)
        XCTAssertEqual(items[0].category, .vowelError)
        XCTAssertEqual(items[0].title, "모음 오류")
        XCTAssertEqual(items[0].errorCount, 1)
    }

    func testTopThreeLimit() {
        // 한 cell 에서 모음+초성+종성 차이가 모두 잡혀 카테고리 3종 이상 등장.
        // 다시 두 cell 의 분류를 합쳐도 최종 노출은 상위 3개로 제한.
        let cell1 = substitutionCell(expected: "각", actual: "넉") // 초성+모음+종성 모두 변경
        let cell2 = substitutionCell(expected: "각", actual: "막") // 초성 비음화 후보
        let items = PronunciationDifficultyAggregator.aggregate(
            cells: [cell1, cell2],
            expectedAll: [syl("각"), syl("각")]
        )
        XCTAssertLessThanOrEqual(items.count, 3)
        XCTAssertGreaterThan(items.count, 0)
    }

    func testRankOrderingByFrequency() {
        // 같은 카테고리(모음 오류) 가 2번, 다른 카테고리(탈락) 가 1번.
        // → rank 1: vowelError(2), rank 2: dropout(1)
        let cells = [
            substitutionCell(expected: "가", actual: "거", expectedIndex: 0, actualIndex: 0),
            substitutionCell(expected: "나", actual: "너", expectedIndex: 1, actualIndex: 1),
            droppedCell("다", expectedIndex: 2)
        ]
        let items = PronunciationDifficultyAggregator.aggregate(
            cells: cells,
            expectedAll: [syl("가"), syl("나"), syl("다")]
        )
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].category, .vowelError)
        XCTAssertEqual(items[0].rank, 1)
        XCTAssertEqual(items[0].errorCount, 2)
        XCTAssertEqual(items[1].category, .dropout)
        XCTAssertEqual(items[1].rank, 2)
        XCTAssertEqual(items[1].errorCount, 1)
    }

    // MARK: - 표시 데이터

    func testEachItemHasFallbackImageName() {
        // 디자인 자산이 카테고리별로 분리될 때까지 모두 error_img_1 fallback.
        let cells = [
            substitutionCell(expected: "가", actual: "거"),
            droppedCell("나", expectedIndex: 1)
        ]
        let items = PronunciationDifficultyAggregator.aggregate(
            cells: cells,
            expectedAll: [syl("가"), syl("나")]
        )
        XCTAssertGreaterThan(items.count, 0)
        for item in items {
            XCTAssertEqual(item.imageName, "error_img_1",
                "사람 아이콘 자산이 카테고리별로 분리되기 전까진 모든 카테고리가 error_img_1")
        }
    }

    func testIdAndTitleMatchCategoryRawValue() {
        // id, title 은 PronunciationErrorCategory.rawValue 를 사용.
        // (popup 의 errorTypes 가 같은 rawValue 를 쓰기 때문에 매핑 회귀 감지)
        let cells = [substitutionCell(expected: "가", actual: "거")]
        let items = PronunciationDifficultyAggregator.aggregate(
            cells: cells,
            expectedAll: [syl("가")]
        )
        XCTAssertEqual(items.first?.id, PronunciationErrorCategory.vowelError.rawValue)
        XCTAssertEqual(items.first?.title, PronunciationErrorCategory.vowelError.rawValue)
    }

    // MARK: - 다중 카테고리 집계 정책 (개선 2)

    func testSingleCellWithMultipleJamoDiffsCountsEachCategory() {
        // 한 cell 의 자모가 여러 슬롯에서 다르면 classify 가 여러 카테고리를 돌려준다.
        // 정책: 그 모든 카테고리를 각각 +1 집계한다(중복 제거하지 않음).
        // "강"(ㄱㅏㅇ) vs "건"(ㄱㅓㄴ): 중성(ㅏ→ㅓ)·종성(ㅇ→ㄴ) 두 슬롯이 다름.
        //   → vowelError + 종성 카테고리 = 서로 다른 2개 카테고리, 각 errorCount 1.
        let cells = [substitutionCell(expected: "강", actual: "건")]
        let items = PronunciationDifficultyAggregator.aggregate(
            cells: cells,
            expectedAll: [syl("강")]
        )
        XCTAssertEqual(items.count, 2,
            "한 cell 의 자모 슬롯별 오류가 각각 다른 카테고리로 집계되어야 함")
        XCTAssertEqual(items.reduce(0) { $0 + $1.errorCount }, 2,
            "다중 카테고리 cell 의 총 집계는 슬롯 오류 수와 같아야 함(슬롯당 1)")
        XCTAssertTrue(items.contains { $0.category == .vowelError },
            "중성 차이가 모음 오류로 집계되지 않음")
    }

    func testSameCategoryAcrossCellsAccumulates() {
        // 서로 다른 cell 에서 같은 카테고리(모음 오류)가 반복되면 errorCount 누적.
        let cells = [
            substitutionCell(expected: "가", actual: "거", expectedIndex: 0, actualIndex: 0),
            substitutionCell(expected: "나", actual: "너", expectedIndex: 1, actualIndex: 1),
            substitutionCell(expected: "다", actual: "더", expectedIndex: 2, actualIndex: 2)
        ]
        let items = PronunciationDifficultyAggregator.aggregate(
            cells: cells,
            expectedAll: [syl("가"), syl("나"), syl("다")]
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].category, .vowelError)
        XCTAssertEqual(items[0].errorCount, 3)
    }

    // MARK: - 순위 배지 색상 (rank 기준)

    /// 빈도가 서로 달라 1·2·3위가 명확히 갈리는 입력.
    ///   vowelError(3) > dropout(2) > finalTensification(1)
    /// 색은 카테고리가 아니라 "순위" 로 부여되므로 어떤 카테고리가 오든
    /// 1위=#FFA0A0, 2위=#FFF79E, 3위=#B2B8FF 로 고정되어야 한다.
    private func rankColorFixtureItems() -> [PronunciationDifficultyResult] {
        let cells: [AlignmentCell] = [
            substitutionCell(expected: "가", actual: "거"),   // vowelError
            substitutionCell(expected: "가", actual: "거"),   // vowelError
            substitutionCell(expected: "가", actual: "거"),   // vowelError
            droppedCell("나", expectedIndex: 1),              // dropout
            droppedCell("나", expectedIndex: 1),              // dropout
            substitutionCell(expected: "각", actual: "간")    // finalTensification
        ]
        return PronunciationDifficultyAggregator.aggregate(
            cells: cells,
            expectedAll: [syl("가")]
        )
    }

    func testRankBadgeColorFollowsRankNotCategory() {
        let items = rankColorFixtureItems()
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].rank, 1)
        XCTAssertEqual(items[0].accentColorHex, "#FFA0A0", "1위는 빨강(#FFA0A0)")
        XCTAssertEqual(items[1].rank, 2)
        XCTAssertEqual(items[1].accentColorHex, "#FFF79E", "2위는 노랑(#FFF79E)")
        XCTAssertEqual(items[2].rank, 3)
        XCTAssertEqual(items[2].accentColorHex, "#B2B8FF", "3위는 파랑(#B2B8FF)")
    }

    func testTopThreeColorsAreAllDistinct() {
        // 회귀 방지: 카테고리별 색을 쓰던 과거 구현은 같은 슬롯 카테고리가 둘
        // 노출되면 1위·3위가 같은 색이 됐다(예: 탈락·초성연음화 모두 빨강).
        // 순위 기준 색은 상위 3개가 항상 서로 다른 색이어야 한다.
        let hexes = rankColorFixtureItems().map(\.accentColorHex)
        XCTAssertEqual(Set(hexes).count, hexes.count, "상위 3개 배지 색은 모두 달라야 한다")
    }

    func testAccentColorMatchesHex() {
        // accentColor(Color) 가 accentColorHex 로부터 파생되는지 확인.
        let item = rankColorFixtureItems()[0]
        XCTAssertEqual(item.accentColor, Color(hex: item.accentColorHex))
    }

    // MARK: - 동률 결정성 (회귀 가드)

    func testTieBreakIsDeterministic() {
        // vowelError(1) 과 dropout(1) 이 동률. 입력이 같으면 출력 순서/내용도
        // 항상 같아야 한다(Dictionary 순회 무작위성에 영향받지 않음).
        let cells: [AlignmentCell] = [
            substitutionCell(expected: "가", actual: "거"),   // vowelError
            droppedCell("나", expectedIndex: 1)               // dropout
        ]
        let run1 = PronunciationDifficultyAggregator.aggregate(cells: cells, expectedAll: [syl("가")])
        let run2 = PronunciationDifficultyAggregator.aggregate(cells: cells, expectedAll: [syl("가")])
        XCTAssertEqual(run1.map(\.category), run2.map(\.category), "동률이라도 순서가 결정적이어야 함")
        XCTAssertEqual(run1.map(\.rank), [1, 2], "동률이어도 순위는 1·2 로 구분 부여")
    }
}
