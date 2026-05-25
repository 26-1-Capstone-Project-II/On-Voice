//
//  KoreanG2PTests.swift
//  OnVoiceTests
//
//  KoreanG2P 의 음운 규칙이 표준 발음 사례에 대해 의도대로 동작하는지 회귀 방지.
//

import XCTest
@testable import OnVoice

final class KoreanG2PTests: XCTestCase {

    // MARK: - 연음화

    func testLinkingWithinWord() {
        // 음악 → 으막 (받침 ㅁ 이 다음 음절 초성으로 이동)
        XCTAssertEqual(KoreanG2P.apply("음악").phoneticText, "으막")
    }

    func testLinkingAcrossWhitespace() {
        // 어절 사이에서도 연음 인정: "고척 에서" → "고처 게서"
        XCTAssertEqual(KoreanG2P.apply("고척 에서").phoneticText, "고처 게서")
    }

    func testLinkingClusterFinal() {
        // 겹받침 ㄺ 연음: "읽어" → "일거" (앞자모 ㄹ 은 받침에 남고 뒤자모 ㄱ 이 이동)
        XCTAssertEqual(KoreanG2P.apply("읽어").phoneticText, "일거")
    }

    // MARK: - 비음화

    func testNasalizationStopBeforeNasal() {
        // 국물 → 궁물 (ㄱ + ㅁ → ㅇ + ㅁ)
        XCTAssertEqual(KoreanG2P.apply("국물").phoneticText, "궁물")
    }

    func testNasalizationBOverNasal() {
        // 합니다 → 함니다 (ㅂ + ㄴ → ㅁ + ㄴ)
        XCTAssertEqual(KoreanG2P.apply("합니다").phoneticText, "함니다")
    }

    // MARK: - 경음화

    func testTensification() {
        // 학교 → 학꾜 (ㄱ 받침 + ㄱ 초성 → 받침 그대로 + 초성 ㄲ)
        XCTAssertEqual(KoreanG2P.apply("학교").phoneticText, "학꾜")
    }

    func testTensificationGukbap() {
        // 국밥 → 국빱
        XCTAssertEqual(KoreanG2P.apply("국밥").phoneticText, "국빱")
    }

    // MARK: - 구개음화

    func testPalatalization() {
        // 같이 → 가치 (ㅌ + ㅣ → ㅊ + 이, 받침 ㅌ 소실)
        XCTAssertEqual(KoreanG2P.apply("같이").phoneticText, "가치")
    }

    func testPalatalizationGudi() {
        // 굳이 → 구지 (ㄷ + ㅣ → ㅈ + 이)
        XCTAssertEqual(KoreanG2P.apply("굳이").phoneticText, "구지")
    }

    // MARK: - 격음화 (겹받침 포함)

    func testAspirationAfterFinalH() {
        // 좋다 → 조타 (받침 ㅎ + ㄷ 초성 → 받침 0 + 초성 ㅌ)
        XCTAssertEqual(KoreanG2P.apply("좋다").phoneticText, "조타")
    }

    func testAspirationBeforeInitialH() {
        // 입학 → 이팍 (받침 ㅂ + ㅎ 초성 → 받침 0 + 초성 ㅍ)
        XCTAssertEqual(KoreanG2P.apply("입학").phoneticText, "이팍")
    }

    func testAspirationClusterRkH() {
        // 밝히다 → 발키다 (ㄺ + ㅎ → ㄹ 남기고 ㄱ 이 ㅋ 으로)
        XCTAssertEqual(KoreanG2P.apply("밝히다").phoneticText, "발키다")
    }

    func testAspirationClusterLbH() {
        // 넓히다 → 널피다 (ㄼ + ㅎ → ㄹ 남기고 ㅂ 이 ㅍ 으로)
        XCTAssertEqual(KoreanG2P.apply("넓히다").phoneticText, "널피다")
    }

    // MARK: - 종성 중화 (단어 끝)

    func testFinalNeutralizationOnlyAtEnd() {
        // 종성 중화는 한글 시퀀스 마지막 음절에만 적용된다.
        // "옆" → "엽" (ㅍ → ㅂ)
        XCTAssertEqual(KoreanG2P.apply("옆").phoneticText, "엽")
    }

    func testFinalNeutralizationNotMidWord() {
        // 받침 ㅌ 이 단어 중간에서는 연음으로 처리되어 중화되지 않음.
        // "같이" 중 받침 ㅌ 은 구개음화로 흡수되고 종성 중화로 ㄷ 이 되지 않는다.
        let result = KoreanG2P.apply("같이")
        XCTAssertEqual(result.phoneticText, "가치")
    }

    // MARK: - 비-한글 보존

    func testNonHangulPreserved() {
        // 공백/구두점은 그대로 유지
        XCTAssertEqual(KoreanG2P.apply("학교, 식당!").phoneticText, "학꾜, 식땅!")
    }

    func testEmptyInput() {
        XCTAssertEqual(KoreanG2P.apply("").phoneticText, "")
    }

    // MARK: - 적용 규칙 메타

    func testApplicationsContainRule() {
        let result = KoreanG2P.apply("학교")
        XCTAssertTrue(result.applications.contains { $0.rule == .tensification })
    }

    // MARK: - 규칙 충돌/우선순위

    func testLinkingPrecedesNeutralizationForClusterFinal() {
        // 닭이 → 달기 (받침 ㄺ + 초성 ㅇ + 모음 ㅣ).
        // 연음이 먼저 적용되어 ㄱ 이 다음 음절 초성으로 이동. 종성은 ㄹ 만 남음.
        // 종성 중화(ㄺ→ㄱ)가 먼저 적용되면 "닥이" → "다기" 가 되어 표준과 다름.
        XCTAssertEqual(KoreanG2P.apply("닭이").phoneticText, "달기")
    }

    func testNasalizationOnClusterFinalBeforeNasalInitial() {
        // 닭만 → 당만 (ㄺ + ㅁ): ㄺ 을 평폐쇄음 ㄱ 으로 환산 후 비음화 ㄱ→ㅇ
        XCTAssertEqual(KoreanG2P.apply("닭만").phoneticText, "당만")
    }

    func testAspirationOnClusterFinalRk() {
        // 밝히다 → 발키다. 격음화가 받침 처리(ㄺ→ㄹ+ㅋ)를 정확히 분해해야 한다.
        XCTAssertEqual(KoreanG2P.apply("밝히다").phoneticText, "발키다")
    }

    func testPalatalizationPrecedesLinking() {
        // 밭이 → 바치. 구개음화가 연음보다 먼저 적용되어 ㅌ 이 ㅊ 으로 변형됨.
        // 연음만 적용되면 "바티" 가 되어 표준과 다름.
        XCTAssertEqual(KoreanG2P.apply("밭이").phoneticText, "바치")
    }

    func testNeutralizationOnlyAtFinalHangulPosition() {
        // 옆집 → 엽찝: 옆 받침 ㅍ 은 어절 사이 경음화 트리거로 평폐쇄음 ㅂ 으로 정리되고
        // 다음 음절 초성 ㅈ → ㅉ 으로 경음화된다. 마지막 음절 집 의 받침 ㅂ 은
        // 시퀀스 끝 중화 대상이라 ㅂ 그대로 유지된다.
        XCTAssertEqual(KoreanG2P.apply("옆집").phoneticText, "엽찝")
    }
}
