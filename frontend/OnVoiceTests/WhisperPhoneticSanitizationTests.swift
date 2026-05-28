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

    // MARK: - 손실 방지 (개선 4) — 정상 ASR 출력은 절대 깎이지 않아야 한다

    func testDoesNotStripLatinDigitMixedSpeech() {
        // 영문·숫자 혼합 발화(예: "GPT4 모델 5점") 가 그대로 보존되는지.
        let input = "GPT4 모델 5점 받았어요"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, input)
    }

    func testPreservesCommonSymbols() {
        // 퍼센트/물결/말줄임표/가운뎃점 등 일반 구두점·기호는 보존.
        let input = "정확도 95% 정도… 거의 다 맞췄어~"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, input)
    }

    func testPreservesEmoji() {
        // 이모지는 제어/포맷/사설영역이 아니므로 보존(과도한 제거 방지).
        // ASR 결과가 손실되지 않는다는 정책을 고정한다.
        let input = "잘했어요 👍 발음 좋아요 🎉"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, input)
    }

    func testPreservesMixedWhitespaceLayout() {
        // 공백/탭/줄바꿈이 섞인 레이아웃을 망가뜨리지 않는다(제어문자만 골라 제거).
        let input = "첫째 줄\n둘째\t줄  세 칸"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, input)
    }

    func testKeepsHalfwidthAndFullwidthDigits() {
        // 반각(5:5) + 전각(５) 숫자 모두 보존. 전각도 decimalNumber 라 통과.
        let input = "오대오 5:5 동점 ５"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, input)
    }

    func testOnlyDropsTargetedCharsInLongSentence() {
        // 긴 정상 문장 중간에 고아 자모 하나만 끼었을 때, 그 한 글자만 빠지고
        // 나머지 음절은 전부 보존되는지(과도한 절단이 없는지).
        let input = "오늘은 키움 히어로즈랑 고척에서\u{3148} 경기를 한다"
        let expected = "오늘은 키움 히어로즈랑 고척에서 경기를 한다"
        let out = WhisperPhoneticTranscriptionService.sanitizePhoneticOutput(input)
        XCTAssertEqual(out, expected)
    }
}
