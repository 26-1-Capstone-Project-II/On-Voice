//
//  PronunciationScriptAnalysisService.swift
//  OnVoice
//
//  녹음 전사 결과(PronunciationErrorScript)에 발음 오류 정보를 채워 넣는 서비스.
//
//  다음 작업에서 이 서비스의 구현이 채워질 예정이다. 지금은 분석 알고리즘이
//  확정되지 않았으므로 원본 UI(빨간 하이라이트 + 탭 → popup card)의 시각적
//  골격이 살아있는지 확인할 수 있도록 첫 문장에 데모 errorDetail을 주입한다.
//  실제 분석 로직이 들어오면 이 stub은 통째로 교체된다.
//

import Foundation
import SwiftUI

protocol PronunciationScriptAnalyzing {
    func analyze(
        script: PronunciationErrorScript,
        referenceText: String?
    ) async -> PronunciationErrorScript
}

final class PronunciationScriptAnalysisService: PronunciationScriptAnalyzing {
    func analyze(
        script: PronunciationErrorScript,
        referenceText: String?
    ) async -> PronunciationErrorScript {
        guard !script.sentences.isEmpty else { return script }

        // STEP-2 PLACEHOLDER: 첫 문장만 데모용으로 오류 표시한다.
        // - 자모 정렬 알고리즘이 채워질 때 이 분기는 제거된다.
        // - 데모 표시임을 명확히 하기 위해 태그 라벨에 "데모"를 박아둔다.
        var sentences = script.sentences
        let first = sentences[0]
        let placeholder = Self.makeDemoErrorDetail(forSentence: first)
        let highlighted = Self.injectDemoHighlight(in: first)
        sentences[0] = PronunciationTranscriptSentence(
            segments: highlighted,
            errorDetail: placeholder
        )
        return PronunciationErrorScript(sentences: sentences)
    }

    /// 데모 표시용으로 문장의 첫 어절을 빨간색으로 강조한다.
    /// 사용자가 어떤 문장이 탭 가능한지 시각적으로 확인할 수 있게 하는 임시 표지.
    private static func injectDemoHighlight(
        in sentence: PronunciationTranscriptSentence
    ) -> [PronunciationTextSegment] {
        let joined = sentence.segments.map(\.text).joined()
        let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sentence.segments }

        if let spaceRange = trimmed.firstIndex(of: " ") {
            let firstWord = String(trimmed[..<spaceRange])
            let rest = String(trimmed[spaceRange...])
            return [.error(firstWord), .normal(rest + " ")]
        }

        return [.error(trimmed + " ")]
    }

    private static func makeDemoErrorDetail(
        forSentence sentence: PronunciationTranscriptSentence
    ) -> PronunciationErrorSentence {
        let joined = sentence.segments.map(\.text).joined().trimmingCharacters(in: .whitespaces)

        return PronunciationErrorSentence(
            originalSegments: [.muted(joined)],
            correctSegments: [.normal("올바른 발음 (분석 알고리즘 연결 후 표시)")],
            userAttemptSegments: [.normal(joined)],
            errorTypes: [
                PronunciationErrorType(title: "데모: 분석 준비 중", isDifficult: false)
            ],
            dummyAttempts: []
        )
    }
}
