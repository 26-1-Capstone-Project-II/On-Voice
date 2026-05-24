//
//  KoreanG2P.swift
//  OnVoice
//
//  Apple ASR이 돌려준 "표기 텍스트"를 한국어 표준 발음(소리나는 대로)으로 변환한다.
//  Whisper(phonetic) 결과와 자모 정렬로 비교하기 위한 reference 측을 만든다.
//
//  적용 규칙(순서):
//    1) 구개음화      : 받침 ㄷ/ㅌ + ㅇ초성 + ㅣ → ㅈ/ㅊ + 이
//    2) 격음화        : ㅎ ↔ 평음 결합 → 격음
//    3) 비음화        : 받침 ㄱ/ㄷ/ㅂ + ㄴ/ㅁ → 받침 ㅇ/ㄴ/ㅁ
//    4) 연음화        : 받침 + ㅇ초성 → 받침이 다음 음절 초성으로
//    5) 경음화        : 받침 ㄱ/ㄷ/ㅂ + 평음 → 경음
//    6) 종성 중화     : 받침 ㅍ→ㅂ, ㅋ/ㄲ→ㄱ, ㅌ/ㅅ/ㅆ/ㅈ/ㅊ→ㄷ 등 (단어 끝/규칙 후)
//
//  각 규칙이 적용된 (앞음절 index, 뒤음절 index) 쌍을 기록해 오류 분류기가
//  "이 음절은 경음화가 일어났어야 했다" 를 판단할 수 있게 한다.
//

import Foundation

enum G2PRule: Equatable {
    case palatalization
    case aspiration
    case nasalization
    case linking
    case tensification
    case neutralization
}

struct G2PRuleApplication: Equatable {
    let rule: G2PRule
    let leadingIndex: Int       // 영향을 준 앞 음절 index (없으면 -1)
    let trailingIndex: Int      // 영향을 받은 뒤 음절 index (없으면 -1)
}

struct G2PResult: Equatable {
    let original: [HangulJamo.Syllable]    // 입력(표기)
    let phonetic: [HangulJamo.Syllable]    // 변환 결과(발음)
    let applications: [G2PRuleApplication]

    var phoneticText: String { HangulJamo.compose(phonetic) }

    /// 특정 음절 index 에 적용된 규칙들
    func rules(at index: Int) -> [G2PRule] {
        applications
            .filter { $0.leadingIndex == index || $0.trailingIndex == index }
            .map(\.rule)
    }
}

enum KoreanG2P {
    /// 초성 평음 → 경음 매핑
    private static let tenseOfPlain: [Int: Int] = [
        0: 1,    // ㄱ → ㄲ
        3: 4,    // ㄷ → ㄸ
        7: 8,    // ㅂ → ㅃ
        9: 10,   // ㅅ → ㅆ
        12: 13   // ㅈ → ㅉ
    ]

    /// 초성 평음 → 격음 매핑 (ㅎ 결합)
    private static let aspiratedOfPlain: [Int: Int] = [
        0: 15,   // ㄱ → ㅋ
        3: 16,   // ㄷ → ㅌ
        7: 17,   // ㅂ → ㅍ
        12: 14   // ㅈ → ㅊ
    ]

    /// 받침(종성) → 비음화시 변환되는 종성 (ㄱ→ㅇ, ㄷ→ㄴ, ㅂ→ㅁ 그룹)
    private static let nasalizedOfFinal: [Int: Int] = [
        1: 21,   // ㄱ → ㅇ
        2: 21,   // ㄲ → ㅇ
        24: 21,  // ㅋ → ㅇ
        7: 4,    // ㄷ → ㄴ
        19: 4,   // ㅅ → ㄴ
        20: 4,   // ㅆ → ㄴ
        22: 4,   // ㅈ → ㄴ
        23: 4,   // ㅊ → ㄴ
        25: 4,   // ㅌ → ㄴ
        27: 4,   // ㅎ → ㄴ
        17: 16,  // ㅂ → ㅁ
        26: 16   // ㅍ → ㅁ
    ]

    /// 받침 → 종성 중화 결과(말끝/평폐쇄음화)
    /// ㄱ-계열은 ㄱ(1), ㄷ-계열은 ㄷ(7), ㅂ-계열은 ㅂ(17) 으로 수렴.
    private static let neutralizedFinal: [Int: Int] = [
        2: 1,    // ㄲ → ㄱ
        24: 1,   // ㅋ → ㄱ
        19: 7,   // ㅅ → ㄷ
        20: 7,   // ㅆ → ㄷ
        22: 7,   // ㅈ → ㄷ
        23: 7,   // ㅊ → ㄷ
        25: 7,   // ㅌ → ㄷ
        26: 17,  // ㅍ → ㅂ
        27: 7    // ㅎ → ㄷ (단독 종성일 때)
    ]

    /// "ㄱ-계열 받침" (종성 평폐쇄음으로 묶이는 그룹). 경음화/비음화 트리거.
    private static let stopFinalsK: Set<Int> = [1, 2, 24, 9]      // ㄱ ㄲ ㅋ ㄺ
    private static let stopFinalsT: Set<Int> = [7, 19, 20, 22, 23, 25] // ㄷ ㅅ ㅆ ㅈ ㅊ ㅌ
    private static let stopFinalsP: Set<Int> = [17, 26, 11, 14]    // ㅂ ㅍ ㄼ ㄿ

    /// 받침이 단일 평폐쇄음으로 환산했을 때의 표준 종성 idx (ㄱ/ㄷ/ㅂ).
    private static func plainStop(of jongIdx: Int) -> Int? {
        if stopFinalsK.contains(jongIdx) { return 1 }
        if stopFinalsT.contains(jongIdx) { return 7 }
        if stopFinalsP.contains(jongIdx) { return 17 }
        return nil
    }

    static func apply(_ text: String) -> G2PResult {
        let originals = HangulJamo.decompose(text)
        var syllables = originals
        var applications: [G2PRuleApplication] = []

        var i = 0
        while i < syllables.count {
            guard syllables[i].isHangul else { i += 1; continue }

            // 다음 한글 음절을 찾는다(공백/구두점은 건너뛴다).
            // 자연 발화에서는 어절 사이에서도 연음/경음화/비음화가 일어나며,
            // Apple ASR 의 띄어쓰기가 G2P 결과를 끊지 못하게 막는다.
            var j = i + 1
            while j < syllables.count && !syllables[j].isHangul { j += 1 }

            if j < syllables.count {
                applyDualSyllableRules(
                    leftIndex: i,
                    rightIndex: j,
                    syllables: &syllables,
                    applications: &applications
                )
            }
            i += 1
        }

        // 마지막 패스: 한글 시퀀스 전체의 마지막 음절(뒤에 한글이 없는 음절) 의 받침 중화.
        let lastHangulIndex = syllables.lastIndex(where: \.isHangul)
        for idx in syllables.indices where syllables[idx].isHangul {
            guard idx == lastHangulIndex, syllables[idx].finalIndex > 0 else { continue }
            if let neutral = neutralizedFinal[syllables[idx].finalIndex] {
                syllables[idx].finalIndex = neutral
                applications.append(.init(rule: .neutralization, leadingIndex: idx, trailingIndex: -1))
            }
        }

        return G2PResult(original: originals, phonetic: syllables, applications: applications)
    }

    // MARK: - Two-syllable rules

    private static func applyDualSyllableRules(
        leftIndex: Int,
        rightIndex: Int,
        syllables: inout [HangulJamo.Syllable],
        applications: inout [G2PRuleApplication]
    ) {
        let left = syllables[leftIndex]
        let right = syllables[rightIndex]

        let finalIdx = left.finalIndex
        guard finalIdx >= 0 else { return }

        let onsetIdx = right.initialIndex
        let medialIdx = right.medialIndex

        // 1) 구개음화: 받침 ㄷ(7) / ㅌ(25) + 초성 ㅇ(11) + ㅣ(20)
        if (finalIdx == 7 || finalIdx == 25),
           onsetIdx == 11,
           medialIdx == 20 {
            let newOnset = (finalIdx == 7) ? 12 : 14  // ㄷ→ㅈ, ㅌ→ㅊ
            syllables[leftIndex].finalIndex = 0
            syllables[rightIndex].initialIndex = newOnset
            applications.append(.init(rule: .palatalization, leadingIndex: leftIndex, trailingIndex: rightIndex))
            return
        }

        // 2) 격음화
        //  2a) 받침 ㅎ(27) + 평음 초성 → 받침 제거 + 초성 격음화
        if finalIdx == 27, let asp = aspiratedOfPlain[onsetIdx] {
            syllables[leftIndex].finalIndex = 0
            syllables[rightIndex].initialIndex = asp
            applications.append(.init(rule: .aspiration, leadingIndex: leftIndex, trailingIndex: rightIndex))
            return
        }
        //  2b) 받침 평음(ㄱ/ㄷ/ㅂ/ㅈ 의 종성형) + 초성 ㅎ(18) → 격음 단일 초성으로
        //      매핑 값: (newFinal, newInitial). 단일 받침은 newFinal = 0 으로 사라지고,
        //      겹받침(ㄺ/ㄼ 등) 은 앞 자모만 남기고 뒤 자모가 ㅎ 과 결합해 격음이 된다.
        //      예: 밝히다 → 발키다 (ㄺ + ㅎ → ㄹ + ㅋ),
        //          넓히다 → 널피다 (ㄼ + ㅎ → ㄹ + ㅍ)
        if onsetIdx == 18 {
            let aspMap: [Int: (newFinal: Int, newInitial: Int)] = [
                1:  (0, 15),   // ㄱ → 0 + ㅋ
                2:  (0, 15),   // ㄲ → 0 + ㅋ
                24: (0, 15),   // ㅋ → 0 + ㅋ
                9:  (8, 15),   // ㄺ → ㄹ + ㅋ
                7:  (0, 16),   // ㄷ → 0 + ㅌ
                19: (0, 16),   // ㅅ → 0 + ㅌ
                20: (0, 16),   // ㅆ → 0 + ㅌ
                22: (0, 16),   // ㅈ → 0 + ㅌ
                23: (0, 16),   // ㅊ → 0 + ㅌ
                25: (0, 16),   // ㅌ → 0 + ㅌ
                17: (0, 17),   // ㅂ → 0 + ㅍ
                26: (0, 17),   // ㅍ → 0 + ㅍ
                11: (8, 17)    // ㄼ → ㄹ + ㅍ
            ]
            if let asp = aspMap[finalIdx] {
                syllables[leftIndex].finalIndex = asp.newFinal
                syllables[rightIndex].initialIndex = asp.newInitial
                applications.append(.init(rule: .aspiration, leadingIndex: leftIndex, trailingIndex: rightIndex))
                return
            }
        }

        // 3) 연음화: 받침 + 초성 ㅇ(11) → 받침을 뒤 음절 초성으로
        //    겹받침은 뒤 자모만 넘기고 앞 자모는 남는다 (단순 받침이면 통째로 이동).
        if onsetIdx == 11, finalIdx > 0 {
            if let split = HangulJamo.splitCluster(jongIndex: finalIdx) {
                syllables[leftIndex].finalIndex = split.leadingJong
                syllables[rightIndex].initialIndex = split.trailingCho
            } else if let choIdx = HangulJamo.jongToChoIndex[finalIdx] {
                syllables[leftIndex].finalIndex = 0
                syllables[rightIndex].initialIndex = choIdx
            } else {
                return
            }
            applications.append(.init(rule: .linking, leadingIndex: leftIndex, trailingIndex: rightIndex))
            return
        }

        // 4) 비음화: 평폐쇄음 받침 + 비음(ㄴ/ㅁ) 초성 → 받침 비음으로
        if (onsetIdx == 2 /*ㄴ*/ || onsetIdx == 6 /*ㅁ*/),
           let neutral = plainStop(of: finalIdx),
           let nasal = nasalizedOfFinal[neutral] {
            syllables[leftIndex].finalIndex = nasal
            applications.append(.init(rule: .nasalization, leadingIndex: leftIndex, trailingIndex: rightIndex))
            return
        }

        // 5) 경음화: 평폐쇄음 받침 + 평음 초성(ㄱ/ㄷ/ㅂ/ㅅ/ㅈ) → 초성 경음으로
        if plainStop(of: finalIdx) != nil, let tense = tenseOfPlain[onsetIdx] {
            // 종성은 평폐쇄음(ㄱ/ㄷ/ㅂ)으로 중화된 채로 유지
            if let plain = plainStop(of: finalIdx), syllables[leftIndex].finalIndex != plain {
                syllables[leftIndex].finalIndex = plain
                applications.append(.init(rule: .neutralization, leadingIndex: leftIndex, trailingIndex: -1))
            }
            syllables[rightIndex].initialIndex = tense
            applications.append(.init(rule: .tensification, leadingIndex: leftIndex, trailingIndex: rightIndex))
            return
        }
    }
}
