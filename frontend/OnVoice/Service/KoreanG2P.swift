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
    // 자모 매핑은 KoreanPhonemeRules 가 단일 source of truth.
    // 분류기와 동일한 정의를 공유해 G2P 적용 결과가 분류기 카테고리와 어긋나지 않게 한다.

    /// G2P 가 처리하는 받침의 확장 그룹(겹받침 포함). plainStopOf 만으로는 잡히지 않는
    /// 겹받침(ㄺ/ㄼ/ㄿ) 도 G2P 시점에서 평폐쇄음으로 환산한다.
    private static let stopFinalsExtended: [Int: Int] = [
        9:  1,   // ㄺ → ㄱ
        11: 17,  // ㄼ → ㅂ
        14: 17   // ㄿ → ㅂ
    ]

    /// 받침이 평폐쇄음(ㄱ/ㄷ/ㅂ) 으로 환산되는 인덱스. 환산 불가하면 nil.
    private static func plainStop(of jongIdx: Int) -> Int? {
        if KoreanPhonemeRules.finalStopGroup.contains(jongIdx) { return jongIdx }
        if let extended = stopFinalsExtended[jongIdx] { return extended }
        return KoreanPhonemeRules.finalNeutralization[jongIdx]
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
            if let neutral = KoreanPhonemeRules.finalNeutralization[syllables[idx].finalIndex] {
                syllables[idx].finalIndex = neutral
                applications.append(.init(rule: .neutralization, leadingIndex: idx, trailingIndex: -1))
            }
        }

        return G2PResult(original: originals, phonetic: syllables, applications: applications)
    }

    // MARK: - Two-syllable rules

    /// 두 음절 결합 규칙. 매칭되는 첫 규칙이 즉시 적용되고 return 한다.
    /// 우선순위 (한국어 표준 발음법과 완전히 같지 않지만 음절-결합 변환에 최적화):
    ///   1) 구개음화 — 받침 ㄷ/ㅌ + 초성 ㅇ + 모음 ㅣ → ㅈ/ㅊ + 이
    ///      연음보다 먼저 적용해야 받침이 변형된 채로 옮겨감 ("밭이" → "바치", "바티" 아님)
    ///   2) 격음화 — 받침 ㅎ + 평음 초성 / 평음 받침 + 초성 ㅎ → 격음
    ///   3) 연음화 — 받침 + 초성 ㅇ → 받침이 다음 음절 초성으로
    ///      받침 ㅇ(21) 은 음가가 없어 제외
    ///   4) 비음화 — 평폐쇄음 받침 + 비음 초성 → 받침 비음으로
    ///   5) 경음화 — 평폐쇄음 받침 + 평음 초성 → 초성 경음으로
    /// 규칙 간 충돌 케이스는 KoreanG2PTests 에 회귀 방지용 단위 테스트로 고정.
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
        if finalIdx == 27, let asp = KoreanPhonemeRules.initialPlainToAspirated[onsetIdx] {
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
        //    받침 ㅇ(21) 은 음가가 없어 연음 대상이 아니다 (ㅇ초성 ㅇ은 동음 → 변화 없음).
        if onsetIdx == 11, finalIdx > 0, finalIdx != 21 {
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
           let nasal = KoreanPhonemeRules.finalStopToNasal[neutral] {
            syllables[leftIndex].finalIndex = nasal
            applications.append(.init(rule: .nasalization, leadingIndex: leftIndex, trailingIndex: rightIndex))
            return
        }

        // 5) 경음화: 평폐쇄음 받침 + 평음 초성(ㄱ/ㄷ/ㅂ/ㅅ/ㅈ) → 초성 경음으로
        if plainStop(of: finalIdx) != nil,
           let tense = KoreanPhonemeRules.initialPlainToTense[onsetIdx] {
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
