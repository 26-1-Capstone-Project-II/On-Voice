//
//  PronunciationErrorClassifier.swift
//  OnVoice
//
//  팀에서 합의한 10종 오류 정의에 따라 (ref = G2P 적용된 기대 음절,
//  hyp = Whisper 가 들은 실제 음절) 자모를 직접 비교해 카테고리를 결정한다.
//  자모 매핑은 KoreanPhonemeRules 가 single source of truth — G2P 와 동일한
//  정의를 공유한다.
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
        let tense = KoreanPhonemeRules.initialPlainToTense

        // 초성 경음화: 평음↔경음 쌍에 해당
        if tense[refInitial] == hypInitial || tense[hypInitial] == refInitial {
            return .initialTensification
        }

        // 초성 구개음화: ref=ㅈ/ㅊ, hyp=ㄷ/ㅌ (또는 반대) + 모음 ㅣ
        if refMedial == KoreanPhonemeRules.medialI {
            let pal = KoreanPhonemeRules.initialPalatalPairs
            if pal[refInitial] == hypInitial || pal[hypInitial] == refInitial {
                return .initialPalatalization
            }
        }

        // 초성 비음화: ㄴ↔ㄹ
        if (refInitial == KoreanPhonemeRules.initialN && hypInitial == KoreanPhonemeRules.initialR)
            || (refInitial == KoreanPhonemeRules.initialR && hypInitial == KoreanPhonemeRules.initialN) {
            return .initialNasalization
        }

        // 초성 연음화: ref 초성 ≠ ㅇ, hyp 초성 = ㅇ (연음 실패)
        if refInitial != KoreanPhonemeRules.initialO && hypInitial == KoreanPhonemeRules.initialO {
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
        if refFinal == 0
            && (hypFinal == KoreanPhonemeRules.finalT || hypFinal == KoreanPhonemeRules.finalTh) {
            if let next = nextExpected, next.medialIndex == KoreanPhonemeRules.medialI {
                return .finalPalatalization
            }
        }

        // 종성 비음화: 폐쇄음 ↔ 비음 (ㄱ↔ㅇ, ㄷ↔ㄴ, ㅂ↔ㅁ)
        // ref/hyp 양측을 평폐쇄음 그룹으로 환산한 뒤 매칭한다.
        // hyp 이 ㄲ/ㅋ/ㅍ/ㅅ/ㅆ/ㅈ/ㅊ/ㅌ/ㅎ 등 비평폐쇄음 종성을 발음했더라도
        // 중화 매핑으로 ㄱ/ㄷ/ㅂ 으로 정렬해 표준 발음 기준 비교가 가능하다.
        let stopMap = KoreanPhonemeRules.finalStopToNasal
        if stopMap[KoreanPhonemeRules.plainStopOf(refFinal)] == hypFinal
            || stopMap[KoreanPhonemeRules.plainStopOf(hypFinal)] == refFinal {
            return .finalNasalization
        }

        // 종성 연음화: ref 가 G2P 로 받침을 다음 음절 초성으로 옮긴 패턴.
        //   - ref 종성 = 0 (받침이 옮겨가 비었음)
        //   - hyp 종성 ≠ 0 (사용자가 받침을 그대로 발음)
        //   - 다음 ref 음절의 초성이 hyp 종성과 동일 (받침이 그쪽으로 옮겨갔다는 시그니처)
        //   - 다음 ref 음절의 초성이 ㅇ 이 아님 (ㅇ 이면 G2P 변환 일어나지 않은 케이스)
        // 위 4개를 모두 만족할 때만 finalLinking. 그렇지 않은 단순 ASR 오인식이
        // finalLinking 으로 흡수되는 것을 막는다.
        if refFinal == 0 && hypFinal != 0,
           let next = nextExpected,
           next.initialIndex != KoreanPhonemeRules.initialO,
           HangulJamo.jongToChoIndex[hypFinal] == next.initialIndex {
            return .finalLinking
        }

        // 종성 경음화 트리거: ref 가 폐쇄음(ㄱ/ㄷ/ㅂ)인데 받침이 변형/소실됨
        if KoreanPhonemeRules.finalStopGroup.contains(refFinal) {
            return .finalTensification
        }

        return .dropout
    }
}
