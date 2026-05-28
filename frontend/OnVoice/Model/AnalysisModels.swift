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
/// 케이스를 세분화해 디버깅/지원 시 권한 거부와 인식 실패를 구분할 수 있게 한다.
/// UI 는 일반화된 메시지를 보여주되, 로그/리포팅은 정확한 사유를 남긴다.
enum AnalysisLimitation: Equatable {
    /// Apple Speech 권한이 부여되지 않아 의도 텍스트 인식이 불가능.
    case speechAuthorizationDenied
    /// 권한은 있으나 SFSpeechRecognizer 가 빈 결과를 돌려준 경우(짧은 발화/잡음 등).
    case intentTextEmpty
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
    /// 발음 분석 리포트 화면(피그마 5-1) 의 도넛 차트에 표시되는 0-100 점수.
    /// 분석 불가 시 0. UI 는 isPronunciationEvaluationAvailable 로 fallback 분기.
    let score: Int
    /// 점수 등급(low/middle/high). UI 색상/제목 매핑에 사용.
    let scoreLevel: PronunciationScoreLevel
    /// 점수 카드 본문 코멘트. 1위 카테고리에 맞춰 자동 생성.
    /// 분석 불가 / 오류 없음 케이스는 등급 기반 fallback.
    let summaryComment: String
    /// "내가 어려워하는 발음" 카드 순위(최대 3개).
    /// 빈 배열이면 fallback UI 표시.
    let difficultyItems: [PronunciationDifficultyResult]

    init(
        transcript: String,
        standardText: String,
        standardPronunciation: String,
        sentences: [AnalysisSentence],
        overallAccuracy: Double,
        isPronunciationEvaluationAvailable: Bool,
        scriptAnalysis: PronunciationErrorScript = .empty,
        transcriptionFailure: TranscriptionFailure? = nil,
        limitation: AnalysisLimitation? = nil,
        score: Int = 0,
        scoreLevel: PronunciationScoreLevel = .low,
        summaryComment: String = "",
        difficultyItems: [PronunciationDifficultyResult] = []
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
        self.score = score
        self.scoreLevel = scoreLevel
        self.summaryComment = summaryComment
        self.difficultyItems = difficultyItems
    }

    var errorSentences: [AnalysisSentence] {
        guard isPronunciationEvaluationAvailable else { return [] }
        return sentences.filter { $0.accuracy < 0.8 }
    }

    // MARK: - Feature-level availability flags
    //
    // transcriptionFailure / limitation 은 "왜 안 되는지" 를 enum 으로 표현하는
    // 부가 정보. UI 분기에서 "기능이 켜져 있나?" 를 직관적으로 보고 싶을 때는
    // 아래 두 플래그가 더 명확하다. 두 플래그는 enum 의 nil 여부로 derive 된다.

    /// 전사(Whisper) 자체가 성공했는가. false 면 사용자에게 실패 화면을 보여준다.
    var isTranscriptionAvailable: Bool {
        transcriptionFailure == nil
    }

    /// 발음 비교(Apple ASR + G2P + 자모 정렬) 까지 활성화되었는가.
    /// false 면 전사는 보이되 오류 하이라이트/분류가 비활성화 — UI 는 안내 배너 노출.
    var isComparisonAvailable: Bool {
        isTranscriptionAvailable && limitation == nil && !scriptAnalysis.isEmpty
    }

    /// 점수/발음 평가가 불가능할 때 그 "사유" 를 하나로 뭉개지 않고 구분한다.
    ///
    /// 기존엔 score=0 + isPronunciationEvaluationAvailable=false 가 전사 실패 /
    /// 권한 거부 / 한글 입력 없음을 모두 같은 fallback 으로 흘려보냈다. 이 derived
    /// 상태는 transcriptionFailure → limitation → 평가 가능 여부 순으로 우선순위를
    /// 매겨 UI/로그가 케이스별로 다른 처리를 할 수 있게 한다.
    ///
    /// 우선순위 근거: 전사가 실패하면 그 외 모든 단계가 무의미하므로 최우선,
    /// 다음으로 비교 비활성(limitation), 마지막으로 "전사·비교는 됐지만 평가할
    /// 한글 음절/정렬 결과가 없는" noEvaluableContent 순이다.
    var evaluationState: PronunciationEvaluationState {
        if let transcriptionFailure {
            return .transcriptionFailed(transcriptionFailure)
        }
        if let limitation {
            return .comparisonUnavailable(limitation)
        }
        if isPronunciationEvaluationAvailable {
            return .available
        }
        return .noEvaluableContent
    }
}

/// 발음 점수/평가의 가용 상태와 그 불가 사유를 구분한다.
/// score=0 fallback 이 "실패" 와 "분석 불가" 를 뭉개지 않도록 UI/로그가
/// 케이스별 메시지를 선택할 수 있게 한다.
enum PronunciationEvaluationState: Equatable {
    /// 점수/난이도가 실제 분석 결과로 채워진 정상 상태.
    case available
    /// Whisper 전사 자체가 실패. 사용자에게 "다시 녹음" 류 안내.
    case transcriptionFailed(TranscriptionFailure)
    /// 전사는 됐으나 발음 비교가 비활성(권한 거부/의도 텍스트 없음 등).
    case comparisonUnavailable(AnalysisLimitation)
    /// 전사·비교는 진행됐으나 평가할 한글 음절/정렬 결과가 없음(예: 외국어/숫자만 발화).
    case noEvaluableContent
}

struct PracticeEvaluationResult {
    let recognizedText: String
    let accuracy: Double
    let isEvaluationAvailable: Bool
}
