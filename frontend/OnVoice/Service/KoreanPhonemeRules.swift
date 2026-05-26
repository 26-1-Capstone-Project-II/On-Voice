//
//  KoreanPhonemeRules.swift
//  OnVoice
//
//  KoreanG2P 와 PronunciationErrorClassifier 가 공유하는 한국어 자모 변환 매핑.
//  두 모듈이 같은 source of truth 를 참조해야 G2P 가 적용한 발음 변화를
//  분류기가 같은 정의로 인식할 수 있다. 한쪽만 수정해 규칙이 어긋나는 회귀를 방지.
//
//  인덱스는 HangulJamo.choseong / jungseong / jongseong 배열의 위치를 가리킨다.
//

import Foundation

enum KoreanPhonemeRules {

    // MARK: - 초성 매핑

    /// 초성 평음 → 경음 (경음화)
    static let initialPlainToTense: [Int: Int] = [
        0: 1,    // ㄱ → ㄲ
        3: 4,    // ㄷ → ㄸ
        7: 8,    // ㅂ → ㅃ
        9: 10,   // ㅅ → ㅆ
        12: 13   // ㅈ → ㅉ
    ]

    /// 초성 평음 → 격음 (ㅎ 결합 시)
    static let initialPlainToAspirated: [Int: Int] = [
        0: 15,   // ㄱ → ㅋ
        3: 16,   // ㄷ → ㅌ
        7: 17,   // ㅂ → ㅍ
        12: 14   // ㅈ → ㅊ
    ]

    /// 초성 ㄷ↔ㅈ, ㅌ↔ㅊ (구개음화 쌍)
    static let initialPalatalPairs: [Int: Int] = [
        3: 12,   // ㄷ → ㅈ
        16: 14   // ㅌ → ㅊ
    ]

    /// 초성 인덱스
    static let initialN  = 2   // ㄴ
    static let initialR  = 5   // ㄹ
    static let initialO  = 11  // ㅇ
    static let initialH  = 18  // ㅎ

    /// 중성 ㅣ
    static let medialI = 20

    // MARK: - 종성 매핑

    /// 종성 평폐쇄음 → 같은 위치 비음 (ㄱ→ㅇ, ㄷ→ㄴ, ㅂ→ㅁ)
    static let finalStopToNasal: [Int: Int] = [
        1: 21,   // ㄱ → ㅇ
        7: 4,    // ㄷ → ㄴ
        17: 16   // ㅂ → ㅁ
    ]

    /// 종성 평폐쇄음화(중화): ㄲ/ㅋ → ㄱ, ㅅ/ㅆ/ㅈ/ㅊ/ㅌ/ㅎ → ㄷ, ㅍ → ㅂ
    /// G2P 가 단어 끝에서 적용하고, classifier 가 hyp 측 종성을 정렬할 때도 사용한다.
    static let finalNeutralization: [Int: Int] = [
        2: 1,    // ㄲ → ㄱ
        24: 1,   // ㅋ → ㄱ
        19: 7,   // ㅅ → ㄷ
        20: 7,   // ㅆ → ㄷ
        22: 7,   // ㅈ → ㄷ
        23: 7,   // ㅊ → ㄷ
        25: 7,   // ㅌ → ㄷ
        27: 7,   // ㅎ → ㄷ
        26: 17   // ㅍ → ㅂ
    ]

    /// 종성 평폐쇄음 그룹(ㄱ, ㄷ, ㅂ).
    static let finalStopGroup: Set<Int> = [1, 7, 17]

    /// 종성 인덱스
    static let finalT  = 7   // ㄷ
    static let finalTh = 25  // ㅌ

    /// 어떤 받침이든 평폐쇄음 그룹(ㄱ/ㄷ/ㅂ) 으로 환산.
    /// classifier 가 ref/hyp 양측을 같은 그룹으로 정렬해 비음화 같은 패턴 매칭에 사용.
    static func plainStopOf(_ jong: Int) -> Int {
        if finalStopGroup.contains(jong) { return jong }
        return finalNeutralization[jong] ?? jong
    }
}
