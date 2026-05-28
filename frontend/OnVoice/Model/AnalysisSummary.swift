//
//  AnalysisSummary.swift
//  OnVoice
//
//  발음 분석 리포트 요약 화면(피그마 5-1) 이 사용하는 도메인 모델.
//  AnalysisSummaryView 가 들고 있던 private 타입(점수 등급, 난이도 카드 데이터)을
//  분석 결과와 함께 외부에서 주입 가능하도록 끌어올린다.
//
//  PronunciationScoreLevel  : 점수 → 등급(low/middle/high) + 표시 색상/제목
//  PronunciationDifficultyResult : "내가 어려워하는 발음" 카드 한 줄의 표시 데이터
//
//  값 자체(코멘트/가이드/색상) 의 출처는 분석 서비스가 채운다.
//  UI 디자인 자산(사람 아이콘 PNG) 이 카테고리별로 확정될 때까지 imageName 은
//  모두 "error_img_1" 로 fallback (별도 후속 이슈에서 매핑).
//

import SwiftUI

enum PronunciationScoreLevel: String, Equatable, CaseIterable {
    case low
    case middle
    case high

    init(score: Int) {
        if score <= 35 {
            self = .low
        } else if score <= 70 {
            self = .middle
        } else {
            self = .high
        }
    }

    var title: String {
        switch self {
        case .low:    return "연습이 조금 필요해요."
        case .middle: return "조금 더 또박또박 말해볼까요?"
        case .high:   return "발음이 자연스럽고 안정적이예요!"
        }
    }

    var color: Color {
        switch self {
        case .low:    return Color(hex: "#FF3838")
        case .middle: return Color(hex: "#FFF79E")
        case .high:   return Color.main
        }
    }
}

/// "내가 어려워하는 발음" 카드 한 줄. 분석 서비스가 빈도 기준 상위 3개까지 채운다.
/// imageName 은 디자인 자산이 카테고리별로 분리될 때까지 모두 "error_img_1" 로 채워진다.
struct PronunciationDifficultyResult: Identifiable, Equatable {
    let id: String
    let rank: Int
    let category: PronunciationErrorCategory
    let title: String
    let subtitle: String
    let practiceTitle: String
    let guideText: String
    let accentColorHex: String
    let imageName: String
    let errorCount: Int

    var accentColor: Color {
        Color(hex: accentColorHex)
    }
}
