//
//  PronunciationSummaryCommentGeneratorTests.swift
//  OnVoiceTests
//
//  요약 코멘트 생성기의 두 분기 — 카테고리 기반 매핑과 등급 기반 fallback — 가
//  의도된 코멘트를 돌려주는지 검증.
//

import XCTest
@testable import OnVoice

final class PronunciationSummaryCommentGeneratorTests: XCTestCase {

    private func difficulty(_ category: PronunciationErrorCategory) -> PronunciationDifficultyResult {
        PronunciationDifficultyResult(
            id: category.rawValue,
            rank: 1,
            category: category,
            title: category.rawValue,
            subtitle: "",
            practiceTitle: "",
            guideText: "",
            accentColorHex: "#FFA0A0",
            imageName: "error_img_1",
            errorCount: 1
        )
    }

    // MARK: - 카테고리 기반

    func testFinalCategoriesReturnDistinctComments() {
        // 종성 4종은 각각 고유한 받침 안내 코멘트를 가져야 한다.
        // (과거엔 4종이 하나의 공통 "받침" 코멘트로 합쳐져 있었음 — #116에서 분리)
        let finals: [PronunciationErrorCategory] = [
            .finalTensification, .finalPalatalization,
            .finalNasalization, .finalLinking
        ]
        var seen: Set<String> = []
        for category in finals {
            let comment = PronunciationSummaryCommentGenerator.generate(
                topItem: difficulty(category),
                level: .middle
            )
            XCTAssertTrue(comment.contains("받침"),
                "카테고리 \(category) → 받침 안내가 빠짐")
            XCTAssertFalse(seen.contains(comment),
                "카테고리 \(category) 코멘트가 다른 종성 카테고리와 중복됨")
            seen.insert(comment)
        }
        XCTAssertEqual(seen.count, finals.count, "종성 4종 코멘트가 서로 구별되지 않음")
    }

    func testReturnsVowelComment() {
        let comment = PronunciationSummaryCommentGenerator.generate(
            topItem: difficulty(.vowelError),
            level: .middle
        )
        XCTAssertTrue(comment.contains("모음"))
    }

    func testReturnsDropoutComment() {
        let comment = PronunciationSummaryCommentGenerator.generate(
            topItem: difficulty(.dropout),
            level: .middle
        )
        XCTAssertTrue(comment.contains("빠뜨리"))
    }

    func testReturnsInitialTensificationComment() {
        let comment = PronunciationSummaryCommentGenerator.generate(
            topItem: difficulty(.initialTensification),
            level: .middle
        )
        XCTAssertTrue(comment.contains("된소리") || comment.contains("경음"))
    }

    // MARK: - 등급 기반 fallback

    func testFallbackUsesLevelWhenTopItemNil() {
        let lowComment = PronunciationSummaryCommentGenerator.generate(topItem: nil, level: .low)
        let middleComment = PronunciationSummaryCommentGenerator.generate(topItem: nil, level: .middle)
        let highComment = PronunciationSummaryCommentGenerator.generate(topItem: nil, level: .high)
        XCTAssertNotEqual(lowComment, middleComment)
        XCTAssertNotEqual(middleComment, highComment)
        XCTAssertNotEqual(lowComment, highComment)
    }

    func testHighLevelFallbackIsPositive() {
        // 오류 0건 + high 등급은 칭찬성 fallback 코멘트로.
        let comment = PronunciationSummaryCommentGenerator.generate(topItem: nil, level: .high)
        XCTAssertTrue(comment.contains("자연스럽") || comment.contains("안정적"),
            "high 등급 fallback 이 칭찬 코멘트가 아님")
    }

    // MARK: - 우선순위

    func testTopItemTakesPrecedenceOverLevel() {
        // topItem 이 있으면 등급은 무시되어야 한다.
        let withVowel = PronunciationSummaryCommentGenerator.generate(
            topItem: difficulty(.vowelError),
            level: .high
        )
        let highFallback = PronunciationSummaryCommentGenerator.generate(
            topItem: nil,
            level: .high
        )
        XCTAssertNotEqual(withVowel, highFallback,
            "topItem 이 있는데 level fallback 으로 떨어짐")
    }
}
