//
//  PronunciationDifficultyAggregator.swift
//  OnVoice
//
//  자모 정렬 결과 cell 시퀀스에서 10종 `PronunciationErrorCategory` 빈도를 집계해
//  "내가 어려워하는 발음" 카드 데이터를 만든다.
//
//  설계 메모:
//   - 카테고리 버킷팅(예: 종성 4종 → "종성 오류") 은 의도적으로 도입하지 않는다.
//     UI 가 raw 카테고리를 그대로 노출하기로 합의됨(에픽 Out of Scope 참조).
//   - 동률은 rawValue 사전순으로 안정 정렬 → 같은 입력에 같은 출력.
//   - 사람 아이콘은 카테고리별로 디자인 자산이 완성될 때까지 모두 "error_img_1" fallback.
//   - 분류기는 `PronunciationScriptAnalysisService` 와 동일한 인터페이스로 호출된다
//     (cell + nextExpected). 단일 source-of-truth 보장을 위해 분류 로직 자체는
//     재구현하지 않는다.
//

import Foundation

enum PronunciationDifficultyAggregator {

    static func aggregate(
        cells: [AlignmentCell],
        expectedAll: [HangulJamo.Syllable]
    ) -> [PronunciationDifficultyResult] {
        let counts = collectCategoryCounts(cells: cells, expectedAll: expectedAll)
        guard !counts.isEmpty else { return [] }

        let sorted = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key.rawValue < rhs.key.rawValue
        }

        return sorted.prefix(3).enumerated().map { offset, entry in
            buildResult(rank: offset + 1, category: entry.key, count: entry.value)
        }
    }

    // MARK: - Counting

    private static func collectCategoryCounts(
        cells: [AlignmentCell],
        expectedAll: [HangulJamo.Syllable]
    ) -> [PronunciationErrorCategory: Int] {
        var counts: [PronunciationErrorCategory: Int] = [:]
        for cell in cells {
            guard cell.hasError else { continue }
            // alignHangulOnly 결과라 거의 항상 한글이지만, 외부에서 직접 cell 을
            // 넘기는 단위 테스트를 위한 방어 가드.
            let isHangulCell =
                (cell.expected?.isHangul ?? false) || (cell.actual?.isHangul ?? false)
            guard isHangulCell else { continue }

            let next = cell.expectedIndex.flatMap { idx in
                idx + 1 < expectedAll.count ? expectedAll[idx + 1] : nil
            }
            let categories = PronunciationErrorClassifier.classify(
                cell: cell,
                nextExpected: next
            )
            for category in categories {
                counts[category, default: 0] += 1
            }
        }
        return counts
    }

    // MARK: - Display info

    private static func buildResult(
        rank: Int,
        category: PronunciationErrorCategory,
        count: Int
    ) -> PronunciationDifficultyResult {
        let info = displayInfo(for: category)
        return PronunciationDifficultyResult(
            id: category.rawValue,
            rank: rank,
            category: category,
            title: category.rawValue,
            subtitle: info.subtitle,
            practiceTitle: info.practiceTitle,
            guideText: info.guideText,
            accentColorHex: accentColorHex(forRank: rank),
            imageName: "error_img_1",
            errorCount: count
        )
    }

    /// 순위 배지 색상. 디자인(피그마 5-1)은 카테고리가 아니라 "순위" 로 색을 구분한다.
    /// 1위 빨강 · 2위 노랑 · 3위 파랑. 상위 3개만 노출하므로 3색이면 충분하다.
    /// (카테고리에 색을 묶으면 서로 다른 순위가 같은 색으로 보이는 충돌이 생긴다.)
    private static func accentColorHex(forRank rank: Int) -> String {
        switch rank {
        case 1:  return "#FFA0A0"   // 빨강
        case 2:  return "#FFF79E"   // 노랑
        default: return "#B2B8FF"   // 파랑
        }
    }

    /// 카테고리별 표시 텍스트. 강조 색상은 순위 기준이므로 여기서 다루지 않는다
    /// (accentColorHex(forRank:) 참조). 텍스트는 잠정 카피 — UI 확정 후 별도 이슈에서 다듬는다.
    private static func displayInfo(
        for category: PronunciationErrorCategory
    ) -> (subtitle: String, practiceTitle: String, guideText: String) {
        switch category {
        case .vowelError:
            return (
                "모음을 정확히 발음해보세요",
                "ㅏ, ㅓ, ㅗ, ㅜ 모음 구분",
                "입 모양과 혀의 위치를 의식하며 모음을 길게 내봅시다.\n비슷한 모음을 짝지어 짧은 단어부터 비교해보세요."
            )
        case .initialTensification:
            return (
                "된소리 발음이 약해요",
                "ㄲ, ㄸ, ㅃ, ㅆ, ㅉ 발음",
                "목과 혀에 힘을 주고 짧게 끊어내듯 소리내보세요.\n평음과 번갈아 발음하며 긴장감 차이를 느껴봅시다."
            )
        case .initialPalatalization:
            return (
                "구개음 변화가 약해요",
                "ㄷ, ㅌ + ㅣ → ㅈ, ㅊ 변화",
                "ㄷ, ㅌ 받침이 ㅣ 모음 앞에서 ㅈ, ㅊ 소리로 바뀌는 흐름을 의식해주세요.\n\"굳이\" → \"구지\" 같은 예시로 반복 연습해보세요."
            )
        case .initialNasalization:
            return (
                "ㄴ과 ㄹ 구분이 어려워요",
                "ㄴ, ㄹ 초성 구분",
                "혀 끝의 위치를 달리하며 두 소리를 짧은 단어부터 비교해보세요.\nㄴ은 코로 울리고 ㄹ은 혀를 굴리는 느낌을 살려봅시다."
            )
        case .initialLinking:
            return (
                "받침을 다음 음절로 옮기지 못해요",
                "어절 사이 연음 규칙",
                "다음 글자가 모음으로 시작하면 받침을 그 음절의 초성으로 옮겨 발음해보세요.\n천천히 어절을 이어 읽으며 끊김을 줄여봅시다."
            )
        case .finalTensification:
            return (
                "받침 발음이 약해요",
                "ㄱ, ㄷ, ㅂ 받침",
                "받침에서 입을 닫거나 혀를 붙여 멈추는 느낌을 살려보세요.\n받침을 또렷이 끊어내면 다음 글자도 또박또박 들립니다."
            )
        case .finalPalatalization:
            return (
                "받침 ㄷ, ㅌ 변화가 약해요",
                "받침 ㄷ, ㅌ + ㅣ 흐름",
                "\"굳이\"가 \"구지\"로 들리도록 받침 변화를 의식해주세요.\n받침과 다음 모음을 연결해 짧게 이어 발음해봅시다."
            )
        case .finalNasalization:
            return (
                "받침 비음화가 약해요",
                "받침 ㄱ↔ㅇ, ㄷ↔ㄴ, ㅂ↔ㅁ",
                "\"국물\"이 \"궁물\"로 들리도록 받침을 비음으로 바꿔 발음해보세요.\n비음으로 바뀌는 짝을 짧은 단어로 익혀봅시다."
            )
        case .finalLinking:
            return (
                "받침 연음 처리가 약해요",
                "받침 연음 규칙",
                "다음 글자가 모음으로 시작하면 받침을 옮겨 발음해보세요.\n어절 사이를 자연스럽게 이어 읽으면 정확도가 올라갑니다."
            )
        case .dropout:
            return (
                "발음하지 않고 빠뜨리는 글자가 있어요",
                "음절 단위 발음",
                "단어를 한 글자씩 나누어 천천히 읽어보세요.\n마지막에 자연스럽게 이어 말하면 누락을 줄일 수 있어요."
            )
        }
    }
}
