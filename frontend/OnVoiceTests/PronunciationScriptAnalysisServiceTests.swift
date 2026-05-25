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
        // → 첫 cell 이 expected-only gap. 누락된 음절은 hyp 상에 빨강으로 표시할
        //   자리가 없어 errorDetail 은 만들어지지 않으며, segment 텍스트는 그대로 유지.
        //   첫 segment 에 오탐(잘못된 빨강 색칠) 이 주입되지 않는지 검증.
        let input = script(["녕하세요"])
        let result = await service.analyze(phoneticScript: input, intentText: "안녕하세요")
        let sentence = result.sentences[0]
        XCTAssertNil(sentence.errorDetail)
        let joined = sentence.segments.map(\.text).joined()
        XCTAssertEqual(joined, "녕하세요 ")
        // 색칠된 segment 가 없어야 함 (전부 normal)
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
}
