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
    /// 원본 UI의 다문단 레이아웃을 그대로 유지하기 위해 segment 경계를 기준으로
    /// 한 segment = 한 문단(PronunciationTranscriptSentence) 으로 매핑한다.
    /// errorDetail은 분석 단계에서 채워지므로 이 함수는 normal segment만 만든다.
    static func makePlainScript(from segments: [String]) -> PronunciationErrorScript {
        let cleaned = segments
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // segment가 비어있으면 fallback으로 종결 부호 기반 분할을 시도한다.
        if cleaned.isEmpty {
            return .empty
        }

        let sentences = cleaned.map { paragraph in
            PronunciationTranscriptSentence(segments: [.normal(paragraph + " ")])
        }
        return PronunciationErrorScript(sentences: sentences)
    }

    /// 종결 부호(.?!) 기준 분할이 필요한 경우(예: 외부에서 단일 텍스트만 주어질 때)
    /// 사용하는 헬퍼.
    static func splitIntoSentences(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let terminators: Set<Character> = [".", "?", "!"]
        var sentences: [String] = []
        var current = ""

        for character in trimmed {
            current.append(character)
            if terminators.contains(character) {
                let chunk = current.trimmingCharacters(in: .whitespaces)
                if !chunk.isEmpty {
                    sentences.append(chunk + " ")
                }
                current = ""
            }
        }

        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty {
            sentences.append(tail)
        }

        return sentences
    }
}
