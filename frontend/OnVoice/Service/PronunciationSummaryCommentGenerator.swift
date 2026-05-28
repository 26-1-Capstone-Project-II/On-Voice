//
//  PronunciationSummaryCommentGenerator.swift
//  OnVoice
//
//  점수 카드 본문 코멘트를 생성한다. 1위 난이도 카테고리가 있으면 그 카테고리에
//  맞춘 코멘트를, 없으면 점수 등급 기반 fallback 을 돌려준다.
//
//  분류 결과가 비어 있는 두 가지 케이스가 fallback 으로 들어온다:
//   1) 발음이 모두 정확해 오류가 한 건도 잡히지 않은 경우 (high 등급)
//   2) 분석 자체가 불가능했던 경우 (limitation 등으로 cells 없음)
//  현재는 두 케이스를 등급으로 구분한다. 더 정밀한 안내가 필요하면 호출자가
//  isPronunciationEvaluationAvailable 플래그로 추가 분기하면 된다.
//

import Foundation

enum PronunciationSummaryCommentGenerator {

    static func generate(
        topItem: PronunciationDifficultyResult?,
        level: PronunciationScoreLevel
    ) -> String {
        if let topItem {
            return comment(for: topItem.category)
        }
        return fallback(for: level)
    }

    // MARK: - Category-specific comments

    private static func comment(for category: PronunciationErrorCategory) -> String {
        switch category {
        case .vowelError:
            return "모음 발음을 가장 어려워하고 있어요.\n입 모양을 크게 하고 모음을 길게 내며\n또박또박 발음해보면 좋을 것 같아요."
        case .initialTensification:
            return "된소리(경음) 발음을 가장 어려워하고 있어요.\n목과 혀에 힘을 주고 짧게 끊어내듯\n소리를 시작해 보세요."
        case .initialPalatalization:
            return "구개음 변화 발음을 가장 어려워하고 있어요.\n받침이 ㅣ 모음 앞에서 ㅈ, ㅊ 소리로 바뀌는\n흐름을 의식하며 천천히 연습해보세요."
        case .initialNasalization:
            return "ㄴ과 ㄹ 초성 구분을 가장 어려워하고 있어요.\n혀 끝의 위치를 다르게 느끼며\n짧은 단어부터 비교해 발음해보세요."
        case .initialLinking:
            return "어절 사이 연음을 가장 어려워하고 있어요.\n받침을 다음 음절의 초성으로 옮겨\n자연스럽게 이어 말해보세요."
        case .finalTensification, .finalPalatalization, .finalNasalization, .finalLinking:
            return "받침 발음을 가장 어려워하고 있어요.\n목소리에 힘을 주고, 단어를 끝까지 소리낸다는\n방식으로 발음을 연습해보면 좋을 것 같아요."
        case .dropout:
            return "발음하지 않고 빠뜨리는 글자가 있어요.\n단어를 한 글자씩 나누어 읽고,\n마지막에 자연스럽게 이어 말해보세요."
        }
    }

    // MARK: - Level-based fallback

    private static func fallback(for level: PronunciationScoreLevel) -> String {
        switch level {
        case .low:
            return "조금 더 천천히, 단어를 끝까지 발음해보세요.\n반복 연습으로 또박또박 말하는\n습관을 만들어볼까요?"
        case .middle:
            return "조금 더 또박또박 말해볼까요?\n받침과 모음을 의식하며\n천천히 발음해보세요."
        case .high:
            return "발음이 자연스럽고 안정적이에요!\n지금의 흐름을 유지하며\n다양한 문장을 읽어보세요."
        }
    }
}
