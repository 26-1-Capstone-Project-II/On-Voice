//
//  PronunciationScoreCalculator.swift
//  OnVoice
//
//  자모 정렬 결과(`AlignmentCell`)에서 발음 점수를 산출한다.
//
//  분모 정책 — 한글 expected 음절 수
//   · 띄어쓰기/구두점이 점수에 영향을 주지 않도록 한글 음절만 분모로 사용.
//   · ASR 이 한글이 아닌 chunk(공백/구두점) 를 흘려도 점수가 흔들리지 않는다.
//
//  분자 정책 — expected 가 있는 cell 중 오류가 없는 cell
//   · `cell.hasError` 는 gap(누락) 과 자모 차이 모두를 True 로 잡으므로
//     "정답 음절" 정의가 자연스럽게 닫힌다.
//
//  cells 는 `PronunciationScriptAnalysisService.alignHangulOnly` 결과로,
//  expected/actual 양쪽 모두 한글로 필터링된 상태가 보장된다.
//

import Foundation

struct PronunciationScoreSummary: Equatable {
    /// 0.0 - 1.0 사이의 정확도. UI 의 도넛 차트 매핑에 사용.
    let accuracy: Double
    /// 0 - 100 사이의 점수(반올림).
    let score: Int
    let level: PronunciationScoreLevel
}

enum PronunciationScoreCalculator {

    /// 한글 expected 음절이 하나도 없을 때 fallback. 분석 자체가 불가능하므로
    /// "분석 불가" 의미로 0/low 를 돌려준다.
    /// 호출자(`SpeechAnalysisService`) 는 이 케이스에서 `isPronunciationEvaluationAvailable`
    /// 을 false 로 두어 화면이 자체 fallback 점수를 쓰도록 한다.
    static let unavailable = PronunciationScoreSummary(
        accuracy: 0,
        score: 0,
        level: .low
    )

    static func compute(cells: [AlignmentCell]) -> PronunciationScoreSummary {
        let expectedCount = cells.reduce(into: 0) { acc, cell in
            if cell.expected != nil { acc += 1 }
        }
        guard expectedCount > 0 else { return unavailable }

        let correctCount = cells.reduce(into: 0) { acc, cell in
            if cell.expected != nil, !cell.hasError { acc += 1 }
        }

        let accuracy = Double(correctCount) / Double(expectedCount)
        let score = Int((accuracy * 100).rounded())
        return PronunciationScoreSummary(
            accuracy: accuracy,
            score: score,
            level: PronunciationScoreLevel(score: score)
        )
    }
}
