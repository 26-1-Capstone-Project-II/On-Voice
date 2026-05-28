//
//  PronunciationScriptSentenceSplitTests.swift
//  OnVoiceTests
//
//  스크립트 문장 분할(이슈 #106) 검증. 종결 부호 기준 분할과 예외 케이스
//  (소수점, 연속 종결 부호, 종결 부호 없음, 다중 segment) 를 고정한다.
//

import XCTest
@testable import OnVoice

final class PronunciationScriptSentenceSplitTests: XCTestCase {

    // MARK: - splitIntoSentences

    func testSplitsOnTerminators() {
        let result = PronunciationErrorScript.splitIntoSentences("안녕하세요. 반갑습니다! 잘 지내?")
        XCTAssertEqual(result, ["안녕하세요.", "반갑습니다!", "잘 지내?"])
    }

    func testNoTerminatorReturnsWholeAsOne() {
        let result = PronunciationErrorScript.splitIntoSentences("종결 부호가 없는 발화")
        XCTAssertEqual(result, ["종결 부호가 없는 발화"])
    }

    func testTrailingTextWithoutTerminatorKept() {
        // 마지막 문장에 종결 부호가 없어도 보존.
        let result = PronunciationErrorScript.splitIntoSentences("첫 문장이야. 두 번째는 안 끝났어")
        XCTAssertEqual(result, ["첫 문장이야.", "두 번째는 안 끝났어"])
    }

    func testEmptyOrWhitespaceReturnsEmpty() {
        XCTAssertEqual(PronunciationErrorScript.splitIntoSentences(""), [])
        XCTAssertEqual(PronunciationErrorScript.splitIntoSentences("   \n  "), [])
    }

    // MARK: - 예외: 소수점

    func testDecimalPointDoesNotSplit() {
        // 5.5 의 마침표는 문장 경계가 아니다.
        let result = PronunciationErrorScript.splitIntoSentences("점수는 5.5점이야. 다음")
        XCTAssertEqual(result, ["점수는 5.5점이야.", "다음"])
    }

    func testMultipleDecimalsNotSplit() {
        let result = PronunciationErrorScript.splitIntoSentences("3.14 그리고 2.71 이다")
        XCTAssertEqual(result, ["3.14 그리고 2.71 이다"])
    }

    // MARK: - 예외: 연속 종결 부호

    func testEllipsisTreatedAsSingleBoundary() {
        // "..." 가 빈/부호만 있는 조각을 만들지 않고 앞 문장에 흡수된다.
        let result = PronunciationErrorScript.splitIntoSentences("진짜야... 믿어줘")
        XCTAssertEqual(result, ["진짜야...", "믿어줘"])
    }

    func testConsecutiveMixedTerminators() {
        let result = PronunciationErrorScript.splitIntoSentences("정말?! 대박이야")
        XCTAssertEqual(result, ["정말?!", "대박이야"])
    }

    func testOnlyTerminatorsProducesSingleChunk() {
        // 부호만 있어도 빈 배열이 아니라 한 조각으로(데이터 손실 방지).
        let result = PronunciationErrorScript.splitIntoSentences("...")
        XCTAssertEqual(result, ["..."])
    }

    // MARK: - 한국어 종결어미 분할 (구두점 없는 음성 전사 대응, #106)

    func testSplitsKoreanPoliteEndingsWithoutPunctuation() {
        // Whisper phonetic 은 구두점이 없다. 정중체 종결(~네요/~까요/~요)로 분할.
        let result = PronunciationErrorScript.splitIntoSentences(
            "오늘 날씨가 맑네요 점심 먹을까요 카페가 좋아요"
        )
        XCTAssertEqual(result, ["오늘 날씨가 맑네요", "점심 먹을까요", "카페가 좋아요"])
    }

    func testSplitsFormalDeclarativeEnding() {
        // 형식체 ~ㅂ니다(다) 로 끝나는 토큰에서 분할.
        let result = PronunciationErrorScript.splitIntoSentences(
            "여행을 떠날 계획입니다 다시 연락드릴게요"
        )
        XCTAssertEqual(result, ["여행을 떠날 계획입니다", "다시 연락드릴게요"])
    }

    func testDoesNotSplitOnAkkaFalsePositive() {
        // "아까"(까로 끝나지만 종결 아님) 에서 잘못 분할되지 않아야 한다.
        // 까를 종결어미에서 제외한 핵심 회귀 케이스(야구 narration 스냅샷 보호).
        let result = PronunciationErrorScript.splitIntoSentences(
            "경기를 하는데 아까 점수를 냈다고"
        )
        XCTAssertEqual(result, ["경기를 하는데 아까 점수를 냈다고"])
    }

    func testDoesNotSplitOnConnectiveDago() {
        // "~다고"(고로 끝남) 는 종결이 아니므로 분할 안 됨.
        let result = PronunciationErrorScript.splitIntoSentences("먹는다고 했는데 안 왔어")
        XCTAssertEqual(result, ["먹는다고 했는데 안 왔어"])
    }

    func testCasualEndingStaysOneSentence() {
        // 반말 종결(어)은 의도적으로 제외 → 한 덩어리로 남는다(과분할 방지).
        let result = PronunciationErrorScript.splitIntoSentences("밥을 먹었어 집에 갔어")
        XCTAssertEqual(result, ["밥을 먹었어 집에 갔어"])
    }

    func testFinalSyllableInsideTokenDoesNotSplit() {
        // 종결어미 음절이 토큰 "끝"이 아니라 내부/앞에 있으면 분할되지 않아야 한다.
        // 요리(요 시작), 다리미(다 시작), 야구장(야 시작), 죠리퐁(죠 시작).
        let result = PronunciationErrorScript.splitIntoSentences(
            "요리사가 다리미로 야구장 죠리퐁 샀다"
        )
        XCTAssertEqual(result, ["요리사가 다리미로 야구장 죠리퐁 샀다"])
    }

    func testNumberUnitWithEndingSplitsOnlyAtEnding() {
        // 숫자+단위가 섞여도 종결어미로 끝나는 토큰에서만 분할.
        let result = PronunciationErrorScript.splitIntoSentences(
            "가격은 3천원이에요 수량은 5개입니다"
        )
        XCTAssertEqual(result, ["가격은 3천원이에요", "수량은 5개입니다"])
    }

    func testCollapsesMixedWhitespace() {
        // 연속 공백/탭/줄바꿈이 섞인 전사도 토큰 분리가 정상 동작.
        let result = PronunciationErrorScript.splitIntoSentences(
            "오늘은 맑아요\t그래서  좋아요\n끝"
        )
        XCTAssertEqual(result, ["오늘은 맑아요", "그래서 좋아요", "끝"])
    }

    func testTokenWithPunctuationAndEndingSplitsOnce() {
        // 한 토큰에 종결어미+구두점이 함께 있어도(좋아요.) 한 번만 경계 처리.
        let result = PronunciationErrorScript.splitIntoSentences("정말 좋아요. 다음 문장")
        XCTAssertEqual(result, ["정말 좋아요.", "다음 문장"])
    }

    // MARK: - 구어체 종결/연결 케이스 (리뷰 보강)

    func testSplitsColloquialPoliteEndings() {
        // "그래요"(요), "아니죠"(죠) 같은 구어체 정중 종결에서 분할.
        let result = PronunciationErrorScript.splitIntoSentences("그래요 아니죠 맞아요")
        XCTAssertEqual(result, ["그래요", "아니죠", "맞아요"])
    }

    func testConnectiveSeoDoesNotSplit() {
        // 연결어미 ~서/~해서(서로 끝남)는 문장 경계가 아니다.
        let result = PronunciationErrorScript.splitIntoSentences("비가 와서 우산을 챙겼어요")
        XCTAssertEqual(result, ["비가 와서 우산을 챙겼어요"])
    }

    func testConnectiveDagoMidSentenceDoesNotSplit() {
        // "~다고"(고로 끝남)가 문장 중간에 있어도 분할되지 않는다.
        let result = PronunciationErrorScript.splitIntoSentences("먹는다고 들었어요 정말요")
        XCTAssertEqual(result, ["먹는다고 들었어요", "정말요"])
    }

    // MARK: - makePlainScript 연계

    func testMakePlainScriptSplitsSingleSegmentIntoSentences() {
        // 한 Whisper segment 안에 세 문장 → 세 PronunciationTranscriptSentence.
        let script = PronunciationErrorScript.makePlainScript(
            from: ["오느른 날씨가 좋다. 그래서 산책했어. 기분 좋아!"]
        )
        XCTAssertEqual(script.sentences.count, 3)
        let joined = script.sentences.map { $0.segments.map(\.text).joined() }
        XCTAssertEqual(joined[0], "오느른 날씨가 좋다. ")
        XCTAssertEqual(joined[1], "그래서 산책했어. ")
        XCTAssertEqual(joined[2], "기분 좋아! ")
    }

    func testMakePlainScriptKeepsMultipleSegments() {
        // 여러 segment 각각이 다시 문장 분할된다.
        let script = PronunciationErrorScript.makePlainScript(
            from: ["첫 세그먼트. 두 문장.", "둘째 세그먼트"]
        )
        XCTAssertEqual(script.sentences.count, 3)
    }

    func testMakePlainScriptEmptyInputReturnsEmpty() {
        XCTAssertTrue(PronunciationErrorScript.makePlainScript(from: []).isEmpty)
        XCTAssertTrue(PronunciationErrorScript.makePlainScript(from: ["  ", ""]).isEmpty)
    }

    func testMakePlainScriptSingleSentenceUnchangedCount() {
        // 종결 부호 없는 단일 발화는 1문장 유지(기존 동작 회귀 방지).
        let script = PronunciationErrorScript.makePlainScript(from: ["학교 가는 길"])
        XCTAssertEqual(script.sentences.count, 1)
    }
}
