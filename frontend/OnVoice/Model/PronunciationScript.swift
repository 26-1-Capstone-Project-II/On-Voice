//
//  PronunciationScript.swift
//  OnVoice
//
//  발음 스크립트(소리나는 대로 전사) 화면이 사용하는 도메인 모델.
//  PronunciationErrorScriptView가 더미 데이터로 들고 있던 타입을
//  외부에서 주입 가능하도록 끌어올린 것이다.
//

import SwiftUI

enum PronunciationSegmentStatus: Equatable {
    case normal
    case muted
    case error
    case success
    case emphasis
}

struct PronunciationTextSegment: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let status: PronunciationSegmentStatus

    var color: Color {
        switch status {
        case .normal: return Color.sub
        case .muted: return Color.gray6
        case .error: return Color(hex: "#FF3867")
        case .success: return Color.main
        case .emphasis: return Color.main
        }
    }

    static func normal(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, status: .normal)
    }

    static func muted(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, status: .muted)
    }

    static func error(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, status: .error)
    }

    static func success(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, status: .success)
    }

    static func emphasis(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, status: .emphasis)
    }
}

struct PronunciationErrorType: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let isDifficult: Bool
    let accentColor: Color

    init(title: String, isDifficult: Bool, accentColor: Color = Color(hex: "#FFA0A0")) {
        self.title = title
        self.isDifficult = isDifficult
        self.accentColor = accentColor
    }
}

struct PronunciationPracticeAttempt: Identifiable, Equatable {
    let id = UUID()
    let segments: [PronunciationTextSegment]
}

struct PronunciationErrorSentence: Identifiable, Equatable {
    let id = UUID()
    let originalSegments: [PronunciationTextSegment]
    let correctSegments: [PronunciationTextSegment]
    let userAttemptSegments: [PronunciationTextSegment]
    let errorTypes: [PronunciationErrorType]
    let dummyAttempts: [PronunciationPracticeAttempt]
}

struct PronunciationTranscriptSentence: Identifiable, Equatable {
    let id = UUID()
    let segments: [PronunciationTextSegment]
    let errorDetail: PronunciationErrorSentence?

    init(
        segments: [PronunciationTextSegment],
        errorDetail: PronunciationErrorSentence? = nil
    ) {
        self.segments = segments
        self.errorDetail = errorDetail
    }
}

struct PronunciationErrorScript: Equatable {
    let sentences: [PronunciationTranscriptSentence]

    static let empty = PronunciationErrorScript(sentences: [])

    var isEmpty: Bool { sentences.isEmpty }
}

extension PronunciationErrorScript {
    /// Whisper segment 배열을 종결 부호(.?!) 기준으로 문장 단위로 쪼개
    /// 한 문장 = 한 PronunciationTranscriptSentence 로 매핑한다.
    /// 한 Whisper segment 안에 여러 문장이 들어와도 각각 분리되어 화면에서
    /// 문장별로 구별·선택할 수 있게 된다(피그마 5-2, 이슈 #106).
    /// errorDetail 은 분석 단계에서 채워지므로 이 함수는 normal segment만 만든다.
    ///
    /// 분석 파이프라인(`PronunciationScriptAnalysisService`)은 sentence 개수와
    /// 무관하게 cell 을 segment 별로 그룹화하므로, 문장 분할이 더 세분화될수록
    /// errorDetail 도 문장 단위로 더 정밀해진다.
    static func makePlainScript(from segments: [String]) -> PronunciationErrorScript {
        // 각 문장 끝의 " " 는 렌더링 전용 구분자다. FlowingTranscriptTextView 가
        // 모든 문장을 한 NSAttributedString 으로 이어 붙일 때 문장 사이가 붙지 않게
        // 한다(인라인 흐름 유지). 분석 단계는 비-한글(공백)을 무시하므로 점수/정렬에는
        // 영향이 없다. 텍스트를 외부로 복사/저장할 일이 생기면 호출부에서 trim 한다.
        let sentences = segments
            .flatMap { splitIntoSentences($0) }
            .map { PronunciationTranscriptSentence(segments: [.normal($0 + " ")]) }

        return sentences.isEmpty ? .empty : PronunciationErrorScript(sentences: sentences)
    }

    /// 텍스트를 문장 단위로 분할한다. 반환 문자열은 trim 된 상태이며 종결 신호는
    /// 앞 문장에 포함된다(연결 시 호출자가 공백을 덧붙인다).
    ///
    /// 분할 신호는 공백으로 나눈 토큰의 "끝"을 본다:
    ///  - 종결 부호(. ? !)로 끝나는 토큰 → 문장 경계
    ///  - 한국어 종결어미 음절(요/죠/다/야)로 끝나는 토큰 → 문장 경계
    ///
    /// Whisper phonetic 전사는 구두점이 거의 없어 종결 부호만으로는 한 덩어리로
    /// 남는다(이슈 #106 회귀). 그래서 부호가 없는 한국어 음성도 문장으로 나뉘도록
    /// 종결어미 휴리스틱을 함께 쓴다.
    ///
    /// 예외/한계:
    ///  - 토큰 끝만 보므로 소수점(5.5)·약어 내부 마침표는 경계로 잡히지 않는다(안전).
    ///  - "까"는 "아까/이따까" 처럼 종결이 아닌 흔한 단어와 겹쳐 제외했다.
    ///    형식 의문(~습니까)은 못 나누지만, 정중체 의문 "~까요"는 요로 잡힌다.
    ///  - 반말 종결(어/아/지/네 등)은 연결어미·일반어("그렇지 않아", "네 알겠어")와
    ///    혼동되기 쉬워 의도적으로 제외 → 반말 발화는 한 덩어리로 남을 수 있다.
    ///
    /// 정밀도 우선(과분할 < 누락)의 의도적 절충이다. 더 높은 recall 이 필요하면
    /// Apple ASR `addsPunctuation` 결과의 문장 경계를 자모 정렬로 phonetic 에
    /// 매핑하는 방식이 견고하나, 분석 파이프라인 변경 폭이 커 후속 과제로 둔다.
    static func splitIntoSentences(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // 공백/탭/줄바꿈 등 모든 공백류로 토큰을 나눈다(연속 공백은 무시).
        let tokens = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        var sentences: [String] = []
        var current: [String] = []

        for (index, token) in tokens.enumerated() {
            current.append(token)
            let isLast = index == tokens.count - 1
            if !isLast, isSentenceEnd(token) {
                sentences.append(current.joined(separator: " "))
                current = []
            }
        }

        if !current.isEmpty {
            sentences.append(current.joined(separator: " "))
        }

        return sentences
    }

    /// 한국어 종결어미 음절(휴리스틱). 정밀도가 높은 것만 포함하고, 연결어미·일반
    /// 단어와 겹치기 쉬운 음절(까: 아까, 어/아/지/네: 반말)은 과분할 방지를 위해 제외한다.
    ///
    /// 원소는 모두 단일 grapheme cluster(= Swift `Character`) 다. 한글 완성형 음절
    /// "요/죠/다/야" 는 각각 한 Character 이므로 `Set<Character>` 가 정확하다.
    /// `isSentenceEnd` 가 `token.last`(Character) 와 비교하므로 String 집합이 아니라
    /// Character 집합이어야 맞다. NFC/NFD 표기차는 Character 비교가 canonical 이라 무관.
    private static let sentenceFinalSyllables: Set<Character> = ["요", "죠", "다", "야"]

    /// 토큰이 문장 경계로 끝나는지. 끝 문자가 종결 부호이거나 종결어미 음절이면 true.
    private static func isSentenceEnd(_ token: String) -> Bool {
        guard let last = token.last else { return false }
        if last == "." || last == "?" || last == "!" { return true }
        return sentenceFinalSyllables.contains(last)
    }
}
