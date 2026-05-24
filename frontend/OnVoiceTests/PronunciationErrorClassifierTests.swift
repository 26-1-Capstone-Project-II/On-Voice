//
//  PronunciationErrorClassifierTests.swift
//  OnVoiceTests
//
//  10종 오류 분류기의 패턴 매칭이 의도대로 동작하는지 회귀 방지.
//  특히 finalLinking 이 G2P 연음 패턴이 명확한 경우에만 잡히는지 검증한다.
//

import XCTest
@testable import OnVoice

final class PronunciationErrorClassifierTests: XCTestCase {

    private func syl(_ ch: Character) -> HangulJamo.Syllable {
        HangulJamo.decompose(ch)
    }

    private func cell(
        expected: Character?,
        actual: Character?
    ) -> AlignmentCell {
        let exp = expected.map { syl($0) }
        let act = actual.map { syl($0) }
        var diffs: [JamoDifference] = []
        if let e = exp, let a = act, e.isHangul, a.isHangul {
            if e.initialIndex != a.initialIndex {
                diffs.append(.init(slot: .initial, expected: e.initial, actual: a.initial))
            }
            if e.medialIndex != a.medialIndex {
                diffs.append(.init(slot: .medial, expected: e.medial, actual: a.medial))
            }
            if e.finalIndex != a.finalIndex {
                diffs.append(.init(slot: .final, expected: e.final, actual: a.final))
            }
        }
        return AlignmentCell(
            expected: exp,
            actual: act,
            expectedIndex: expected != nil ? 0 : nil,
            actualIndex: actual != nil ? 0 : nil,
            differences: diffs
        )
    }

    // MARK: - 탈락

    func testDropoutWhenActualMissing() {
        let c = cell(expected: "가", actual: nil)
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: nil),
            [.dropout]
        )
    }

    // MARK: - 모음 오류

    func testVowelError() {
        // 가 vs 거 — 중성만 다름
        let c = cell(expected: "가", actual: "거")
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: nil),
            [.vowelError]
        )
    }

    // MARK: - 초성 경음화

    func testInitialTensification() {
        // 까 vs 가 — ㄲ ↔ ㄱ
        let c = cell(expected: "까", actual: "가")
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: nil),
            [.initialTensification]
        )
    }

    // MARK: - 초성 구개음화

    func testInitialPalatalizationOnlyBeforeI() {
        // 지 vs 디 — ㄷ↔ㅈ, 중성 ㅣ
        let c = cell(expected: "지", actual: "디")
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: nil),
            [.initialPalatalization]
        )
    }

    func testInitialDjPairWithoutIFallsThroughToDropout() {
        // 자 vs 다 — ㄷ↔ㅈ, 중성 ㅏ (ㅣ 아님) → 구개음화 아님
        let c = cell(expected: "자", actual: "다")
        let result = PronunciationErrorClassifier.classify(cell: c, nextExpected: nil)
        XCTAssertNotEqual(result, [.initialPalatalization])
    }

    // MARK: - 초성 비음화

    func testInitialNasalizationNR() {
        // 나 vs 라 — ㄴ↔ㄹ
        let c = cell(expected: "나", actual: "라")
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: nil),
            [.initialNasalization]
        )
    }

    // MARK: - 초성 연음화

    func testInitialLinking() {
        // ref 초성 ㄱ (받침이 옮겨온 상태), hyp 초성 ㅇ — 연음 실패 패턴
        let c = cell(expected: "거", actual: "어")
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: nil),
            [.initialLinking]
        )
    }

    // MARK: - 종성 연음화 (좁힌 조건 검증)

    func testFinalLinkingPositive() {
        // ref: "으" 종성 0 ↔ hyp: "음" 종성 ㅁ. nextExpected: "막" 초성 ㅁ.
        // hyp 의 ㅁ 받침이 다음 ref 초성과 일치 → finalLinking
        let c = cell(expected: "으", actual: "음")
        let next = syl("막")
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: next),
            [.finalLinking]
        )
    }

    func testFinalLinkingNegativeWhenNextInitialMismatch() {
        // ref: "으" 종성 0 ↔ hyp: "음". nextExpected: "악" 초성 ㅇ
        // → 연음 패턴 아님. finalLinking 으로 잡히면 안 된다.
        let c = cell(expected: "으", actual: "음")
        let next = syl("악")
        let result = PronunciationErrorClassifier.classify(cell: c, nextExpected: next)
        XCTAssertNotEqual(result, [.finalLinking])
    }

    func testFinalLinkingNegativeWhenNoNext() {
        // 다음 음절이 없으면 연음 판정 불가 → dropout 등으로 fallback
        let c = cell(expected: "으", actual: "음")
        let result = PronunciationErrorClassifier.classify(cell: c, nextExpected: nil)
        XCTAssertNotEqual(result, [.finalLinking])
    }

    // MARK: - 종성 비음화

    func testFinalNasalization() {
        // ref: "궁" 종성 ㅇ ↔ hyp: "국" 종성 ㄱ — ㄱ↔ㅇ 쌍
        let c = cell(expected: "궁", actual: "국")
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: nil),
            [.finalNasalization]
        )
    }

    // MARK: - 종성 구개음화

    func testFinalPalatalization() {
        // ref: "가" 종성 0 ↔ hyp: "갇" 종성 ㄷ. next: "이" 중성 ㅣ
        let c = cell(expected: "가", actual: "갇")
        let next = syl("이")
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: next),
            [.finalPalatalization]
        )
    }

    // MARK: - 종성 경음화

    func testFinalTensification() {
        // ref: "학" 종성 ㄱ ↔ hyp: "하" 종성 0 — ref 폐쇄음 받침이 변형/소실
        let c = cell(expected: "학", actual: "하")
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: nil),
            [.finalTensification]
        )
    }

    // MARK: - 비-한글 cell

    func testNonHangulSyllableProducesNoCategory() {
        let c = cell(expected: " ", actual: " ")
        XCTAssertEqual(
            PronunciationErrorClassifier.classify(cell: c, nextExpected: nil),
            []
        )
    }
}
