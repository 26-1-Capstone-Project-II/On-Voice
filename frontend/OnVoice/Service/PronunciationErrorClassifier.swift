//
//  PronunciationErrorClassifier.swift
//  OnVoice
//
//  팀에서 합의한 10종 오류 정의에 따라 (ref = G2P 적용된 기대 음절,
//  hyp = Whisper 가 들은 실제 음절) 자모를 직접 비교해 카테고리를 결정한다.
//  G2P 가 어떤 규칙을 적용했는지는 더 이상 분류 입력으로 쓰지 않고,
//  ref/hyp 자모 패턴만으로 분류한다.
//

import Foundation

enum PronunciationErrorCategory: String, CaseIterable, Equatable {
    case vowelError = "모음 오류"
    case initialTensification = "초성 경음화"
    case initialPalatalization = "초성 구개음화"
    case initialNasalization = "초성 비음화"
    case initialLinking = "초성 연음화"
    case finalTensification = "종성 경음화"
    case finalPalatalization = "종성 구개음화"
    case finalNasalization = "종성 비음화"
    case finalLinking = "종성 연음화"
    case dropout = "탈락"

    var slot: JamoSlot? {
        switch self {
        case .vowelError: return .medial
        case .initialTensification, .initialPalatalization,
             .initialNasalization, .initialLinking: return .initial
        case .finalTensification, .finalPalatalization,
             .finalNasalization, .finalLinking: return .final
        case .dropout: return nil
        }
    }
}

enum PronunciationErrorClassifier {
    // MARK: - Jamo index 상수 (HangulJamo 의 choseong/jongseong 배열 인덱스)

    /// 초성 평음 → 경음
    private static let initialPlainToTense: [Int: Int] = [
        0: 1,    // ㄱ → ㄲ
        3: 4,    // ㄷ → ㄸ
        7: 8,    // ㅂ → ㅃ
        9: 10,   // ㅅ → ㅆ
        12: 13   // ㅈ → ㅉ
    ]

    /// 초성 ㄷ↔ㅈ, ㅌ↔ㅊ (구개음화)
    private static let initialPalatalPairs: [Int: Int] = [
        3: 12,   // ㄷ → ㅈ
        16: 14   // ㅌ → ㅊ
    ]

    /// 종성 폐쇄음 → 비음 (ㄱ→ㅇ, ㄷ→ㄴ, ㅂ→ㅁ)
    private static let finalStopToNasal: [Int: Int] = [
        1: 21,   // ㄱ → ㅇ
        7: 4,    // ㄷ → ㄴ
        17: 16   // ㅂ → ㅁ
    ]

    /// 종성 폐쇄음 그룹(ㄱ, ㄷ, ㅂ). 경음화 트리거 변형 검출에 사용.
    private static let finalStopGroup: Set<Int> = [1, 7, 17]

    /// 초성 ㄴ(2), ㄹ(5), ㅇ(11), ㅎ(18) 인덱스
    private static let initialN = 2
    private static let initialR = 5
    private static let initialO = 11

    /// 중성 ㅣ 인덱스
    private static let medialI = 20

    /// 종성 ㄷ(7), ㅌ(25) 인덱스
    private static let finalT = 7
    private static let finalTh = 25

    // MARK: - Classify

    /// 한 정렬 cell + 다음 ref 음절 정보를 받아 오류 카테고리들을 돌려준다.
    /// 자모 슬롯마다 한 개씩 분류되므로 한 cell 에서 최대 3개 까지 나올 수 있다.
    static func classify(
        cell: AlignmentCell,
        nextExpected: HangulJamo.Syllable?
    ) -> [PronunciationErrorCategory] {
        // 1) gap → 탈락
        if cell.expected != nil, cell.actual == nil { return [.dropout] }
        if cell.expected == nil, cell.actual != nil { return [.dropout] }

        guard let ref = cell.expected, let hyp = cell.actual else { return [] }
        // 비-한글(공백/문장부호)은 분류 대상 아님
        guard ref.isHangul, hyp.isHangul else { return [] }

        var result: [PronunciationErrorCategory] = []

        // 2) 중성 차이 → 모음 오류
        if ref.medialIndex != hyp.medialIndex {
            result.append(.vowelError)
        }

        // 3) 초성 차이 → 초성 4종 중 하나, 매칭 안 되면 탈락
        if ref.initialIndex != hyp.initialIndex {
            result.append(classifyInitial(
                refInitial: ref.initialIndex,
                hypInitial: hyp.initialIndex,
                refMedial: ref.medialIndex
            ))
        }

        // 4) 종성 차이 → 종성 4종 중 하나, 매칭 안 되면 탈락
        if ref.finalIndex != hyp.finalIndex {
            result.append(classifyFinal(
                refFinal: ref.finalIndex,
                hypFinal: hyp.finalIndex,
                nextExpected: nextExpected
            ))
        }

        return result
    }

    // MARK: - Initial

    private static func classifyInitial(
        refInitial: Int,
        hypInitial: Int,
        refMedial: Int
    ) -> PronunciationErrorCategory {
        // 초성 경음화: 평음↔경음 쌍에 해당
        if initialPlainToTense[refInitial] == hypInitial
            || initialPlainToTense[hypInitial] == refInitial {
            return .initialTensification
        }

        // 초성 구개음화: ref=ㅈ/ㅊ, hyp=ㄷ/ㅌ (또는 반대) + 모음 ㅣ
        if refMedial == medialI {
            if initialPalatalPairs[refInitial] == hypInitial
                || initialPalatalPairs[hypInitial] == refInitial {
                return .initialPalatalization
            }
        }

        // 초성 비음화: ㄴ↔ㄹ
        if (refInitial == initialN && hypInitial == initialR)
            || (refInitial == initialR && hypInitial == initialN) {
            return .initialNasalization
        }

        // 초성 연음화: ref 초성 ≠ ㅇ, hyp 초성 = ㅇ (연음 실패)
        if refInitial != initialO && hypInitial == initialO {
            return .initialLinking
        }

        // 패턴 매칭 안 됨 → 탈락
        return .dropout
    }

    // MARK: - Final

    private static func classifyFinal(
        refFinal: Int,
        hypFinal: Int,
        nextExpected: HangulJamo.Syllable?
    ) -> PronunciationErrorCategory {
        // 종성 구개음화: ref 종성 없음, hyp 종성 ㄷ/ㅌ 잔존, 다음 ref 중성이 ㅣ
        if refFinal == 0 && (hypFinal == finalT || hypFinal == finalTh) {
            if let next = nextExpected, next.medialIndex == medialI {
                return .finalPalatalization
            }
        }

        // 종성 비음화: 폐쇄음 ↔ 비음 (ㄱ↔ㅇ, ㄷ↔ㄴ, ㅂ↔ㅁ)
        if finalStopToNasal[refFinal] == hypFinal
            || finalStopToNasal[hypFinal] == refFinal {
            return .finalNasalization
        }

        // 종성 연음화: ref 종성 없음, hyp 종성 잔존 (구개음화로 분기 안 된 일반 케이스)
        if refFinal == 0 && hypFinal != 0 {
            return .finalLinking
        }

        // 종성 경음화 트리거: ref 가 폐쇄음(ㄱ/ㄷ/ㅂ)인데 받침이 변형/소실됨
        if finalStopGroup.contains(refFinal) {
            return .finalTensification
        }

        return .dropout
    }
}
