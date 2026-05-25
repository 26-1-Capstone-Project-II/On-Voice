//
//  PronunciationScriptAnalysisServiceTests.swift
//  OnVoiceTests
//
//  Whisper phonetic 전사 + Apple ASR 의도 텍스트를 받아 PronunciationErrorScript
//  를 채우는 분석 서비스의 핵심 매핑 동작 검증. 특히 segment 경계에서 gap cell 이
//  어떻게 부착되는지, intentText 가 없을 때 분석이 비활성화되는지에 집중한다.
//

import XCTest
@testable import OnVoice

final class PronunciationScriptAnalysisServiceTests: XCTestCase {

    private let service = PronunciationScriptAnalysisService()

    private func script(_ segments: [String]) -> PronunciationErrorScript {
        PronunciationErrorScript.makePlainScript(from: segments)
    }

    // MARK: - intentText 없음

    func testReturnsInputUntouchedWhenIntentTextIsNil() async {
        let input = script(["오느른 날씨가 좋다"])
        let result = await service.analyze(phoneticScript: input, intentText: nil)
        // intentText 가 없으면 비교 불가 — 입력 그대로 반환되고 errorDetail 은 없음.
        XCTAssertEqual(result.sentences.count, 1)
        XCTAssertNil(result.sentences[0].errorDetail)
    }

    func testReturnsInputUntouchedWhenIntentTextIsBlank() async {
        let input = script(["오느른"])
        let result = await service.analyze(phoneticScript: input, intentText: "   ")
        XCTAssertNil(result.sentences[0].errorDetail)
    }

    // MARK: - 동일 발음(오류 없음)

    func testNoErrorWhenHypMatchesG2POutput() async {
        // intent: "오늘은" → G2P → "오느른" (받침 ㄹ 연음).
        // hyp 도 동일하게 "오느른" 이면 오류 없음.
        let input = script(["오느른"])
        let result = await service.analyze(phoneticScript: input, intentText: "오늘은")
        XCTAssertNil(result.sentences[0].errorDetail)
    }

    // MARK: - 음절 단위 오류 색칠

    func testHighlightsOnlyMismatchedSyllable() async {
        // intent: "학교" → G2P → "학꾜". hyp: "학교" (경음화 미적용)
        // 두 번째 음절 초성만 다름 → "교" 만 빨강
        let input = script(["학교"])
        let result = await service.analyze(phoneticScript: input, intentText: "학교")
        let sentence = result.sentences[0]
        XCTAssertNotNil(sentence.errorDetail)
        // segments 안에 error status 가 있는 segment 가 정확히 하나 있고, 그 텍스트가 "교".
        let errorSegments = sentence.segments.filter { $0.status == .error }
        XCTAssertEqual(errorSegments.count, 1)
        XCTAssertEqual(errorSegments.first?.text, "교")
    }

    // MARK: - 여러 segment 매핑

    func testMultipleSegmentsKeepErrorScoped() async {
        // 두 segment. 첫 segment 만 오류, 두 번째는 정확.
        let input = script(["학교", "오느른"])
        let result = await service.analyze(phoneticScript: input, intentText: "학교 오늘은")
        XCTAssertEqual(result.sentences.count, 2)
        XCTAssertNotNil(result.sentences[0].errorDetail)
        XCTAssertNil(result.sentences[1].errorDetail)
    }

    // MARK: - 첫 cell 이 expected-only gap 인 경계 케이스

    func testFirstCellExpectedOnlyGapHandledSafely() async {
        // intent: "안녕하세요" (5음절) vs hyp: "녕하세요" (4음절, 첫 음절 누락)
        // → 첫 cell 이 expected-only gap. errorDetail 은 popup 안내용으로 생성되지만,
        //   메인 스크립트에는 잘못된 빨강 색칠이 주입되지 않아야 한다.
        let input = script(["녕하세요"])
        let result = await service.analyze(phoneticScript: input, intentText: "안녕하세요")
        let sentence = result.sentences[0]
        // errorDetail 은 누락 음절을 popup 에 표시하기 위해 생성됨
        XCTAssertNotNil(sentence.errorDetail)
        let joined = sentence.segments.map(\.text).joined()
        XCTAssertEqual(joined, "녕하세요 ")
        // 메인 스크립트 색칠은 normal 만 (오탐 없음)
        XCTAssertTrue(sentence.segments.allSatisfy { $0.status == .normal })
    }

    // MARK: - 공백/구두점 포함

    func testWhitespaceAndPunctuationDoNotMarkErrors() async {
        // intent / hyp 둘 다 공백/마침표 위치까지 동일하면 비-한글 차이는 색칠되지 않는다.
        let input = script(["오느른, 식땅에 가."])
        let result = await service.analyze(phoneticScript: input, intentText: "오늘은, 식당에 가.")
        XCTAssertNil(result.sentences[0].errorDetail)
    }

    func testInterWordLinkingNotMarkedAsError() async {
        // intent "고척 에서" → G2P → "고처 게서" (어절 사이 연음).
        // hyp 가 "고처 게서" 면 오류 없음.
        let input = script(["고처 게서"])
        let result = await service.analyze(phoneticScript: input, intentText: "고척 에서")
        XCTAssertNil(result.sentences[0].errorDetail)
    }

    // MARK: - 누락 음절 errorDetail 보존

    func testDroppedSyllablePreservesErrorDetailForPopup() async {
        // intent: "안녕하세요" (5음절) vs hyp: "녕하세요" (4음절).
        // hyp 측에 색칠 자리는 없지만 정답 발음을 popup 으로 보여줘야 하므로
        // errorDetail 이 생성되어야 한다.
        let input = script(["녕하세요"])
        let result = await service.analyze(phoneticScript: input, intentText: "안녕하세요")
        let sentence = result.sentences[0]
        XCTAssertNotNil(sentence.errorDetail)
        // 메인 스크립트 텍스트는 그대로(누락된 음절을 잘못 색칠하지 않음)
        XCTAssertTrue(sentence.segments.allSatisfy { $0.status == .normal })
        // popup 의 correctSegments 에 누락된 음절을 포함한 ref 발음이 포함되어야 한다.
        let correctText = sentence.errorDetail?.correctSegments.map(\.text).joined() ?? ""
        XCTAssertTrue(correctText.contains("안"))
    }

    func testMultipleDroppedSyllablesProduceErrorDetail() async {
        // intent: "오늘은 학교에 갔어요" vs hyp: "학교에 갔어요" (앞 2어절 누락).
        // 누락 음절이 여러 개여도 한 segment 의 errorDetail 로 정확히 채워진다.
        let input = script(["학꾜에 가써요"])
        let result = await service.analyze(
            phoneticScript: input,
            intentText: "오늘은 학교에 갔어요"
        )
        let sentence = result.sentences[0]
        XCTAssertNotNil(sentence.errorDetail)
    }

    // MARK: - 비-한글 segment

    func testAllPunctuationSegmentNotMarkedAsError() async {
        // segment 가 전부 비-한글이면 분류/색칠 대상 자체가 없어 오류 없음.
        let input = script(["..."])
        let result = await service.analyze(phoneticScript: input, intentText: "...")
        XCTAssertNil(result.sentences[0].errorDetail)
    }
}
