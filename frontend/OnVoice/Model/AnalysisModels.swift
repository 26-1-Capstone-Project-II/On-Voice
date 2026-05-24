//
//  AnalysisModels.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Foundation

struct AnalysisWordPiece: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isError: Bool
}

struct AnalysisSentence: Identifiable {
    let id = UUID()
    let index: Int
    let referenceText: String
    let standardPronunciation: String
    let spokenText: String
    let referencePieces: [AnalysisWordPiece]
    let spokenPieces: [AnalysisWordPiece]
    let accuracy: Double
    let isCorrect: Bool
}

/// 전사는 성공했지만 후속 분석이 제약된 사유. transcriptionFailure 와 달리
/// 전사 결과 자체는 화면에 보이지만 오류 하이라이트/분류가 비활성화된다.
enum AnalysisLimitation: Equatable {
    /// Apple ASR 의 의도 텍스트가 비어 있어 G2P 비교가 불가능한 경우.
    /// (권한 거부, 너무 짧은 발화로 SFSpeechRecognizer 가 빈 결과를 돌려준 경우 등)
    case intentTextUnavailable
}

struct AnalysisResult {
    let transcript: String
    let standardText: String
    let standardPronunciation: String
    let sentences: [AnalysisSentence]
    let overallAccuracy: Double
    let isPronunciationEvaluationAvailable: Bool
    let scriptAnalysis: PronunciationErrorScript
    /// 전사 파이프라인이 실패한 경우의 사유. nil이면 전사 자체는 성공한 것으로
    /// 간주한다(빈 결과/분석 미구현 상태는 nil + scriptAnalysis.isEmpty 로 표현).
    let transcriptionFailure: TranscriptionFailure?
    /// 전사는 성공했지만 발음 비교가 비활성화된 사유. nil 이면 정상 분석 모드.
    let limitation: AnalysisLimitation?

    init(
        transcript: String,
        standardText: String,
        standardPronunciation: String,
        sentences: [AnalysisSentence],
        overallAccuracy: Double,
        isPronunciationEvaluationAvailable: Bool,
        scriptAnalysis: PronunciationErrorScript = .empty,
        transcriptionFailure: TranscriptionFailure? = nil,
        limitation: AnalysisLimitation? = nil
    ) {
        self.transcript = transcript
        self.standardText = standardText
        self.standardPronunciation = standardPronunciation
        self.sentences = sentences
        self.overallAccuracy = overallAccuracy
        self.isPronunciationEvaluationAvailable = isPronunciationEvaluationAvailable
        self.scriptAnalysis = scriptAnalysis
        self.transcriptionFailure = transcriptionFailure
        self.limitation = limitation
    }

    var errorSentences: [AnalysisSentence] {
        guard isPronunciationEvaluationAvailable else { return [] }
        return sentences.filter { $0.accuracy < 0.8 }
    }
}

struct PracticeEvaluationResult {
    let recognizedText: String
    let accuracy: Double
    let isEvaluationAvailable: Bool
}
