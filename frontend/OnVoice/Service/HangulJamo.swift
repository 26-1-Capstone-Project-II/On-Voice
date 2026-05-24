//
//  HangulJamo.swift
//  OnVoice
//
//  한글 음절 ↔ 자모(초/중/종) 변환 유틸. G2P와 자모 정렬 비교의 공통 토대.
//

import Foundation

enum HangulJamo {
    static let choseong: [Character] = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ",
        "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]

    static let jungseong: [Character] = [
        "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ",
        "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"
    ]

    /// 0번째 인덱스는 종성 없음.
    static let jongseong: [Character?] = [
        nil, "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ",
        "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ",
        "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]

    /// 분해된 한 음절. 한글 음절이 아닌 문자는 raw 로 보존한다.
    struct Syllable: Equatable {
        var initialIndex: Int      // 초성 index (0..<19) — 한글이 아니면 -1
        var medialIndex: Int       // 중성 index (0..<21) — 한글이 아니면 -1
        var finalIndex: Int        // 종성 index (0..<28, 0 = 없음) — 한글이 아니면 0
        var raw: Character?        // 한글이 아닐 때 원본 문자(공백/문장부호)를 그대로 보존

        var isHangul: Bool { raw == nil }

        /// 결합해 음절 문자열로 복원. 한글 음절이면 한 글자, 아니면 raw 문자 그대로.
        /// 인덱스를 정상 범위(초성 0..<19, 중성 0..<21, 종성 0..<28) 로 clamp 해
        /// scalar 가 항상 한글 영역(0xAC00..0xD7A3) 안에 떨어지도록 한다.
        /// 그래도 UnicodeScalar 가 nil 을 돌려주는 비정상 경로에서는 데이터를
        /// 조용히 잃지 않도록 가시적 placeholder("\u{FFFD}", 즉 �) 를 반환한다.
        var composed: String {
            if let raw {
                return String(raw)
            }
            let i = max(0, min(initialIndex, choseong.count - 1))
            let m = max(0, min(medialIndex, jungseong.count - 1))
            let f = max(0, min(finalIndex, jongseong.count - 1))
            let scalar = 0xAC00 + i * 21 * 28 + m * 28 + f
            guard let unicode = UnicodeScalar(scalar) else {
                assertionFailure("Invalid Hangul scalar composed: \(scalar) (initial=\(i), medial=\(m), final=\(f))")
                return "\u{FFFD}"  // U+FFFD REPLACEMENT CHARACTER — 데이터 손실을 가시화
            }
            return String(unicode)
        }

        var initial: Character? {
            guard isHangul, initialIndex >= 0 else { return nil }
            return choseong[initialIndex]
        }

        var medial: Character? {
            guard isHangul, medialIndex >= 0 else { return nil }
            return jungseong[medialIndex]
        }

        var final: Character? {
            guard isHangul, finalIndex > 0 else { return nil }
            return jongseong[finalIndex] ?? nil
        }

        static func nonHangul(_ ch: Character) -> Syllable {
            Syllable(initialIndex: -1, medialIndex: -1, finalIndex: 0, raw: ch)
        }
    }

    /// 한 글자를 Syllable 로 분해. 한글이 아니면 raw 유지.
    static func decompose(_ ch: Character) -> Syllable {
        guard let scalar = ch.unicodeScalars.first?.value,
              (0xAC00...0xD7A3).contains(scalar) else {
            return .nonHangul(ch)
        }
        let offset = Int(scalar) - 0xAC00
        let initial = offset / (21 * 28)
        let medial = (offset % (21 * 28)) / 28
        let final = offset % 28
        return Syllable(initialIndex: initial, medialIndex: medial, finalIndex: final, raw: nil)
    }

    /// 문자열 전체를 Syllable 배열로 분해.
    static func decompose(_ text: String) -> [Syllable] {
        text.map { decompose($0) }
    }

    /// Syllable 배열을 다시 문자열로 합성.
    static func compose(_ syllables: [Syllable]) -> String {
        syllables.map(\.composed).joined()
    }

    /// 종성 index → 초성 index 변환 (연음화에서 사용).
    /// 종성으로만 존재하는 자모(ㄳ, ㄵ 등 겹받침)는 onsetIndex(for:) 에서 별도 처리.
    static let jongToChoIndex: [Int: Int] = {
        var map: [Int: Int] = [:]
        for (jongIdx, jamo) in jongseong.enumerated() {
            guard let jamo else { continue }
            if let choIdx = choseong.firstIndex(of: jamo) {
                map[jongIdx] = choIdx
            }
        }
        return map
    }()

    /// 겹받침을 (앞자모 종성 index, 뒤자모 초성 index) 로 분해.
    /// 연음/비음/경음 규칙에서 뒤 자모만 다음 음절로 넘길 때 사용한다.
    /// 단순 받침은 nil 을 반환한다.
    static func splitCluster(jongIndex: Int) -> (leadingJong: Int, trailingCho: Int)? {
        // 종성 index → (남는 종성 index, 다음 음절 초성 index)
        switch jongIndex {
        case 3:  return (1, 9)   // ㄳ → ㄱ + ㅅ
        case 5:  return (4, 12)  // ㄵ → ㄴ + ㅈ
        case 6:  return (4, 18)  // ㄶ → ㄴ + ㅎ
        case 9:  return (8, 0)   // ㄺ → ㄹ + ㄱ
        case 10: return (8, 6)   // ㄻ → ㄹ + ㅁ
        case 11: return (8, 7)   // ㄼ → ㄹ + ㅂ
        case 12: return (8, 9)   // ㄽ → ㄹ + ㅅ
        case 13: return (8, 16)  // ㄾ → ㄹ + ㅌ
        case 14: return (8, 17)  // ㄿ → ㄹ + ㅍ
        case 15: return (8, 18)  // ㅀ → ㄹ + ㅎ
        case 18: return (17, 9)  // ㅄ → ㅂ + ㅅ
        default: return nil
        }
    }
}
