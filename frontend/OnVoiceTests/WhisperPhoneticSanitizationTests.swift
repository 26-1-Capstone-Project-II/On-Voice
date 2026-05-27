//
//  WhisperPhoneticSanitizationTests.swift
//  OnVoiceTests
//
//  WhisperPhoneticTranscriptionService.sanitizePhoneticOutput 의 회귀 방지.
//  fine-tuned Whisper-tiny 가 가끔 흘리는 비완성 자모/대체문자가 화면에 □(tofu)
//  로 보이는 회귀를 막기 위한 검증.
//

import XCTest
@testable import OnVoice

final class WhisperPhoneticSanitizationTests: XCTestCase {

    // MARK: - 정상 한글 통과

    func testKeepsPlainHangulIntact() {
        let input = "오늘은 키움 히어로즈랑 경기를 한다"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, input)
    }

    func testKeepsPunctuationAndDigits() {
        let input = "오대오 동점, 5-5. 정말?"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, input)
    }

    // MARK: - NFC 결합

    func testCombinesAdjacentModernJamoIntoSyllable() {
        // U+110C (ᄌ) + U+1167 (ᅧ) → NFC 후 "져" (U+C838) 한 글자.
        // BPE 디코더가 음절을 자모 단위로 흘리는 가장 흔한 케이스.
        let input = "막떤\u{110C}\u{1167}서"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, "막떤져서")
    }

    // MARK: - 고아 자모 제거

    func testRemovesOrphanCompatibilityJamo() {
        // 호환 자모 단독 "ㅈ"(U+3148), "ㅕ"(U+3155) 는 음절로 합쳐지지 않으므로 제거.
        let input = "막떤\u{3148}\u{3155}서"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, "막떤서",
            "호환 자모가 보존되면 폰트가 못 그리는 □ tofu 박스로 표시됨")
    }

    func testRemovesOrphanModernJamoLeftovers() {
        // U+1100 (ᄀ) 단독은 결합할 V 가 없으면 NFC 가 합치지 못함 → 제거.
        let input = "안녕\u{1100}하세요"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, "안녕하세요")
    }

    // MARK: - 대체문자/제어 제거

    func testRemovesReplacementCharacter() {
        let input = "막떤\u{FFFD}서"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, "막떤서")
    }

    func testRemovesControlCharsExceptTabAndNewline() {
        // \r 은 제거, \t / \n 은 보존.
        let input = "한\u{0000}글\r보존\t유\n지"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, "한글보존\t유\n지")
    }

    func testRemovesPrivateUseAreaChars() {
        // 사설 영역(U+E000-) 은 폰트마다 다르게 그려져 안정성을 해치므로 제거.
        let input = "발음\u{E000}연습"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, "발음연습")
    }

    func testRemovesZeroWidthFormatChars() {
        // ZWJ(U+200D), ZWNJ(U+200C) 같은 포맷 코드는 음운에 무의미하니 제거.
        let input = "한\u{200D}국\u{200C}어"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, "한국어")
    }

    // MARK: - 빈 결과 / 트림

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(""), "")
    }

    func testAllInvalidCharsReturnsEmpty() {
        let input = "\u{FFFD}\u{3148}\u{200D}"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, "")
    }
}
